import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/services.dart';

import 'pip_window_payload.dart';

class PipWindowChannelMethod {
  static const String enterPipAck = 'enter_pip_ack';
  static const String restoreMainPlayer = 'restore_main_player';
  static const String closePip = 'close_pip';
  static const String syncBounds = 'sync_bounds';
}

class PipWindowChannel {
  static const String _channelName = 'fly_narwhal/player_pip_bridge';
  static const WindowMethodChannel _channel =
      WindowMethodChannel(
        _channelName,
        mode: ChannelMode.unidirectional,
      );

  static Future<void> register(
    Future<dynamic> Function(MethodCall call)? handler,
  ) {
    return _channel.setMethodCallHandler(handler);
  }

  static Future<void> sendEnterAck() {
    return _channel.invokeMethod<void>(PipWindowChannelMethod.enterPipAck);
  }

  static Future<void> sendRestoreMainPlayer(PipWindowPayload payload) {
    return _channel.invokeMethod<void>(
      PipWindowChannelMethod.restoreMainPlayer,
      payload.toJson(),
    );
  }

  static Future<void> sendClosePip() {
    return _channel.invokeMethod<void>(PipWindowChannelMethod.closePip);
  }

  static Future<void> sendSyncBounds(PipWindowBounds bounds) {
    return _channel.invokeMethod<void>(
      PipWindowChannelMethod.syncBounds,
      bounds.toJson(),
    );
  }
}
