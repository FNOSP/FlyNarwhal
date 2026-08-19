// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_data_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$UserDataGetRequestToJson(UserDataGetRequest instance) {
  final val = <String, dynamic>{
    'key': instance.key,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('mdb_guid', instance.mdbGuid);
  writeNotNull('item_guid', instance.itemGuid);
  return val;
}

Map<String, dynamic> _$UserDataSetRequestToJson(UserDataSetRequest instance) {
  final val = <String, dynamic>{
    'key': instance.key,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('mdb_guid', instance.mdbGuid);
  writeNotNull('item_guid', instance.itemGuid);
  val['value'] = instance.value;
  return val;
}

UserDataResponse _$UserDataResponseFromJson(Map<String, dynamic> json) =>
    UserDataResponse(
      key: json['key'] as String? ?? '',
      mdbGuid: json['mdb_guid'] as String?,
      value: json['value'] as String?,
    );
