import 'package:json_annotation/json_annotation.dart';

import '../../core/constants/app_constants.dart';
import 'home_models.dart';

part 'media_request_models.g.dart';

@JsonSerializable(createFactory: false)
class ItemGuidRequest {
  @JsonKey(name: 'item_guid')
  final String itemGuid;

  const ItemGuidRequest({
    required this.itemGuid,
  });

  Map<String, dynamic> toJson() => _$ItemGuidRequestToJson(this);
}

@JsonSerializable(createFactory: false)
class MediaLibraryBrowseRequest {
  @JsonKey(name: 'ancestor_guid')
  final String? ancestorGuid;
  @JsonKey(includeToJson: false)
  final String? categoryType;
  @JsonKey(name: 'page_size')
  final int pageSize;
  final int page;
  @JsonKey(name: 'sort_column')
  final String sortColumn;
  @JsonKey(name: 'sort_type')
  final String sortType;
  @JsonKey(includeToJson: false)
  final bool favoriteOnly;
  @JsonKey(includeToJson: false)
  final Tags tags;

  const MediaLibraryBrowseRequest({
    this.ancestorGuid,
    this.categoryType,
    this.pageSize = 50,
    this.page = 1,
    this.sortColumn = 'create_time',
    this.sortType = 'DESC',
    this.favoriteOnly = false,
    required this.tags,
  });

  ItemListQueryRequest toItemListQueryRequest() {
    return ItemListQueryRequest(
      ancestorGuid: ancestorGuid,
      page: page,
      pageSize: pageSize,
      sortColumn: sortColumn,
      sortType: sortType,
      tags: tags,
    );
  }

  String resolveEndpoint() {
    return favoriteOnly ? ApiEndpoints.favoriteList : ApiEndpoints.itemList;
  }

  MediaLibraryBrowseRequest copyWith({
    String? ancestorGuid,
    String? categoryType,
    int? pageSize,
    int? page,
    String? sortColumn,
    String? sortType,
    bool? favoriteOnly,
    Tags? tags,
  }) {
    return MediaLibraryBrowseRequest(
      ancestorGuid: ancestorGuid ?? this.ancestorGuid,
      categoryType: categoryType ?? this.categoryType,
      pageSize: pageSize ?? this.pageSize,
      page: page ?? this.page,
      sortColumn: sortColumn ?? this.sortColumn,
      sortType: sortType ?? this.sortType,
      favoriteOnly: favoriteOnly ?? this.favoriteOnly,
      tags: tags ?? this.tags,
    );
  }
}
