import 'media_entity.dart';

/// Play detail entity for recently watched items
class PlayDetailEntity {
  final String guid;
  final String title;
  final MediaType type;
  final String? poster;
  final bool isFavorite;
  final bool isWatched;
  final MediaStreamEntity? mediaStream;
  final String? voteAverage;
  final int seasonNumber;
  final int episodeNumber;
  final String? tvTitle;
  final int? duration;
  final int? timestamp;
  final String? status;
  final String? parentGuid;

  const PlayDetailEntity({
    required this.guid,
    required this.title,
    this.type = MediaType.video,
    this.poster,
    this.isFavorite = false,
    this.isWatched = false,
    this.mediaStream,
    this.voteAverage,
    this.seasonNumber = 0,
    this.episodeNumber = 0,
    this.tvTitle,
    this.duration,
    this.timestamp,
    this.status,
    this.parentGuid,
  });

  /// Build display title
  String buildDisplayTitle() {
    if (type == MediaType.episode) {
      return tvTitle?.trim().isNotEmpty == true ? tvTitle!.trim() : title;
    }
    return title;
  }

  /// Build subtitle
  String? buildSubtitle() {
    switch (type) {
      case MediaType.episode:
        return '第 $seasonNumber 季 · 第 $episodeNumber 集';
      case MediaType.video:
        return ' ';
      default:
        return _mediaTypeDescription();
    }
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

  PlayDetailEntity copyWith({
    String? guid,
    String? title,
    MediaType? type,
    String? poster,
    bool? isFavorite,
    bool? isWatched,
    MediaStreamEntity? mediaStream,
    String? voteAverage,
    int? seasonNumber,
    int? episodeNumber,
    String? tvTitle,
    int? duration,
    int? timestamp,
    String? status,
    String? parentGuid,
  }) {
    return PlayDetailEntity(
      guid: guid ?? this.guid,
      title: title ?? this.title,
      type: type ?? this.type,
      poster: poster ?? this.poster,
      isFavorite: isFavorite ?? this.isFavorite,
      isWatched: isWatched ?? this.isWatched,
      mediaStream: mediaStream ?? this.mediaStream,
      voteAverage: voteAverage ?? this.voteAverage,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      tvTitle: tvTitle ?? this.tvTitle,
      duration: duration ?? this.duration,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      parentGuid: parentGuid ?? this.parentGuid,
    );
  }
}