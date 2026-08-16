import 'package:fluent_ui/fluent_ui.dart';

/// Wraps a widget so that the mouse cursor becomes a hand when the pointer is
/// over it. Used to give all interactive controls a consistent pointer cursor.
class Clickable extends StatelessWidget {
  final Widget child;
  final MouseCursor cursor;
  final bool enabled;

  const Clickable({
    super.key,
    required this.child,
    this.cursor = SystemMouseCursors.click,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: enabled ? cursor : MouseCursor.defer,
      child: child,
    );
  }
}

/// A wrapper around [Button] that always shows a hand cursor on desktop.
class AppButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final GestureTapDownCallback? onTapDown;
  final GestureTapUpCallback? onTapUp;
  final FocusNode? focusNode;
  final bool autofocus;
  final ButtonStyle? style;
  final bool focusable;

  const AppButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.onLongPress,
    this.onTapDown,
    this.onTapUp,
    this.focusNode,
    this.autofocus = false,
    this.style,
    this.focusable = true,
  });

  bool get _enabled =>
      onPressed != null ||
      onLongPress != null ||
      onTapDown != null ||
      onTapUp != null;

  @override
  Widget build(BuildContext context) {
    return Clickable(
      enabled: _enabled,
      child: Button(
        key: key,
        onPressed: onPressed,
        onLongPress: onLongPress,
        onTapDown: onTapDown,
        onTapUp: onTapUp,
        focusNode: focusNode,
        autofocus: autofocus,
        style: style,
        focusable: focusable,
        child: child,
      ),
    );
  }
}

/// A wrapper around [FilledButton] that always shows a hand cursor on desktop.
class AppFilledButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final GestureTapDownCallback? onTapDown;
  final GestureTapUpCallback? onTapUp;
  final FocusNode? focusNode;
  final bool autofocus;
  final ButtonStyle? style;
  final bool focusable;

  const AppFilledButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.onLongPress,
    this.onTapDown,
    this.onTapUp,
    this.focusNode,
    this.autofocus = false,
    this.style,
    this.focusable = true,
  });

  bool get _enabled =>
      onPressed != null ||
      onLongPress != null ||
      onTapDown != null ||
      onTapUp != null;

  @override
  Widget build(BuildContext context) {
    return Clickable(
      enabled: _enabled,
      child: FilledButton(
        key: key,
        onPressed: onPressed,
        onLongPress: onLongPress,
        onTapDown: onTapDown,
        onTapUp: onTapUp,
        focusNode: focusNode,
        autofocus: autofocus,
        style: style,
        focusable: focusable,
        child: child,
      ),
    );
  }
}

/// A wrapper around [OutlinedButton] that always shows a hand cursor on desktop.
class AppOutlinedButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final GestureTapDownCallback? onTapDown;
  final GestureTapUpCallback? onTapUp;
  final FocusNode? focusNode;
  final bool autofocus;
  final ButtonStyle? style;
  final bool focusable;

  const AppOutlinedButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.onLongPress,
    this.onTapDown,
    this.onTapUp,
    this.focusNode,
    this.autofocus = false,
    this.style,
    this.focusable = true,
  });

  bool get _enabled =>
      onPressed != null ||
      onLongPress != null ||
      onTapDown != null ||
      onTapUp != null;

  @override
  Widget build(BuildContext context) {
    return Clickable(
      enabled: _enabled,
      child: OutlinedButton(
        key: key,
        onPressed: onPressed,
        onLongPress: onLongPress,
        onTapDown: onTapDown,
        onTapUp: onTapUp,
        focusNode: focusNode,
        autofocus: autofocus,
        style: style,
        focusable: focusable,
        child: child,
      ),
    );
  }
}

/// A wrapper around [HyperlinkButton] that always shows a hand cursor on desktop.
class AppHyperlinkButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final GestureTapDownCallback? onTapDown;
  final GestureTapUpCallback? onTapUp;
  final FocusNode? focusNode;
  final bool autofocus;
  final ButtonStyle? style;
  final bool focusable;

  const AppHyperlinkButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.onLongPress,
    this.onTapDown,
    this.onTapUp,
    this.focusNode,
    this.autofocus = false,
    this.style,
    this.focusable = true,
  });

  bool get _enabled =>
      onPressed != null ||
      onLongPress != null ||
      onTapDown != null ||
      onTapUp != null;

  @override
  Widget build(BuildContext context) {
    return Clickable(
      enabled: _enabled,
      child: HyperlinkButton(
        key: key,
        onPressed: onPressed,
        onLongPress: onLongPress,
        onTapDown: onTapDown,
        onTapUp: onTapUp,
        focusNode: focusNode,
        autofocus: autofocus,
        style: style,
        focusable: focusable,
        child: child,
      ),
    );
  }
}

/// A wrapper around [IconButton] that always shows a hand cursor on desktop.
class AppIconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final GestureTapDownCallback? onTapDown;
  final GestureTapUpCallback? onTapUp;
  final FocusNode? focusNode;
  final bool autofocus;
  final ButtonStyle? style;
  final bool focusable;
  final IconButtonMode? iconButtonMode;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.onLongPress,
    this.onTapDown,
    this.onTapUp,
    this.focusNode,
    this.autofocus = false,
    this.style,
    this.focusable = true,
    this.iconButtonMode,
  });

  bool get _enabled =>
      onPressed != null ||
      onLongPress != null ||
      onTapDown != null ||
      onTapUp != null;

  @override
  Widget build(BuildContext context) {
    return Clickable(
      enabled: _enabled,
      child: IconButton(
        key: key,
        icon: icon,
        onPressed: onPressed,
        onLongPress: onLongPress,
        onTapDown: onTapDown,
        onTapUp: onTapUp,
        focusNode: focusNode,
        autofocus: autofocus,
        style: style,
        focusable: focusable,
        iconButtonMode: iconButtonMode,
      ),
    );
  }
}

/// A wrapper around [ToggleButton] that always shows a hand cursor on desktop.
class AppToggleButton extends StatelessWidget {
  final bool checked;
  final ValueChanged<bool>? onChanged;
  final Widget? child;
  final ToggleButtonThemeData? style;
  final String? semanticLabel;
  final FocusNode? focusNode;
  final bool autofocus;

  const AppToggleButton({
    super.key,
    required this.checked,
    required this.onChanged,
    this.child,
    this.style,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
  });

  bool get _enabled => onChanged != null;

  @override
  Widget build(BuildContext context) {
    return Clickable(
      enabled: _enabled,
      child: ToggleButton(
        key: key,
        checked: checked,
        onChanged: onChanged,
        style: style,
        semanticLabel: semanticLabel,
        focusNode: focusNode,
        autofocus: autofocus,
        child: child,
      ),
    );
  }
}
