import '../../../core/version/semantic_version.dart';
import '../../../core/version/version_parser.dart';
import '../entities/update_models.dart';
import 'update_asset_selector.dart';

/// Candidate selection result with stable exclusion diagnostics.
final class UpdatePolicyResult {
  const UpdatePolicyResult(
      {required this.candidate, required this.diagnostics});

  final UpdateCandidate? candidate;
  final List<UpdateSelectionDiagnostic> diagnostics;
}

/// Applies version, channel, skip-list, and strict platform policy.
final class UpdatePolicy {
  const UpdatePolicy(this._assetSelector);

  final UpdateAssetSelector _assetSelector;

  UpdateCandidate? selectCandidate({
    required List<UpdateRelease> releases,
    required SemanticVersion currentVersion,
    required UpdatePlatform platform,
    required bool includePrerelease,
    required Set<String> skippedVersions,
  }) {
    return evaluate(
      releases: releases,
      currentVersion: currentVersion,
      platform: platform,
      includePrerelease: includePrerelease,
      skippedVersions: skippedVersions,
    ).candidate;
  }

  UpdatePolicyResult evaluate({
    required List<UpdateRelease> releases,
    required SemanticVersion currentVersion,
    required UpdatePlatform platform,
    required bool includePrerelease,
    required Set<String> skippedVersions,
  }) {
    final diagnostics = <UpdateSelectionDiagnostic>[];
    final eligibleReleases =
        <({UpdateRelease release, SemanticVersion version})>[];

    for (final release in releases) {
      final parsedVersion = VersionParser.parseReleaseVersion(
        tagName: release.tagName,
        displayName: release.displayName,
      );

      if (release.isDraft) {
        diagnostics.add(const UpdateSelectionDiagnostic(
          reason: UpdateSelectionDiagnosticReason.draftRelease,
        ));
        continue;
      }
      if (!includePrerelease && release.isPrerelease) {
        diagnostics.add(const UpdateSelectionDiagnostic(
          reason: UpdateSelectionDiagnosticReason.prereleaseChannelExcluded,
        ));
        continue;
      }
      final version = parsedVersion;
      if (version == null) {
        diagnostics.add(const UpdateSelectionDiagnostic(
          reason: UpdateSelectionDiagnosticReason.invalidVersion,
        ));
        continue;
      }
      if (release.isPrerelease != version.isPreRelease) {
        diagnostics.add(UpdateSelectionDiagnostic(
          reason: UpdateSelectionDiagnosticReason.prereleaseContractMismatch,
          versionKey: version.skipKey,
        ));
      }
      if (version.compareTo(currentVersion) <= 0) {
        diagnostics.add(UpdateSelectionDiagnostic(
          reason: UpdateSelectionDiagnosticReason.versionNotNewer,
          versionKey: version.skipKey,
        ));
        continue;
      }
      if (skippedVersions.contains(version.skipKey)) {
        diagnostics.add(UpdateSelectionDiagnostic(
          reason: UpdateSelectionDiagnosticReason.skippedVersion,
          versionKey: version.skipKey,
        ));
        continue;
      }
      eligibleReleases.add((release: release, version: version));
    }

    // Scan newest first so an incomplete release falls back deterministically.
    eligibleReleases.sort(
      (left, right) => right.version.compareTo(left.version),
    );
    for (final eligibleRelease in eligibleReleases) {
      final selection = _assetSelector.select(
        assets: eligibleRelease.release.assets,
        releaseVersion: eligibleRelease.version,
        platform: platform,
      );
      if (selection.asset == null) {
        diagnostics.add(UpdateSelectionDiagnostic(
          reason: _mapAssetReason(selection.reason!),
          versionKey: eligibleRelease.version.skipKey,
        ));
        continue;
      }
      return UpdatePolicyResult(
        candidate: UpdateCandidate(
          version: eligibleRelease.version,
          releaseNotes: eligibleRelease.release.releaseNotes,
          releasePageUrl: eligibleRelease.release.htmlUrl,
          asset: selection.asset!,
          isPrerelease: eligibleRelease.release.isPrerelease,
        ),
        diagnostics: List<UpdateSelectionDiagnostic>.unmodifiable(diagnostics),
      );
    }
    return UpdatePolicyResult(
      candidate: null,
      diagnostics: List<UpdateSelectionDiagnostic>.unmodifiable(diagnostics),
    );
  }

  UpdateSelectionDiagnosticReason _mapAssetReason(
    UpdateAssetExclusionReason reason,
  ) {
    return switch (reason) {
      UpdateAssetExclusionReason.unsupportedArchitecture =>
        UpdateSelectionDiagnosticReason.unsupportedArchitecture,
      UpdateAssetExclusionReason.malformedAssetName =>
        UpdateSelectionDiagnosticReason.malformedAssetName,
      UpdateAssetExclusionReason.operatingSystemMismatch =>
        UpdateSelectionDiagnosticReason.operatingSystemMismatch,
      UpdateAssetExclusionReason.architectureMismatch =>
        UpdateSelectionDiagnosticReason.architectureMismatch,
      UpdateAssetExclusionReason.assetVersionMismatch =>
        UpdateSelectionDiagnosticReason.assetVersionMismatch,
      UpdateAssetExclusionReason.packageMissing =>
        UpdateSelectionDiagnosticReason.packageMissing,
      UpdateAssetExclusionReason.invalidSize =>
        UpdateSelectionDiagnosticReason.invalidSize,
      UpdateAssetExclusionReason.invalidDigest =>
        UpdateSelectionDiagnosticReason.invalidDigest,
      UpdateAssetExclusionReason.invalidOfficialUrl =>
        UpdateSelectionDiagnosticReason.invalidOfficialUrl,
      UpdateAssetExclusionReason.invalidPackageType =>
        UpdateSelectionDiagnosticReason.invalidPackageType,
      UpdateAssetExclusionReason.duplicateCanonicalAsset =>
        UpdateSelectionDiagnosticReason.duplicateCanonicalAsset,
    };
  }
}
