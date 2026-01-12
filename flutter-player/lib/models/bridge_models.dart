class AppSettings {
  bool isFollowingSystemTheme;
  bool darkMode;
  bool autoPlay;
  bool useExternalPlayer;
  String githubResourceProxyUrl;
  int introEndMs;
  int outroStartMs;

  AppSettings({
    this.isFollowingSystemTheme = false,
    this.darkMode = true,
    this.autoPlay = true,
    this.useExternalPlayer = false,
    this.githubResourceProxyUrl = "https://ghfast.top/",
    this.introEndMs = 0,
    this.outroStartMs = 0,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      isFollowingSystemTheme: json['isFollowingSystemTheme'] ?? false,
      darkMode: json['darkMode'] ?? true,
      autoPlay: json['autoPlay'] ?? true,
      useExternalPlayer: json['useExternalPlayer'] ?? false,
      githubResourceProxyUrl: json['githubResourceProxyUrl'] ?? "https://ghfast.top/",
      introEndMs: json['introEndMs'] ?? 0,
      outroStartMs: json['outroStartMs'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isFollowingSystemTheme': isFollowingSystemTheme,
      'darkMode': darkMode,
      'autoPlay': autoPlay,
      'useExternalPlayer': useExternalPlayer,
      'githubResourceProxyUrl': githubResourceProxyUrl,
      'introEndMs': introEndMs,
      'outroStartMs': outroStartMs,
    };
  }
}

class PlayerSettings {
  double volume;
  String? qualityResolution;
  int? qualityBitrate;
  double playerWindowWidth;
  double playerWindowHeight;
  double playerWindowX;
  double playerWindowY;
  bool playerIsFullscreen;
  String playerWindowAspectRatio;
  String navigationDisplayMode;

  PlayerSettings({
    this.volume = 1.0,
    this.qualityResolution,
    this.qualityBitrate,
    this.playerWindowWidth = 1280.0,
    this.playerWindowHeight = 720.0,
    this.playerWindowX = 0.0,
    this.playerWindowY = 0.0,
    this.playerIsFullscreen = false,
    this.playerWindowAspectRatio = "AUTO",
    this.navigationDisplayMode = "Left",
  });

  factory PlayerSettings.fromJson(Map<String, dynamic> json) {
    return PlayerSettings(
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
      qualityResolution: json['quality_resolution'],
      qualityBitrate: json['quality_bitrate'],
      playerWindowWidth: (json['playerWindowWidth'] as num?)?.toDouble() ?? 1280.0,
      playerWindowHeight: (json['playerWindowHeight'] as num?)?.toDouble() ?? 720.0,
      playerWindowX: (json['playerWindowX'] as num?)?.toDouble() ?? 0.0,
      playerWindowY: (json['playerWindowY'] as num?)?.toDouble() ?? 0.0,
      playerIsFullscreen: json['playerIsFullscreen'] ?? false,
      playerWindowAspectRatio: json['playerWindowAspectRatio'] ?? "AUTO",
      navigationDisplayMode: json['navigationDisplayMode'] ?? "Left",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'volume': volume,
      'quality_resolution': qualityResolution,
      'quality_bitrate': qualityBitrate,
      'playerWindowWidth': playerWindowWidth,
      'playerWindowHeight': playerWindowHeight,
      'playerWindowX': playerWindowX,
      'playerWindowY': playerWindowY,
      'playerIsFullscreen': playerIsFullscreen,
      'playerWindowAspectRatio': playerWindowAspectRatio,
      'navigationDisplayMode': navigationDisplayMode,
    };
  }
}

class ProxyConfig {
  final String baseUrl;
  final Map<String, String> headers;

  ProxyConfig({required this.baseUrl, required this.headers});

  factory ProxyConfig.fromJson(Map<String, dynamic> json) {
    return ProxyConfig(
      baseUrl: json['baseUrl'] ?? "",
      headers: Map<String, String>.from(json['headers'] ?? {}),
    );
  }
}
