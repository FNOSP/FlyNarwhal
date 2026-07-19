/// A strict Semantic Version 2.0.0 value object.
final class SemanticVersion implements Comparable<SemanticVersion> {
  const SemanticVersion._({
    required this.major,
    required this.minor,
    required this.patch,
    required this.preReleaseIdentifiers,
    required this.buildMetadata,
  });

  static final RegExp _expression = RegExp(
    r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|[0-9A-Za-z-]+)(?:\.(?:0|[1-9]\d*|[0-9A-Za-z-]+))*))?(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$',
  );

  final int major;
  final int minor;
  final int patch;
  final List<String> preReleaseIdentifiers;
  final String? buildMetadata;

  bool get isPreRelease => preReleaseIdentifiers.isNotEmpty;

  /// Returns the normalized key used for precedence comparisons.
  String get precedenceKey {
    final preReleaseSuffix =
        isPreRelease ? '-${preReleaseIdentifiers.join('.')}' : '';
    return '$major.$minor.$patch$preReleaseSuffix';
  }

  /// Returns the normalized key persisted for exact skip matching.
  String get skipKey => precedenceKey;

  static SemanticVersion? tryParse(String value) {
    final match = _expression.firstMatch(value.trim());
    if (match == null) {
      return null;
    }

    final preReleaseIdentifiers =
        match.group(4)?.split('.') ?? const <String>[];
    final hasInvalidNumericIdentifier = preReleaseIdentifiers.any(
      (identifier) =>
          identifier.length > 1 &&
          int.tryParse(identifier) != null &&
          identifier.startsWith('0'),
    );
    if (hasInvalidNumericIdentifier) {
      return null;
    }

    return SemanticVersion._(
      major: int.parse(match.group(1)!),
      minor: int.parse(match.group(2)!),
      patch: int.parse(match.group(3)!),
      preReleaseIdentifiers: List<String>.unmodifiable(
        preReleaseIdentifiers,
      ),
      buildMetadata: match.group(5),
    );
  }

  @override
  int compareTo(SemanticVersion other) {
    final coreComparison = _compareCore(other);
    if (coreComparison != 0) {
      return coreComparison;
    }
    if (!isPreRelease && !other.isPreRelease) {
      return 0;
    }
    if (!isPreRelease) {
      return 1;
    }
    if (!other.isPreRelease) {
      return -1;
    }

    final identifierCount =
        preReleaseIdentifiers.length < other.preReleaseIdentifiers.length
            ? preReleaseIdentifiers.length
            : other.preReleaseIdentifiers.length;
    for (var identifierIndex = 0;
        identifierIndex < identifierCount;
        identifierIndex++) {
      final comparison = _comparePreReleaseIdentifier(
        preReleaseIdentifiers[identifierIndex],
        other.preReleaseIdentifiers[identifierIndex],
      );
      if (comparison != 0) {
        return comparison;
      }
    }
    return preReleaseIdentifiers.length
        .compareTo(other.preReleaseIdentifiers.length);
  }

  int _compareCore(SemanticVersion other) {
    final majorComparison = major.compareTo(other.major);
    if (majorComparison != 0) return majorComparison;
    final minorComparison = minor.compareTo(other.minor);
    if (minorComparison != 0) return minorComparison;
    return patch.compareTo(other.patch);
  }

  int _comparePreReleaseIdentifier(String left, String right) {
    final leftNumber = int.tryParse(left);
    final rightNumber = int.tryParse(right);
    if (leftNumber != null && rightNumber != null) {
      return leftNumber.compareTo(rightNumber);
    }
    if (leftNumber != null) {
      return -1;
    }
    if (rightNumber != null) {
      return 1;
    }
    return left.compareTo(right);
  }

  @override
  String toString() {
    final preReleaseSuffix =
        isPreRelease ? '-${preReleaseIdentifiers.join('.')}' : '';
    final buildSuffix = buildMetadata == null ? '' : '+$buildMetadata';
    return '$major.$minor.$patch$preReleaseSuffix$buildSuffix';
  }
}
