import 'dart:convert';

import 'package:crypto/crypto.dart';

final class ReportingLaunchRequest {
  const ReportingLaunchRequest({
    required this.deviceId,
    required this.deviceIdType,
    required this.osName,
    required this.osArch,
    required this.cpuModel,
    required this.gpuModel,
    required this.gpuType,
    required this.version,
    required this.timestamp,
  });

  final String deviceId;
  final String deviceIdType;
  final String osName;
  final String osArch;
  final String cpuModel;
  final String gpuModel;
  final String gpuType;
  final String version;
  final int timestamp;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'deviceId': deviceId,
        'deviceIdType': deviceIdType,
        'osName': osName,
        'osArch': osArch,
        'cpuModel': cpuModel,
        'gpuModel': gpuModel,
        'gpuType': gpuType,
        'version': version,
        'timestamp': timestamp,
      };

  Map<String, dynamic> toSignedJson(String apiSecret) {
    final sortedBody = <String, dynamic>{};
    final body = toJson();
    for (final key in body.keys.toList()..sort()) {
      sortedBody[key] = body[key];
    }
    final compactJson = jsonEncode(sortedBody).replaceAll(RegExp(r'\s'), '');
    final signature =
        md5.convert(utf8.encode(compactJson + apiSecret)).toString();
    return <String, dynamic>{...sortedBody, 'signature': signature};
  }
}
