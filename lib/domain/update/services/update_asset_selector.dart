import '../../../core/version/semantic_version.dart';
import '../entities/update_models.dart';

/// Parsed fields from a canonical Flutter 2.x release asset name.
final class CanonicalUpdateAssetName {
  const CanonicalUpdateAssetName({
    required this.edition,
    required this.operatingSystem,
    required this.architecture,
    required this.version,
    required this.packageType,
  });

  final UpdateDistributionEdition edition;
  final UpdateOperatingSystem operatingSystem;
  final UpdateArchitecture architecture;
  final SemanticVersion version;
  final UpdatePackageType packageType;
}

/// Strictly parses the published Flutter 2.x asset naming contract.
final class CanonicalUpdateAssetNameParser {
  const CanonicalUpdateAssetNameParser();

  static final RegExp _expression = RegExp(
    r'^FlyNarwhal_(Setup|Portable)_(Windows|MacOS|Linux)_(amd64|aarch64)_([^/]+)\.(exe|dmg|deb|rpm|AppImage|pkg\.tar\.zst|zip)$',
    caseSensitive: false,
  );

  CanonicalUpdateAssetName? tryParse(String assetName) {
    final match = _expression.firstMatch(assetName);
    if (match == null) {
      return null;
    }
    final edition = _parseEdition(match.group(1)!);
    final operatingSystem = _parseOperatingSystem(match.group(2)!);
    final architecture = _parseArchitecture(match.group(3)!);
    final version = SemanticVersion.tryParse(match.group(4)!);
    final packageType = _parsePackageType(match.group(5)!);
    if (edition == null ||
        operatingSystem == null ||
        architecture == null ||
        version == null ||
        packageType == null ||
        !_isValidCombination(operatingSystem, edition, packageType)) {
      return null;
    }
    return CanonicalUpdateAssetName(
      edition: edition,
      operatingSystem: operatingSystem,
      architecture: architecture,
      version: version,
      packageType: packageType,
    );
  }

  UpdateDistributionEdition? _parseEdition(String value) {
    return switch (value.toLowerCase()) {
      'setup' => UpdateDistributionEdition.setup,
      'portable' => UpdateDistributionEdition.portable,
      _ => null,
    };
  }

  UpdateOperatingSystem? _parseOperatingSystem(String value) {
    return switch (value.toLowerCase()) {
      'windows' => UpdateOperatingSystem.windows,
      'macos' => UpdateOperatingSystem.macos,
      'linux' => UpdateOperatingSystem.linux,
      _ => null,
    };
  }

  UpdateArchitecture? _parseArchitecture(String value) {
    return switch (value.toLowerCase()) {
      'amd64' => UpdateArchitecture.x64,
      'aarch64' => UpdateArchitecture.arm64,
      _ => null,
    };
  }

  UpdatePackageType? _parsePackageType(String value) {
    return switch (value.toLowerCase()) {
      'exe' => UpdatePackageType.exe,
      'dmg' => UpdatePackageType.dmg,
      'deb' => UpdatePackageType.deb,
      'rpm' => UpdatePackageType.rpm,
      'appimage' => UpdatePackageType.appImage,
      'pkg.tar.zst' => UpdatePackageType.pacman,
      'zip' => UpdatePackageType.zip,
      _ => null,
    };
  }

  bool _isValidCombination(
    UpdateOperatingSystem operatingSystem,
    UpdateDistributionEdition edition,
    UpdatePackageType packageType,
  ) {
    if (edition == UpdateDistributionEdition.portable) {
      // Only Windows publishes a portable edition bundle today.
      return operatingSystem == UpdateOperatingSystem.windows &&
          packageType == UpdatePackageType.zip;
    }
    return switch (operatingSystem) {
      UpdateOperatingSystem.windows => packageType == UpdatePackageType.exe,
      UpdateOperatingSystem.macos => packageType == UpdatePackageType.dmg,
      UpdateOperatingSystem.linux => packageType == UpdatePackageType.deb ||
          packageType == UpdatePackageType.rpm ||
          packageType == UpdatePackageType.appImage ||
          packageType == UpdatePackageType.pacman,
    };
  }
}

/// Asset-level selection result with a stable exclusion reason.
final class UpdateAssetSelectionResult {
  const UpdateAssetSelectionResult({this.asset, this.reason});

  final UpdateReleaseAsset? asset;
  final UpdateAssetExclusionReason? reason;
}

/// Stable reasons why no canonical asset can be selected.
enum UpdateAssetExclusionReason {
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

/// Selects one complete canonical release package for a desktop platform.
final class UpdateAssetSelector {
  const UpdateAssetSelector({
    CanonicalUpdateAssetNameParser parser =
        const CanonicalUpdateAssetNameParser(),
  }) : _parser = parser;

  final CanonicalUpdateAssetNameParser _parser;

