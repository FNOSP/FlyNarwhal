import '../../l10n/generated/app_localizations.dart';

/// Stable failure codes the server sends as `ThumbnailStatusResponse.errorCode`
/// (server >= 2.1.4). Mirrors the backend's ThumbnailErrorCode wire names; the
/// raw English text stays available separately for troubleshooting.
class ThumbnailErrorCodes {
  const ThumbnailErrorCodes._();

  static const String ffmpegUnavailable = 'ffmpeg_unavailable';
  static const String fileUnreadable = 'file_unreadable';
  static const String durationUnreadable = 'duration_unreadable';
  static const String tooShort = 'too_short';
  static const String timeout = 'timeout';
  static const String decodeFailed = 'decode_failed';
  static const String sheetInvalid = 'sheet_invalid';
  static const String unknown = 'unknown';
}

/// Localized reason for a failed sprite task. Prefers the stable [code]; older
/// servers send none, so it falls back to matching the raw wording. Callers
/// should keep [rawError] reachable (the detail dialog) rather than show it in
/// place of this text.
String humanizeThumbnailError(
    String? code, String? rawError, AppLocalizations l10n) {
  switch (code) {
    case ThumbnailErrorCodes.ffmpegUnavailable:
      return l10n.thumbnailScanFailureReasonFfmpegUnavailable;
    case ThumbnailErrorCodes.fileUnreadable:
      return l10n.thumbnailScanFailureReasonFileUnreadable;
    case ThumbnailErrorCodes.durationUnreadable:
      return l10n.thumbnailScanFailureReasonDurationUnreadable;
    case ThumbnailErrorCodes.tooShort:
      return l10n.thumbnailScanFailureReasonTooShort;
    case ThumbnailErrorCodes.timeout:
      return l10n.thumbnailScanFailureReasonTimeout;
    case ThumbnailErrorCodes.decodeFailed:
      return l10n.thumbnailScanFailureReasonDecodeFailed;
    case ThumbnailErrorCodes.sheetInvalid:
      return l10n.thumbnailScanFailureReasonSheetInvalid;
  }
  // No code, or one this client does not know yet: the wording still identifies
  // every reason the server has ever reported.
  return humanizeThumbnailRawError(rawError ?? '', l10n);
}

/// Matches the server's raw failure wording. Shared by the task and scan-run
/// surfaces so both describe the same failure identically. Prefix matching
/// because most messages carry a suffix (path, exit code, elapsed seconds).
String humanizeThumbnailRawError(String rawError, AppLocalizations l10n) {
  final message = rawError.trim();
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