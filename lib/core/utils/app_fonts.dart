import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

class AppFonts {
  static String get primary {
    if (kIsWeb) return 'SourceHanSansSC';
    if (Platform.isWindows) return 'Microsoft YaHei';
    if (Platform.isMacOS) return 'PingFang SC';
    // Linux: the bundled SourceHanSansSC-VF.otf is a variable font that the
    // Flutter engine fails to render on Linux (CJK glyphs show as boxes).
    // Use the system CJK font instead.
    return 'Noto Sans CJK SC';
  }

  static const List<String> fallback = ['SourceHanSansSC', 'Noto Sans CJK SC'];
}
