/// Media type enumeration
enum MediaType {
  movie('Movie'),
  tv('TV'),
  directory('Directory'),
  video('Video'),
  episode('Episode'),
  season('Season');

  final String value;
  const MediaType(this.value);

  static MediaType fromString(String? value) {
    return MediaType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => MediaType.video,
    );
  }
}

/// Media stream information entity
class MediaStreamEntity {
  final List<String>? resolutions;
  final String? audioType;
  final String? colorRangeType;

  const MediaStreamEntity({
    this.resolutions,
    this.audioType,
    this.colorRangeType,
  });

  bool get hasResolutions => resolutions != null && resolutions!.isNotEmpty;
  bool get hasAudioType => audioType != null && audioType!.isNotEmpty;
  bool get hasColorRange => colorRangeType != null && colorRangeType!.isNotEmpty;
}

/// Media item entity (core business entity)
class MediaEntity {
  final String guid;
  final String? language;
  final int? doubanId;
  final String? imdbId;
  final String title;
  final MediaType type;
  final String? poster;
  final int? posterWidth;
  final int? posterHeight;
  final bool isFavorite;
  final bool isWatched;
  final String? voteAverage;
  final MediaStreamEntity? mediaStream;
  final String? releaseDate;
  final int seasonNumber;
  final int episodeNumber;
  final String? firstAirDate;
  final String? lastAirDate;
  final int? numberOfSeasons;
  final int? numberOfEpisodes;
  final int? localNumberOfSeasons;
  final int? localNumberOfEpisodes;
  final String? status;
  final String? overview;
  final String? ancestorGuid;
  final String? ancestorName;
  final String? ancestorCategory;
  final int? duration;

  const MediaEntity({
    required this.guid,
    this.language,
    this.doubanId,
    this.imdbId,
    required this.title,
    this.type = MediaType.video,
    this.poster,
    this.posterWidth,
    this.posterHeight,
    this.isFavorite = false,
    this.isWatched = false,
    this.voteAverage,
    this.mediaStream,
    this.releaseDate,
    this.seasonNumber = 0,
    this.episodeNumber = 0,
    this.firstAirDate,
    this.lastAirDate,
    this.numberOfSeasons = 0,
    this.numberOfEpisodes = 0,
    this.localNumberOfSeasons,
    this.localNumberOfEpisodes,
    this.status,
    this.overview,
    this.ancestorGuid,
    this.ancestorName,
    this.ancestorCategory,
    this.duration,
  });

  /// Get year from release date
  String? get year {
    if (releaseDate == null || releaseDate!.isEmpty) return null;
    final trimmed = releaseDate!.trim();
    return trimmed.length >= 4 ? trimmed.substring(0, 4) : trimmed;
  }

  /// Build poster subtitle for display
  String? buildPosterSubtitle() {
    if (type == MediaType.tv) {
      if (!_isBlank(firstAirDate) && !_isBlank(lastAirDate)) {
        // Use local season count (available in library) with fallback to metadata count
        final seasonCount = localNumberOfSeasons ?? numberOfSeasons ?? 0;
        return '共 $seasonCount 季 · ${_takeYear(firstAirDate)}~${_takeYear(lastAirDate)}';
      }
      // Use local counts for single-season ended shows
      if ((localNumberOfSeasons ?? numberOfSeasons) == 1 && status == 'Ended') {
        final year = !_isBlank(releaseDate) ? ' · ${_takeYear(releaseDate)}' : '';
        final episodeCount = localNumberOfEpisodes ?? numberOfEpisodes ?? 0;
        return '共 $episodeCount 集$year';
      }
      if (numberOfSeasons != null && !_isBlank(releaseDate)) {
        return '第 $seasonNumber 季 · ${_takeYear(releaseDate)}';
      }
      return _takeYear(releaseDate);
    }

    if (status == '1' && type == MediaType.video) {
      return '';
    }

    return _takeYear(releaseDate);
  }

  bool _isBlank(String? value) => value == null || value.trim().isEmpty;

  String? _takeYear(String? value) {
    if (_isBlank(value)) return null;
    final trimmed = value!.trim();
    return trimmed.length >= 4 ? trimmed.substring(0, 4) : trimmed;
  }

  /// Create a copy with updated values
  MediaEntity copyWith({
    String? guid,
    String? language,
    int? doubanId,
    String? imdbId,
    String? title,
    MediaType? type,
    String? poster,
    int? posterWidth,
    int? posterHeight,
    bool? isFavorite,
    bool? isWatched,
    String? voteAverage,
    MediaStreamEntity? mediaStream,
    String? releaseDate,
    int? seasonNumber,
    int? episodeNumber,
    String? firstAirDate,
    String? lastAirDate,
    int? numberOfSeasons,
    int? numberOfEpisodes,
    int? localNumberOfSeasons,
    int? localNumberOfEpisodes,
    String? status,
    String? overview,
    String? ancestorGuid,
    String? ancestorName,
    String? ancestorCategory,
    int? duration,
  }) {
    return MediaEntity(
      guid: guid ?? this.guid,
      language: language ?? this.language,
      doubanId: doubanId ?? this.doubanId,
      imdbId: imdbId ?? this.imdbId,
      title: title ?? this.title,
      type: type ?? this.type,
      poster: poster ?? this.poster,
      posterWidth: posterWidth ?? this.posterWidth,
      posterHeight: posterHeight ?? this.posterHeight,
      isFavorite: isFavorite ?? this.isFavorite,
      isWatched: isWatched ?? this.isWatched,
      voteAverage: voteAverage ?? this.voteAverage,
      mediaStream: mediaStream ?? this.mediaStream,
      releaseDate: releaseDate ?? this.releaseDate,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      firstAirDate: firstAirDate ?? this.firstAirDate,
      lastAirDate: lastAirDate ?? this.lastAirDate,
      numberOfSeasons: numberOfSeasons ?? this.numberOfSeasons,
      numberOfEpisodes: numberOfEpisodes ?? this.numberOfEpisodes,
      localNumberOfSeasons: localNumberOfSeasons ?? this.localNumberOfSeasons,
      localNumberOfEpisodes: localNumberOfEpisodes ?? this.localNumberOfEpisodes,
      status: status ?? this.status,
      overview: overview ?? this.overview,
      ancestorGuid: ancestorGuid ?? this.ancestorGuid,
      ancestorName: ancestorName ?? this.ancestorName,
      ancestorCategory: ancestorCategory ?? this.ancestorCategory,
      duration: duration ?? this.duration,
    );
  }
}