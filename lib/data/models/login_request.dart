import 'package:json_annotation/json_annotation.dart';

part 'login_request.g.dart';

@JsonSerializable()
class LoginRequest {
  final String username;
  final String password;
  @JsonKey(name: 'app_name')
  final String appName;

  LoginRequest({
    required this.username,
    required this.password,
    this.appName = "trimemedia-web",
  });

  factory LoginRequest.fromJson(Map<String, dynamic> json) => _$LoginRequestFromJson(json);
  Map<String, dynamic> toJson() => _$LoginRequestToJson(this);
}
