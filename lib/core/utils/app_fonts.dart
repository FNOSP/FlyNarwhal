import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

class AppFonts {
  static String get primary {
    if (kIsWeb) return 'SourceHanSansSC';
    if (Platform.isWindows) return 'Microsoft YaHei';
    if (Platform.isMacOS) return 'PingFang SC';
    return 'SourceHanSansSC';
  }

  static const List<String> fallback = ['SourceHanSansSC'];
}
