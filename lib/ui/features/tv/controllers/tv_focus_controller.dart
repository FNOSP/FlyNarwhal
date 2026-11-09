import 'package:flutter/widgets.dart';

import '../tv_theme.dart';

/// Arrow directions for the TV focus navigation.
enum TvDirection { up, down, left, right }

/// Pure geometric nearest-focus picker, mirroring the design's `shared.js`
/// `move(dir)` scoring: a candidate must lie in the pressed direction (with
/// an 8px dead zone) and is scored by `along + across * 2.2`, lowest wins —
/// strongly biasing same-row/column movement.
abstract final class TvFocusGeometry {
  static const double deadZone = 8;
  static const double acrossWeight = 2.2;

  /// Scroll offset that reveals an element sitting between [contentLeading]
  /// and [contentTrailing] (content coordinates), or null when it is already
  /// fully visible inside the inset-adjusted viewport.
  ///
  /// `Scrollable.ensureVisible` cannot be used here: its one-sided policies
  /// (`keepVisibleAtEnd`/`keepVisibleAtStart`) clamp the offset to the current
  /// position for the opposite direction, so focus moves up/left never
  /// scrolled. This reveals in both directions.
  static double? revealOffset({
    required double pixels,
    required double viewportExtent,
    required double contentLeading,
    required double contentTrailing,
    required double leadingInset,
    required double trailingInset,
    required double minScrollExtent,
    required double maxScrollExtent,
  }) {
    double? target;
    if (contentLeading < pixels + leadingInset) {
      target = contentLeading - leadingInset;
    } else if (contentTrailing > pixels + viewportExtent - trailingInset) {
      target = contentTrailing - (viewportExtent - trailingInset);
    }
    if (target == null) {
      return null;
    }
    target = target.clamp(minScrollExtent, maxScrollExtent);
    if ((target - pixels).abs() < 1) {
      return null;
    }
    return target;
  }

  /// Returns the index into [candidates] to focus, or null when nothing lies
  /// in [direction].
  static int? pickNext({
    required Rect current,
    required List<Rect> candidates,
    required TvDirection direction,
  }) {
    final center = current.center;
    int? best;
    double bestScore = double.infinity;

    for (var i = 0; i < candidates.length; i++) {
      final other = candidates[i].center;
      final dx = other.dx - center.dx;
      final dy = other.dy - center.dy;

      final double along;
      final double across;
      switch (direction) {
        case TvDirection.right:
          along = dx;
          across = dy.abs();
        case TvDirection.left:
          along = -dx;
          across = dy.abs();
        case TvDirection.down:
          along = dy;
          across = dx.abs();
        case TvDirection.up:
          along = -dy;
          across = dx.abs();
      }

      if (along < deadZone) {
        continue;
      }
      final score = along + across * acrossWeight;
      if (score < bestScore) {
        bestScore = score;
        best = i;
      }
    }
    return best;
  }
}

/// A focusable element registered with the [TvFocusController].
class TvFocusEntry {
  TvFocusEntry({
    required this.node,
    required this.key,
    this.onActivate,
    this.onFocusGained,
    this.order = 0,
  });

  final FocusNode node;

  /// Key of the widget whose render box provides the focus rectangle.
  final GlobalKey key;

  /// Invoked on Enter/Space/click. Null for items that render but are not
  /// actionable yet (unimplemented rail targets, poster cards).
  VoidCallback? onActivate;

  /// Invoked whenever this entry gains focus (drives the hero spotlight).
  VoidCallback? onFocusGained;

  /// Registration order hint; the registry keeps insertion order and this is
  /// only used to break ties for the initial-focus pick.
  int order;

  /// Global rect of the entry, computed with two `localToGlobal` points so
  /// it stays correct inside the TV canvas' `Transform.scale`.
  Rect? globalRect() {
    final context = key.currentContext;
    if (context == null) return null;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return null;
    final topLeft = box.localToGlobal(Offset.zero);
    final bottomRight = box.localToGlobal(box.size.bottomRight(Offset.zero));
    return Rect.fromPoints(topLeft, bottomRight);
  }
}

/// Registry of the TV screen's focusable elements plus the arrow-key
/// navigation between them. Owned by `TvModeScreen` and handed down through
/// [TvFocusScopeWidget].
class TvFocusController {
  final List<TvFocusEntry> _entries = [];

  Iterable<TvFocusEntry> get entries => _entries;

  void register(TvFocusEntry entry) {
    if (!_entries.contains(entry)) {
      _entries.add(entry);
    }
  }

  void unregister(TvFocusEntry entry) {
    _entries.remove(entry);
  }

