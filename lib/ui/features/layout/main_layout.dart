import 'dart:io' show Platform;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import '../home/home_view_model.dart';
import '../../../providers/providers.dart';
import '../../../providers/global_refresh.dart';
import '../../../data/storage/shortcut_settings_store.dart';
import '../../navigation/navigation_display_mode_mapper.dart';
import '../../shared/window_caption.dart';
import '../../shared/common/app_loading_progress_ring.dart';
import '../search/widgets/capsule_search_box.dart';
import '../update/update_badge.dart';

class MainLayout extends ConsumerStatefulWidget {
  final Widget child;
  final GoRouterState state;

  const MainLayout({
    super.key,
    required this.child,
    required this.state,
  });

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  final FocusNode _searchFocusNode = FocusNode(debugLabel: 'global-search');
  final FocusNode _shortcutFocusNode =
      FocusNode(debugLabel: 'global-shortcuts');

  /// Direct handle to the [NavigationView] so the title bar's hamburger
  /// button (which lives outside the [NavigationView]'s subtree) can call
  /// [NavigationViewState.togglePane] without going through an inherited
  /// widget lookup.
  final GlobalKey<NavigationViewState> _navigationViewKey =
      GlobalKey<NavigationViewState>();

  /// macOS standard "open preferences" shortcut (⌘,).
  static final ShortcutKeyBinding _openSettingsBinding =
      ShortcutKeyBinding(LogicalKeyboardKey.comma.keyId, meta: true);

  @override
  void initState() {
    super.initState();
    // Register the macOS "open preferences" shortcut as a global
    // hardware-keyboard handler so it fires no matter which widget owns the
    // focus (including right after launch, when nothing is focused yet).
    // The player pages (/player/:guid, /live/:guid) live outside the
    // ShellRoute, so MainLayout is not mounted there and the handler stays
    // inactive.
    if (!kIsWeb && Platform.isMacOS) {
      HardwareKeyboard.instance.addHandler(_handleOpenSettingsKey);
    }
  }

  bool _handleOpenSettingsKey(KeyEvent event) {
    // Only react to the initial key-down so holding the keys navigates
    // once instead of on every key repeat.
    if (event is! KeyDownEvent || !_openSettingsBinding.matches(event)) {
      return false;
    }
    context.go('/settings');
    return true;
  }

  @override
  void dispose() {
    if (!kIsWeb && Platform.isMacOS) {
      HardwareKeyboard.instance.removeHandler(_handleOpenSettingsKey);
    }
    _searchFocusNode.dispose();
    _shortcutFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaDbList = ref.watch(mediaDbListNotifierProvider);
    final mediaSumAsync = ref.watch(mediaSumNotifierProvider);
    final mediaSum = mediaSumAsync.asData?.value ?? const <String, int>{};
    final settings = ref.watch(settingsProvider);
    final currentPath = widget.state.uri.toString();
    final currentRoutePath = widget.state.uri.path;
    final globalRefreshManager = ref.read(globalRefreshManagerProvider);
    final titleBarRefreshVisibility =
        ref.watch(titleBarRefreshVisibilityProvider);

    // Dispatch a single window-level refresh event to the active page.
    Future<void> triggerWindowRefresh() async {
      await globalRefreshManager.requestRefresh();
    }

    // Show the title bar back button only when a previous page exists.
    final navigationStack = ref.watch(navigationStackProvider);
    final canGoBack = navigationStack.length > 1;

    // Pop the navigation stack and route to the previous page.
    void handleBackNavigation() {
      final previousPath = ref.read(navigationStackProvider.notifier).pop();
      if (previousPath != null && previousPath.isNotEmpty) {
        context.go(previousPath);
      } else {
        context.go('/home');
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(navigationStackProvider.notifier).pushPath(currentPath);
      globalRefreshManager.updateCurrentRoutePath(currentRoutePath);
    });

    Widget? buildCountText(int? count) {
      if (count == null) return null;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Text('$count'),
      );
    }

