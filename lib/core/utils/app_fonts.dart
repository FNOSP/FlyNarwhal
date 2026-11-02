import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

import '../../ui/settings/app_language.dart';

class AppFonts {
  /// 简体中文界面字体。
  static String get primary => primaryFor(AppLanguage.zhHans);

  /// 按界面语言选择字体族。
  ///
  /// 简繁必须分用不同字体族：打包的 SourceHanSansSC-VF.otf 是纯简体子集，
  /// 系统 SC 字体在繁体下会回退成简体字形（如「門」写成「门」）。
  static String primaryFor(String language) {
    final isTraditional = AppLanguage.normalize(language) == AppLanguage.zhHant;
    if (kIsWeb) {
      // 打包字体只有简体子集，繁体交给浏览器自行回退。
      return 'SourceHanSansSC';
    }
    if (Platform.isWindows) {
      return isTraditional ? 'Microsoft JhengHei' : 'Microsoft YaHei';
    }
    if (Platform.isMacOS) {
      return isTraditional ? 'PingFang TC' : 'PingFang SC';
    }
    // Linux: the bundled SourceHanSansSC-VF.otf is a variable font that the
    // Flutter engine fails to render on Linux (CJK glyphs show as boxes).
    // Use the system CJK font instead.
    return isTraditional ? 'Noto Sans CJK TC' : 'Noto Sans CJK SC';
  }

  static const List<String> fallback = [
    'SourceHanSansSC',
    'Noto Sans CJK SC',
    'Noto Sans CJK TC',
    'PingFang SC',
    'PingFang TC',
    'Microsoft YaHei',
    'Microsoft JhengHei',
  ];
}
