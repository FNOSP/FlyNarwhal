import 'package:fly_narwhal/data/models/fly_narwhal/index.dart';
import 'package:fly_narwhal/l10n/generated/app_localizations_en.dart';
import 'package:fly_narwhal/providers/thumbnail/thumbnail_scan_failure_humanizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = AppLocalizationsEn();

  ThumbnailScanFailure file(String error) => ThumbnailScanFailure(
      filePath: '/vol1/media/a.mp4', rawError: error, kind: ThumbnailScanFailure.kindFile);

  group('humanizeThumbnailScanFailure', () {
    test('maps each known server wording to its own description', () {
      expect(humanizeThumbnailScanFailure(file('media file not found or unreadable: /vol1/media/a.mp4'), l10n),
          l10n.thumbnailScanFailureReasonFileUnreadable);
      expect(humanizeThumbnailScanFailure(file('ffmpeg is not available on the server'), l10n),
          l10n.thumbnailScanFailureReasonFfmpegUnavailable);
      expect(humanizeThumbnailScanFailure(file('cannot read media duration'), l10n),
          l10n.thumbnailScanFailureReasonDurationUnreadable);
      expect(humanizeThumbnailScanFailure(file('media too short for thumbnails (1.2s)'), l10n),
          l10n.thumbnailScanFailureReasonTooShort);
      expect(humanizeThumbnailScanFailure(file('sprite generation timed out after 1800s'), l10n),
          l10n.thumbnailScanFailureReasonTimeout);
      expect(humanizeThumbnailScanFailure(file('sprite generation failed (exit 1): ...'), l10n),
          l10n.thumbnailScanFailureReasonDecodeFailed);
      expect(humanizeThumbnailScanFailure(file('cannot read dimensions of generated sprite sheet /tmp/1.jpg'), l10n),
          l10n.thumbnailScanFailureReasonSheetInvalid);
    });

    test('a directory failure always maps to the inaccessible-directory reason', () {
      const failure = ThumbnailScanFailure(
          filePath: '/vol1/locked', rawError: 'directory is not accessible', kind: ThumbnailScanFailure.kindDirectory);
      expect(humanizeThumbnailScanFailure(failure, l10n), l10n.thumbnailScanFailureReasonDirInaccessible);
    });

    test('an unrecognized message falls back to the generic reason', () {
      expect(humanizeThumbnailScanFailure(file('some unexpected new error'), l10n),
          l10n.thumbnailScanFailureReasonGeneric);
    });
  });
}