    Widget buildNavigationAssetIcon(String assetPath) {
      final theme = FluentTheme.of(context);
      final iconColor =
          IconTheme.of(context).color ?? theme.iconTheme.color ?? Colors.white;
      return SvgPicture.asset(
        assetPath,
        width: 14,
        height: 14,
        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
      );
    }

    Widget buildCategoryIcon(String category) {
      String assetPath;
      switch (category) {
        case 'Movie':
          assetPath = 'assets/images/movie.svg';
          break;
        case 'TV':
          assetPath = 'assets/images/tv.svg';
          break;
        case 'Mix':
          assetPath = 'assets/images/mix_media.svg';
          break;
        case 'IPTV':
          // Live TV media library (e.g. 国内电视台).
          assetPath = 'assets/images/live_tv.svg';
          break;
        case 'Others':
          assetPath = 'assets/images/other_media.svg';
          break;
        default:
          assetPath = 'assets/images/other_media.svg';
          break;
      }
      return buildNavigationAssetIcon(assetPath);
    }

    List<NavigationPaneItem> buildMediaDbItems() {
      return mediaDbList.when(
        data: (list) {
          if (list.isEmpty) {
            return [
              PaneItem(
                title: const Text('暂无媒体库'),
                icon: const Icon(FluentIcons.info),
                enabled: false,
                body: const SizedBox.shrink(),
              ),
            ];
          }
          return list.map((e) {
            return PaneItem(
              key: ValueKey('media-${e.guid}'),
              title: Text(e.title),
              body: const SizedBox.shrink(),
              icon: buildCategoryIcon(e.category),
            );
          }).toList();
        },
        loading: () => [
          PaneItem(
            title: const Text('加载中…'),
            icon: const AppLoadingProgressRing(size: 16),
            enabled: false,
            body: const SizedBox.shrink(),
          ),
        ],
        error: (err, _) => [
          PaneItem(
            title: const Text('加载失败'),
            icon: const Icon(FluentIcons.error),
            enabled: false,
            body: const SizedBox.shrink(),
          ),
        ],
      );
    }

    List<NavigationPaneItem> buildCategoryItems() {
      return [
        PaneItem(
          key: const ValueKey('category-total'),
          title: const Text('全部'),
          body: const SizedBox.shrink(),
          icon: buildNavigationAssetIcon('assets/images/category_all.svg'),
          trailing: buildCountText(mediaSum['total']),
        ),
        PaneItem(
          key: const ValueKey('category-movie'),
          title: const Text('电影'),
          body: const SizedBox.shrink(),
          icon: buildNavigationAssetIcon('assets/images/movie.svg'),
          trailing: buildCountText(mediaSum['movie']),
        ),
        PaneItem(
          key: const ValueKey('category-tv'),
          title: const Text('电视节目'),
          body: const SizedBox.shrink(),
          icon: buildNavigationAssetIcon('assets/images/tv.svg'),
          trailing: buildCountText(mediaSum['tv']),
        ),
        PaneItem(
          key: const ValueKey('category-live'),
          title: const Text('电视直播'),
          body: const SizedBox.shrink(),
          icon: buildNavigationAssetIcon('assets/images/live_tv.svg'),
          trailing: buildCountText(mediaSum['live']),
        ),
        PaneItem(
          key: const ValueKey('category-video'),
          title: const Text('其他'),
          body: const SizedBox.shrink(),
          icon: buildNavigationAssetIcon('assets/images/other_media.svg'),
          trailing: buildCountText(mediaSum['video']),
        ),
      ];
    }

    Widget buildFavoriteIcon() {
      return buildNavigationAssetIcon('assets/images/favorite.svg');
    }

    final mediaDbPaneItems = buildMediaDbItems();
    final categoryPaneItems = buildCategoryItems();
    String? resolveRouteForItem(NavigationPaneItem item) {
      if (item is! PaneItem) return null;
      final key = item.key;
      if (key is ValueKey<String>) {
        final value = key.value;
        if (value == 'nav-home') return '/home';
        if (value == 'nav-favorites') return '/favorites';
        if (value == 'nav-settings') return '/settings';
        if (value.startsWith('media-')) {
          return '/library/${value.substring('media-'.length)}';
        }
        switch (value) {
          case 'category-total':
            return '/category/total';
          case 'category-tv':
            return '/category/tv';
          case 'category-movie':
            return '/category/movie';
          case 'category-live':
            return '/category/live';
          case 'category-video':
            return '/category/video';
        }
      }
      return null;
    }

