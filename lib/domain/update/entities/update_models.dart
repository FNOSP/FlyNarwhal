import '../../../core/version/semantic_version.dart';

/// Supported desktop operating systems for update packages.
enum UpdateOperatingSystem { windows, macos, linux }

/// Supported CPU architectures for update packages.
enum UpdateArchitecture { x64, arm64, x86 }

/// Supported package formats for update packages.
enum UpdatePackageType { exe, dmg, deb, rpm, appImage, pacman, zip }

/// Distribution edition encoded in the canonical asset name prefix.
enum UpdateDistributionEdition { setup, portable }

/// Linux package ecosystem inferred from structured os-release fields.
enum LinuxDistributionFamily { debian, rpm, arch, other }

/// Stable reasons why platform detection cannot produce an update target.
enum PlatformInfoFailureReason {
  unsupportedOperatingSystem,
  unsupportedArchitecture,
  architectureProbeFailed,
  linuxDistributionProbeFailed,
}

/// Stable reasons why a release or asset is excluded from selection.
enum UpdateSelectionDiagnosticReason {
  draftRelease,
  prereleaseChannelExcluded,
  invalidVersion,
  versionNotNewer,
  skippedVersion,
  prereleaseContractMismatch,
  unsupportedArchitecture,
  malformedAssetName,
  operatingSystemMismatch,
  architectureMismatch,
  assetVersionMismatch,
  packageMissing,
  invalidSize,
  invalidDigest,
  invalidOfficialUrl,
  invalidPackageType,
  duplicateCanonicalAsset,
}

/// A stable, non-sensitive explanation emitted during candidate selection.
final class UpdateSelectionDiagnostic {
  const UpdateSelectionDiagnostic({
    required this.reason,
    this.versionKey,
  });

  final UpdateSelectionDiagnosticReason reason;
  final String? versionKey;
}

/// Stable reasons why mapped update data violates domain invariants.
enum UpdateModelValidationReason { invalidHttpsUrl, invalidAssetSize }

/// A typed validation result which keeps tolerant JSON mapping migratable.
sealed class UpdateModelValidationResult<T> {
  const UpdateModelValidationResult();
}

/// A validated update model.
final class UpdateModelValidationSuccess<T>
    extends UpdateModelValidationResult<T> {
  const UpdateModelValidationSuccess(this.value);

  final T value;
}

/// A stable validation failure for invalid mapped data.
final class UpdateModelValidationFailure<T>
    extends UpdateModelValidationResult<T> {
  const UpdateModelValidationFailure(this.reason);

  final UpdateModelValidationReason reason;
}

/// Describes the device constraints used to select a release asset.
final class UpdatePlatform {
  const UpdatePlatform({
    required this.operatingSystem,
    required this.architecture,
    required this.packageTypes,
    this.linuxFamily,
    this.executablePath,
    this.appBundlePath,
    this.appImagePath,
    this.isPortable = false,
  });

  final UpdateOperatingSystem operatingSystem;
  final UpdateArchitecture architecture;
  final List<UpdatePackageType> packageTypes;
  final LinuxDistributionFamily? linuxFamily;
  final String? executablePath;
  final String? appBundlePath;
  final String? appImagePath;

  /// True when the Windows app runs from a self-contained portable bundle.
  final bool isPortable;
}

/// Injectable contract for resolving the running desktop environment.
abstract interface class PlatformInfo {
  Future<PlatformInfoResult> detect();
}

/// Result of platform detection without infrastructure exceptions leaking out.
sealed class PlatformInfoResult {
  const PlatformInfoResult();
}

/// Successfully detected update platform information.
final class PlatformInfoSuccess extends PlatformInfoResult {
  const PlatformInfoSuccess(this.platform);

  final UpdatePlatform platform;
}

/// Explicit failure produced when platform detection is not reliable.
final class PlatformInfoFailure extends PlatformInfoResult {
  const PlatformInfoFailure(this.reason);

  final PlatformInfoFailureReason reason;
}

