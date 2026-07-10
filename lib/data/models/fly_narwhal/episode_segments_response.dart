class EpisodeSegmentsResponse {
  final EpisodeSegment? intro;
  final EpisodeSegment? credits;

  const EpisodeSegmentsResponse({
    this.intro,
    this.credits,
  });

  factory EpisodeSegmentsResponse.fromJson(Map<String, dynamic> json) {
    return EpisodeSegmentsResponse(
      intro: _readSegment(json['intro']),
      credits: _readSegment(json['credits']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'intro': intro?.toJson(),
      'credits': credits?.toJson(),
    };
  }

  static EpisodeSegment? _readSegment(Object? value) {
    if (value == null) return null;
    return EpisodeSegment.fromJson(Map<String, dynamic>.from(value as Map));
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
