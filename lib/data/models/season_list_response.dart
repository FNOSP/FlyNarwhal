import 'package:json_annotation/json_annotation.dart';

part 'season_list_response.g.dart';

@JsonSerializable()
class MediaStream {
  final List<String>? resolutions;
  @JsonKey(name: 'audio_type')
  final String? audioType;
  @JsonKey(name: 'color_range_type')
  final String? colorRangeType;

  MediaStream({
    this.resolutions,
    this.audioType,
    this.colorRangeType,
  });

  factory MediaStream.fromJson(Map<String, dynamic> json) => _$MediaStreamFromJson(json);
  Map<String, dynamic> toJson() => _$MediaStreamToJson(this);
}

@JsonSerializable()
class SeasonListResponse {
  final String guid;
  final String lan;
  @JsonKey(name: 'imdb_id')
  final String? imdbId;
  @JsonKey(name: 'trim_id')
  final String trimId;
  @JsonKey(name: 'tv_title')
  final String tvTitle;
  @JsonKey(name: 'parent_guid')
  final String parentGuid;
  @JsonKey(name: 'parent_title')
  final String parentTitle;
  final String title;
  final String type;
  final String? poster;
  @JsonKey(name: 'poster_width')
  final int posterWidth;
  @JsonKey(name: 'poster_height')
  final int posterHeight;
  @JsonKey(name: 'is_favorite')
  final int isFavorite;
  final int watched;
  @JsonKey(name: 'watched_ts')
  final int watchedTs;
  @JsonKey(name: 'vote_average')
  final String voteAverage;
  @JsonKey(name: 'media_stream')
  final MediaStream mediaStream;
  @JsonKey(name: 'season_number')
  final int seasonNumber;
  @JsonKey(name: 'episode_number')
  final int episodeNumber;
  @JsonKey(name: 'air_date')
  final String? airDate;
  @JsonKey(name: 'number_of_seasons')
  final int numberOfSeasons;
  @JsonKey(name: 'number_of_episodes')
  final int numberOfEpisodes;
  @JsonKey(name: 'local_number_of_episodes')
  final int localNumberOfEpisodes;
  @JsonKey(name: 'local_number_of_seasons')
  final int localNumberOfSeasons;
  final String status;
  final String? overview;
  @JsonKey(name: 'ancestor_guid')
  final String ancestorGuid;
  @JsonKey(name: 'ancestor_name')
  final String ancestorName;
  @JsonKey(name: 'ancestor_category')
  final String ancestorCategory;
  final int ts;
  final int duration;
  @JsonKey(name: 'single_child_guid')
  final String singleChildGuid;
  @JsonKey(name: 'file_name')
  final String fileName;

  SeasonListResponse({
    required this.guid,
    required this.lan,
    this.imdbId,
    required this.trimId,
    required this.tvTitle,
    required this.parentGuid,
    required this.parentTitle,
    required this.title,
    required this.type,
    this.poster,
    required this.posterWidth,
    required this.posterHeight,
    required this.isFavorite,
    required this.watched,
    required this.watchedTs,
    required this.voteAverage,
    required this.mediaStream,
    required this.seasonNumber,
    required this.episodeNumber,
    this.airDate,
    required this.numberOfSeasons,
    required this.numberOfEpisodes,
    required this.localNumberOfEpisodes,
    required this.localNumberOfSeasons,
    required this.status,
    this.overview,
    required this.ancestorGuid,
    required this.ancestorName,
    required this.ancestorCategory,
    required this.ts,
    required this.duration,
    required this.singleChildGuid,
    required this.fileName,
  });

  factory SeasonListResponse.fromJson(Map<String, dynamic> json) => _$SeasonListResponseFromJson(json);
  Map<String, dynamic> toJson() => _$SeasonListResponseToJson(this);
}
