import 'semantic_version.dart';

/// Identifies which release field supplied a valid version.
enum ReleaseVersionSource { releaseTag, displayName }

/// Stable publication contract issues that callers can log or count.
enum ReleaseVersionContractIssue { invalidReleaseTag }

/// Stable reasons why neither release field produced a version.
enum ReleaseVersionParseFailureReason { noParseableVersion }

/// A typed result for release version parsing.
sealed class ReleaseVersionParseResult {
  const ReleaseVersionParseResult();
}

/// A parsed release version with its source and optional contract issue.
final class ReleaseVersionParseSuccess extends ReleaseVersionParseResult {
  const ReleaseVersionParseSuccess({
    required this.version,
    required this.source,
    required this.contractIssue,
  });

  final SemanticVersion version;
  final ReleaseVersionSource source;
  final ReleaseVersionContractIssue? contractIssue;
}

/// A stable failure returned when both release fields are unusable.
final class ReleaseVersionParseFailure extends ReleaseVersionParseResult {
  const ReleaseVersionParseFailure({
    required this.reason,
    required this.contractIssue,
  });

  final ReleaseVersionParseFailureReason reason;
  final ReleaseVersionContractIssue? contractIssue;
}

/// Parses application build names and GitHub release fields as SemVer values.
final class VersionParser {
  const VersionParser._();

  /// Compatibility API for callers migrating to typed parsing.
  static SemanticVersion? parseReleaseVersion({
    required String tagName,
    required String displayName,
  }) {
    final result = parseReleaseVersionResult(
      tagName: tagName,
      displayName: displayName,
    );
    return switch (result) {
      ReleaseVersionParseSuccess(:final version) => version,
      ReleaseVersionParseFailure() => null,
    };
  }

  static ReleaseVersionParseResult parseReleaseVersionResult({
    required String tagName,
    required String displayName,
  }) {
    final tagVersion = parseTagName(tagName);
    if (tagVersion != null) {
      return ReleaseVersionParseSuccess(
        version: tagVersion,
        source: ReleaseVersionSource.releaseTag,
        contractIssue: null,
      );
    }

    final displayNameVersion = SemanticVersion.tryParse(displayName);
    if (displayNameVersion != null) {
      return ReleaseVersionParseSuccess(
        version: displayNameVersion,
        source: ReleaseVersionSource.displayName,
        contractIssue: ReleaseVersionContractIssue.invalidReleaseTag,
      );
    }

    return const ReleaseVersionParseFailure(
      reason: ReleaseVersionParseFailureReason.noParseableVersion,
      contractIssue: ReleaseVersionContractIssue.invalidReleaseTag,
    );
  }

  static SemanticVersion? parseTagName(String tagName) {
    final normalizedTagName = tagName.trim();
    if (!normalizedTagName.startsWith('v')) {
      return null;
    }
    return SemanticVersion.tryParse(normalizedTagName.substring(1));
  }
}
