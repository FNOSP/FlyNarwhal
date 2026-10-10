import 'dart:math' as math;
import 'dart:ui';

/// Lifecycle of a sprite task on the fly-narwhal server; `none` means the guid
/// was never triggered (the server answers status "NONE").
enum ThumbnailTaskStatus {
  none,
  pending,
  inProgress,
  completed,
  failed;

  static ThumbnailTaskStatus fromString(Object? value) {
    switch (value?.toString().toUpperCase()) {
      case 'PENDING':
        return ThumbnailTaskStatus.pending;
      case 'IN_PROGRESS':
        return ThumbnailTaskStatus.inProgress;
      case 'COMPLETED':
        return ThumbnailTaskStatus.completed;
      case 'FAILED':
        return ThumbnailTaskStatus.failed;
      default:
        return ThumbnailTaskStatus.none;
    }
  }

  bool get isTerminal =>
      this == ThumbnailTaskStatus.completed || this == ThumbnailTaskStatus.failed;
}

/// Which sprite sheet and which cell inside it hold the frame for a hover time.
class SpriteFrameRef {
  final int sheetIndex;
  final Rect srcRect;

  const SpriteFrameRef({required this.sheetIndex, required this.srcRect});
}

/// Sprite layout of one media guid, exactly as the server persists it. The
/// client never hardcodes tile sizes — it crops from these fields.
class ThumbnailMetadata {
  final String guid;
  final ThumbnailTaskStatus status;
  final bool stale;
  final int intervalMs;
  final int thumbWidth;
  final int thumbHeight;
  final int tileCols;
  final int tileRows;
  final int sheetCount;
  final int durationMs;
  final int generation;
  final String? error;

  const ThumbnailMetadata({
    required this.guid,
    this.status = ThumbnailTaskStatus.none,
    this.stale = false,
    this.intervalMs = 0,
    this.thumbWidth = 0,
    this.thumbHeight = 0,
    this.tileCols = 0,
    this.tileRows = 0,
    this.sheetCount = 0,
    this.durationMs = 0,
    this.generation = 0,
    this.error,
  });

  factory ThumbnailMetadata.fromJson(Map<String, dynamic> json) {
    return ThumbnailMetadata(
      guid: json['guid']?.toString() ?? '',
      status: ThumbnailTaskStatus.fromString(json['status']),
      stale: json['stale'] == true,
      intervalMs: _readInt(json['intervalMs']),
      thumbWidth: _readInt(json['thumbWidth']),
      thumbHeight: _readInt(json['thumbHeight']),
      tileCols: _readInt(json['tileCols']),
      tileRows: _readInt(json['tileRows']),
      sheetCount: _readInt(json['sheetCount']),
      durationMs: _readInt(json['durationMs']),
      generation: _readInt(json['generation']),
      error: json['error']?.toString(),
    );
  }

  /// Previews are only usable once generation finished on an unchanged file.
  bool get isReady =>
      status == ThumbnailTaskStatus.completed && !stale && _layoutComplete;

  bool get _layoutComplete =>
      intervalMs > 0 &&
      thumbWidth > 0 &&
      thumbHeight > 0 &&
      tileCols > 0 &&
      tileRows > 0 &&
      sheetCount > 0 &&
      generation > 0;

  /// Total addressable frames: the layout's capacity, capped by the duration so
  /// a partially filled last sheet is never read past its real cells.
  int get totalFrames {
    if (!_layoutComplete) return 0;
    final capacity = sheetCount * tileCols * tileRows;
    final fromDuration = (durationMs + intervalMs - 1) ~/ intervalMs;
    return math.max(1, math.min(capacity, fromDuration));
  }

  /// Hover time → sheet index + crop rect. Returns null when previews are not
  /// usable or the time is outside the media.
  SpriteFrameRef? frameAt(Duration hoverTime) {
    if (!isReady || hoverTime.isNegative) return null;
    final frames = totalFrames;
    if (frames <= 0) return null;
    final frameIdx = math.min(hoverTime.inMilliseconds ~/ intervalMs, frames - 1);
    final perSheet = tileCols * tileRows;
    final sheet = frameIdx ~/ perSheet;
    final cell = frameIdx % perSheet;
    final col = cell % tileCols;
    final row = cell ~/ tileCols;
    return SpriteFrameRef(
      sheetIndex: sheet,
      srcRect: Rect.fromLTWH(
        col * thumbWidth.toDouble(),
        row * thumbHeight.toDouble(),
        thumbWidth.toDouble(),
        thumbHeight.toDouble(),
      ),
    );
  }
}

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
