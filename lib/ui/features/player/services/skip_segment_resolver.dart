import '../../../../data/models/fly_narwhal/episode_segments_response.dart';
import '../models/resolved_skip_segments.dart';

class SkipSegmentResolver {
  const SkipSegmentResolver();

  ResolvedSkipSegments resolve({
    required String episodeGuid,
    required EpisodeSegmentsResponse? smartSegments,
    required int manualSkipOpeningSeconds,
    required int manualSkipEndingSeconds,
    required int? durationMilliseconds,
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
    final introSegment = smartIntro ??
        _resolveManualIntro(
          manualSkipOpeningSeconds,
          durationMilliseconds: normalizedDuration,
        );
    final creditsSegment = smartCredits ??
        _resolveManualCredits(
          manualSkipEndingSeconds,
          durationMilliseconds: normalizedDuration,
        );

    return ResolvedSkipSegments(
      episodeGuid: episodeGuid,
      introSegment: introSegment,
      introSource: _sourceForSegment(
        resolvedSegment: introSegment,
        smartSegment: smartIntro,
      ),
      creditsSegment: creditsSegment,
      creditsSource: _sourceForSegment(
        resolvedSegment: creditsSegment,
        smartSegment: smartCredits,
      ),
      durationMilliseconds: normalizedDuration,
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

  SkipSegmentSource _sourceForSegment({
    required SkipSegmentMillis? resolvedSegment,
    required SkipSegmentMillis? smartSegment,
  }) {
    if (resolvedSegment == null) {
      return SkipSegmentSource.none;
    }
    return smartSegment != null
        ? SkipSegmentSource.smart
        : SkipSegmentSource.manual;
  }
}
