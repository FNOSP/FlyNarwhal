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
  /// `guid#generation#sheet` → the in-flight load of that sheet, so the main
  /// hover path and the prefetcher share one fetch and one decode.
  final Map<String, Future<ui.Image?>> _inFlightDecodes = {};
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

  /// Fetch metadata once; only a ready task enables previews. Pass [filePath]
  /// (the local NAS path being played) when known: a server >= 2.1.0 then
  /// adopts sprites its scheduled scan generated for the same file, so a video
  /// the user never manually triggered still gets hover previews.
  Future<void> init({String? filePath}) async {
    if (_initialized) return;
    _initialized = true;
    if (!_settings.enabled || _mediaGuid.isEmpty) return;
    try {
      final result = await _remoteDataSource.getThumbnailStatus(_mediaGuid,
          filePath: filePath);
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

    final image = await _loadSheet(metadata, sheet);
    if (image == null) return null;

    // A long hover sweep may have moved on; drop stale resolutions so an old
    // sheet never flashes under the cursor.
    if (token != _requestToken) return null;

    _lastServedImage = image;
    _prefetchAdjacent(metadata, sheet);
    return _preview(image, frame, metadata);
  }

  /// Resolve one sheet to a decoded image, sharing the work with any concurrent
  /// caller for the same sheet.
  ///
  /// A hover sweep can hit the same sheet many times before the first fetch or
  /// decode finishes; without this the disk miss repeats and each pass fires
  /// its own request. The in-flight future is keyed per sheet so the main path
  /// and the prefetch path also collapse onto one another.
  Future<ui.Image?> _loadSheet(ThumbnailMetadata metadata, int sheet) {
    final generation = metadata.generation;
    final key = '$_mediaGuid#$generation#$sheet';
    final pending = _inFlightDecodes[key];
    if (pending != null) return pending;

    final future = _resolveSheet(metadata, sheet).whenComplete(() {
      _inFlightDecodes.remove(key);
    });
    _inFlightDecodes[key] = future;
    return future;
  }

  Future<ui.Image?> _resolveSheet(ThumbnailMetadata metadata, int sheet) async {
    final generation = metadata.generation;

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

    final image = await _decode(bytes);
    if (image == null) {
      _failedSheets.add(sheet);
      return null;
    }
    _decodedCache.put(_mediaGuid, generation, sheet, image);
    _evictProtectingDisplayed();
    return image;
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
      if (_inFlightDecodes.containsKey(key)) continue;
      unawaited(_loadSheet(metadata, adjacent));
    }
  }

  /// Bump the token so in-flight resolutions resolve to null.
  void cancelInFlight() {
    _requestToken++;
  }

  /// Drop every decoded sheet, disposing all but the one the progress bar may
  /// still be painting.
  ///
  /// Called when the on-disk sheets are being cleared (the settings page) and
  /// when the sprites themselves were regenerated. [clear] would dispose the
  /// live image too, which throws inside `drawImageRect` on the next frame;
  /// [_lastServedImage] is the one image we know can still be on screen. It is
  /// dropped from the cache without disposal and left to the GC.
  void dropDecodedSheets() {
    final taken = _decodedCache.takeAll();
    for (final entry in taken.entries) {
      if (!identical(entry.value, _lastServedImage)) {
        entry.value.dispose();
      }
    }
    _lastServedImage = null;
  }

  /// Invalidate everything (e.g. the detail page regenerated the sprites).
  void invalidate() {
    _requestToken++;
    _initialized = false;
    _failedSheets.clear();
    state = null;
    dropDecodedSheets();
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
