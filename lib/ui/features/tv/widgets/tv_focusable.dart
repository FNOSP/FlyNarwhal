import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

import '../controllers/tv_focus_controller.dart';
import '../tv_theme.dart';

/// How a focused [TvFocusable] presents itself.
enum TvFocusStyle {
  /// Design `.focusable.is-focused`: scale 1.06, 3px white ring 4px outside
  /// the box, drop shadow + blue glow.
  ring,

  /// Design `.nav-item.is-focused`: scale 1.04 only — no ring (the pill
  /// background change is up to the wrapped widget via [onFocusChanged]).
  nav,

  /// No focus visuals at all (still focusable/navigable).
  plain,
}

/// Focus + hover + activation wrapper for every TV-mode interactive element.
///
/// - Arrow keys are consumed here and routed to the [TvFocusController]'s
///   geometric nearest-picker (bubbling them up would hit the scrollables'
///   built-in arrow-to-scroll shortcuts instead).
/// - Enter/Space/click activate; Escape/Backspace bubble up to the screen.
/// - Mouse hover only brightens the card; it never steals keyboard focus.
///   A click focuses first, then activates.
class TvFocusable extends StatefulWidget {
  const TvFocusable({
    super.key,
    required this.child,
    this.onActivate,
    this.onFocusGained,
    this.onFocusChanged,
    this.style = TvFocusStyle.ring,
    this.ringRadius = BorderRadius.zero,
    this.order = 100,
    this.enabled = true,
    this.semanticLabel,
  });

  final Widget child;

  /// Invoked on Enter/Space/click. Null = renders but is not actionable yet.
  final VoidCallback? onActivate;

  /// Invoked whenever focus lands on this element (hero spotlight sync).
  final VoidCallback? onFocusGained;

  /// Lets the child restyle itself on focus (e.g. poster titles turn white).
  final ValueChanged<bool>? onFocusChanged;

  final TvFocusStyle style;

  /// Corner radius of the focus ring; should match the child's own radius.
  final BorderRadius ringRadius;

  /// Registration order hint; lower wins the initial focus.
  final int order;

  /// Disabled elements are neither focusable nor clickable.
  final bool enabled;

  final String? semanticLabel;

  @override
  State<TvFocusable> createState() => TvFocusableState();
}

class TvFocusableState extends State<TvFocusable> {
  final FocusNode _focusNode = FocusNode();
  final GlobalKey _childKey = GlobalKey();
  TvFocusEntry? _entry;
  TvFocusController? _controller;

  bool _focused = false;
  bool _hovered = false;

  FocusNode get focusNode => _focusNode;

  bool get _hasRing => widget.style == TvFocusStyle.ring;

  double get _focusScale => switch (widget.style) {
        TvFocusStyle.ring => TvTheme.focusScaleCard,
        TvFocusStyle.nav => TvTheme.focusScaleNav,
        TvFocusStyle.plain => 1.0,
      };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = TvFocusScopeWidget.maybeOf(context);
    if (controller != _controller) {
      if (_entry != null) {
        _controller?.unregister(_entry!);
      }
      _controller = controller;
      _entry = null;
      if (controller != null && widget.enabled) {
        _entry = TvFocusEntry(
          node: _focusNode,
          key: _childKey,
          onActivate: widget.onActivate,
          onFocusGained: widget.onFocusGained,
          order: widget.order,
        );
        controller.register(_entry!);
      }
    } else if (_entry != null) {
      // Keep the entry's callbacks fresh across rebuilds.
      _entry!
        ..onActivate = widget.onActivate
        ..onFocusGained = widget.onFocusGained
        ..order = widget.order;
    }
  }

  @override
  void dispose() {
    if (_entry != null) {
      _controller?.unregister(_entry!);
    }
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange(bool focused) {
    if (_focused == focused) return;
    setState(() => _focused = focused);
    widget.onFocusChanged?.call(focused);
    if (focused) {
      widget.onFocusGained?.call();
    }
  }

  void _activate() {
    if (!widget.enabled) return;
    _focusNode.requestFocus();
    widget.onActivate?.call();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    // Repeat events only matter for arrows (hold-to-navigate); Enter should
    // fire once per press.
    final isRepeat = event is KeyRepeatEvent;

    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => TvDirection.left,
      LogicalKeyboardKey.arrowRight => TvDirection.right,
      LogicalKeyboardKey.arrowUp => TvDirection.up,
      LogicalKeyboardKey.arrowDown => TvDirection.down,
      _ => null,
    };
    if (direction != null) {
      // Consume even when no candidate is found so the scrollables'
      // arrow-to-scroll shortcuts never fire.
      _controller?.moveFocus(direction);
      return KeyEventResult.handled;
    }

    final isActivateKey = event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        event.logicalKey == LogicalKeyboardKey.space;
    if (isActivateKey && !isRepeat) {
      widget.onActivate?.call();
      return KeyEventResult.handled;
    }

    // Escape/Backspace bubble up to TvModeScreen (exit TV mode).
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final ringActive = _focused && _hasRing;
    final halo = _hasRing ? TvTheme.focusHaloExtent : 0.0;

    Widget child = KeyedSubtree(key: _childKey, child: widget.child);
    if (_hovered && !_focused) {
      child = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: widget.ringRadius,
        ),
        child: child,
      );
    }

    return Semantics(
      button: widget.onActivate != null,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      child: Focus(
        focusNode: _focusNode,
        canRequestFocus: widget.enabled,
        onFocusChange: _handleFocusChange,
        onKeyEvent: _handleKeyEvent,
        child: MouseRegion(
          cursor: widget.enabled && widget.onActivate != null
              ? SystemMouseCursors.click
              : MouseCursor.defer,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.enabled ? _activate : null,
            child: AnimatedScale(
              scale: _focused ? _focusScale : 1.0,
              duration: TvTheme.focusTransition,
              curve: TvTheme.focusCurve,
              child: AnimatedContainer(
                duration: TvTheme.focusTransition,
                curve: TvTheme.focusCurve,
                padding: EdgeInsets.all(halo),
                decoration: BoxDecoration(
                  borderRadius: ringActive
                      ? widget.ringRadius.add(
                          BorderRadius.circular(TvTheme.focusHaloExtent),
                        )
                      : null,
                  border: ringActive
                      ? Border.all(
                          color: TvTheme.text0,
                          width: TvTheme.focusRingWidth,
                        )
                      : null,
                  boxShadow: ringActive ? TvTheme.shadowFocus : null,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
