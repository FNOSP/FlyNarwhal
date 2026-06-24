import 'package:json_annotation/json_annotation.dart';

part 'home_models.g.dart';

@JsonSerializable()
class MediaDbListResponse {
  final String guid;
  final String title;
  final List<String> posters;
  final String category;
  @JsonKey(name: 'view_type')
  final int viewType;

  MediaDbListResponse({
    required this.guid,
    required this.title,
    this.posters = const [],
    required this.category,
    this.viewType = 0,
  });

  factory MediaDbListResponse.fromJson(Map<String, dynamic> json) => _$MediaDbListResponseFromJson(json);
  Map<String, dynamic> toJson() => _$MediaDbListResponseToJson(this);
}

@JsonSerializable()
class MediaStream {
  final List<String>? resolutions;
  @JsonKey(name: 'audio_type')
  final String? audioType;
  @JsonKey(name: 'color_range_type')
  final String? colorRangeType;

  MediaStream({this.resolutions, this.audioType, this.colorRangeType});

  factory MediaStream.fromJson(Map<String, dynamic> json) => _$MediaStreamFromJson(json);
  Map<String, dynamic> toJson() => _$MediaStreamToJson(this);
}

@JsonSerializable()
class MediaItem {
  final String guid;
  final String? lan;
  @JsonKey(name: 'douban_id')
  final int? doubanId;
  @JsonKey(name: 'imdb_id')
  final String? imdbId;
  final String title;
  final String? type;
  final String? poster;
  @JsonKey(name: 'poster_width')
  final int? posterWidth;
  @JsonKey(name: 'poster_height')
  final int? posterHeight;
  @JsonKey(name: 'is_favorite')
  final int isFavorite;
  final int? watched;
  @JsonKey(name: 'vote_average')
  final String? voteAverage;
  @JsonKey(name: 'media_stream')
  final MediaStream? mediaStream;
  @JsonKey(name: 'release_date')
  final String? releaseDate;
  @JsonKey(name: 'season_number')
  final int seasonNumber;
  @JsonKey(name: 'episode_number')
  final int episodeNumber;
  @JsonKey(name: 'first_air_date')
  final String? firstAirDate;
  @JsonKey(name: 'last_air_date')
  final String? lastAirDate;
  @JsonKey(name: 'number_of_seasons')
  final int? numberOfSeasons;
  @JsonKey(name: 'number_of_episodes')
  final int? numberOfEpisodes;
  final String? status;
  final String? overview;
  @JsonKey(name: 'ancestor_guid')
  final String? ancestorGuid;
  @JsonKey(name: 'ancestor_name')
  final String? ancestorName;
  @JsonKey(name: 'ancestor_category')
  final String? ancestorCategory;
  final int? duration;
  // Genre id list, mapped to text via tag/genres endpoint
  final List<int>? genres;
  // Number of works for a person result
  @JsonKey(name: 'number_of_item')
  final int? numberOfItem;

  MediaItem({
    required this.guid,
    this.lan,
    this.doubanId,
    this.imdbId,
    required this.title,
    this.type,
    this.poster,
    this.posterWidth,
    this.posterHeight,
    this.isFavorite = 0,
    this.watched,
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
    this.genres,
    this.numberOfItem,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) => _$MediaItemFromJson(json);
  Map<String, dynamic> toJson() => _$MediaItemToJson(this);
}

String? buildPosterSubtitle(MediaItem item) {
  if (item.type == 'TV') {
    if (!_isBlank(item.firstAirDate) && !_isBlank(item.lastAirDate)) {
      final seasonCount = item.numberOfSeasons ?? 0;
      return '共 $seasonCount 季 · ${_takeYear(item.firstAirDate)}~${_takeYear(item.lastAirDate)}';
    }
    if (item.numberOfSeasons == 1 && item.status == 'Ended') {
      final year = !_isBlank(item.releaseDate) ? ' · ${_takeYear(item.releaseDate)}' : '';
      final episodeCount = item.numberOfEpisodes ?? 0;
      return '共 $episodeCount 集$year';
    }
    if (item.numberOfSeasons != null && !_isBlank(item.releaseDate)) {
      return '第 ${item.seasonNumber} 季 · ${_takeYear(item.releaseDate)}';
    }
    return _takeYear(item.releaseDate);
  }

  if (_isBlank(item.releaseDate) && !_isBlank(item.type)) {
    return _mediaTypeDescription(item.type);
  }

  if (item.status == '1' && item.type == 'Video') {
    return '';
  }

  return _takeYear(item.releaseDate);
}

String _mediaTypeDescription(String? type) {
  switch (type) {
    case 'Movie':
      return '电影';
    case 'TV':
      return '电视节目';
    case 'Directory':
      return '目录';
    case 'Video':
      return '其他';
    case 'Episode':
      return '剧集';
    case 'Season':
      return '季';
    default:
      return '其他';
  }
}

bool _isBlank(String? value) {
  return value == null || value.trim().isEmpty;
}

String? _takeYear(String? value) {
  if (_isBlank(value)) return null;
  final trimmed = value!.trim();
  return trimmed.length >= 4 ? trimmed.substring(0, 4) : trimmed;
}

@JsonSerializable()
class ItemListQueryResponse {
  final List<MediaItem> list;
  final int total;
  @JsonKey(name: 'mdb_name')
  final String? mdbName;

