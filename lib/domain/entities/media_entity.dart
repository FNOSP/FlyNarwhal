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
    this.numberOfSeasons,
    this.numberOfEpisodes,
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
        final seasonCount = numberOfSeasons ?? 0;
        return '共 $seasonCount 季 · ${_takeYear(firstAirDate)}~${_takeYear(lastAirDate)}';
      }
      if (numberOfSeasons == 1 && status == 'Ended') {
        final year = !_isBlank(releaseDate) ? ' · ${_takeYear(releaseDate)}' : '';
        final episodeCount = numberOfEpisodes ?? 0;
        return '共 $episodeCount 集$year';
      }
      if (numberOfSeasons != null && !_isBlank(releaseDate)) {
        return '第 $seasonNumber 季 · ${_takeYear(releaseDate)}';
      }
      return _takeYear(releaseDate);
    }

    if (_isBlank(releaseDate) && type != MediaType.video) {
      return _mediaTypeDescription();
    }

    if (status == '1' && type == MediaType.video) {
      return '';
    }

    return _takeYear(releaseDate);
  }

  String _mediaTypeDescription() {
    switch (type) {
      case MediaType.movie:
        return '电影';
      case MediaType.tv:
        return '电视节目';
      case MediaType.directory:
        return '目录';
      case MediaType.video:
        return '其他';
      case MediaType.episode:
        return '剧集';
      case MediaType.season:
        return '季';
    }
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
      status: status ?? this.status,
      overview: overview ?? this.overview,
      ancestorGuid: ancestorGuid ?? this.ancestorGuid,
      ancestorName: ancestorName ?? this.ancestorName,
      ancestorCategory: ancestorCategory ?? this.ancestorCategory,
      duration: duration ?? this.duration,
    );
  }
}