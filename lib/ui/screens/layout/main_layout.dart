import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../home/home_view_model.dart';
import '../../../providers/providers.dart';

class MainLayout extends ConsumerWidget {
  final Widget child;
  final GoRouterState state;

  const MainLayout({
    super.key,
    required this.child,
    required this.state,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaDbList = ref.watch(mediaDbListNotifierProvider);
    final mediaSumAsync = ref.watch(mediaSumNotifierProvider);
    final mediaSum = mediaSumAsync.asData?.value ?? const <String, int>{};
    final settings = ref.watch(settingsProvider);
    final navigationStack = ref.watch(navigationStackProvider);
    final currentPath = state.uri.toString();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(navigationStackProvider.notifier).pushPath(currentPath);
    });

    Widget? buildCountText(int? count) {
      if (count == null) return null;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Text('$count'),
      );
    }

    Widget buildCategoryIcon(String category) {
      final theme = FluentTheme.of(context);
      final iconColor = IconTheme.of(context).color ?? theme.iconTheme.color ?? Colors.white;
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
        case 'Others':
          assetPath = 'assets/images/other_media.svg';
          break;
        default:
          assetPath = 'assets/images/other_media.svg';
          break;
      }
      return SvgPicture.asset(
        assetPath,
        width: 16,
        height: 16,
        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
      );
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
            icon: const ProgressRing(),
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
          icon: const Icon(FluentIcons.list),
          trailing: buildCountText(mediaSum['total']),
        ),
        PaneItem(
          key: const ValueKey('category-tv'),
          title: const Text('电视节目'),
          body: const SizedBox.shrink(),
          icon: const Icon(FluentIcons.play),
          trailing: buildCountText(mediaSum['tv']),
        ),
        PaneItem(
          key: const ValueKey('category-movie'),
          title: const Text('电影'),
          body: const SizedBox.shrink(),
          icon: const Icon(FluentIcons.video),
          trailing: buildCountText(mediaSum['movie']),
        ),
        PaneItem(
          key: const ValueKey('category-video'),
          title: const Text('其他'),
          body: const SizedBox.shrink(),
          icon: const Icon(FluentIcons.bulleted_list),
          trailing: buildCountText(mediaSum['video']),
        ),
      ];
    }

    Widget buildFavoriteIcon() {
      final theme = FluentTheme.of(context);
      final iconColor = IconTheme.of(context).color ?? theme.iconTheme.color ?? Colors.white;
      return SvgPicture.asset(
        'assets/images/favorite.svg',
        width: 16,
        height: 16,
        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
      );
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
        icon: const Icon(FluentIcons.library),
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
        icon: const Icon(FluentIcons.filter),
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
      if (path == '/settings' || path.startsWith('/settings/')) return 'nav-settings';
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
        case '/category/video':
          return 'category-video';
      }
      return null;
    }

    final pane = NavigationPane(
      // header: const Padding(
      //   padding: EdgeInsets.only(left: 20.0),
      //   child: Text('Fly Narwhal', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      // ),
      selected: null,
      onChanged: null,
      displayMode: _resolveDisplayMode(settings.navigationDisplayMode),
      items: paneItems,
      footerItems: footerPaneItems,
    );

    final isMovieDetail = state.uri.path.startsWith('/movie/');
    final lastSelectedKey = ref.watch(lastNavigationKeyProvider);
    final selectedKey = resolveSelectedKey(state.uri.path);
    if (!isMovieDetail && selectedKey != null && selectedKey != lastSelectedKey) {
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
        return route != null && state.uri.path.startsWith(route);
      });
    }

    return NavigationView(
      pane: NavigationPane(
        header: pane.header,
        selected: selectedIndex >= 0 ? selectedIndex : null,
        onChanged: pane.onChanged,
        displayMode: pane.displayMode,
        items: pane.items,
        footerItems: pane.footerItems,
      ),
      paneBodyBuilder: (item, body) {
        final canNavigateUp = navigationStack.length > 1;
        return Stack(
          children: [
            child,
            if (canNavigateUp)
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: IconButton(
                      icon: const Icon(FluentIcons.back, size: 20),
                      onPressed: () {
                        final target = ref.read(navigationStackProvider.notifier).pop();
                        if (target != null) {
                          context.go(target);
                        }
                      },
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

PaneDisplayMode _resolveDisplayMode(String value) {
  switch (value) {
    case 'Top':
      return PaneDisplayMode.top;
    case 'Left':
      return PaneDisplayMode.open;
    case 'LeftCompact':
      return PaneDisplayMode.compact;
    case 'LeftMinimal':
      return PaneDisplayMode.minimal;
    case 'Auto':
    default:
      return PaneDisplayMode.auto;
  }
}
