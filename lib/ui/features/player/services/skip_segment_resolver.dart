import '../../../../data/models/fly_narwhal/episode_segments_response.dart';
import '../models/resolved_skip_segments.dart';

class SkipSegmentResolver {
  const SkipSegmentResolver();

  /// Adjacent smart segments merge only when their gap is at most this wide.
  static const int mergeGapToleranceMilliseconds = 1000;

  ResolvedSkipSegments resolve({
    required String episodeGuid,
    required EpisodeSegmentsResponse? smartSegments,
    required int manualSkipOpeningSeconds,
    required int manualSkipEndingSeconds,
    required int? durationMilliseconds,
    SkipSwitches switches = SkipSwitches.allEnabled,
  }) {
    final normalizedDuration =
        durationMilliseconds != null && durationMilliseconds > 0
            ? durationMilliseconds
            : null;
    final smartIntro = _resolveSmartSegment(
      smartSegments?.intro,
      durationMilliseconds: normalizedDuration,
    );
    final smartCredits = _resolveSmartSegment(
      smartSegments?.credits,
      durationMilliseconds: normalizedDuration,
    );
    final smartRecap = _resolveSmartSegment(
      smartSegments?.recap,
      durationMilliseconds: normalizedDuration,
    );
    final smartPreview = _resolveSmartSegment(
      smartSegments?.preview,
      durationMilliseconds: normalizedDuration,
    );

    final segments = <ResolvedSkipSegment>[
      ..._resolveIntroSide(
        smartIntro: smartIntro,
        smartRecap: smartRecap,
        switches: switches,
        manualSkipOpeningSeconds: manualSkipOpeningSeconds,
        durationMilliseconds: normalizedDuration,
      ),
      ..._resolveOutroSide(
        smartCredits: smartCredits,
        smartPreview: smartPreview,
        switches: switches,
        manualSkipEndingSeconds: manualSkipEndingSeconds,
        durationMilliseconds: normalizedDuration,
      ),
    ];
    // Keep smart segments over manual ones on overlap (priority order), then
    // sort for the non-overlapping invariant on ResolvedSkipSegments.
    final deduplicated = _dropOverlapping(segments);
    deduplicated.sort(
        (a, b) => a.startMilliseconds.compareTo(b.startMilliseconds));

    return ResolvedSkipSegments(
      episodeGuid: episodeGuid,
      segments: deduplicated,
      durationMilliseconds: normalizedDuration,
    );
  }

  List<ResolvedSkipSegment> _dropOverlapping(
      List<ResolvedSkipSegment> segments) {
    final result = <ResolvedSkipSegment>[];
    for (final segment in segments) {
      final overlaps = result.any(
        (kept) =>
            segment.startMilliseconds < kept.endMilliseconds &&
            kept.startMilliseconds < segment.endMilliseconds,
      );
      if (!overlaps) {
        result.add(segment);
      }
    }
    return result;
  }

  List<ResolvedSkipSegment> _resolveIntroSide({
    required SkipSegmentMillis? smartIntro,
    required SkipSegmentMillis? smartRecap,
    required SkipSwitches switches,
    required int manualSkipOpeningSeconds,
    required int? durationMilliseconds,
  }) {
    final enabledIntro =
        switches.intro ? smartIntro : null;
    final enabledRecap =
        switches.recap ? smartRecap : null;

    final merged = _mergeAdjacentSmartSegments(
      earlier: enabledIntro,
      later: enabledRecap,
      earlierKind: SkipSegmentKind.intro,
      laterKind: SkipSegmentKind.recap,
    );
    if (merged != null) {
      return [merged];
    }

    final result = <ResolvedSkipSegment>[];
    if (enabledIntro != null) {
      result.add(ResolvedSkipSegment(
        segment: enabledIntro,
        source: SkipSegmentSource.smart,
        kinds: const {SkipSegmentKind.intro},
      ));
    } else if (switches.intro) {
      // Fall back to the manual intro duration only when the intro switch is
      // on; turning the switch off must disable intro skipping entirely.
      final manualIntro = _resolveManualIntro(
        manualSkipOpeningSeconds,
        durationMilliseconds: durationMilliseconds,
      );
      if (manualIntro != null) {
        result.add(ResolvedSkipSegment(
          segment: manualIntro,
          source: SkipSegmentSource.manual,
          kinds: const {SkipSegmentKind.intro},
        ));
      }
    }
    if (enabledRecap != null) {
      result.add(ResolvedSkipSegment(
        segment: enabledRecap,
        source: SkipSegmentSource.smart,
        kinds: const {SkipSegmentKind.recap},
      ));
    }
    return result;
  }