  ItemListQueryResponse({this.list = const [], this.total = 0, this.mdbName});

  factory ItemListQueryResponse.fromJson(Map<String, dynamic> json) => _$ItemListQueryResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ItemListQueryResponseToJson(this);
}

@JsonSerializable()
class PlayDetailResponse {
  final String guid;
  final String title;
  final String? type;
  final String? poster;
  @JsonKey(name: 'is_favorite')
  final int isFavorite;
  final int watched;
  @JsonKey(name: 'media_stream')
  final MediaStream? mediaStream;
  @JsonKey(name: 'vote_average')
  final String? voteAverage;
  @JsonKey(name: 'season_number')
  final int seasonNumber;
  @JsonKey(name: 'episode_number')
  final int episodeNumber;
  @JsonKey(name: 'tv_title')
  final String? tvTitle;
  final int? duration;
  final int? ts;
  final String? status;
  @JsonKey(name: 'parent_guid')
  final String? parentGuid;

  PlayDetailResponse({
    required this.guid,
    required this.title,
    this.type,
    this.poster,
    this.isFavorite = 0,
    this.watched = 0,
    this.mediaStream,
    this.voteAverage,
    this.seasonNumber = 0,
    this.episodeNumber = 0,
    this.tvTitle,
    this.duration,
    this.ts,
    this.status,
    this.parentGuid,
  });

  factory PlayDetailResponse.fromJson(Map<String, dynamic> json) => _$PlayDetailResponseFromJson(json);
  Map<String, dynamic> toJson() => _$PlayDetailResponseToJson(this);
}

String buildPlayDetailTitle(PlayDetailResponse item) {
  if (item.type == 'Episode') {
    return item.tvTitle?.trim().isNotEmpty == true ? item.tvTitle!.trim() : item.title;
  }
  return item.title;
}

String? buildPlayDetailSubtitle(PlayDetailResponse item) {
  switch (item.type) {
    case 'Episode':
      return '第 ${item.seasonNumber} 季 · 第 ${item.episodeNumber} 集';
    case 'Video':
      return ' ';
    default:
      return _mediaTypeDescription(item.type);
  }
}

@JsonSerializable(createFactory: false)
class ItemListQueryRequest {
  @JsonKey(name: 'ancestor_guid')
  final String? ancestorGuid;
  @JsonKey(name: 'exclude_grouped_video')
  final int excludeGroupedVideo;
  @JsonKey(name: 'sort_type')
  final String sortType;
  @JsonKey(name: 'sort_column')
  final String sortColumn;
  @JsonKey(name: 'page_size')
  final int pageSize;
  final int page;
  final Tags tags;

  ItemListQueryRequest({
    this.ancestorGuid,
    this.excludeGroupedVideo = 1,
    this.sortType = "DESC",
    this.sortColumn = "create_time",
    this.pageSize = 22,
    this.page = 1,
    required this.tags,
  });

  Map<String, dynamic> toJson() => _$ItemListQueryRequestToJson(this);
}

@JsonSerializable()
class Tags {
  final List<String> type;
  final int? genres;
  final String? resolution;
  @JsonKey(name: 'color_range')
  final String? colorRange;
  @JsonKey(name: 'locate')
  final String? locate;
  final String? decade;
  @JsonKey(name: 'recognition_status')
  final String? recognitionStatus;
  final String? watched;
  @JsonKey(name: 'audio_type')
  final String? audioType;
  
  Tags({
    required this.type,
    this.genres,
    this.resolution,
    this.colorRange,
    this.locate,
    this.decade,
    this.recognitionStatus,
    this.watched,
    this.audioType,
  });

  factory Tags.fromJson(Map<String, dynamic> json) => _$TagsFromJson(json);
  Map<String, dynamic> toJson() => _$TagsToJson(this);
}
