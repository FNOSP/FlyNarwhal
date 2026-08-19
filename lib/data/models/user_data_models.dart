import 'package:json_annotation/json_annotation.dart';

part 'user_data_models.g.dart';

/// Request body for POST /user/getData. [mdbGuid] scopes the key to one
/// media library; omit it for global (e.g. category) settings. [itemGuid]
/// narrows further to a single item (e.g. a folder's own browse settings).
@JsonSerializable(createFactory: false)
class UserDataGetRequest {
  final String key;
  @JsonKey(name: 'mdb_guid', includeIfNull: false)
  final String? mdbGuid;
  @JsonKey(name: 'item_guid', includeIfNull: false)
  final String? itemGuid;

  const UserDataGetRequest({required this.key, this.mdbGuid, this.itemGuid});

  Map<String, dynamic> toJson() => _$UserDataGetRequestToJson(this);
}

/// Request body for POST /user/setData. [value] is an opaque JSON string.
@JsonSerializable(createFactory: false)
class UserDataSetRequest {
  final String key;
  @JsonKey(name: 'mdb_guid', includeIfNull: false)
  final String? mdbGuid;
  @JsonKey(name: 'item_guid', includeIfNull: false)
  final String? itemGuid;
  final String value;

  const UserDataSetRequest({
    required this.key,
    this.mdbGuid,
    this.itemGuid,
    required this.value,
  });

  Map<String, dynamic> toJson() => _$UserDataSetRequestToJson(this);
}

/// Response data for POST /user/getData. [value] holds the persisted JSON
/// string (empty when nothing was stored yet).
@JsonSerializable()
class UserDataResponse {
  final String key;
  @JsonKey(name: 'mdb_guid')
  final String? mdbGuid;
  final String? value;

  const UserDataResponse({this.key = '', this.mdbGuid, this.value});

  factory UserDataResponse.fromJson(Map<String, dynamic> json) =>
      _$UserDataResponseFromJson(json);
}
