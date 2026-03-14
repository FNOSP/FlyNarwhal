/// Tag entity for filtering
class TagEntity {
  final String key;
  final String value;

  const TagEntity({
    required this.key,
    required this.value,
  });
}

/// Genre entity
class GenreEntity {
  final int id;
  final String name;

  const GenreEntity({
    required this.id,
    required this.name,
  });
}

/// Tag list entity for filtering options
class TagListEntity {
  final List<int> genres;
  final List<String> resolutions;
  final List<String> colorRanges;
  final List<String> audioTypes;
  final List<String> locations;
  final List<String> decades;
  final List<int> recognitionStatuses;

  const TagListEntity({
    this.genres = const [],
    this.resolutions = const [],
    this.colorRanges = const [],
    this.audioTypes = const [],
    this.locations = const [],
    this.decades = const [],
    this.recognitionStatuses = const [],
  });

  bool get isEmpty =>
      genres.isEmpty &&
      resolutions.isEmpty &&
      colorRanges.isEmpty &&
      audioTypes.isEmpty &&
      locations.isEmpty &&
      decades.isEmpty &&
      recognitionStatuses.isEmpty;

  bool get isNotEmpty => !isEmpty;

  TagListEntity copyWith({
    List<int>? genres,
    List<String>? resolutions,
    List<String>? colorRanges,
    List<String>? audioTypes,
    List<String>? locations,
    List<String>? decades,
    List<int>? recognitionStatuses,
  }) {
    return TagListEntity(
      genres: genres ?? this.genres,
      resolutions: resolutions ?? this.resolutions,
      colorRanges: colorRanges ?? this.colorRanges,
      audioTypes: audioTypes ?? this.audioTypes,
      locations: locations ?? this.locations,
      decades: decades ?? this.decades,
      recognitionStatuses: recognitionStatuses ?? this.recognitionStatuses,
    );
  }
}