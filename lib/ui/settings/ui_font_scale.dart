/// 界面整体文字大小的三档取值与缩放系数映射。
///
/// 持久化的是语义串（'small' | 'medium' | 'large'），不是浮点系数，
/// 这样调整档位系数时已有用户的选择仍然有效。
class UiFontScale {
  const UiFontScale._();

  static const String small = 'small';
  static const String medium = 'medium';
  static const String large = 'large';

  static const List<String> values = <String>[small, medium, large];

  /// 中档为基准，即原始字号。
  static const double mediumFactor = 1.0;

  static double factorFromValue(String value) {
    switch (value) {
      case small:
        return 0.85;
      case large:
        return 1.25;
      case medium:
      default:
        return mediumFactor;
    }
  }

  static String labelFromValue(String value) {
    switch (value) {
      case small:
        return '小';
      case large:
        return '大';
      case medium:
      default:
        return '中';
    }
  }

  /// 滑块用：档位在 [values] 中的下标（0=小, 1=中, 2=大）。
  static int indexFromValue(String value) {
    final index = values.indexOf(value);
    return index < 0 ? values.indexOf(medium) : index;
  }

  /// 下标还原为档位值，越界时钳制到合法范围。
  static String valueFromIndex(int index) {
    return values[index.clamp(0, values.length - 1)];
  }
}
