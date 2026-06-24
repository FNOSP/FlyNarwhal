import 'package:json_annotation/json_annotation.dart';

import 'home_models.dart';

part 'person_models.g.dart';

/// Person detail response from GET /v/api/v1/person/{guid}
@JsonSerializable()
class PersonResponse {
  final String guid;
  final String name;
  @JsonKey(name: 'imdb_id')
  final String? imdbId;
  @JsonKey(name: 'original_name')
  final String? originalName;
  final String? profile;
  final String? biography;
  @JsonKey(name: 'is_favorite')
  final int isFavorite;

  PersonResponse({
    required this.guid,
    required this.name,
    this.imdbId,
    this.originalName,
    this.profile,
    this.biography,
    this.isFavorite = 0,
  });

  factory PersonResponse.fromJson(Map<String, dynamic> json) =>
      _$PersonResponseFromJson(json);
  Map<String, dynamic> toJson() => _$PersonResponseToJson(this);
}

/// Single work entry under a person, from POST /v/api/v1/person/item/list
@JsonSerializable()
class PersonItemList {
  final String guid;
  final String title;
  final String? poster;
  @JsonKey(name: 'poster_width')
  final int? posterWidth;
  @JsonKey(name: 'poster_height')
  final int? posterHeight;
  @JsonKey(name: 'release_date')
  final String? releaseDate;
  @JsonKey(name: 'vote_average')
  final String? voteAverage;
  @JsonKey(name: 'is_favorite')
  final int isFavorite;
  final int watched;
  final int? duration;
  final String? status;
  final String? type;
  @JsonKey(name: 'media_stream')
  final MediaStream? mediaStream;

  PersonItemList({
    required this.guid,
    required this.title,
    this.poster,
    this.posterWidth,
    this.posterHeight,
    this.releaseDate,
    this.voteAverage,
    this.isFavorite = 0,
    this.watched = 0,
    this.duration,
    this.status,
    this.type,
    this.mediaStream,
  });

  factory PersonItemList.fromJson(Map<String, dynamic> json) =>
      _$PersonItemListFromJson(json);
  Map<String, dynamic> toJson() => _$PersonItemListToJson(this);
}

/// Wrapper for person work list response
@JsonSerializable()
class PersonItemListQueryResponse {
  final List<PersonItemList> list;
  final int total;

  PersonItemListQueryResponse({this.list = const [], this.total = 0});

  factory PersonItemListQueryResponse.fromJson(Map<String, dynamic> json) =>
      _$PersonItemListQueryResponseFromJson(json);
  Map<String, dynamic> toJson() => _$PersonItemListQueryResponseToJson(this);
}

/// Request body for POST /v/api/v1/person/item/list
@JsonSerializable(createFactory: false)
class PersonItemListRequest {
  @JsonKey(name: 'person_guid')
  final String personGuid;
  final int page;
  @JsonKey(name: 'page_size')
  final int pageSize;
  final String job;
  @JsonKey(name: 'sort_column')
  final String sortColumn;
  @JsonKey(name: 'sort_type')
  final String sortType;

  PersonItemListRequest({
    required this.personGuid,
    this.page = 1,
    this.pageSize = 100,
    required this.job,
    this.sortColumn = 'update_time',
    this.sortType = 'desc',
  });

  Map<String, dynamic> toJson() => _$PersonItemListRequestToJson(this);
}