  List<ResolvedSkipSegment> _resolveOutroSide({
    required SkipSegmentMillis? smartCredits,
    required SkipSegmentMillis? smartPreview,
    required SkipSwitches switches,
    required int manualSkipEndingSeconds,
    required int? durationMilliseconds,
  }) {
    final enabledCredits = switches.credits ? smartCredits : null;
    final enabledPreview = switches.preview ? smartPreview : null;

    final merged = _mergeAdjacentSmartSegments(
      earlier: enabledCredits,
      later: enabledPreview,
      earlierKind: SkipSegmentKind.credits,
      laterKind: SkipSegmentKind.preview,
    );
    if (merged != null) {
      return [merged];
    }

    final result = <ResolvedSkipSegment>[];
    if (enabledCredits != null) {
      result.add(ResolvedSkipSegment(
        segment: enabledCredits,
        source: SkipSegmentSource.smart,
        kinds: const {SkipSegmentKind.credits},
      ));
    } else if (switches.credits) {
      // Fall back to the manual credits duration only when the credits switch
      // is on; turning the switch off must disable credits skipping entirely.
      final manualCredits = _resolveManualCredits(
        manualSkipEndingSeconds,
        durationMilliseconds: durationMilliseconds,
      );
      if (manualCredits != null) {
        result.add(ResolvedSkipSegment(
          segment: manualCredits,
          source: SkipSegmentSource.manual,
          kinds: const {SkipSegmentKind.credits},
        ));
      }
    }
    if (enabledPreview != null) {
      result.add(ResolvedSkipSegment(
        segment: enabledPreview,
        source: SkipSegmentSource.smart,
        kinds: const {SkipSegmentKind.preview},
      ));
    }
    return result;
  }

  /// Merge two adjacent same-side smart segments into one when their gap is
  /// within tolerance. Merged segments skip together as a single unit.
  ResolvedSkipSegment? _mergeAdjacentSmartSegments({
    required SkipSegmentMillis? earlier,
    required SkipSegmentMillis? later,
    required SkipSegmentKind earlierKind,
    required SkipSegmentKind laterKind,
  }) {
    if (earlier == null || later == null) {
      return null;
    }
    final gap = later.startMilliseconds - earlier.endMilliseconds;
    if (gap < 0 || gap > mergeGapToleranceMilliseconds) {
      return null;
    }
    final mergedRange = SkipSegmentMillis(
      startMilliseconds: earlier.startMilliseconds,
      endMilliseconds:
          later.endMilliseconds > earlier.endMilliseconds
              ? later.endMilliseconds
              : earlier.endMilliseconds,
    );
    if (mergedRange.endMilliseconds <= mergedRange.startMilliseconds) {
      return null;
    }
    return ResolvedSkipSegment(
      segment: mergedRange,
      source: SkipSegmentSource.mergedSmart,
      kinds: {earlierKind, laterKind},
    );
  }

  SkipSegmentMillis? _resolveSmartSegment(
    EpisodeSegment? segment, {
    required int? durationMilliseconds,
  }) {
    if (segment == null ||
        !segment.valid ||
        !segment.start.isFinite ||
        !segment.end.isFinite ||
        segment.end <= segment.start ||
        segment.end <= 0) {
      return null;
    }

    final rawStartMilliseconds = (segment.start * 1000).round();
    final rawEndMilliseconds = (segment.end * 1000).round();
    final startMilliseconds = _clampMilliseconds(
      rawStartMilliseconds,
      durationMilliseconds: durationMilliseconds,
    );
    final endMilliseconds = _clampMilliseconds(
      rawEndMilliseconds,
      durationMilliseconds: durationMilliseconds,
    );
    return _createSegment(startMilliseconds, endMilliseconds);
  }

  SkipSegmentMillis? _resolveManualIntro(
    int seconds, {
    required int? durationMilliseconds,
  }) {
    if (seconds <= 0) {
      return null;
    }
    final endMilliseconds = _clampMilliseconds(
      seconds * 1000,
      durationMilliseconds: durationMilliseconds,
    );
    return _createSegment(0, endMilliseconds);
  }

  SkipSegmentMillis? _resolveManualCredits(
    int seconds, {
    required int? durationMilliseconds,
  }) {
    if (seconds <= 0 || durationMilliseconds == null) {
      return null;
    }
    final startMilliseconds =
        (durationMilliseconds - seconds * 1000).clamp(0, durationMilliseconds);
    return _createSegment(startMilliseconds, durationMilliseconds);
  }

  int _clampMilliseconds(
    int milliseconds, {
    required int? durationMilliseconds,
  }) {
    if (durationMilliseconds == null) {
      return milliseconds < 0 ? 0 : milliseconds;
    }
    return milliseconds.clamp(0, durationMilliseconds);
  }

  SkipSegmentMillis? _createSegment(
    int startMilliseconds,
    int endMilliseconds,
  ) {
    if (endMilliseconds <= startMilliseconds) {
      return null;
    }
    return SkipSegmentMillis(
      startMilliseconds: startMilliseconds,
      endMilliseconds: endMilliseconds,
    );
  }
}
