import '../../data/models/fly_narwhal/index.dart';
import '../../l10n/generated/app_localizations.dart';
import 'thumbnail_error_humanizer.dart';

/// Maps a scan failure's raw server wording to a localized, human-friendly
/// description — same convention as the config save errors' localization.
/// Unrecognized messages fall back to a generic explanation; callers should
/// still show [ThumbnailScanFailure.rawError] alongside it for troubleshooting.
String humanizeThumbnailScanFailure(
    ThumbnailScanFailure failure, AppLocalizations l10n) {
  if (failure.isDirectory) {
    return l10n.thumbnailScanFailureReasonDirInaccessible;
  }
  return humanizeThumbnailRawError(failure.rawError, l10n);
}