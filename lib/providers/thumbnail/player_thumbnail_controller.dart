import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/remote/fly_narwhal_remote_data_source.dart';
import '../../data/models/fly_narwhal/index.dart';
import '../../data/storage/fly_narwhal_settings.dart';
import '../../data/storage/thumbnail_sprite_cache.dart';

/// A hover preview: the decoded sheet plus the crop rect of the hovered frame.
class SpritePreview {
  final ui.Image image;
  final ui.Rect srcRect;

  /// thumbWidth / thumbHeight, so the widget can keep the frame aspect.
  final double aspectRatio;

  const SpritePreview({
    required this.image,
    required this.srcRect,
    required this.aspectRatio,
  });
}

/// Player-side sprite previews for one media guid (family provider).
///
/// Fetches the task metadata once per playback session; when the task is
/// COMPLETED on an unchanged file, `previewAt` lazily resolves the hovered
/// frame through the decoded cache → disk cache → network, fetching only the
/// single sheet that covers the hover position. Any failure (404, decode,
/// network) resolves to null: the progress bar simply shows no preview.
class PlayerThumbnailController extends StateNotifier<ThumbnailMetadata?> {
  final FlyNarwhalRemoteDataSource _remoteDataSource;
  final FlyNarwhalSettings _settings;
  final ThumbnailSpriteCache _spriteCache;
  final ThumbnailDecodedSheetCache _decodedCache;
  final String _mediaGuid;

  final Set<int> _failedSheets = <int>{};
  final Set<String> _inFlightPrefetch = <String>{};
  ui.Image? _lastServedImage;
  int _requestToken = 0;
  bool _initialized = false;

  PlayerThumbnailController(
    this._remoteDataSource,
    this._settings,
    this._spriteCache,
    this._decodedCache,
    this._mediaGuid,
  ) : super(null);

  /// Fetch metadata once; only a ready task enables previews.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    if (!_settings.enabled || _mediaGuid.isEmpty) return;
    try {
      final result = await _remoteDataSource.getThumbnailStatus(_mediaGuid);
      final metadata = result.getOrThrow().data;
      if (metadata != null && metadata.isReady) {
        state = metadata;
      }
    } catch (_) {
      // Unavailable server or old route: stay without previews.
    }
  }

  bool get hasPreviews => state?.isReady ?? false;

  Future<SpritePreview?> previewAt(Duration hoverTime) async {
    final metadata = state;
    if (metadata == null || !metadata.isReady) return null;
    final frame = metadata.frameAt(hoverTime);
    if (frame == null) return null;

    final sheet = frame.sheetIndex;
    if (_failedSheets.contains(sheet)) return null;

    final token = _requestToken;
    final generation = metadata.generation;

    final cached = _decodedCache.get(_mediaGuid, generation, sheet);
    if (cached != null) {
      _lastServedImage = cached;
      _prefetchAdjacent(metadata, sheet);
      return _preview(cached, frame, metadata);
    }

    var bytes = await _spriteCache.readBytes(_mediaGuid, generation, sheet);
    if (bytes == null) {
      final fetched = await _remoteDataSource.fetchSpriteBytes(
        guid: _mediaGuid,
        index: sheet,
        generation: generation,
      );
      final data = fetched.dataOrNull;
      if (data == null || data.isEmpty) {
        _failedSheets.add(sheet);
        return null;
      }
      bytes = data;
      await _spriteCache.writeBytes(_mediaGuid, generation, sheet, data);
    }

    // A long hover sweep may have moved on; drop stale resolutions so an old
    // sheet never flashes under the cursor.
    if (token != _requestToken) return null;

    final image = await _decode(bytes);
    if (image == null) {
      _failedSheets.add(sheet);
      return null;
    }
    _decodedCache.put(_mediaGuid, generation, sheet, image);
    _lastServedImage = image;
    _evictProtectingDisplayed();
    if (token != _requestToken) return null;
    _prefetchAdjacent(metadata, sheet);
    return _preview(image, frame, metadata);
  }

  /// Evict over-limit decoded sheets, but never dispose one a preview may
  /// still be painting (the last image served to the progress bar).
  void _evictProtectingDisplayed() {
    final evicted = _decodedCache.evictIfNeeded();
    if (evicted == null) return;
    if (!identical(evicted, _lastServedImage)) {
      evicted.dispose();
    }
  }

  /// Decode the sheets adjacent to the hovered one in the background so a
  /// sweep meets them already decoded instead of paying the decode cost
  /// mid-sweep (the main cause of playback stutter).
  void _prefetchAdjacent(ThumbnailMetadata metadata, int sheet) {
    for (final adjacent in [sheet - 1, sheet + 1]) {
      if (adjacent < 0 || adjacent >= metadata.sheetCount) continue;
      if (_failedSheets.contains(adjacent)) continue;
      if (_decodedCache.contains(_mediaGuid, metadata.generation, adjacent)) {
        continue;
      }
      final key = '$_mediaGuid#${metadata.generation}#$adjacent';
      if (!_inFlightPrefetch.add(key)) continue;
      unawaited(_prefetchSheet(metadata, adjacent, key));
    }
  }

  Future<void> _prefetchSheet(
      ThumbnailMetadata metadata, int sheet, String key) async {
    try {
      var bytes =
          await _spriteCache.readBytes(_mediaGuid, metadata.generation, sheet);
      if (bytes == null) {
        final fetched = await _remoteDataSource.fetchSpriteBytes(
          guid: _mediaGuid,
          index: sheet,
          generation: metadata.generation,
        );
        final data = fetched.dataOrNull;
        if (data == null || data.isEmpty) {
          _failedSheets.add(sheet);
          return;
        }
        bytes = data;
        await _spriteCache.writeBytes(_mediaGuid, metadata.generation, sheet, data);
      }
      if (_decodedCache.contains(_mediaGuid, metadata.generation, sheet)) {
        return; // the user already reached it through the normal path
      }
      final image = await _decode(bytes);
      if (image == null) {
        _failedSheets.add(sheet);
        return;
      }
      _decodedCache.put(_mediaGuid, metadata.generation, sheet, image);
      _evictProtectingDisplayed();
    } finally {
      _inFlightPrefetch.remove(key);
    }
  }

  /// Bump the token so in-flight resolutions resolve to null.
  void cancelInFlight() {
    _requestToken++;
  }

  /// Invalidate everything (e.g. the detail page regenerated the sprites).
  void invalidate() {
    _requestToken++;
    _initialized = false;
    _failedSheets.clear();
    state = null;
    _decodedCache.clear();
  }

  SpritePreview _preview(
      ui.Image image, SpriteFrameRef frame, ThumbnailMetadata metadata) {
    return SpritePreview(
      image: image,
      srcRect: frame.srcRect,
      aspectRatio: metadata.thumbHeight > 0
          ? metadata.thumbWidth / metadata.thumbHeight
          : 16 / 9,
    );
  }

  Future<ui.Image?> _decode(Uint8List bytes) {
    final completer = Completer<ui.Image?>();
    ui.decodeImageFromList(bytes, (image) {
      if (!completer.isCompleted) completer.complete(image);
    });
    return completer.future
        .timeout(const Duration(seconds: 5), onTimeout: () => null)
        .catchError((Object _) => null);
  }

  @override
  void dispose() {
    _decodedCache.clear();
    super.dispose();
  }
}
