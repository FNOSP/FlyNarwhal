import '../../../../l10n/generated/app_localizations.dart';

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

/// A progress-bar marker range plus the styling flag the bar needs. Carries
/// only what the painter uses, so the bar never has to know SkipSegmentKind.
class SkipSegmentMarker {
  const SkipSegmentMarker({
    required this.range,
    required this.isCommercial,
  });

  final SkipSegmentMillis range;
  final bool isCommercial;

  @override
  bool operator ==(Object other) {
    return other is SkipSegmentMarker &&
        other.range == range &&
        other.isCommercial == isCommercial;
  }

  @override
  int get hashCode => Object.hash(range, isCommercial);
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
  commercial,
}

/// Human-readable label for a segment kind set, used in skip prompts
/// (e.g. "intro", or "intro and recap").
String skipSegmentLabel(AppLocalizations l10n, Set<SkipSegmentKind> kinds) {
  final parts = <String>[];
  if (kinds.contains(SkipSegmentKind.intro)) {
    parts.add(l10n.playerSkipSegmentIntro);
  }
  if (kinds.contains(SkipSegmentKind.recap)) {
    parts.add(l10n.playerSkipSegmentRecap);
  }
  if (kinds.contains(SkipSegmentKind.credits)) {
    parts.add(l10n.playerSkipSegmentOutro);
  }
  if (kinds.contains(SkipSegmentKind.preview)) {
    parts.add(l10n.playerSkipSegmentPreview);
  }
  if (kinds.contains(SkipSegmentKind.commercial)) {
    parts.add(l10n.playerSkipSegmentCommercial);
  }
  if (parts.isEmpty) return l10n.playerSkipSegmentGeneric;
  return parts.join(l10n.playerSkipSegmentConnector);
}

/// Per-kind playback skip switches, decided before segment resolution.
///
/// Commercials are the one exception among the defaults: ad skipping is opt-in,
/// so [commercial] starts off while the other kinds start on.
class SkipSwitches {
  const SkipSwitches({
    this.intro = true,
    this.recap = true,
    this.credits = true,
    this.preview = true,
    this.commercial = false,
  });

  /// Every kind enabled except [commercial], which is opt-in.
  static const SkipSwitches allEnabled = SkipSwitches();

  final bool intro;
  final bool recap;
  final bool credits;
  final bool preview;
  final bool commercial;

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
      case SkipSegmentKind.commercial:
        return commercial;
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

  /// Segments containing intro, recap or commercial skip automatically with an
  /// undo prompt, mirroring the historical intro behavior.
  bool get isIntroRole =>
      kinds.contains(SkipSegmentKind.intro) ||
      kinds.contains(SkipSegmentKind.recap) ||
      kinds.contains(SkipSegmentKind.commercial);

  /// Segments containing credits or preview show a countdown prompt before
  /// skipping, mirroring the historical credits behavior.
  bool get isOutroRole =>
      kinds.contains(SkipSegmentKind.credits) ||
      kinds.contains(SkipSegmentKind.preview);

  /// Commercial segments get their own progress-bar marker color.
  bool get isCommercial => kinds.contains(SkipSegmentKind.commercial);

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

  /// Progress-bar markers with the commercial flag preserved, so the bar can
  /// color ad breaks differently from intro/outro segments.
  List<SkipSegmentMarker> get allSegmentMarkers => segments
      .map((segment) => SkipSegmentMarker(
            range: segment.segment,
            isCommercial: segment.isCommercial,
          ))
      .toList();

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
