import 'dart:ui' show Locale;

/// 应用界面语言的取值与映射。
///
/// 持久化的是语义串（'zh-Hans' | 'zh-Hant' | 'en'），与具体服务端语言代码解耦，
/// 这样后续调整 lan 映射时已有用户的选择仍然有效。
///
/// [labelFromValue] 返回的是各语言的**原生名**（用自己的文字显示自己），
/// 因此不随当前界面语言变化，也不参与文案翻译。
class AppLanguage {
  const AppLanguage._();

  static const String zhHans = 'zh-Hans';
  static const String zhHant = 'zh-Hant';
  static const String en = 'en';

  static const List<String> values = <String>[zhHans, zhHant, en];

  /// 未知/空值一律归一到简体中文。
  static String normalize(String? value) {
    switch (value) {
      case zhHant:
        return zhHant;
      case en:
        return en;
      case zhHans:
      default:
        return zhHans;
    }
  }

  /// 映射到 Flutter 的 Locale。繁体需要带上 scriptCode 才能命中本地化表。
  static Locale localeFromValue(String value) {
    switch (normalize(value)) {
      case zhHant:
        return const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
      case en:
        return const Locale('en');
      case zhHans:
      default:
        return const Locale('zh');
    }
  }

  /// 映射到 tag 接口的 `lan` 查询参数。
  ///
  /// 服务端只提供 zh-CN 与 en 两套标签数据（已实测：lan=zh-TW 仍返回简体），
  /// 因此繁体界面下请求英文标签，与 Web 端行为一致。
  static String tagLanFromValue(String value) {
    switch (normalize(value)) {
      case zhHant:
      case en:
        return 'en';
      case zhHans:
      default:
        return 'zh-CN';
    }
  }

  /// 语言在设置页下拉框中的显示名（原生名）。
  static String labelFromValue(String value) {
    switch (normalize(value)) {
      case zhHant:
        return '繁體中文';
      case en:
        return 'English';
      case zhHans:
      default:
        return '简体中文';
    }
  }
}
