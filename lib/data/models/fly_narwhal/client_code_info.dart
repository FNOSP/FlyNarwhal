/// Metadata of the activated per-client authorization code, returned by
/// `/api/client/activate` and `/api/client/me`.
class ClientCodeInfo {
  final String name;

  /// Epoch millis; null when permanent.
  final int? expireTime;
  final bool permanent;
  final String status;
  final String scope;
  final String? boundDeviceId;
  final String? boundDeviceLabel;
  final int serverTime;

  const ClientCodeInfo({
    required this.name,
    required this.expireTime,
    required this.permanent,
    required this.status,
    required this.scope,
    required this.boundDeviceId,
    required this.boundDeviceLabel,
    required this.serverTime,
  });

  bool get isReadOnly => scope == 'READ_ONLY';

  bool get isExpired =>
      !permanent && expireTime != null && expireTime! < DateTime.now().millisecondsSinceEpoch;

  factory ClientCodeInfo.fromJson(Map<String, dynamic> json) {
    return ClientCodeInfo(
      name: json['name']?.toString() ?? '',
      expireTime: (json['expireTime'] as num?)?.toInt(),
      permanent: json['permanent'] == true,
      status: json['status']?.toString() ?? 'ACTIVE',
      scope: json['scope']?.toString() ?? 'READ_WRITE',
      boundDeviceId: json['boundDeviceId']?.toString(),
      boundDeviceLabel: json['boundDeviceLabel']?.toString(),
      serverTime: (json['serverTime'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'expireTime': expireTime,
        'permanent': permanent,
        'status': status,
        'scope': scope,
        'boundDeviceId': boundDeviceId,
        'boundDeviceLabel': boundDeviceLabel,
        'serverTime': serverTime,
      };
}