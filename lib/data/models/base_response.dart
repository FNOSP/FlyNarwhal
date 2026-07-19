import 'package:json_annotation/json_annotation.dart';

part 'base_response.g.dart';

@JsonSerializable(genericArgumentFactories: true, createToJson: false)
class FnBaseResponse<T> {
  final int code;
  final String msg;
  final T? data;

  FnBaseResponse({required this.code, required this.msg, this.data});

  factory FnBaseResponse.fromJson(Map<String, dynamic> json, T Function(Object? json) fromJsonT) =>
      _$FnBaseResponseFromJson(json, fromJsonT);
}
