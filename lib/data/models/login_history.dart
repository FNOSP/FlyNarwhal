import 'package:json_annotation/json_annotation.dart';

part 'login_history.g.dart';

@JsonSerializable()
class LoginHistory {
  final String host;
  final int port;
  final String username;
  final String? password;
  final bool isHttps;
  final bool rememberPassword;
  final bool isNasLogin;
  final String fnConnectUrl;
  final String fnId;
  final int lastLoginTimestamp;
  final String displayHost;
  final int? displayPort;

  LoginHistory({
    required this.host,
    required this.port,
    required this.username,
    this.password,
    required this.isHttps,
    required this.rememberPassword,
    this.isNasLogin = false,
    this.fnConnectUrl = "",
    this.fnId = "",
    int? lastLoginTimestamp,
    this.displayHost = "",
    this.displayPort,
  }) : lastLoginTimestamp = lastLoginTimestamp ?? DateTime.now().millisecondsSinceEpoch;

  factory LoginHistory.fromJson(Map<String, dynamic> json) => _$LoginHistoryFromJson(json);
  Map<String, dynamic> toJson() => _$LoginHistoryToJson(this);

  String getEndpoint() {
    if (isNasLogin) {
      return fnId.isEmpty ? "FN Connect" : fnId;
    }
    final dHost = displayHost.isEmpty ? host : displayHost;
    final dPort = displayPort ?? port;
    if (dPort != 0) {
      return "$dHost:$dPort";
    } else {
      return dHost;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LoginHistory) return false;

    if (isNasLogin != other.isNasLogin) return false;

    if (isNasLogin) {
      return fnId == other.fnId &&
          username == other.username &&
          isHttps == other.isHttps;
    } else {
      return displayHost == other.displayHost &&
          displayPort == other.displayPort &&
          username == other.username &&
          isHttps == other.isHttps;
    }
  }

  @override
  int get hashCode {
    var result = isNasLogin.hashCode;
    if (isNasLogin) {
      result = 31 * result + fnId.hashCode;
    } else {
      result = 31 * result + displayHost.hashCode;
      if (displayPort != null) result = 31 * result + displayPort!;
    }
    result = 31 * result + username.hashCode;
    result = 31 * result + isHttps.hashCode;
    return result;
  }
}
