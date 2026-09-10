class SkipSegmentMillis {
  const SkipSegmentMillis({
    required this.startMilliseconds,
    required this.endMilliseconds,
  })  : assert(startMilliseconds >= 0),
        assert(endMilliseconds > startMilliseconds);

  final int startMilliseconds;
  final int endMilliseconds;

  bool contains(int positionMilliseconds) {
    return positionMilliseconds >= startMilliseconds &&
        positionMilliseconds < endMilliseconds;
  }

  @override
  bool operator ==(Object other) {
    return other is SkipSegmentMillis &&
        other.startMilliseconds == startMilliseconds &&
        other.endMilliseconds == endMilliseconds;
  }

  @override
  int get hashCode => Object.hash(startMilliseconds, endMilliseconds);
}

enum SkipSegmentSource {
  none,
  smart,
  manual,
  mergedSmart,
}

/// Which smart-skip category contributed to a resolved segment. Merged
/// segments carry multiple kinds (e.g. an intro immediately followed by a
/// recap that gets skipped together).
enum SkipSegmentKind {
  intro,
  recap,
  credits,
  preview,
}

/// Human-readable label for a segment kind set, used in skip prompts
/// (e.g. '片头', '片头与前情提要').
String skipSegmentLabel(Set<SkipSegmentKind> kinds) {
  final parts = <String>[];
  if (kinds.contains(SkipSegmentKind.intro)) parts.add('片头');
  if (kinds.contains(SkipSegmentKind.recap)) parts.add('前情提要');
  if (kinds.contains(SkipSegmentKind.credits)) parts.add('片尾');
  if (kinds.contains(SkipSegmentKind.preview)) parts.add('下集预告');
  return parts.isEmpty ? '片段' : parts.join('与');
}

/// Per-kind playback skip switches, decided before segment resolution.
class SkipSwitches {
  const SkipSwitches({
    this.intro = true,
    this.recap = true,
    this.credits = true,
    this.preview = true,
  });

  static const SkipSwitches allEnabled = SkipSwitches();

  final bool intro;
  final bool recap;
  final bool credits;
  final bool preview;

  bool forKind(SkipSegmentKind kind) {
    switch (kind) {
      case SkipSegmentKind.intro:
        return intro;
      case SkipSegmentKind.recap:
        return recap;
      case SkipSegmentKind.credits:
        return credits;
      case SkipSegmentKind.preview:
        return preview;
    }
  }
}

class ResolvedSkipSegment {
  const ResolvedSkipSegment({
    required this.segment,
    required this.source,
    required this.kinds,
  }) : assert(kinds.length > 0);

  final SkipSegmentMillis segment;
  final SkipSegmentSource source;
  final Set<SkipSegmentKind> kinds;

  /// Segments containing intro or recap skip automatically with an undo
  /// prompt, mirroring the historical intro behavior.
  bool get isIntroRole =>
      kinds.contains(SkipSegmentKind.intro) ||
      kinds.contains(SkipSegmentKind.recap);

  /// Segments containing credits or preview show a countdown prompt before
  /// skipping, mirroring the historical credits behavior.
  bool get isOutroRole =>
      kinds.contains(SkipSegmentKind.credits) ||
      kinds.contains(SkipSegmentKind.preview);

  int get startMilliseconds => segment.startMilliseconds;
  int get endMilliseconds => segment.endMilliseconds;
}

class ResolvedSkipSegments {
  ResolvedSkipSegments({
    required this.episodeGuid,
    required List<ResolvedSkipSegment> segments,
    required this.durationMilliseconds,
  }) : segments = List.unmodifiable(segments) {
    assert(() {
      for (var i = 1; i < this.segments.length; i++) {
        if (this.segments[i].startMilliseconds <=
            this.segments[i - 1].endMilliseconds) {
          return false;
        }
      }
      return true;
    }(), 'segments must be non-overlapping and sorted by start');
  }

  factory ResolvedSkipSegments.empty({
    String episodeGuid = '',
    int? durationMilliseconds,
  }) {
    return ResolvedSkipSegments(
      episodeGuid: episodeGuid,
      segments: const <ResolvedSkipSegment>[],
      durationMilliseconds: durationMilliseconds,
    );
  }

  final String episodeGuid;
  final List<ResolvedSkipSegment> segments;
  final int? durationMilliseconds;

  List<ResolvedSkipSegment> get introRoleSegments =>
      segments.where((segment) => segment.isIntroRole).toList();

  List<ResolvedSkipSegment> get outroRoleSegments =>
      segments.where((segment) => segment.isOutroRole).toList();

  /// All segment ranges for progress-bar markers.
  List<SkipSegmentMillis> get allSegmentRanges =>
      segments.map((segment) => segment.segment).toList();

  // Compatibility accessors for callers that only care about the first
  // intro/credits-role segment (e.g. the manual intro-end check on replay).
  SkipSegmentMillis? get introSegment =>
      introRoleSegments.isEmpty ? null : introRoleSegments.first.segment;

  SkipSegmentMillis? get creditsSegment =>
      outroRoleSegments.isEmpty ? null : outroRoleSegments.first.segment;

  SkipSegmentSource get introSource =>
      introRoleSegments.isEmpty
          ? SkipSegmentSource.none
          : introRoleSegments.first.source;

  SkipSegmentSource get creditsSource =>
      outroRoleSegments.isEmpty
          ? SkipSegmentSource.none
          : outroRoleSegments.first.source;

  ResolvedSkipSegments copyWithDuration(int? durationMilliseconds) {
    return ResolvedSkipSegments(
      episodeGuid: episodeGuid,
      segments: segments,
      durationMilliseconds: durationMilliseconds,
    );
  }
}
