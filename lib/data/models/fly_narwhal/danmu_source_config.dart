/// Runtime-editable danmu source configuration served by
/// `/api/danmu/source-config` (server > 0.7.0).
///
/// The server is the single source of truth — nothing here is mirrored into
/// local preferences. Hand-written JSON codecs, matching the style of
/// `smart_skip_config.dart`.
library;

class DanmuDandanConfig {
  const DanmuDandanConfig({
    this.url = '',
    this.enabled = false,
    this.priority,
  });

  /// Effective ddp relay base URL; empty means the source has no address.
  final String url;

  /// Whether the relay is switched on. Independent of [url]: a blank address
  /// with [enabled] true stores an unusable source rather than an off one.
  final bool enabled;

  /// Search order against the official channel: 0 = preferred, 1 = fallback.
  /// Null means the server has never been told — treat it as "official first".
  final int? priority;

  factory DanmuDandanConfig.fromJson(Map<String, dynamic> json) {
    final rawPriority = json['priority'];
    return DanmuDandanConfig(
      url: (json['url'] as String?)?.trim() ?? '',
      enabled: json['enabled'] == true,
      priority: rawPriority is int
          ? rawPriority
          : int.tryParse(rawPriority?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'enabled': enabled,
        if (priority != null) 'priority': priority,
      };

  DanmuDandanConfig copyWith({
    String? url,
    bool? enabled,
    int? priority,
  }) {
    return DanmuDandanConfig(
      url: url ?? this.url,
      enabled: enabled ?? this.enabled,
      priority: priority ?? this.priority,
    );
  }
}

/// One third-party fallback danmu server row. [id] is null for entries that
/// only exist as a client-side draft (not saved yet).
class DanmuFallbackServer {
  const DanmuFallbackServer({
    this.id,
    this.name,
    required this.url,
    this.enabled = true,
  });

  final int? id;
  final String? name;
  final String url;
  final bool enabled;

  factory DanmuFallbackServer.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    return DanmuFallbackServer(
      id: rawId is int ? rawId : int.tryParse(rawId?.toString() ?? ''),
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : null,
      url: (json['url'] as String?)?.trim() ?? '',
      enabled: json['enabled'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (name != null) 'name': name,
        'url': url,
        'enabled': enabled,
      };

  DanmuFallbackServer copyWith({
    int? id,
    String? name,
    String? url,
    bool? enabled,
  }) {
    return DanmuFallbackServer(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      enabled: enabled ?? this.enabled,
    );
  }
}

/// Dandanplay open-network application credentials (edited in the client
/// settings; stored server-side in DANMU_SOURCE_CONFIG).
class DandanAccount {
  const DandanAccount({
    this.appId = '',
    this.appSecret = '',
    this.enabled = false,
    this.priority,
  });

  final String appId;
  final String appSecret;

  /// Whether the official channel is switched on. Independent of the
  /// credentials: turning it off keeps the values for the next time.
  final bool enabled;

  /// Search order against the relay: 0 = preferred, 1 = fallback. Null means
  /// the server has never been told — treat it as "official first".
  final int? priority;

  /// Both fields present, regardless of the switch.
  bool get hasCredentials => appId.isNotEmpty && appSecret.isNotEmpty;

  /// Actually usable: switched on with complete credentials.
  bool get isActive => enabled && hasCredentials;

  factory DandanAccount.fromJson(Map<String, dynamic> json) {
    final rawPriority = json['priority'];
    return DandanAccount(
      appId: (json['app_id'] as String?)?.trim() ?? '',
      appSecret: (json['app_secret'] as String?)?.trim() ?? '',
      enabled: json['enabled'] == true,
      priority: rawPriority is int
          ? rawPriority
          : int.tryParse(rawPriority?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'app_id': appId,
        'app_secret': appSecret,
        'enabled': enabled,
        if (priority != null) 'priority': priority,
      };

  DandanAccount copyWith({
    String? appId,
    String? appSecret,
    bool? enabled,
    int? priority,
  }) {
    return DandanAccount(
      appId: appId ?? this.appId,
      appSecret: appSecret ?? this.appSecret,
      enabled: enabled ?? this.enabled,
      priority: priority ?? this.priority,
    );
  }
}

class DanmuSourceConfig {
  const DanmuSourceConfig({
    this.dandan = const DanmuDandanConfig(),
    this.fallbackServers = const [],
    this.dandanAccount = const DandanAccount(),
  });

  final DanmuDandanConfig dandan;
  final List<DanmuFallbackServer> fallbackServers;
  final DandanAccount dandanAccount;

  factory DanmuSourceConfig.fromJson(Map<String, dynamic> json) {
    final dandanJson = json['dandan'];
    final accountJson = json['dandan_account'];
    final rawServers = json['fallback_servers'];
    return DanmuSourceConfig(
      dandan: dandanJson is Map<String, dynamic>
          ? DanmuDandanConfig.fromJson(dandanJson)
          : const DanmuDandanConfig(),
      fallbackServers: rawServers is List
          ? rawServers
              .whereType<Map>()
              .map((e) =>
                  DanmuFallbackServer.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false)
          : const [],
      dandanAccount: accountJson is Map<String, dynamic>
          ? DandanAccount.fromJson(accountJson)
          : const DandanAccount(),
    );
  }

  Map<String, dynamic> toJson() => {
        'dandan': dandan.toJson(),
        'fallback_servers': fallbackServers.map((e) => e.toJson()).toList(),
        'dandan_account': dandanAccount.toJson(),
      };
}
