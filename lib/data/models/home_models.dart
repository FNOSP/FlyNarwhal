import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/media_type.dart';

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

  factory MediaDbListResponse.fromJson(Map<String, dynamic> json) =>
      _$MediaDbListResponseFromJson(json);
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

  factory MediaStream.fromJson(Map<String, dynamic> json) =>
      _$MediaStreamFromJson(json);
  Map<String, dynamic> toJson() => _$MediaStreamToJson(this);
}

// color_range_type 在不同接口下可能是字符串或数组（文件夹浏览返回
// ["SDR"]）；统一归一为首项字符串，避免解析期类型转换异常。
String? parseColorRangeType(dynamic value) {
  if (value is List) {
    return value.isEmpty ? null : value.first?.toString();
  }
  return value as String?;
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
  // Folder items expose covers via poster_list (no `poster` field).
  @JsonKey(name: 'poster_list')
  final List<String>? posterList;
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
  @JsonKey(name: 'local_number_of_seasons')
  final int? localNumberOfSeasons;
  @JsonKey(name: 'local_number_of_episodes')
  final int? localNumberOfEpisodes;
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
    this.posterList,
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
    this.localNumberOfSeasons,
    this.localNumberOfEpisodes,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) =>
      _$MediaItemFromJson(json);
  Map<String, dynamic> toJson() => _$MediaItemToJson(this);

  // 封面优先级：poster 字段 → poster_list 首项（文件夹视图的封面来源）。
  String? get effectivePoster {
    final p = poster?.trim();
    if (p != null && p.isNotEmpty) {
      return poster;
    }
    if (posterList != null && posterList!.isNotEmpty) {
      return posterList!.first;
    }
    return null;
  }
}

String? buildPosterSubtitle(MediaItem item) {
  final mediaType = MediaType.tryParse(item.type);
  if (mediaType == MediaType.tv) {
    // Mirror the web layout subheading builder for TV items:
    //   c = number_of_seasons, u = local_number_of_seasons,
    //   l = local_number_of_episodes, a = season_number
    //   if (c > 1 || u > 1) { u>1 => "共 u 季"; u==1 => "第 a 季" }
    //   else if ((c==1||u==1) && u==1) => "共 l 集"
    //   then append the year range from first/last air date.
    final c = item.numberOfSeasons ?? 0;
    final u = item.localNumberOfSeasons ?? 0;
    final l = item.localNumberOfEpisodes ?? 0;

    final List<String> parts = [];
    if (c > 1 || u > 1) {
      if (u > 1) {
        parts.add('共 $u 季');
      } else {
        parts.add('第 ${item.seasonNumber} 季');
      }
    } else if ((c == 1 || u == 1) && u == 1) {
      parts.add('共 $l 集');
    }

    final year = _buildAirDateYear(item.firstAirDate, item.lastAirDate);
    if (year.isNotEmpty) parts.add(year);

    return parts.isEmpty ? null : parts.join(' · ');
  }

  if (_isBlank(item.releaseDate) && !_isBlank(item.type)) {
    return _mediaTypeDescription(item.type);
  }

  if (item.status == '1' && mediaType == MediaType.video) {
    return '';
  }

  return _takeYear(item.releaseDate);
}

/// Builds the year segment for a TV item from its first/last air date,
/// mirroring the web `cD` helper: `firstYear` (or `firstYear-lastYear` when
/// they differ), returning '' when neither date is present.
String _buildAirDateYear(String? firstAirDate, String? lastAirDate) {
  final firstYear = _takeYear(firstAirDate);
  if (firstYear == null) return '';
  final lastYear = _takeYear(lastAirDate);
  if (lastYear != null && lastAirDate != firstAirDate && lastYear != firstYear) {
    return '$firstYear-$lastYear';
  }
  return firstYear;
}

String _mediaTypeDescription(String? type) {
  return MediaType.fromString(type).description;
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
  // Breadcrumb chain returned when browsing a folder (parent_guid):
  // all entries up to the last are ancestors, the last is the folder itself.
  @JsonKey(name: 'jump_list')
  final List<JumpItem> jumpList;

  ItemListQueryResponse({
    this.list = const [],
    this.total = 0,
    this.mdbName,
    this.jumpList = const [],
  });

  factory ItemListQueryResponse.fromJson(Map<String, dynamic> json) =>
      _$ItemListQueryResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ItemListQueryResponseToJson(this);
}

@JsonSerializable()
class JumpItem {
  @JsonKey(name: 'fv_guid')
  final String fvGuid;
  @JsonKey(name: 'base_name')
  final String baseName;

  const JumpItem({required this.fvGuid, required this.baseName});

  factory JumpItem.fromJson(Map<String, dynamic> json) =>
      _$JumpItemFromJson(json);
  Map<String, dynamic> toJson() => _$JumpItemToJson(this);
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

  factory PlayDetailResponse.fromJson(Map<String, dynamic> json) =>
      _$PlayDetailResponseFromJson(json);
  Map<String, dynamic> toJson() => _$PlayDetailResponseToJson(this);
}

String buildPlayDetailTitle(PlayDetailResponse item) {
  if (MediaType.tryParse(item.type) == MediaType.episode) {
    return item.tvTitle?.trim().isNotEmpty == true
        ? item.tvTitle!.trim()
        : item.title;
  }
  return item.title;
}

String? buildPlayDetailSubtitle(PlayDetailResponse item) {
  switch (MediaType.tryParse(item.type)) {
    case MediaType.episode:
      return '第 ${item.seasonNumber} 季 · 第 ${item.episodeNumber} 集';
    case MediaType.video:
      return ' ';
    default:
      return _mediaTypeDescription(item.type);
  }
}

@JsonSerializable(createFactory: false)
class ItemListQueryRequest {
  @JsonKey(name: 'ancestor_guid')
  final String? ancestorGuid;
  // Direct-parent folder guid (fv_*): lists only the folder's children,
  // mirroring the web folder view's item/list request.
  @JsonKey(name: 'parent_guid')
  final String? parentGuid;
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
    this.parentGuid,
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
