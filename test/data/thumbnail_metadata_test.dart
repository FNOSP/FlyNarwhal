import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/data/models/fly_narwhal/thumbnail_metadata.dart';

ThumbnailMetadata metadata({
  ThumbnailTaskStatus status = ThumbnailTaskStatus.completed,
  bool stale = false,
  int intervalMs = 10000,
  int thumbWidth = 320,
  int thumbHeight = 180,
  int tileCols = 10,
  int tileRows = 10,
  int sheetCount = 8,
  int durationMs = 7200000,
  int generation = 1,
}) {
  return ThumbnailMetadata(
    guid: 'guid-1',
    status: status,
    stale: stale,
    intervalMs: intervalMs,
    thumbWidth: thumbWidth,
    thumbHeight: thumbHeight,
    tileCols: tileCols,
    tileRows: tileRows,
    sheetCount: sheetCount,
    durationMs: durationMs,
    generation: generation,
  );
}

void main() {
  group('ThumbnailTaskStatus', () {
    test('maps server strings', () {
      expect(ThumbnailTaskStatus.fromString('NONE'),
          ThumbnailTaskStatus.none);
      expect(ThumbnailTaskStatus.fromString('PENDING'),
          ThumbnailTaskStatus.pending);
      expect(ThumbnailTaskStatus.fromString('IN_PROGRESS'),
          ThumbnailTaskStatus.inProgress);
      expect(ThumbnailTaskStatus.fromString('COMPLETED'),
          ThumbnailTaskStatus.completed);
      expect(ThumbnailTaskStatus.fromString('FAILED'),
          ThumbnailTaskStatus.failed);
      expect(ThumbnailTaskStatus.fromString(null), ThumbnailTaskStatus.none);
      expect(ThumbnailTaskStatus.fromString('bogus'),
          ThumbnailTaskStatus.none);
    });
  });

  group('ThumbnailMetadata readiness', () {
    test('only completed non-stale tasks are ready', () {
      expect(metadata().isReady, isTrue);
      expect(metadata(stale: true).isReady, isFalse);
      expect(metadata(status: ThumbnailTaskStatus.inProgress).isReady,
          isFalse);
      expect(metadata(status: ThumbnailTaskStatus.none).isReady, isFalse);
    });

    test('a zero generation is not ready (nothing was ever generated)', () {
      expect(metadata(generation: 0).isReady, isFalse);
    });

    test('total frames are capped by the layout capacity', () {
      // 7200s / 10s = 720 frames, exactly 8 full sheets.
      expect(metadata().totalFrames, 720);
      // Duration beyond capacity clamps to the sheet capacity.
      expect(metadata(durationMs: 9000000).totalFrames, 800);
      // A short clip keeps at least one frame.
      expect(metadata(durationMs: 3000).totalFrames, 1);
    });
  });

  group('ThumbnailMetadata.frameAt', () {
    test('maps hover time to the 10s slot frame', () {
      final m = metadata();
      final first = m.frameAt(Duration.zero)!;
      expect(first.sheetIndex, 0);
      expect(first.srcRect.left, 0);
      expect(first.srcRect.top, 0);
      expect(first.srcRect.width, 320);
      expect(first.srcRect.height, 180);

      final second = m.frameAt(const Duration(seconds: 10))!;
      expect(second.sheetIndex, 0);
      expect(second.srcRect.left, 320);
      expect(second.srcRect.top, 0);

      final eleventh = m.frameAt(const Duration(seconds: 100))!;
      expect(eleventh.sheetIndex, 0);
      expect(eleventh.srcRect.left, 0);
      expect(eleventh.srcRect.top, 180);
    });

    test('rolls onto the next sheet after 100 frames', () {
      final m = metadata();
      final frame = m.frameAt(const Duration(seconds: 1000))!;
      expect(frame.sheetIndex, 1);
      expect(frame.srcRect.left, 0);
      expect(frame.srcRect.top, 0);
    });

    test('clamps past the end and never reads a phantom cell', () {
      final m = metadata();
      final last = m.frameAt(const Duration(hours: 5))!;
      // 720 frames: last index 719 = sheet 7, cell 19 → col 9, row 1.
      expect(last.sheetIndex, 7);
      expect(last.srcRect.left, 9 * 320);
      expect(last.srcRect.top, 1 * 180);
    });

    test('returns null when previews are unavailable', () {
      expect(metadata(status: ThumbnailTaskStatus.failed)
          .frameAt(const Duration(seconds: 30)), isNull);
      expect(metadata(stale: true).frameAt(const Duration(seconds: 30)),
          isNull);
    });

    test('mid-hover inside a slot stays on the slot frame', () {
      final m = metadata();
      final mid = m.frameAt(const Duration(seconds: 14, milliseconds: 500))!;
      expect(mid.srcRect.left, 320, reason: 'floor(14.5s/10s) = 1');
    });
  });
}
