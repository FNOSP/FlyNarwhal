import 'package:json_annotation/json_annotation.dart';

part 'tag_models.g.dart';

@JsonSerializable()
class TagListResponse {
  final List<int> genres;
  final List<String> resolutions;
  @JsonKey(name: 'color_range')
  final List<String> colorRange;
  @JsonKey(name: 'audio_type')
  final List<String> audioType;
  final List<String> locate;
  final List<String> decades;
  @JsonKey(name: 'recognition_status')
  final List<int> recognitionStatus;

  TagListResponse({
    this.genres = const [],
    this.resolutions = const [],
    this.colorRange = const [],
    this.audioType = const [],
    this.locate = const [],
    this.decades = const [],
    this.recognitionStatus = const [],
  });

  factory TagListResponse.fromJson(Map<String, dynamic> json) => _$TagListResponseFromJson(json);
  Map<String, dynamic> toJson() => _$TagListResponseToJson(this);
}

@JsonSerializable()
class QueryTagResponse {
  final String key;
  final String value;

  QueryTagResponse({required this.key, required this.value});

  factory QueryTagResponse.fromJson(Map<String, dynamic> json) => _$QueryTagResponseFromJson(json);
  Map<String, dynamic> toJson() => _$QueryTagResponseToJson(this);
}

@JsonSerializable()
class GenresResponse {
  final int id;
  final String value;

  GenresResponse({this.id = 0, this.value = ''});

  factory GenresResponse.fromJson(Map<String, dynamic> json) => _$GenresResponseFromJson(json);
  Map<String, dynamic> toJson() => _$GenresResponseToJson(this);
}
