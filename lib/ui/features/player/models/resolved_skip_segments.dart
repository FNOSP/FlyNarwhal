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
}

class ResolvedSkipSegments {
  const ResolvedSkipSegments({
    required this.episodeGuid,
    required this.introSegment,
    required this.introSource,
    required this.creditsSegment,
    required this.creditsSource,
    required this.durationMilliseconds,
  })  : assert(
          introSegment != null || introSource == SkipSegmentSource.none,
        ),
        assert(
          creditsSegment != null || creditsSource == SkipSegmentSource.none,
        );

  factory ResolvedSkipSegments.empty({
    String episodeGuid = '',
    int? durationMilliseconds,
  }) {
    return ResolvedSkipSegments(
      episodeGuid: episodeGuid,
      introSegment: null,
      introSource: SkipSegmentSource.none,
      creditsSegment: null,
      creditsSource: SkipSegmentSource.none,
      durationMilliseconds: durationMilliseconds,
    );
  }

  final String episodeGuid;
  final SkipSegmentMillis? introSegment;
  final SkipSegmentSource introSource;
  final SkipSegmentMillis? creditsSegment;
  final SkipSegmentSource creditsSource;
  final int? durationMilliseconds;

  ResolvedSkipSegments copyWithDuration(int? durationMilliseconds) {
    return ResolvedSkipSegments(
      episodeGuid: episodeGuid,
      introSegment: introSegment,
      introSource: introSource,
      creditsSegment: creditsSegment,
      creditsSource: creditsSource,
      durationMilliseconds: durationMilliseconds,
    );
  }
}
