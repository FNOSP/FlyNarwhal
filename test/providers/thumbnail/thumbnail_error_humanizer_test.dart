import 'package:fly_narwhal/l10n/generated/app_localizations_en.dart';
import 'package:fly_narwhal/providers/thumbnail/thumbnail_error_humanizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = AppLocalizationsEn();

  group('humanizeThumbnailError', () {
    test('maps each stable code to its own description', () {
      expect(
          humanizeThumbnailError(
              ThumbnailErrorCodes.ffmpegUnavailable, null, l10n),
          l10n.thumbnailScanFailureReasonFfmpegUnavailable);
      expect(
          humanizeThumbnailError(ThumbnailErrorCodes.fileUnreadable, null, l10n),
          l10n.thumbnailScanFailureReasonFileUnreadable);
      expect(
          humanizeThumbnailError(
              ThumbnailErrorCodes.durationUnreadable, null, l10n),
          l10n.thumbnailScanFailureReasonDurationUnreadable);
      expect(humanizeThumbnailError(ThumbnailErrorCodes.tooShort, null, l10n),
          l10n.thumbnailScanFailureReasonTooShort);
      expect(humanizeThumbnailError(ThumbnailErrorCodes.timeout, null, l10n),
          l10n.thumbnailScanFailureReasonTimeout);
      expect(
          humanizeThumbnailError(ThumbnailErrorCodes.decodeFailed, null, l10n),
          l10n.thumbnailScanFailureReasonDecodeFailed);
      expect(
          humanizeThumbnailError(ThumbnailErrorCodes.sheetInvalid, null, l10n),
          l10n.thumbnailScanFailureReasonSheetInvalid);
    });

    test('the code wins over a raw message that would map elsewhere', () {
      expect(
          humanizeThumbnailError(ThumbnailErrorCodes.timeout,
              'cannot read media duration', l10n),
          l10n.thumbnailScanFailureReasonTimeout);
    });

    test('an older server sends no code, so the wording still identifies it', () {
      expect(
          humanizeThumbnailError(
              null, 'media file not found or unreadable: /vol1/a.mp4', l10n),
          l10n.thumbnailScanFailureReasonFileUnreadable);
      expect(
          humanizeThumbnailError(
              null, 'sprite generation timed out after 1800s', l10n),
          l10n.thumbnailScanFailureReasonTimeout);
    });

    test('an unknown code falls back to the wording', () {
      expect(
          humanizeThumbnailError(
              'some_future_code', 'cannot read media duration', l10n),
          l10n.thumbnailScanFailureReasonDurationUnreadable);
    });

    test('the unknown code with an unrecognized message is generic', () {
      expect(
          humanizeThumbnailError(ThumbnailErrorCodes.unknown,
              '/var/apps/other: AccessDeniedException', l10n),
          l10n.thumbnailScanFailureReasonGeneric);
    });

    test('no code and no message is generic, never a crash', () {
      expect(humanizeThumbnailError(null, null, l10n),
          l10n.thumbnailScanFailureReasonGeneric);
      expect(humanizeThumbnailError(null, '   ', l10n),
          l10n.thumbnailScanFailureReasonGeneric);
    });

    test('the server restart wording is not shown as a raw English failure', () {
      // The backend no longer writes this, but rows from older versions still
      // carry it; it must not reach the user as English text.
      expect(
          humanizeThumbnailError(null, 'interrupted by server restart', l10n),
          isNot(contains('interrupted')));
    });
  });
}