    final paneItems = <NavigationPaneItem>[
      PaneItem(
        key: const ValueKey('nav-home'),
        icon: const Icon(FluentIcons.home),
        title: const Text('首页'),
        body: const SizedBox.shrink(),
        onTap: () => context.go('/home'),
      ),
      PaneItem(
        key: const ValueKey('nav-favorites'),
        icon: buildFavoriteIcon(),
        title: const Text('收藏'),
        body: const SizedBox.shrink(),
        trailing: buildCountText(mediaSum['favorite']),
        onTap: () => context.go('/favorites'),
      ),
      PaneItemExpander(
        icon: buildNavigationAssetIcon('assets/images/media_library.svg'),
        title: const Text('媒体库'),
        body: const SizedBox.shrink(),
        items: mediaDbPaneItems.map((item) {
          if (item is PaneItem) {
            final key = item.key;
            if (key is ValueKey<String> && key.value.startsWith('media-')) {
              final guid = key.value.substring('media-'.length);
              return PaneItem(
                key: item.key,
                title: item.title,
                body: item.body,
                icon: item.icon,
                trailing: buildCountText(mediaSum[guid]),
                enabled: item.enabled,
                onTap: () => context.go('/library/$guid'),
              );
            }
          }
          return item;
        }).toList(),
      ),
      PaneItemExpander(
        icon: buildNavigationAssetIcon('assets/images/category.svg'),
        title: const Text('分类'),
        body: const SizedBox.shrink(),
        items: categoryPaneItems.map((item) {
          if (item is PaneItem) {
            final key = item.key;
            if (key is ValueKey<String>) {
              switch (key.value) {
                case 'category-total':
                  return PaneItem(
                    key: item.key,
                    title: item.title,
                    body: item.body,
                    icon: item.icon,
                    trailing: item.trailing,
                    enabled: item.enabled,
                    onTap: () => context.go('/category/total'),
                  );
                case 'category-tv':
                  return PaneItem(
                    key: item.key,
                    title: item.title,
                    body: item.body,
                    icon: item.icon,
                    trailing: item.trailing,
                    enabled: item.enabled,
                    onTap: () => context.go('/category/tv'),
                  );
                case 'category-movie':
                  return PaneItem(
                    key: item.key,
                    title: item.title,
                    body: item.body,
                    icon: item.icon,
                    trailing: item.trailing,
                    enabled: item.enabled,
                    onTap: () => context.go('/category/movie'),
                  );
                case 'category-live':
                  return PaneItem(
                    key: item.key,
                    title: item.title,
                    body: item.body,
                    icon: item.icon,
                    trailing: item.trailing,
                    enabled: item.enabled,
                    onTap: () => context.go('/category/live'),
                  );
                case 'category-video':
                  return PaneItem(
                    key: item.key,
                    title: item.title,
                    body: item.body,
                    icon: item.icon,
                    trailing: item.trailing,
                    enabled: item.enabled,
                    onTap: () => context.go('/category/video'),
                  );
              }
            }
          }
          return item;
        }).toList(),
      ),
    ];
    final footerPaneItems = <NavigationPaneItem>[
      PaneItem(
        key: const ValueKey('nav-settings'),
        icon: const Icon(FluentIcons.settings),
        title: const Text('设置'),
        body: const SizedBox.shrink(),
        onTap: () => context.go('/settings'),
      ),
    ];

    String? resolveSelectedKey(String path) {
      if (path.startsWith('/movie/')) return null;
      if (path == '/home') return 'nav-home';
      if (path == '/favorites') return 'nav-favorites';
      if (path == '/settings' || path.startsWith('/settings/')) {
        return 'nav-settings';
      }
      if (path.startsWith('/library/')) {
        return 'media-${path.substring('/library/'.length)}';
      }
      switch (path) {
        case '/category/total':
          return 'category-total';
        case '/category/tv':
          return 'category-tv';
        case '/category/movie':
          return 'category-movie';
        case '/category/live':
          return 'category-live';
        case '/category/video':
          return 'category-video';
      }
      return null;
    }

