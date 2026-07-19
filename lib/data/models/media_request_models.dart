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

class PlayInfoRequest {
  final String itemGuid;
  final String? mediaGuid;

  const PlayInfoRequest({
    required this.itemGuid,
    this.mediaGuid,
  });

  Map<String, dynamic> toJson() {
    return {
      'item_guid': itemGuid,
      if (mediaGuid != null && mediaGuid!.isNotEmpty) 'media_guid': mediaGuid,
    };
  }
}

@JsonSerializable(createFactory: false)
class PlayRecordRequest {
  @JsonKey(name: 'item_guid')
  final String itemGuid;
  @JsonKey(name: 'media_guid')
  final String mediaGuid;
  @JsonKey(name: 'video_guid')
  final String videoGuid;
  @JsonKey(name: 'audio_guid')
  final String audioGuid;
  @JsonKey(name: 'subtitle_guid')
  final String? subtitleGuid;
  final String resolution;
  final int bitrate;
  final int ts;
  final int duration;
  @JsonKey(name: 'play_link')
  final String? playLink;
  @JsonKey(name: 'device_id')
  final String deviceId;
  @JsonKey(name: 'direct_link_audio_index')
  final int directLinkAudioIndex;
  @JsonKey(name: 'lan')
  final String lan;
  @JsonKey(name: 'device_name')
  final String deviceName;

  const PlayRecordRequest({
    required this.itemGuid,
    required this.mediaGuid,
    required this.videoGuid,
    required this.audioGuid,
    this.subtitleGuid,
    required this.resolution,
    required this.bitrate,
    required this.ts,
    required this.duration,
    this.playLink,
    required this.deviceId,
    required this.directLinkAudioIndex,
    required this.lan,
    required this.deviceName,
  });

  Map<String, dynamic> toJson() => _$PlayRecordRequestToJson(this);
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