  UpdateAssetSelectionResult select({
    required List<UpdateReleaseAsset> assets,
    required SemanticVersion releaseVersion,
    required UpdatePlatform platform,
  }) {
    if (platform.architecture == UpdateArchitecture.x86) {
      return const UpdateAssetSelectionResult(
        reason: UpdateAssetExclusionReason.unsupportedArchitecture,
      );
    }

    var observedReason = UpdateAssetExclusionReason.packageMissing;
    for (final packageType in platform.packageTypes) {
      final matchingAssets = <UpdateReleaseAsset>[];
      for (final asset in assets) {
        final parsedName = _parser.tryParse(asset.name);
        if (parsedName == null) {
          observedReason = _selectMoreSpecificReason(
            observedReason,
            UpdateAssetExclusionReason.malformedAssetName,
          );
          continue;
        }
        if (parsedName.operatingSystem != platform.operatingSystem) {
          observedReason = _selectMoreSpecificReason(
            observedReason,
            UpdateAssetExclusionReason.operatingSystemMismatch,
          );
          continue;
        }
        if (parsedName.architecture != platform.architecture) {
          observedReason = _selectMoreSpecificReason(
            observedReason,
            UpdateAssetExclusionReason.architectureMismatch,
          );
          continue;
        }
        if (parsedName.version.compareTo(releaseVersion) != 0) {
          observedReason = _selectMoreSpecificReason(
            observedReason,
            UpdateAssetExclusionReason.assetVersionMismatch,
          );
          continue;
        }
        if (parsedName.packageType != packageType) {
          continue;
        }
        final integrityReason = _validateIntegrity(asset, packageType);
        if (integrityReason != null) {
          observedReason = integrityReason;
          continue;
        }
        matchingAssets.add(asset);
      }

      // Duplicate canonical packages make release behavior non-deterministic.
      if (matchingAssets.length > 1) {
        return const UpdateAssetSelectionResult(
          reason: UpdateAssetExclusionReason.duplicateCanonicalAsset,
        );
      }
      if (matchingAssets.length == 1) {
        return UpdateAssetSelectionResult(asset: matchingAssets.single);
      }
    }
    return UpdateAssetSelectionResult(reason: observedReason);
  }

  /// Compatibility API retained for M01 callers while production policy uses select.
  UpdateReleaseAsset? selectAsset({
    required List<UpdateReleaseAsset> assets,
    required UpdatePlatform platform,
  }) {
    for (final asset in assets) {
      final parsedName = _parser.tryParse(asset.name);
      if (parsedName == null) {
        continue;
      }
      final result = select(
        assets: assets,
        releaseVersion: parsedName.version,
        platform: platform,
      );
      return result.asset;
    }
    return null;
  }

  UpdateAssetExclusionReason? _validateIntegrity(
    UpdateReleaseAsset asset,
    UpdatePackageType packageType,
  ) {
    if (asset.sizeInBytes <= 0) {
      return UpdateAssetExclusionReason.invalidSize;
    }
    if (!asset.hasValidSha256Digest) {
      return UpdateAssetExclusionReason.invalidDigest;
    }
    if (!_isOfficialReleaseAssetUrl(asset.officialDownloadUrl)) {
      return UpdateAssetExclusionReason.invalidOfficialUrl;
    }
    if (!_isValidContentType(asset.contentType, packageType)) {
      return UpdateAssetExclusionReason.invalidPackageType;
    }
    return null;
  }

  UpdateAssetExclusionReason _selectMoreSpecificReason(
    UpdateAssetExclusionReason currentReason,
    UpdateAssetExclusionReason candidateReason,
  ) {
    return _reasonPriority(candidateReason) >= _reasonPriority(currentReason)
        ? candidateReason
        : currentReason;
  }

  int _reasonPriority(UpdateAssetExclusionReason reason) {
    return switch (reason) {
      UpdateAssetExclusionReason.packageMissing => 0,
      UpdateAssetExclusionReason.malformedAssetName => 1,
      UpdateAssetExclusionReason.operatingSystemMismatch => 2,
      UpdateAssetExclusionReason.architectureMismatch => 3,
      UpdateAssetExclusionReason.assetVersionMismatch => 4,
      UpdateAssetExclusionReason.invalidSize => 5,
      UpdateAssetExclusionReason.invalidDigest => 6,
      UpdateAssetExclusionReason.invalidOfficialUrl => 7,
      UpdateAssetExclusionReason.invalidPackageType => 8,
      UpdateAssetExclusionReason.duplicateCanonicalAsset => 9,
      UpdateAssetExclusionReason.unsupportedArchitecture => 10,
    };
  }

  bool _isOfficialReleaseAssetUrl(Uri url) {
    final segments = url.pathSegments;
    return url.scheme == 'https' &&
        url.host.toLowerCase() == 'github.com' &&
        segments.length >= 6 &&
        segments[0] == 'FNOSP' &&
        segments[1] == 'FlyNarwhal' &&
        segments[2] == 'releases' &&
        segments[3] == 'download' &&
        segments[4].isNotEmpty &&
        segments.skip(5).every((segment) => segment.isNotEmpty) &&
        !url.hasQuery &&
        !url.hasFragment &&
        url.userInfo.isEmpty;
  }

  bool _isValidContentType(
    String? contentType,
    UpdatePackageType packageType,
  ) {
    if (contentType == null || contentType.isEmpty) {
      return false;
    }
    final normalized = contentType.toLowerCase().split(';').first.trim();
    const commonBinaryTypes = <String>{
      'application/octet-stream',
      'binary/octet-stream',
    };
    if (commonBinaryTypes.contains(normalized)) {
      return true;
    }
    return switch (packageType) {
      UpdatePackageType.exe =>
        normalized == 'application/vnd.microsoft.portable-executable' ||
            normalized == 'application/x-msdownload' ||
            normalized == 'application/x-msdos-program',
      UpdatePackageType.dmg => normalized == 'application/x-apple-diskimage',
      UpdatePackageType.deb =>
        normalized == 'application/vnd.debian.binary-package' ||
            normalized == 'application/x-debian-package',
      UpdatePackageType.rpm => normalized == 'application/x-rpm',
      UpdatePackageType.appImage => normalized == 'application/vnd.appimage',
      UpdatePackageType.pacman =>
        normalized == 'application/zstd' ||
            normalized == 'application/x-xz' ||
            normalized == 'application/x-tar',
      UpdatePackageType.zip =>
        normalized == 'application/zip' ||
            normalized == 'application/x-zip-compressed',
    };
  }
}
