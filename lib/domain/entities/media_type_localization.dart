import '../../l10n/generated/app_localizations.dart';
import 'media_type.dart';

/// Localized display label for a [MediaType].
///
/// Kept out of the enum itself so the domain layer stays free of
/// `BuildContext`/localization dependencies.
extension MediaTypeLocalization on MediaType {
  String localizedLabel(AppLocalizations l10n) {
    switch (this) {
      case MediaType.movie:
        return l10n.mediaTypeMovie;
      case MediaType.tv:
        return l10n.mediaTypeTv;
      case MediaType.directory:
        return l10n.mediaTypeDirectory;
      case MediaType.video:
        return l10n.mediaTypeOther;
      case MediaType.liveChannel:
        return l10n.mediaTypeLive;
      case MediaType.episode:
        return l10n.mediaTypeEpisode;
      case MediaType.season:
        return l10n.mediaTypeSeason;
    }
  }
}
