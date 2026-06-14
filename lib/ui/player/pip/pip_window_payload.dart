import 'dart:convert';
import 'dart:ui';

enum DesktopWindowType { main, pip }

class DesktopWindowBootstrapArgs {
  final DesktopWindowType type;
  final PipWindowPayload? pipPayload;

  const DesktopWindowBootstrapArgs({
    required this.type,
    this.pipPayload,
  });

  factory DesktopWindowBootstrapArgs.main() {
    return const DesktopWindowBootstrapArgs(type: DesktopWindowType.main);
  }

  factory DesktopWindowBootstrapArgs.pip(PipWindowPayload payload) {
    return DesktopWindowBootstrapArgs(
      type: DesktopWindowType.pip,
      pipPayload: payload,
    );
  }

  factory DesktopWindowBootstrapArgs.fromJson(Map<String, dynamic> json) {
    final typeValue = json['type'] as String? ?? 'main';
    final type = typeValue == 'pip'
        ? DesktopWindowType.pip
        : DesktopWindowType.main;
    return DesktopWindowBootstrapArgs(
      type: type,
      pipPayload: type == DesktopWindowType.pip
          ? PipWindowPayload.fromJson(
              Map<String, dynamic>.from(
                json['pipPayload'] as Map<dynamic, dynamic>? ??
                    const <String, dynamic>{},
              ),
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type.name,
      if (pipPayload != null) 'pipPayload': pipPayload!.toJson(),
    };
  }

  String encode() => jsonEncode(toJson());

  static DesktopWindowBootstrapArgs tryParse(String? value) {
    if (value == null || value.trim().isEmpty) {
      return DesktopWindowBootstrapArgs.main();
    }
    try {
      final json = jsonDecode(value);
      if (json is Map<String, dynamic>) {
        return DesktopWindowBootstrapArgs.fromJson(json);
      }
      if (json is Map) {
        return DesktopWindowBootstrapArgs.fromJson(
          Map<String, dynamic>.from(json),
        );
      }
    } catch (_) {
      // Ignore malformed window arguments and fall back to main window.
    }
    return DesktopWindowBootstrapArgs.main();
  }
}

class PipWindowBounds {
  final double left;
  final double top;
  final double width;
  final double height;

  const PipWindowBounds({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  factory PipWindowBounds.fromRect(Rect rect) {
    return PipWindowBounds(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
    );
  }

  factory PipWindowBounds.fromJson(Map<String, dynamic> json) {
    return PipWindowBounds(
      left: (json['left'] as num?)?.toDouble() ?? 0,
      top: (json['top'] as num?)?.toDouble() ?? 0,
      width: (json['width'] as num?)?.toDouble() ?? 320,
      height: (json['height'] as num?)?.toDouble() ?? 180,
    );
  }

  Rect toRect() => Rect.fromLTWH(left, top, width, height);

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'left': left,
      'top': top,
      'width': width,
      'height': height,
    };
  }
}

class PipWindowPayload {
  final String mainWindowId;
  final String guid;
  final String? mediaGuid;
  final String? audioGuid;
  final String? subtitleGuid;
  final int startPositionMs;
  final double volume;
  final double speed;
  final String title;
  final String subhead;
  final PipWindowBounds? bounds;

  const PipWindowPayload({
    required this.mainWindowId,
    required this.guid,
    this.mediaGuid,
    this.audioGuid,
    this.subtitleGuid,
    required this.startPositionMs,
    required this.volume,
    required this.speed,
    required this.title,
    required this.subhead,
    this.bounds,
  });

  factory PipWindowPayload.fromJson(Map<String, dynamic> json) {
    final boundsJson = json['bounds'];
    return PipWindowPayload(
      mainWindowId: json['mainWindowId'] as String? ?? '',
      guid: json['guid'] as String? ?? '',
      mediaGuid: json['mediaGuid'] as String?,
      audioGuid: json['audioGuid'] as String?,
      subtitleGuid: json['subtitleGuid'] as String?,
      startPositionMs: (json['startPositionMs'] as num?)?.toInt() ?? 0,
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
      speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
      title: json['title'] as String? ?? '',
      subhead: json['subhead'] as String? ?? '',
      bounds: boundsJson is Map
          ? PipWindowBounds.fromJson(
              Map<String, dynamic>.from(boundsJson),
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'mainWindowId': mainWindowId,
      'guid': guid,
      'mediaGuid': mediaGuid,
      'audioGuid': audioGuid,
      'subtitleGuid': subtitleGuid,
      'startPositionMs': startPositionMs,
      'volume': volume,
      'speed': speed,
      'title': title,
      'subhead': subhead,
      'bounds': bounds?.toJson(),
    };
  }

  PipWindowPayload copyWith({
    String? mainWindowId,
    String? guid,
    String? mediaGuid,
    String? audioGuid,
    String? subtitleGuid,
    int? startPositionMs,
    double? volume,
    double? speed,
    String? title,
    String? subhead,
    PipWindowBounds? bounds,
  }) {
    return PipWindowPayload(
      mainWindowId: mainWindowId ?? this.mainWindowId,
      guid: guid ?? this.guid,
      mediaGuid: mediaGuid ?? this.mediaGuid,
      audioGuid: audioGuid ?? this.audioGuid,
      subtitleGuid: subtitleGuid ?? this.subtitleGuid,
      startPositionMs: startPositionMs ?? this.startPositionMs,
      volume: volume ?? this.volume,
      speed: speed ?? this.speed,
      title: title ?? this.title,
      subhead: subhead ?? this.subhead,
      bounds: bounds ?? this.bounds,
    );
  }
}
