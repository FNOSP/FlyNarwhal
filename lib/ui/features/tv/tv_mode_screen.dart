import 'dart:io' show Platform;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';

import '../../../data/models/home_models.dart';
import '../../../domain/entities/media_type.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../providers/providers.dart';
import '../../shared/common/app_loading_progress_ring.dart';
import '../home/home_view_model.dart';
import '../media_library/media_library_view_model.dart';
import 'controllers/tv_focus_controller.dart';
import 'controllers/tv_mode_controller.dart';
import 'tv_theme.dart';
import 'tv_view_model.dart';
import 'widgets/tv_hero.dart';
import 'widgets/tv_key_hints.dart';
import 'widgets/tv_poster_card.dart';
import 'widgets/tv_rail.dart';
import 'widgets/tv_scale_canvas.dart';
import 'widgets/tv_shelf.dart';
import 'widgets/tv_wide_card.dart';

/// TV big-screen mode home (design/tv-ui/home.html + home-empty.html).
///
/// Rendered from the top-level `/bigscreen` route, outside the ShellRoute,
/// like the player routes. Pairs with [TvModeController] for the window
/// fullscreen form; Esc/Backspace or the rail's exit item leave TV mode.
class TvModeScreen extends ConsumerStatefulWidget {
  const TvModeScreen({super.key});

  @override
  ConsumerState<TvModeScreen> createState() => _TvModeScreenState();
}

