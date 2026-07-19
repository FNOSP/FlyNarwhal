class HlsSubtitleCue {
  final int startTimeMs;
  final int endTimeMs;
  final String text;

  const HlsSubtitleCue({
    required this.startTimeMs,
    required this.endTimeMs,
    required this.text,
  });

  bool isVisibleAt(int positionMs) {
    return positionMs >= startTimeMs && positionMs < endTimeMs;
  }
}

class HlsSubtitleSegment {
  final int index;
  final String uri;
  final int durationMs;
  final int startTimeMs;
  final int endTimeMs;

  const HlsSubtitleSegment({
    required this.index,
    required this.uri,
    required this.durationMs,
    required this.startTimeMs,
    required this.endTimeMs,
  });

  bool overlapsWindow(int startMs, int endMs) {
    return startTimeMs < endMs && endTimeMs > startMs;
  }
}
