import '../../data/models/fly_narwhal/index.dart';
import '../../l10n/generated/app_localizations.dart';

/// Maps a scan failure's raw server wording to a localized, human-friendly
/// description — same convention as the config save errors' localization.
/// Unrecognized messages fall back to a generic explanation; callers should
/// still show [ThumbnailScanFailure.rawError] alongside it for troubleshooting.
String humanizeThumbnailScanFailure(
    ThumbnailScanFailure failure, AppLocalizations l10n) {
  if (failure.isDirectory) {
    return l10n.thumbnailScanFailureReasonDirInaccessible;
  }
  final message = failure.rawError.trim();
  if (message.startsWith('media file not found or unreadable')) {
    return l10n.thumbnailScanFailureReasonFileUnreadable;
  }
  switch (message) {
    case 'ffmpeg is not available on the server':
      return l10n.thumbnailScanFailureReasonFfmpegUnavailable;
    case 'cannot read media duration':
      return l10n.thumbnailScanFailureReasonDurationUnreadable;
  }
  if (message.startsWith('media too short for thumbnails')) {
    return l10n.thumbnailScanFailureReasonTooShort;
  }
  if (message.startsWith('sprite generation timed out after')) {
    return l10n.thumbnailScanFailureReasonTimeout;
  }
  if (message.startsWith('sprite generation failed (exit')) {
    return l10n.thumbnailScanFailureReasonDecodeFailed;
  }
  if (message.startsWith('cannot read dimensions of generated sprite sheet')) {
    return l10n.thumbnailScanFailureReasonSheetInvalid;
  }
  return l10n.thumbnailScanFailureReasonGeneric;
}