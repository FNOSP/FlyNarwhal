import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/providers.dart';
import '../../navigation/navigation_display_mode_mapper.dart';
import '../../shared/common/app_loading_progress_ring.dart';
import 'widgets/card_expander_item.dart';
import 'widgets/shortcut_settings_dialog.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _flyNarwhalServerUrlController =
      TextEditingController();
  final TextEditingController _flyNarwhalAuthCodeController =
      TextEditingController();
  bool _isFlyNarwhalAuthCodeVisible = false;

  @override
  void initState() {
    super.initState();
    _flyNarwhalServerUrlController.text =
        ref.read(settingsProvider).flyNarwhalServerBaseUrl;
  }

  void _openFlyNarwhalAuthCodeDialog() {
    _flyNarwhalAuthCodeController.text =
        ref.read(settingsProvider.notifier).getFlyNarwhalAuthCode();
    _isFlyNarwhalAuthCodeVisible = false;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => ContentDialog(
          title: const Text('填写授权码'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('请输入飞鲸服务端授权码：'),
              const SizedBox(height: 12),
              TextBox(
                key: const ValueKey('settings-fly-narwhal-auth-code-input'),
                controller: _flyNarwhalAuthCodeController,
                obscureText: !_isFlyNarwhalAuthCodeVisible,
                onSubmitted: (_) => _saveFlyNarwhalAuthCode(dialogContext),
                suffix: IconButton(
                  icon: Icon(
                    _isFlyNarwhalAuthCodeVisible
                        ? FluentIcons.hide3
                        : FluentIcons.view,
                  ),
                  onPressed: () {
                    setDialogState(() {
                      _isFlyNarwhalAuthCodeVisible =
                          !_isFlyNarwhalAuthCodeVisible;
                    });
                  },
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '请在飞鲸服务端页面点击“获取授权码”后粘贴到此处。',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          actions: [
            Button(
              child: const Text('取消'),
              onPressed: () {
                _isFlyNarwhalAuthCodeVisible = false;
                Navigator.pop(dialogContext);
              },
            ),
            FilledButton(
              key: const ValueKey('settings-fly-narwhal-auth-code-save'),
              child: const Text('确定'),
              onPressed: () => _saveFlyNarwhalAuthCode(dialogContext),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveFlyNarwhalAuthCode(BuildContext dialogContext) async {
    await ref
        .read(settingsProvider.notifier)
        .setFlyNarwhalAuthCode(_flyNarwhalAuthCodeController.text);
    _isFlyNarwhalAuthCodeVisible = false;
    if (mounted) {
      Navigator.pop(dialogContext);
    }
  }

  @override
  void dispose() {
    _flyNarwhalAuthCodeController.dispose();
    _flyNarwhalServerUrlController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final userInfoAsync = ref.watch(userInfoProvider);
    final connectionTestState = ref.watch(flyNarwhalConnectionTestProvider);

    ref.listen<AsyncValue<String?>>(
      flyNarwhalConnectionTestProvider,
      (_, nextState) {
        nextState.whenOrNull(
          data: (version) {
            if (version == null) return;
            displayInfoBar(
              context,
              builder: (context, close) => InfoBar(
                title: const Text('连接成功'),
                content: Text('当前服务端版本号：$version'),
                severity: InfoBarSeverity.success,
                onClose: close,
              ),
            );
            ref.read(flyNarwhalConnectionTestProvider.notifier).clear();
          },
          error: (error, _) {
            displayInfoBar(
              context,
              builder: (context, close) => InfoBar(
                title: const Text('连接失败'),
                content: Text(error.toString()),
                severity: InfoBarSeverity.error,
                onClose: close,
              ),
            );
            ref.read(flyNarwhalConnectionTestProvider.notifier).clear();
          },
        );
      },
    );
    final isTestingFlyNarwhalServer = connectionTestState.isLoading;

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
                                            border:
                                                Border.all(color: Colors.blue),
                                            borderRadius:
                                                BorderRadius.circular(50),
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
                                  AppLoadingProgressRing(size: 18),
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
                              final dataSource =
                                  ref.read(userRemoteDataSourceProvider);
                              unawaited(
                                dataSource.logout().then(
                                      (_) {},
                                      onError: (_) {},
                                    ),
                              );

                              await ref
                                  .read(sessionStateControllerProvider)
                                  .invalidateSession();
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
                              onChanged: (v) =>
                                  settingsNotifier.setFollowSystemTheme(v),
                              content: Text(
                                settings.followSystemTheme ? '跟随系统' : '手动设置',
                              ),
                            ),
                          ),
                          _AnimatedVisibility(
                            visible: !settings.followSystemTheme,
                            child: CardExpanderItem(
                              icon: Icon(
                                settings.darkMode
                                    ? FluentIcons.clear_night
                                    : FluentIcons.brightness,
                              ),
                              heading: const Text('颜色'),
                              caption: const Text('请选择主题颜色'),
                              trailing: ToggleSwitch(
                                checked: settings.darkMode,
                                onChanged: (v) =>
                                    settingsNotifier.setDarkMode(v),
                                content: Text(settings.darkMode ? '深色' : '浅色'),
                              ),
                            ),
                          ),
                          CardExpanderItem(
                            icon: const Icon(FluentIcons.navigation_flipper),
                            heading: const Text('导航栏样式'),
                            caption: const Text('请选择导航视图布局'),
                            trailing: DropDownButton(
                              title: Text(
                                NavigationDisplayModeMapper.labelFromValue(
                                  settings.navigationDisplayMode,
                                ),
                              ),
                              items: PaneDisplayMode.values
                                  .map(
                                    (e) => MenuFlyoutItem(
                                      text: Text(
                                        NavigationDisplayModeMapper.toValue(e),
                                      ),
                                      onPressed: () => settingsNotifier
                                          .setNavigationDisplayMode(
                                        NavigationDisplayModeMapper.toValue(e),
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
                              key: const ValueKey('settings-shortcuts-open'),
                              child: const Text('自定义'),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) =>
                                      const ShortcutSettingsDialog(),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 4),
                          const _Header(title: '服务器'),
                          CardExpanderItem(
                            key: const ValueKey('settings-fly-narwhal-enabled'),
                            icon: const Icon(FluentIcons.server),
                            heading: const Text('启用飞鲸服务端'),
                            caption: const Text(
                              '启用后可连接飞鲸服务端实现智能识别片头/片尾、弹幕等功能支持',
                            ),
                            trailing: ToggleSwitch(
                              checked: settings.flyNarwhalServerEnabled,
                              onChanged:
                                  settingsNotifier.setFlyNarwhalServerEnabled,
                              content: Text(
                                settings.flyNarwhalServerEnabled ? '开启' : '关闭',
                              ),
                            ),
                          ),
                          _AnimatedVisibility(
                            visible: settings.flyNarwhalServerEnabled,
                            child: Column(
                              children: [
                                CardExpanderItem(
                                  key: const ValueKey(
                                    'settings-fly-narwhal-url',
                                  ),
                                  icon: const Icon(FluentIcons.globe),
                                  heading: const Text('飞鲸服务端地址'),
                                  caption: const Text('请填写完整的服务端 URL'),
                                  trailing: SizedBox(
                                    width: 360,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextBox(
                                            key: const ValueKey(
                                              'settings-fly-narwhal-url-input',
                                            ),
                                            controller:
                                                _flyNarwhalServerUrlController,
                                            placeholder:
                                                'http://192.168.1.1:5365',
                                            onSubmitted: settingsNotifier
                                                .setFlyNarwhalServerBaseUrl,
                                            onTapOutside: (_) =>
                                                settingsNotifier
                                                    .setFlyNarwhalServerBaseUrl(
                                              _flyNarwhalServerUrlController
                                                  .text,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Button(
                                          key: const ValueKey(
                                            'settings-fly-narwhal-test',
                                          ),
                                          onPressed: isTestingFlyNarwhalServer
                                              ? null
                                              : () async {
                                                  final baseUrl =
                                                      _flyNarwhalServerUrlController
                                                          .text;
                                                  await settingsNotifier
                                                      .setFlyNarwhalServerBaseUrl(
                                                    baseUrl,
                                                  );
                                                  await ref
                                                      .read(
                                                        flyNarwhalConnectionTestProvider
                                                            .notifier,
                                                      )
                                                      .testConnection(baseUrl);
                                                },
                                          child: Text(
                                            isTestingFlyNarwhalServer
                                                ? '测试中'
                                                : '测试',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                CardExpanderItem(
                                  key: const ValueKey(
                                    'settings-fly-narwhal-auth-code',
                                  ),
                                  icon: const Icon(FluentIcons.key),
                                  heading: const Text('授权码'),
                                  caption: Text(
                                    settings.hasFlyNarwhalAuthCode
                                        ? '已填写飞鲸服务端授权码'
                                        : '填写飞鲸服务端授权码',
                                  ),
                                  trailing: Button(
                                    child: const Text('填写授权码'),
                                    onPressed: _openFlyNarwhalAuthCodeDialog,
                                  ),
                                ),
                              ],
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
}

class _AnimatedVisibility extends StatelessWidget {
  const _AnimatedVisibility({
    required this.visible,
    required this.child,
  });

  static const Duration _duration = Duration(milliseconds: 220);

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedSwitcher(
        duration: _duration,
        reverseDuration: _duration,
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        transitionBuilder: (child, animation) {
          return SizeTransition(
            sizeFactor: animation,
            alignment: Alignment.topCenter,
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
        child: visible
            ? KeyedSubtree(
                key: const ValueKey('settings-color-visible'),
                child: child,
              )
            : const SizedBox(
                key: ValueKey('settings-color-hidden'),
                width: double.infinity,
                height: 0,
              ),
      ),
    );
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
