import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Disk cache for fetched sprite sheets plus a tiny in-memory cache of decoded
/// images. Files are keyed by sha256(guid) so a regeneration (generation bump)
/// writes new file names and old entries can never be served by mistake.
///
/// Cache misses and I/O errors surface as null or no-ops: the cache is a pure
/// optimization and must never break the hover preview.
final class ThumbnailSpriteCache {
  static const String _directoryName = 'thumbnail_sprites';

  /// ~40-60 movies at the 320px layout (8-15MB per live-action movie).
  static const int _maxBytes = 500 * 1024 * 1024;

  /// A 3200x1800 sheet decodes to ~23MB RGBA. Four sheets (~92MB) cover the
  /// back-and-forth of a hover sweep without re-decoding; two was too few and
  /// caused decode thrashing (sheet evicted before the sweep returns to it),
  /// which starved video playback during fast sweeps.
  static const int _maxDecodedSheets = 4;

  Future<Directory?> _directory() async {
    try {
      final support = await getApplicationSupportDirectory();
      final directory = Directory(path.join(support.path, _directoryName));
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return directory;
    } on Object {
      return null;
    }
  }

  static String _guidHash(String guid) =>
      sha256.convert(guid.codeUnits).toString();

  String _fileName(String guid, int generation, int index) =>
      '${_guidHash(guid)}_g${generation}_$index.jpg';

  Future<Uint8List?> readBytes(
      String guid, int generation, int index) async {
    try {
      final directory = await _directory();
      if (directory == null) return null;
      final file = File(path.join(directory.path, _fileName(guid, generation, index)));
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } on Object {
      return null;
    }
  }

  Future<void> writeBytes(
      String guid, int generation, int index, Uint8List bytes) async {
    try {
      final directory = await _directory();
      if (directory == null) return;
      final file = File(path.join(directory.path, _fileName(guid, generation, index)));
      await file.writeAsBytes(bytes);
      await _evictIfNeeded(directory);
    } on Object {
      // Best-effort optimization; write failures are ignored.
    }
  }

  /// Drop every cached sheet of a guid (called when a regeneration invalidates
  /// the old generation).
  Future<void> purgeGuid(String guid) async {
    try {
      final directory = await _directory();
      if (directory == null) return;
      final prefix = _guidHash(guid);
      await for (final entity in directory.list()) {
        if (entity is File &&
            path.basename(entity.path).startsWith('${prefix}_')) {
          await entity.delete();
        }
      }
    } on Object {
      // Best-effort cleanup; failures are ignored.
    }
  }

  Future<void> _evictIfNeeded(Directory directory) async {
    try {
      final entries = <File, int>{};
      var total = 0;
      await for (final entity in directory.list()) {
        if (entity is! File) continue;
        final size = await entity.length();
        entries[entity] = size;
        total += size;
      }
      if (total <= _maxBytes) return;

      final byAge = entries.keys.toList()
        ..sort((a, b) => _mtimeMillis(a).compareTo(_mtimeMillis(b)));
      for (final file in byAge) {
        if (total <= _maxBytes) break;
        total -= entries[file] ?? 0;
        await file.delete();
      }
    } on Object {
      // Best-effort eviction; failures are ignored.
    }
  }

  static int _mtimeMillis(File file) {
    try {
      return file.lastModifiedSync().millisecondsSinceEpoch;
    } on Object {
      return 0;
    }
  }
}

/// Least-recently-used cache of decoded sprite sheets. Decoding a 3200x1800
/// JPEG is comparatively expensive, so a sheet hovered away and back should
/// not be re-decoded; images are disposed on eviction.
final class ThumbnailDecodedSheetCache {
  final int _maxEntries;
  final LinkedHashMap<String, ui.Image> _images =
      LinkedHashMap<String, ui.Image>();

  ThumbnailDecodedSheetCache(
      {int maxEntries = ThumbnailSpriteCache._maxDecodedSheets})
      : _maxEntries = maxEntries;

  ui.Image? get(String guid, int generation, int index) {
    final key = '$guid#$generation#$index';
    final image = _images.remove(key);
    if (image != null) {
      _images[key] = image; // bump to most-recently-used
    }
    return image;
  }

  /// Membership check that does not disturb LRU order (used by prefetch).
  bool contains(String guid, int generation, int index) {
    return _images.containsKey('$guid#$generation#$index');
  }

  void put(String guid, int generation, int index, ui.Image image) {
    final key = '$guid#$generation#$index';
    final replaced = _images.remove(key);
    if (replaced != null && !identical(replaced, image)) {
      replaced.dispose();
    }
    _images[key] = image;
    // Eviction must not dispose an image a preview is still painting. The
    // caller checks the evicted image against the one currently displayed
    // before disposing it.
  }

  /// Removes and returns the least-recently-used image (caller owns disposal),
  /// or null when the cache is within its limit.
  ui.Image? evictIfNeeded() {
    if (_images.length <= _maxEntries) return null;
    final oldestKey = _images.keys.first;
    return _images.remove(oldestKey);
  }

  void clear() {
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
  }
}