class _TvModeScreenState extends ConsumerState<TvModeScreen>
    with WindowListener {
  final TvFocusController _focusController = TvFocusController();
  final ScrollController _verticalScrollController = ScrollController();

  bool _pendingInitialFocus = false;
  bool _listeningWindow = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && (Platform.isMacOS || Platform.isLinux)) {
      windowManager.addListener(this);
      _listeningWindow = true;
    }
  }

  @override
  void dispose() {
    if (_listeningWindow) {
      windowManager.removeListener(this);
    }
    _verticalScrollController.dispose();
    super.dispose();
  }

  /// System-gesture fullscreen exit (macOS green traffic light, Linux WM
  /// shortcut): fall back to desktop mode so the UI and the window form
  /// never disagree.
  @override
  void onWindowLeaveFullScreen() {
    final controller = ref.read(tvModeControllerProvider);
    if (controller.isInTvMode && !controller.driver.isTransitioning) {
      controller.exitTvMode();
    }
  }

  KeyEventResult _handleRootKey(FocusNode node, KeyEvent event) {
    // Arrow fallback while nothing else is focused (e.g. right after the
    // route was pushed, or after a mouse user clicked a blank area). Consume
    // the key-up as well so the scrollables' built-in arrow-to-scroll
    // shortcuts cannot double-scroll on it.
    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => TvDirection.left,
      LogicalKeyboardKey.arrowRight => TvDirection.right,
      LogicalKeyboardKey.arrowUp => TvDirection.up,
      LogicalKeyboardKey.arrowDown => TvDirection.down,
      _ => null,
    };
    if (direction != null) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        if (!_focusController.moveFocus(direction)) {
          _focusController.focusInitial();
        }
      }
      return KeyEventResult.handled;
    }

    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final isRepeat = event is KeyRepeatEvent;

    if (!isRepeat &&
        (event.logicalKey == LogicalKeyboardKey.escape ||
            event.logicalKey == LogicalKeyboardKey.backspace)) {
      ref.read(tvModeControllerProvider).exitTvMode();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _playResumeItem(PlayDetailResponse item) {
    // Mirrors the desktop home's RecentlyWatched activation: record the
    // source path for the player's back handling, then push the right
    // fullscreen player route on top of the TV route.
    ref.read(navigationStackProvider.notifier).playerSourcePath = kTvModeRoute;
    if (item.type == MediaType.liveChannel.value) {
      context.push('/live/${item.guid}');
    } else {
      context.push('/player/${item.guid}');
    }
  }

  void _scheduleInitialFocus() {
    if (_pendingInitialFocus) return;
    _pendingInitialFocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingInitialFocus = false;
      if (mounted && _focusController.focusedEntry == null) {
        _focusController.focusInitial();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final playListAsync = ref.watch(playListNotifierProvider);
    final resumeItems = playListAsync.valueOrNull ?? const [];

    final heroIndex = ref.watch(tvHeroFocusIndexProvider);
    final effectiveHeroIndex = resumeItems.isEmpty
        ? null
        : (heroIndex ?? 0).clamp(0, resumeItems.length - 1);
    final heroItem =
        effectiveHeroIndex == null ? null : resumeItems[effectiveHeroIndex];

    // Restore the card focus when returning from the player (the player
    // route owned focus) or once the first data lands.
    if (resumeItems.isNotEmpty && _focusController.focusedEntry == null) {
      _scheduleInitialFocus();
    }

    return Focus(
      autofocus: true,
      onKeyEvent: _handleRootKey,
      child: TvFocusScopeWidget(
        controller: _focusController,
        child: TvScaleCanvas(
          child: Container(
            color: TvTheme.bgBase,
            child: Stack(
              children: [
                Positioned.fill(
                  child: playListAsync.isLoading && !playListAsync.hasValue
                      ? const Center(child: AppLoadingProgressRing())
                      : SingleChildScrollView(
                          controller: _verticalScrollController,
                          padding: const EdgeInsets.only(
                            bottom: TvTheme.keyHintsHeight + 24,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (resumeItems.isEmpty)
                                TvHeroEmpty(
                                  libraryTotal: _libraryTotal(),
                                )
                              else
                                TvHero(
                                  item: heroItem,
                                  onPlay: heroItem == null
                                      ? null
                                      : () => _playResumeItem(heroItem),
                                ),
                              if (resumeItems.isNotEmpty)
                                TvShelf(
                                  title: l10n.homeContinueWatching,
                                  countLabel: l10n.tvShelfResumeHint,
                                  moreLabel: l10n.tvShelfAllCount(
                                    '${resumeItems.length}',
                                  ),
                                  marginTop: TvTheme.shelfFirstTopMargin,
                                  itemCount: resumeItems.length,
                                  itemExtent:
                                      TvTheme.wideCardWidth + TvTheme.cardGap,
                                  // Card column ~302 + 14 halo; keep slack
                                  // so font-metric jitter never overflows.
                                  rowHeight: 330,
                                  itemBuilder: (context, index) {
                                    final item = resumeItems[index];
                                    return TvWideCard(
                                      item: item,
                                      order: index,
                                      onFocusGained: () {
                                        ref
                                            .read(
                                              tvHeroFocusIndexProvider.notifier,
                                            )
                                            .state = index;
                                      },
                                      onActivate: () => _playResumeItem(item),
                                    );
                                  },
                                ),
                              _buildPosterShelf(
                                title: l10n.mediaTypeMovie,
                                categoryGuid: 'category:movie',
                              ),
                              _buildPosterShelf(
                                title: l10n.mediaTypeTv,
                                categoryGuid: 'category:tv',
                              ),
                            ],
                          ),
                        ),
                ),
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: TvRail(),
                ),
                const Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: TvKeyHints(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int? _libraryTotal() {
    final sum = ref.watch(mediaSumNotifierProvider).valueOrNull;
    final total = sum?['total'];
    return total != null && total > 0 ? total : null;
  }

  Widget _buildPosterShelf({
    required String title,
    required String categoryGuid,
  }) {
    final l10n = AppLocalizations.of(context);
    final state =
        ref.watch(mediaLibraryNotifierProvider(categoryGuid)).valueOrNull;
    final items = state?.items ?? const <MediaItem>[];
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return TvShelf(
      title: title,
      countLabel: l10n.tvShelfCountItems('${state?.total ?? items.length}'),
      moreLabel: l10n.tvShelfEnterLibrary,
      itemCount: items.length,
      itemExtent: TvTheme.posterCardWidth + TvTheme.cardGap,
      // Poster 360 + drawer (~56) + 14 halo + slack.
      rowHeight: 448,
      itemBuilder: (context, index) => TvPosterCard(
        item: items[index],
        order: 200 + index,
      ),
    );
  }
}
