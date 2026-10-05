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
  });

  /// Effective ddp relay base URL; empty means the source is off.
  final String url;

  final bool enabled;

  factory DanmuDandanConfig.fromJson(Map<String, dynamic> json) {
    return DanmuDandanConfig(
      url: (json['url'] as String?)?.trim() ?? '',
      enabled: json['enabled'] == true,
    );
  }

  Map<String, dynamic> toJson() => {'url': url, 'enabled': enabled};

  DanmuDandanConfig copyWith({String? url, bool? enabled}) {
    return DanmuDandanConfig(
      url: url ?? this.url,
      enabled: enabled ?? this.enabled,
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

class DanmuSourceConfig {
  const DanmuSourceConfig({
    this.dandan = const DanmuDandanConfig(),
    this.fallbackServers = const [],
  });

  final DanmuDandanConfig dandan;
  final List<DanmuFallbackServer> fallbackServers;

  factory DanmuSourceConfig.fromJson(Map<String, dynamic> json) {
    final dandanJson = json['dandan'];
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
    );
  }

  Map<String, dynamic> toJson() => {
        'dandan': dandan.toJson(),
        'fallback_servers': fallbackServers.map((e) => e.toJson()).toList(),
      };
}
