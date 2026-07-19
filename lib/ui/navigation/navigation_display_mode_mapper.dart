import 'package:fluent_ui/fluent_ui.dart';

class NavigationDisplayModeMapper {
  const NavigationDisplayModeMapper._();

  static String toValue(PaneDisplayMode mode) {
    switch (mode) {
      case PaneDisplayMode.top:
        return 'Top';
      case PaneDisplayMode.expanded:
        return 'Left';
      case PaneDisplayMode.compact:
        return 'LeftCompact';
      case PaneDisplayMode.minimal:
        return 'LeftMinimal';
      case PaneDisplayMode.auto:
        return 'Auto';
    }
  }

  static PaneDisplayMode fromValue(String value) {
    switch (value) {
      case 'Top':
        return PaneDisplayMode.top;
      case 'Left':
        return PaneDisplayMode.expanded;
      case 'LeftCompact':
        return PaneDisplayMode.compact;
      case 'LeftMinimal':
        return PaneDisplayMode.minimal;
      case 'Auto':
      default:
        return PaneDisplayMode.auto;
    }
  }

  // Normalize persisted values through the shared mapping table.
  static String labelFromValue(String value) {
    return toValue(fromValue(value));
  }
}