  TvFocusEntry? get focusedEntry {
    for (final entry in _entries) {
      if (entry.node.hasFocus) {
        return entry;
      }
    }
    return null;
  }

  /// Moves the focus one step in [direction]. Returns false when no candidate
  /// was found (the caller may fall back to scrolling or ignore).
  bool moveFocus(TvDirection direction) {
    final current = focusedEntry ?? _initialEntry();
    if (current == null) {
      return false;
    }
    final currentRect = current.globalRect();
    if (currentRect == null) {
      return false;
    }

    final candidates = <TvFocusEntry>[];
    final rects = <Rect>[];
    for (final entry in _entries) {
      if (entry == current) continue;
      final rect = entry.globalRect();
      if (rect == null) continue;
      candidates.add(entry);
      rects.add(rect);
    }

    final index = TvFocusGeometry.pickNext(
      current: currentRect,
      candidates: rects,
      direction: direction,
    );
    if (index == null) {
      return false;
    }

    final target = candidates[index];
    target.node.requestFocus();
    _ensureVisible(target);
    return true;
  }

  /// Focuses the first registered entry (initial focus after build).
  bool focusInitial() {
    final entry = _initialEntry();
    if (entry == null) {
      return false;
    }
    entry.node.requestFocus();
    return true;
  }

  TvFocusEntry? _initialEntry() {
    TvFocusEntry? best;
    for (final entry in _entries) {
      if (best == null || entry.order < best.order) {
        best = entry;
      }
    }
    return best;
  }

  // Reveal insets per axis: keep focused cards clear of the floating rail /
  // key hints overlays (vertical) and of the row's leading padding /
  // trailing fade (horizontal).
  static const double _verticalLeadingInset = TvTheme.railHeight + 12;
  static const double _verticalTrailingInset = TvTheme.keyHintsHeight + 12;
  static const double _horizontalLeadingInset =
      TvTheme.sidePadding - TvTheme.focusHaloExtent;
  static const double _horizontalTrailingInset =
      TvTheme.shelfFadeWidth + TvTheme.focusHaloExtent;

  static const Duration _revealDuration = Duration(milliseconds: 220);

  void _ensureVisible(TvFocusEntry entry) {
    final context = entry.key.currentContext;
    if (context == null) return;
    final targetBox = context.findRenderObject();
    if (targetBox is! RenderBox || !targetBox.attached || !targetBox.hasSize) {
      return;
    }

    // Walk every scrollable ancestor (the shelf row and the vertical page
    // scroll) so focus moves never hide behind an edge or an overlay.
    var scrollable = context.findAncestorStateOfType<ScrollableState>();
    while (scrollable != null) {
      _revealInScrollable(scrollable, targetBox);
      scrollable =
          scrollable.context.findAncestorStateOfType<ScrollableState>();
    }
  }

  void _revealInScrollable(ScrollableState scrollable, RenderBox targetBox) {
    final position = scrollable.position;
    final viewportBox = scrollable.context.findRenderObject();
    if (viewportBox is! RenderBox ||
        !viewportBox.attached ||
        !viewportBox.hasSize) {
      return;
    }

    final rect = MatrixUtils.transformRect(
      targetBox.getTransformTo(viewportBox),
      Offset.zero & targetBox.size,
    );
    final horizontal = position.axis == Axis.horizontal;
    final target = TvFocusGeometry.revealOffset(
      pixels: position.pixels,
      viewportExtent: position.viewportDimension,
      contentLeading: (horizontal ? rect.left : rect.top) + position.pixels,
      contentTrailing:
          (horizontal ? rect.right : rect.bottom) + position.pixels,
      leadingInset:
          horizontal ? _horizontalLeadingInset : _verticalLeadingInset,
      trailingInset:
          horizontal ? _horizontalTrailingInset : _verticalTrailingInset,
      minScrollExtent: position.minScrollExtent,
      maxScrollExtent: position.maxScrollExtent,
    );
    if (target == null) {
      return;
    }
    position.animateTo(
      target,
      duration: _revealDuration,
      curve: Curves.easeOutCubic,
    );
  }
}

/// Inherited lookup so nested [TvFocusable] widgets can find the screen's
/// controller without prop drilling.
class TvFocusScopeWidget extends InheritedWidget {
  const TvFocusScopeWidget({
    super.key,
    required this.controller,
    required super.child,
  });

  final TvFocusController controller;

  static TvFocusController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<TvFocusScopeWidget>()
      ?.controller;

  @override
  bool updateShouldNotify(TvFocusScopeWidget oldWidget) =>
      controller != oldWidget.controller;
}
