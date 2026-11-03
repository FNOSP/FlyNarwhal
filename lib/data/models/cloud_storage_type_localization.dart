import '../../l10n/generated/app_localizations.dart';
import 'cloud_storage_type.dart';

/// Localized display name for a [CloudStorageType].
///
/// Providers with a brand name that is identical in every language fall back
/// to the enum's own ASCII label.
extension CloudStorageTypeLocalization on CloudStorageType {
  String localizedLabel(AppLocalizations l10n) {
    switch (this) {
      case CloudStorageType.baiduPan:
        return l10n.cloudStorageBaiduPan;
      case CloudStorageType.aliPan:
        return l10n.cloudStorageAliyunDrive;
      case CloudStorageType.oneOneFivePan:
        return l10n.cloudStorage115;
      case CloudStorageType.quarkPan:
        return l10n.cloudStorageQuark;
      case CloudStorageType.oneTwoThreePan:
        return l10n.cloudStorage123;
      case CloudStorageType.oneDrivePan:
      case CloudStorageType.googleDrivePan:
      case CloudStorageType.dropboxPan:
      case CloudStorageType.oneDriveBusiness:
      case CloudStorageType.oneDrivePersonal:
      case CloudStorageType.strm:
      case CloudStorageType.unknown:
        return displayLabel;
    }
  }
}
