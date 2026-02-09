import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/providers.dart';
import '../../widgets/card_expander_item.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final userInfoAsync = ref.watch(userInfoProvider);

    return ScaffoldPage(
      content: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 24),
            child: Text(
              '设置',
              style: FluentTheme.of(context).typography.subtitle,
            ),
          ),
          const _Header(title: '账号'),
          userInfoAsync.when(
            data: (user) {
              return CardExpanderItem(
                icon: const Icon(FluentIcons.contact),
                heading: Row(
                  children: [
                    Text(user.username),
                    if (user.isAdmin == 1)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blue),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Text(
                            '管理员',
                            style: TextStyle(fontSize: 12, color: Colors.blue),
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
            icon: const Icon(FluentIcons.sign_out),
            heading: const Text('退出登录'),
            caption: const Text('退出当前账号'),
            onPressed: () async {
              final prefs = ref.read(preferencesManagerProvider);
              await prefs.clear();
              if (context.mounted) context.go('/login');
            },
          ),
          const SizedBox(height: 24),
          const _Header(title: '外观'),
          CardExpanderItem(
            icon: const Icon(FluentIcons.color),
            heading: const Text('主题模式'),
            caption: const Text('是否跟随系统主题'),
            trailing: ToggleSwitch(
              checked: settings.followSystemTheme,
              onChanged: (v) => settingsNotifier.setFollowSystemTheme(v),
              content: Text(settings.followSystemTheme ? '跟随系统' : '手动设置'),
            ),
          ),
          if (!settings.followSystemTheme)
            CardExpanderItem(
              icon: Icon(settings.darkMode ? FluentIcons.clear_night : FluentIcons.brightness),
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
                  .map((e) => MenuFlyoutItem(
                        text: Text(_mapDisplayModeLabel(_modeToString(e))),
                        onPressed: () => settingsNotifier.setNavigationDisplayMode(_modeToString(e)),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 24),
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
                      Button(child: const Text('确定'), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
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
                    Button(child: const Text('我知道了'), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _modeToString(PaneDisplayMode mode) {
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

class _Header extends StatelessWidget {
  final String title;
  const _Header({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8, top: 16),
      child: Text(
        title,
        style: FluentTheme.of(context).typography.subtitle?.copyWith(color: Colors.grey[130]),
      ),
    );
  }
}
