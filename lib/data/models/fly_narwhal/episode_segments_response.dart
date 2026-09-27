class EpisodeSegmentsResponse {
  final EpisodeSegment? intro;
  final EpisodeSegment? credits;
  final EpisodeSegment? recap;
  final EpisodeSegment? preview;

  /// An episode can hold several ad breaks, so commercials are a list.
  final List<EpisodeSegment> commercials;

  const EpisodeSegmentsResponse({
    this.intro,
    this.credits,
    this.recap,
    this.preview,
    this.commercials = const <EpisodeSegment>[],
  });

  factory EpisodeSegmentsResponse.fromJson(Map<String, dynamic> json) {
    return EpisodeSegmentsResponse(
      intro: _readSegment(json['intro']),
      credits: _readSegment(json['credits']),
      recap: _readSegment(json['recap']),
      preview: _readSegment(json['preview']),
      commercials: _readSegmentList(json['commercials'] ?? json['commercial']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'intro': intro?.toJson(),
      'credits': credits?.toJson(),
      'recap': recap?.toJson(),
      'preview': preview?.toJson(),
      'commercials':
          commercials.map((segment) => segment.toJson()).toList(),
    };
  }

  static EpisodeSegment? _readSegment(Object? value) {
    if (value is! Map) return null;
    return EpisodeSegment.fromJson(Map<String, dynamic>.from(value));
  }

  /// Accepts the list form, plus a bare single segment left over from the
  /// singular `commercial` key the response used to carry.
  static List<EpisodeSegment> _readSegmentList(Object? value) {
    if (value is List) {
      final segments = <EpisodeSegment>[];
      for (final entry in value) {
        final segment = _readSegment(entry);
        if (segment != null) segments.add(segment);
      }
      return segments;
    }
    final single = _readSegment(value);
    return single == null ? const <EpisodeSegment>[] : <EpisodeSegment>[single];
  }
}

class EpisodeSegment {
  final double start;
  final double end;
  final bool valid;

  const EpisodeSegment({
    required this.start,
    required this.end,
    required this.valid,
  });

  factory EpisodeSegment.fromJson(Map<String, dynamic> json) {
    return EpisodeSegment(
      start: _readDouble(json['start']),
      end: _readDouble(json['end']),
      valid: json['valid'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'start': start,
      'end': end,
      'valid': valid,
    };
  }
}

double _readDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}
