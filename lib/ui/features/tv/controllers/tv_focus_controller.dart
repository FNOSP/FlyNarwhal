import 'package:flutter/widgets.dart';

/// Arrow directions for the TV focus navigation.
enum TvDirection { up, down, left, right }

/// Pure geometric nearest-focus picker, mirroring the design's `shared.js`
/// `move(dir)` scoring: a candidate must lie in the pressed direction (with
/// an 8px dead zone) and is scored by `along + across * 2.2`, lowest wins —
/// strongly biasing same-row/column movement.
abstract final class TvFocusGeometry {
  static const double deadZone = 8;
  static const double acrossWeight = 2.2;

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

  void _ensureVisible(TvFocusEntry entry) {
    final context = entry.key.currentContext;
    if (context == null) return;
    // Walk every scrollable ancestor (the shelf row and the vertical page
    // scroll) so focus moves never hide behind an edge.
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
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