/// A GitHub Release asset which can be downloaded and installed locally.
final class UpdateReleaseAsset {
  const UpdateReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.sizeInBytes,
    required this.digest,
    required this.contentType,
  });

  static final RegExp _sha256DigestExpression =
      RegExp(r'^sha256:([a-fA-F0-9]{64})$');

  final String name;

  /// The official URL mapped from GitHub's browser_download_url field.
  final Uri downloadUrl;
  final int sizeInBytes;

  /// The unmodified digest supplied by the release API.
  final String? digest;
  final String? contentType;

  /// Explicit domain name for the official URL; retained alias aids migration.
  Uri get officialDownloadUrl => downloadUrl;

  /// Explicit domain name for the raw digest; retained alias aids migration.
  String? get rawDigest => digest;

  String? get sha256Digest {
    return _sha256DigestExpression
        .firstMatch(digest ?? '')
        ?.group(1)
        ?.toLowerCase();
  }

  bool get hasValidSha256Digest => sha256Digest != null;

  static UpdateModelValidationResult<UpdateReleaseAsset> validate({
    required String name,
    required Uri officialDownloadUrl,
    required int sizeInBytes,
    required String? rawDigest,
    required String? contentType,
  }) {
    if (!_isHttpsUrl(officialDownloadUrl)) {
      return const UpdateModelValidationFailure<UpdateReleaseAsset>(
        UpdateModelValidationReason.invalidHttpsUrl,
      );
    }
    if (sizeInBytes <= 0) {
      return const UpdateModelValidationFailure<UpdateReleaseAsset>(
        UpdateModelValidationReason.invalidAssetSize,
      );
    }
    return UpdateModelValidationSuccess<UpdateReleaseAsset>(
      UpdateReleaseAsset(
        name: name,
        downloadUrl: officialDownloadUrl,
        sizeInBytes: sizeInBytes,
        digest: rawDigest,
        contentType: contentType,
      ),
    );
  }
}

/// A GitHub Release containing update metadata and distributable assets.
final class UpdateRelease {
  const UpdateRelease({
    required this.tagName,
    required this.displayName,
    required this.releaseNotes,
    required this.htmlUrl,
    required this.isPrerelease,
    required this.isDraft,
    required this.assets,
    this.publishedAt,
  });

  final String tagName;
  final String displayName;
  final String releaseNotes;
  final Uri htmlUrl;
  final bool isPrerelease;
  final bool isDraft;
  final List<UpdateReleaseAsset> assets;
  final DateTime? publishedAt;

  static UpdateModelValidationResult<UpdateRelease> validate({
    required String tagName,
    required String displayName,
    required String releaseNotes,
    required Uri htmlUrl,
    required bool isPrerelease,
    required bool isDraft,
    required List<UpdateReleaseAsset> assets,
    DateTime? publishedAt,
  }) {
    if (!_isHttpsUrl(htmlUrl)) {
      return const UpdateModelValidationFailure<UpdateRelease>(
        UpdateModelValidationReason.invalidHttpsUrl,
      );
    }
    return UpdateModelValidationSuccess<UpdateRelease>(
      UpdateRelease(
        tagName: tagName,
        displayName: displayName,
        releaseNotes: releaseNotes,
        htmlUrl: htmlUrl,
        isPrerelease: isPrerelease,
        isDraft: isDraft,
        assets: List<UpdateReleaseAsset>.unmodifiable(assets),
        publishedAt: publishedAt,
      ),
    );
  }
}

/// One target or intermediate release-note section.
final class UpdateReleaseNotesFragment {
  const UpdateReleaseNotesFragment({
    required this.version,
    required this.markdown,
    required this.releasePageUrl,
    required this.isTargetVersion,
  });

  final SemanticVersion version;
  final String markdown;
  final Uri releasePageUrl;
  final bool isTargetVersion;
}

/// A verified release and package selected for the current desktop platform.
final class UpdateCandidate {
  const UpdateCandidate({
    required this.version,
    this.operatingSystem = UpdateOperatingSystem.windows,
    this.architecture = UpdateArchitecture.x64,
    this.packageType = UpdatePackageType.exe,
    required this.releaseNotes,
    required this.releasePageUrl,
    required this.asset,
    required this.isPrerelease,
    this.releaseNotesFragments = const <UpdateReleaseNotesFragment>[],
  });

  final SemanticVersion version;
  final UpdateOperatingSystem operatingSystem;
  final UpdateArchitecture architecture;
  final UpdatePackageType packageType;
  final String releaseNotes;
  final Uri releasePageUrl;
  final UpdateReleaseAsset asset;
  final bool isPrerelease;
  final List<UpdateReleaseNotesFragment> releaseNotesFragments;

  String get canonicalSha256 => asset.sha256Digest!;
}

bool _isHttpsUrl(Uri url) {
  return url.scheme.toLowerCase() == 'https' && url.host.isNotEmpty;
}
