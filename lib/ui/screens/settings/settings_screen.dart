import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/providers.dart';
import '../../widgets/card_expander_item.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final userInfoAsync = ref.watch(userInfoProvider);

    return ScaffoldPage(
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: _HorizontalSpace(
              child: Text(
                '设置',
                style: FluentTheme.of(context)
                    .typography
                    .subtitle
                    ?.copyWith(color: Colors.grey[110]),
              ),
            ),
          ),
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              child: ListView(
                controller: _scrollController,
                primary: false,
                padding: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 24),
                    child: _HorizontalSpace(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _Header(title: '账号'),
                          userInfoAsync.when(
                            data: (user) {
                              if (user == null) {
                                return const CardExpanderItem(
                                  icon: Icon(FluentIcons.contact),
                                  heading: Text('未加载用户信息'),
                                  caption: Text('登录后将在首页自动完成用户信息校验'),
                                );
                              }

                              return CardExpanderItem(
                                icon: const Icon(FluentIcons.contact),
                                heading: Row(
                                  children: [
                                    Text(user.username),
                                    if (user.isAdmin == 1)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.blue),
                                            borderRadius: BorderRadius.circular(50),
                                          ),
                                          child: Text(
                                            '管理员',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                caption: const Text('FN_Media'),
                              );
                            },
                            loading: () => const CardExpanderItem(
                              heading: Row(
                                children: [
                                  ProgressRing(),
                                  SizedBox(width: 12),
                                  Text('正在加载用户信息…'),
                                ],
                              ),
                            ),
                            error: (e, _) => CardExpanderItem(
                              icon: const Icon(FluentIcons.error),
                              heading: const Text('加载用户信息失败'),
                              caption: Text(e.toString()),
                            ),
                          ),
                          CardExpanderItem(
                            key: const ValueKey('settings-logout'),
                            icon: const Icon(FluentIcons.sign_out),
                            heading: const Text('退出登录'),
                            caption: const Text('退出当前账号'),
                            onPressed: () async {
                              // Best-effort server-side logout while credentials are still valid.
                              // Mirrors KMP LoginStateManager.logout(): fire logout API, do not block on result.
                              try {
                                final dataSource =
                                    ref.read(userRemoteDataSourceProvider);
                                await dataSource.logout();
                              } catch (_) {
                                // Ignore logout API failure; local logout must still proceed.
                              }

                              // Reuse the shared session invalidation flow.
                              await ref.read(sessionStateControllerProvider).invalidateSession();
                            },
                          ),
                          const SizedBox(height: 4),
                          const _Header(title: '外观'),
                          CardExpanderItem(
                            icon: const Icon(FluentIcons.color),
                            heading: const Text('主题模式'),
                            caption: const Text('是否跟随系统主题'),
                            trailing: ToggleSwitch(
                              checked: settings.followSystemTheme,
                              onChanged: (v) => settingsNotifier.setFollowSystemTheme(v),
                              content: Text(
                                settings.followSystemTheme ? '跟随系统' : '手动设置',
                              ),
                            ),
                          ),
                          if (!settings.followSystemTheme)
                            CardExpanderItem(
                              icon: Icon(
                                settings.darkMode
                                    ? FluentIcons.clear_night
                                    : FluentIcons.brightness,
                              ),
                              heading: const Text('颜色'),
                              caption: const Text('请选择主题颜色'),
                              trailing: ToggleSwitch(
                                checked: settings.darkMode,
                                onChanged: (v) => settingsNotifier.setDarkMode(v),
                                content: Text(settings.darkMode ? '深色' : '浅色'),
                              ),
                            ),
                          CardExpanderItem(
                            icon: const Icon(FluentIcons.navigation_flipper),
                            heading: const Text('导航栏样式'),
                            caption: const Text('请选择导航视图布局'),
                            trailing: DropDownButton(
                              title: Text(_mapDisplayModeLabel(settings.navigationDisplayMode)),
                              items: PaneDisplayMode.values
                                  .map(
                                    (e) => MenuFlyoutItem(
                                      text: Text(_mapDisplayModeLabel(_modeToString(e))),
                                      onPressed: () => settingsNotifier.setNavigationDisplayMode(
                                        _modeToString(e),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const _Header(title: '通用'),
                          CardExpanderItem(
                            icon: const Icon(FluentIcons.keyboard_classic),
                            heading: const Text('快捷键设置'),
                            caption: const Text('自定义快捷键'),
                            trailing: Button(
                              child: const Text('自定义'),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => ContentDialog(
                                    title: const Text('快捷键设置'),
                                    content: const Text('Flutter 版本暂不支持快捷键自定义，后续补充。'),
                                    actions: [
                                      Button(
                                        child: const Text('确定'),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 4),
                          const _Header(title: '关于'),
                          CardExpanderItem(
                            icon: const Icon(FluentIcons.info),
                            heading: const Text('隐私声明'),
                            caption: const Text('隐私声明'),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => ContentDialog(
                                  title: const Text('隐私声明'),
                                  content: const Text(
                                    '为了改进软件性能，我们会收集部分硬件信息（如 CPU、GPU 型号等）作为参考依据。这些信息将仅用于优化软件，不会涉及个人隐私。',
                                  ),
                                  actions: [
                                    Button(
                                      child: const Text('我知道了'),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _modeToString(PaneDisplayMode mode) {
    switch (mode) {
      case PaneDisplayMode.top:
        return 'Top';
      case PaneDisplayMode.open:
        return 'Left';
      case PaneDisplayMode.compact:
        return 'LeftCompact';
      case PaneDisplayMode.minimal:
        return 'LeftMinimal';
      case PaneDisplayMode.auto:
        return 'Auto';
    }
  }

  String _mapDisplayModeLabel(String value) {
    switch (value) {
      case 'Top':
        return 'Top';
      case 'Left':
        return 'Left';
      case 'LeftCompact':
        return 'LeftCompact';
      case 'LeftMinimal':
        return 'LeftMinimal';
      case 'Auto':
      default:
        return 'Auto';
    }
  }
}

class _HorizontalSpace extends StatelessWidget {
  final Widget child;
  const _HorizontalSpace({required this.child});

  static const double _maxWidth = 1000;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: SizedBox(width: double.infinity, child: child),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  const _Header({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Text(
        title,
        style: FluentTheme.of(context).typography.bodyStrong,
      ),
    );
  }
}
