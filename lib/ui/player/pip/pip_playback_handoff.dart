import 'pip_window_payload.dart';

class PipPlaybackHandoff {
  static PipWindowPayload createPayload({
    required String mainWindowId,
    required String guid,
    String? mediaGuid,
    String? audioGuid,
    String? subtitleGuid,
    required int startPositionMs,
    required double volume,
    required double speed,
    required String title,
    required String subhead,
    PipWindowBounds? bounds,
  }) {
    return PipWindowPayload(
      mainWindowId: mainWindowId,
      guid: guid,
      mediaGuid: mediaGuid,
      audioGuid: audioGuid,
      subtitleGuid: subtitleGuid,
      startPositionMs: startPositionMs,
      volume: volume,
      speed: speed,
      title: title,
      subhead: subhead,
      bounds: bounds,
    );
  }

  static DesktopWindowBootstrapArgs createBootstrapArgs(
    PipWindowPayload payload,
  ) {
    return DesktopWindowBootstrapArgs.pip(payload);
  }
}