    final pane = NavigationPane(
      selected: null,
      onChanged: null,
      displayMode: NavigationDisplayModeMapper.fromValue(
        settings.navigationDisplayMode,
      ),
      items: paneItems,
      footerItems: footerPaneItems,
    );

    final isMovieDetail = widget.state.uri.path.startsWith('/movie/');
    final lastSelectedKey = ref.watch(lastNavigationKeyProvider);
    final selectedKey = resolveSelectedKey(widget.state.uri.path);
    if (!isMovieDetail &&
        selectedKey != null &&
        selectedKey != lastSelectedKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(lastNavigationKeyProvider.notifier).state = selectedKey;
      });
    }
    final effectiveSelectedKey = selectedKey ?? lastSelectedKey;
    var selectedIndex = pane.effectiveItems.indexWhere((item) {
      final key = item.key;
      return key is ValueKey<String> && key.value == effectiveSelectedKey;
    });
    if (selectedIndex < 0) {
      selectedIndex = pane.effectiveItems.indexWhere((item) {
        final route = resolveRouteForItem(item);
        return route != null && widget.state.uri.path.startsWith(route);
      });
    }

    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isMacOS = !kIsWeb && Platform.isMacOS;

    // The hamburger toggle is only mounted when the effective display mode
    // is minimal — other layouts (top / expanded / compact) keep their own
    // built-in affordances. Mirrors fluent_ui's _resolveDisplayMode:
    // PaneDisplayMode.auto falls back to the window width
    // (<=640 minimal, >=1008 expanded, else compact).
    PaneDisplayMode resolveEffectiveDisplayMode() {
      final configured = NavigationDisplayModeMapper.fromValue(
        settings.navigationDisplayMode,
      );
      if (configured != PaneDisplayMode.auto) return configured;
      final width = MediaQuery.of(context).size.width;
      if (width <= 640) return PaneDisplayMode.minimal;
      if (width >= 1008) return PaneDisplayMode.expanded;
      return PaneDisplayMode.compact;
    }

    final isMinimalDisplayMode =
        resolveEffectiveDisplayMode() == PaneDisplayMode.minimal;

    void handleNavToggle() {
      _navigationViewKey.currentState?.togglePane();
    }

    KeyEventResult handleGlobalKeyEvent(FocusNode node, KeyEvent event) {
      if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
        return KeyEventResult.ignored;
      }
      final shortcutStore = ref.read(shortcutSettingsStoreProvider);
      if (shortcutStore.shouldSuppressFocusSearchInput(event)) {
        return KeyEventResult.ignored;
      }
      if (shortcutStore.matches(event, ShortcutActionId.focusSearch)) {
        _searchFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // Traffic light buttons area dimensions for macOS
    const double kTrafficLightLeftPadding = 20.0;
    const double kTrafficLightTopPadding = 10.0;
    const double kTrafficLightAreaWidth = 70.0;
    const double kRefreshButtonLeftOffset = 10.0;
    // Horizontal breathing room between the back / pin / refresh buttons so
    // they don't sit flush against each other next to the traffic lights.
    const double kCaptionButtonSpacing = 4.0;
    // Nudge the refresh button slightly lower to match the traffic lights.
    const double kRefreshButtonTopPadding = kTrafficLightTopPadding + 6.0;

    return Focus(
      focusNode: _shortcutFocusNode,
      autofocus: true,
      onKeyEvent: handleGlobalKeyEvent,
      child: Column(
        children: [
          if (isMacOS)
            Container(
              height: kWindowTitleBarHeight,
              color: theme.resources.solidBackgroundFillColorBase,
              child: Stack(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(
                        width: kTrafficLightLeftPadding +
                            kTrafficLightAreaWidth -
                            kRefreshButtonLeftOffset,
                      ),
                      if (isMinimalDisplayMode)
                        Padding(
                          // Center the 28px compact button on the same
                          // vertical axis as the 20px caption buttons
                          // (back/pin/refresh): their top padding plus half
                          // the height difference, 16 + (20 - 28) / 2 = 12.
                          padding: const EdgeInsets.only(
                            top: kRefreshButtonTopPadding + (20 - 28) / 2,
                            left: kCaptionButtonSpacing,
                            right: kCaptionButtonSpacing,
                          ),
                          child: WindowCaptionNavToggleButton.compact(
                            key: const ValueKey(
                                'macos-window-caption-nav-toggle-button'),
                            brightness:
                                isDark ? Brightness.dark : Brightness.light,
                            onPressed: handleNavToggle,
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(
                            top: kRefreshButtonTopPadding,
                            left: kCaptionButtonSpacing,
                            right: kCaptionButtonSpacing),
                        child: WindowCaptionBackButton.compact(
                          key: const ValueKey(
                              'macos-window-caption-back-button'),
                          brightness:
                              isDark ? Brightness.dark : Brightness.light,
                          onPressed: canGoBack ? handleBackNavigation : null,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                            top: kRefreshButtonTopPadding,
                            left: kCaptionButtonSpacing,
                            right: kCaptionButtonSpacing),
                        child: WindowCaptionPinButton.compact(
                          key:
                              const ValueKey('macos-window-caption-pin-button'),
                          brightness:
                              isDark ? Brightness.dark : Brightness.light,
                        ),
                      ),
                      if (titleBarRefreshVisibility.shouldShowRefreshAction)
                        Padding(
                          padding: const EdgeInsets.only(
                              top: kRefreshButtonTopPadding,
                              left: kCaptionButtonSpacing,
                              right: kCaptionButtonSpacing),
                          child: WindowCaptionRefreshButton.compact(
                            key: const ValueKey(
                                'macos-window-caption-refresh-button'),
                            brightness:
                                isDark ? Brightness.dark : Brightness.light,
                            onPressed: triggerWindowRefresh,
                          ),
                        ),
                      const Padding(
                        padding: EdgeInsets.only(
                            top: kRefreshButtonTopPadding,
                            left: kCaptionButtonSpacing,
                            right: kCaptionButtonSpacing),
                        child: SharedUpdateBadge(
                          key: ValueKey('macos-titlebar-update-badge'),
                        ),
                      ),
                      Expanded(
                        child: DragToMoveArea(
                          child: Container(
                            height: double.infinity,
                            alignment: Alignment.centerLeft,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: CapsuleSearchBox(
                      focusNode: _searchFocusNode,
                      onDismissed: _shortcutFocusNode.requestFocus,
                    ),
                  ),
                ],
              ),
            )
          else
            WindowCaption(
              title: const Text('飞鲸影视'),
              titleTrailing: const SharedUpdateBadge(
                key: ValueKey('titlebar-update-badge'),
              ),
              center: CapsuleSearchBox(
                focusNode: _searchFocusNode,
                onDismissed: _shortcutFocusNode.requestFocus,
              ),
              brightness: isDark ? Brightness.dark : Brightness.light,
              backgroundColor: theme.resources.solidBackgroundFillColorBase,
              showRefreshAction:
                  titleBarRefreshVisibility.shouldShowRefreshAction,
              onRefreshPressed: triggerWindowRefresh,
              showBackButton: true,
              onBack: canGoBack ? handleBackNavigation : null,
              showNavToggle: isMinimalDisplayMode,
              onNavToggle: isMinimalDisplayMode ? handleNavToggle : null,
            ),
          Expanded(
            child: NavigationView(
              key: _navigationViewKey,
              pane: NavigationPane(
                header: pane.header,
                selected: selectedIndex >= 0 ? selectedIndex : null,
                onChanged: pane.onChanged,
                displayMode: pane.displayMode,
                items: pane.items,
                footerItems: pane.footerItems,
              ),
              paneBodyBuilder: (item, body) => widget.child,
            ),
          ),
        ],
      ),
    );
  }
}
