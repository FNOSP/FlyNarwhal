import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../data/storage/update_settings_store.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../providers/fly_narwhal_server_capabilities.dart';
import '../../../providers/providers.dart';
import '../../../providers/update_providers.dart';
import '../../../providers/update_settings_provider.dart';
import '../update/update_badge.dart';
import '../update/update_dialog.dart';
import '../update/update_state.dart';
import '../../navigation/navigation_display_mode_mapper.dart';
import '../../settings/app_language.dart';
import '../../settings/ui_font_scale.dart';
import '../../shared/common/app_loading_progress_ring.dart';
import '../../shared/toast.dart';
import '../../shared/hover_tip.dart';
import '../../shared/dialogs/app_dialog.dart';
import 'widgets/card_expander_item.dart';
import 'widgets/changelog_dialog.dart';
import 'widgets/danmu_dandan_source_dialog.dart';
import 'widgets/danmu_fallback_servers_dialog.dart';
import 'widgets/segmented_slider.dart';
import 'widgets/shortcut_settings_dialog.dart';
import 'widgets/smart_skip_config_dialog.dart';
import 'widgets/ssl_whitelist_dialog.dart';
import 'widgets/support_author_item.dart';
import 'package:fly_narwhal/ui/shared/app_button.dart';
import 'package:fly_narwhal/ui/shared/semi_icons.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _flyNarwhalServerUrlFocusNode = FocusNode();
  final TextEditingController _flyNarwhalServerUrlController =
      TextEditingController();
  final TextEditingController _flyNarwhalAuthCodeController =
      TextEditingController();
  final TextEditingController _updateProxyUrlController =
      TextEditingController();
  bool _danmuSourceConfigLoadRequested = false;
  bool _capabilitiesProbeRequested = false;
  String? _lastProbedFlyNarwhalServerUrl;
  bool _isFlyNarwhalAuthCodeVisible = false;
  List<String> _availableLogDates = const <String>[];
  String? _selectedLogDate;
  bool _isExportingLogs = false;
  String? _logExportErrorMessage;

  /// 「字体大小」所在的行。改字号会让它上方所有行重新排版，用这个 key
  /// 量出该行的位置，把滚动偏移补偿回去，避免它从指针下方跑掉。
  final GlobalKey _fontScaleRowKey = GlobalKey();

  /// 待补偿的字号切换：切换前该行在内容坐标中的位置和目标字号。
  /// 等 build 观察到新字号真正排版生效后才消费。
  ({double baselineOffsetInContent, String target})? _pendingFontScaleAnchor;

  /// 补偿进行中：列表暂时沿用的缩放系数。
  ///
  /// 行高与字号不是线性关系（实测 0.85/1.0/1.25 对应 74/77/87px），位移
  /// 只能等新排版量出来才知道；而 Flutter 的度量都在排版之后，所以
  /// 「先量后补」必然晚一帧。让列表在补偿落地前保持旧字号排版，就根本
  /// 不会产生那一帧的位移，也就没有可感知的跳动或闪烁。
  double? _listFontScaleFactorForLayout;

  @override
  void initState() {
    super.initState();
    _flyNarwhalServerUrlController.text =
        ref.read(settingsProvider).flyNarwhalServerBaseUrl;
    _updateProxyUrlController.text =
        ref.read(updateSettingsStoreProvider).proxyUrl;

    // Cache available log dates once so the export picker stays stable.
    _availableLogDates =
        ref.read(errorLogExporterProvider).getAvailableLogDates();
    if (_availableLogDates.isNotEmpty) {
      _selectedLogDate = _availableLogDates.first;
    }

    // Ask the server for its version on entry, so the cards that only exist on
    // 2.0.0-or-newer servers are drawn from a fresh answer rather than from
    // whatever the last probe (possibly a different server) left behind.
    WidgetsBinding.instance.addPostFrameCallback((_) => _probeCapabilities());
  }

  /// Requests the server version unless the server isn't fully configured.
  ///
  /// The answer flips the 2.0.0-gated cards; it is deliberately not cached
  /// across entries, because the server may have been updated or replaced.
  void _probeCapabilities() {
    final settings = ref.read(settingsProvider);
    final baseUrl = settings.flyNarwhalServerBaseUrl;
    if (!settings.flyNarwhalServerEnabled || baseUrl.isEmpty) {
      return;
    }
    if (!settings.hasFlyNarwhalAuthCode) {
      return;
    }
    if (baseUrl != _lastProbedFlyNarwhalServerUrl) {
      _lastProbedFlyNarwhalServerUrl = baseUrl;
      _capabilitiesProbeRequested = true;
    }
    if (!_capabilitiesProbeRequested || !mounted) {
      return;
    }
    unawaited(probeFlyNarwhalServerCapabilities(ref));
  }

  /// One-line state of the two dandanplay sources for the settings card, e.g.
  /// "官方服务 · 已启用（优先）  中转服务 · 已停用".
  String _dandanSourceSummary(AppLocalizations l10n) {
    final config =
        ref.watch(danmuSourceConfigControllerProvider).config.valueOrNull;
    if (config == null) return l10n.settingsDanmuDandanSourceCaption;
    final account = config.dandanAccount;
    final relay = config.dandan;
    if (!account.enabled && !relay.enabled) {
      return l10n.danmuDandanNoneEnabled;
    }
    // Mark the source the server will actually search first, not the stored
    // priority: a preference stranded on a switched-off source is skipped.
    final storedOfficialPreferred =
        account.priority == 0 || (account.priority == null && relay.priority != 0);
    final officialWins =
        account.enabled && (storedOfficialPreferred || !relay.enabled);
    return [
      _dandanSourceState(
          l10n, l10n.danmuDandanOfficialTitle, account.enabled, officialWins),
      _dandanSourceState(
          l10n, l10n.danmuDandanRelayTitle, relay.enabled, !officialWins),
    ].join('  ');
  }

  String _dandanSourceState(
      AppLocalizations l10n, String title, bool enabled, bool preferred) {
    final state = enabled
        ? l10n.danmuDandanStatusEnabled
        : l10n.danmuDandanStatusDisabled;
    return preferred && enabled
        ? '$title · $state（${l10n.danmuDandanStatusPreferred}）'
        : '$title · $state';
  }

  void _openFlyNarwhalAuthCodeDialog() {
    final l10n = AppLocalizations.of(context);
    _flyNarwhalAuthCodeController.text =
        ref.read(settingsProvider.notifier).getFlyNarwhalAuthCode();
    _isFlyNarwhalAuthCodeVisible = false;
    showAppDialog(
      context: context,
      title: l10n.settingsServerAuthCodePrompt,
      content: StatefulBuilder(
        builder: (context, setDialogState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.settingsServerAuthCodeLabel),
            const SizedBox(height: 12),
            TextBox(
              key: const ValueKey('settings-fly-narwhal-auth-code-input'),
              controller: _flyNarwhalAuthCodeController,
              obscureText: !_isFlyNarwhalAuthCodeVisible,
              onSubmitted: (_) async {
                // The dialog lives on the root navigator; pop it after saving.
                await _saveFlyNarwhalAuthCode();
                if (context.mounted) {
                  Navigator.of(context, rootNavigator: true).pop();
                }
              },
              suffix: AppIconButton(
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
            Text(
              l10n.settingsServerAuthCodeHint,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      secondaryButtonText: l10n.commonCancel,
      primaryButtonText: l10n.commonConfirm,
      // AppDialog waits for this and then closes itself using its own context.
      onPrimaryPressed: _saveFlyNarwhalAuthCode,
      autoDismiss: true,
    );
  }

  Future<void> _saveFlyNarwhalAuthCode() async {
    await ref
        .read(settingsProvider.notifier)
        .setFlyNarwhalAuthCode(_flyNarwhalAuthCodeController.text);
  }

  void _openSslWhitelistDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => const SslWhitelistDialog(),
    );
  }

  Future<void> _exportErrorLogs() async {
    final selectedLogDate = _selectedLogDate;
    if (selectedLogDate == null || _isExportingLogs) {
      return;
    }

    // Keep export status local so repeated clicks are ignored.
    setState(() {
      _isExportingLogs = true;
      _logExportErrorMessage = null;
    });

    try {
      await ref.read(errorLogExporterProvider).exportErrorLogs(selectedLogDate);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _logExportErrorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isExportingLogs = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _flyNarwhalAuthCodeController.dispose();
    _updateProxyUrlController.dispose();
    _flyNarwhalServerUrlController.dispose();
    _flyNarwhalServerUrlFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 「字体大小」行顶部相对滚动内容原点的偏移。
  double? _fontScaleRowOffsetInContent() {
    final rowContext = _fontScaleRowKey.currentContext;
    final scrollable = _scrollController.position.context.storageContext;
    final rowBox = rowContext?.findRenderObject() as RenderBox?;
    final viewportBox = scrollable.findRenderObject() as RenderBox?;
    if (rowBox == null || viewportBox == null) return null;
    // 该行在视口坐标系里的 y，加上已滚动距离即内容坐标。
    final rowTopInViewport =
        rowBox.localToGlobal(Offset.zero, ancestor: viewportBox).dy;
    return rowTopInViewport + _scrollController.offset;
  }

  /// 切换字号：先记下该行当前在内容中的位置，等新排版生效后补偿滚动。
  void _applyUiFontScale(SettingsNotifier settingsNotifier, String value) {
    final before = _fontScaleRowOffsetInContent();
    if (before != null) {
      _pendingFontScaleAnchor = (
        baselineOffsetInContent: before,
        target: value,
      );
      // 列表先钉在旧字号上：这一帧不重排，行就不会动。
      setState(() {
        _listFontScaleFactorForLayout =
            UiFontScale.factorFromValue(ref.read(settingsProvider).uiFontScale);
      });
    }
    settingsNotifier.setUiFontScale(value);
  }

  /// [build] 排完版后调用：把新字号与滚动补偿放在同一帧一起生效。
  ///
  /// 补偿量 = 该行在内容坐标中的位移。用 jumpTo 而不是 correctBy：后者
  /// 只是标记一次待处理的修正，需要下一轮 applyContentDimensions 才会
  /// 生效，在布局之外调用不会有任何效果。
  void _settleFontScaleAnchor() {
    final pending = _pendingFontScaleAnchor;
    if (pending == null) return;
    // 新字号尚未生效，下一帧再试。
    if (pending.target != ref.read(settingsProvider).uiFontScale) return;
    _pendingFontScaleAnchor = null;
    if (!mounted) return;
    setState(() => _listFontScaleFactorForLayout = null);
    if (!_scrollController.hasClients) return;
    // 此刻列表仍按旧字号排版，量到的位移就是「换成新字号后会产生的位移」。
    final oldLayoutOffset = _fontScaleRowOffsetInContent();
    if (oldLayoutOffset == null) return;
    // 下一帧按新字号重排后，把这段时间内新增的位移补回去。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final after = _fontScaleRowOffsetInContent();
      if (after == null) return;
      final delta = after - oldLayoutOffset;
      if (delta == 0) return;
      final position = _scrollController.position;
      final target = (position.pixels + delta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if (target != position.pixels) {
        _scrollController.jumpTo(target);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final errorLogExporter = ref.watch(errorLogExporterProvider);
    final userInfoAsync = ref.watch(userInfoProvider);
    final connectionTestState = ref.watch(flyNarwhalConnectionTestProvider);

    // Once the connected server is known to carry the danmu source config API,
    // pull the stored values a single time per screen life so the card summary
    // reflects the current sources without opening the dialog.
    final supportsModernContract = ref
            .watch(flyNarwhalServerCapabilitiesProvider)
            .valueOrNull
            ?.supportsModernContract ??
        false;
    if (supportsModernContract && !_danmuSourceConfigLoadRequested) {
      _danmuSourceConfigLoadRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(danmuSourceConfigControllerProvider.notifier).load();
        }
      });
    }
    final updateState = ref.watch(updateControllerProvider);
    final updateSettingsAsync = ref.watch(updateSettingsProvider);
    final updateSettings = updateSettingsAsync.asData?.value;
    final updateSettingsNotifier = ref.read(updateSettingsProvider.notifier);
    final currentVersionAsync = ref.watch(currentAppVersionProvider);
    final canExportLogs =
        errorLogExporter.isSupported && _availableLogDates.isNotEmpty;

    // 这一帧已按新字号排版，据此补偿滚动偏移，把「字体大小」那行钉回
    // 原位。
    if (_pendingFontScaleAnchor != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _settleFontScaleAnchor();
      });
    }

    // A changed address, auth code or enable switch means the previously probed
    // version belongs to a different server, so re-ask. Edits to unrelated
    // settings leave the state untouched and trigger nothing.
    ref.listen<SettingsState>(settingsProvider, (previous, next) {
      if (previous == null) return;
      final changed = previous.flyNarwhalServerEnabled !=
              next.flyNarwhalServerEnabled ||
          previous.flyNarwhalServerBaseUrl != next.flyNarwhalServerBaseUrl ||
          previous.hasFlyNarwhalAuthCode != next.hasFlyNarwhalAuthCode;
      if (changed) {
        _probeCapabilities();
      }
    });

    ref.listen<AsyncValue<String?>>(
      flyNarwhalConnectionTestProvider,
      (_, nextState) {
        nextState.whenOrNull(
          data: (version) {
            if (version == null) return;
            ref.read(toastManagerProvider.notifier).showToast(
                  l10n.settingsServerTestSuccess(version),
                  type: ToastType.success,
                  category: 'fly-narwhal-connection',
                );
            ref.read(flyNarwhalConnectionTestProvider.notifier).clear();
          },
          error: (error, _) {
            final isUnreachable =
                error.toString() == l10n.settingsServerUnreachable;
            ref.read(toastManagerProvider.notifier).showToast(
                  isUnreachable
                      ? l10n.settingsServerUnreachable
                      : l10n.settingsServerTestConnectFailed('$error'),
                  type: ToastType.failed,
                  category: 'fly-narwhal-connection',
                );
            ref.read(flyNarwhalConnectionTestProvider.notifier).clear();
          },
        );
      },
    );
    final isTestingFlyNarwhalServer = connectionTestState.isLoading;

    return Stack(
      children: [
        ScaffoldPage(
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: _HorizontalSpace(
                  child: Text(
                    l10n.settingsTitle,
                    style: FluentTheme.of(context)
                        .typography
                        .subtitle
                        ?.copyWith(color: Colors.grey[110]),
                  ),
                ),
              ),
              Expanded(
                // 切换字号时，这一帧的列表先按旧字号排版：整页不重排，
                // 「字体大小」那一行自然不会位移。等 postFrame 里把滚动
                // 偏移补偿好，下一帧两者一起生效，用户看不到中间态。
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(
                      _listFontScaleFactorForLayout ??
                          UiFontScale.factorFromValue(settings.uiFontScale),
                    ),
                  ),
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
                              _Header(title: l10n.settingsSectionAccount),
                              userInfoAsync.when(
                                data: (user) {
                                  if (user == null) {
                                    return CardExpanderItem(
                                      icon: const Icon(FluentIcons.contact),
                                      heading: Text(l10n.settingsAccountUnloaded),
                                      caption: Text(
                                        l10n.settingsAccountUnloadedCaption,
                                      ),
                                    );
                                  }

                                  return CardExpanderItem(
                                    icon: const Icon(FluentIcons.contact),
                                    heading: Row(
                                      children: [
                                        Text(user.username),
                                        if (user.isAdmin == 1)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(left: 8),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: Colors.blue,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(50),
                                              ),
                                              child: Text(
                                                l10n.settingsAccountAdminBadge,
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
                                loading: () => CardExpanderItem(
                                  heading: Row(
                                    children: [
                                      const AppLoadingProgressRing(size: 18),
                                      const SizedBox(width: 12),
                                      Text(l10n.commonUserInfoLoading),
                                    ],
                                  ),
                                ),
                                error: (e, _) => CardExpanderItem(
                                  icon: const Icon(FluentIcons.error),
                                  heading: Text(l10n.commonUserInfoLoadFailed),
                                  caption: Text(e.toString()),
                                ),
                              ),
                              CardExpanderItem(
                                key: const ValueKey('settings-logout'),
                                icon: const Icon(FluentIcons.sign_out),
                                heading: Text(l10n.settingsAccountSignOut),
                                caption: Text(l10n.settingsAccountSignOutCaption),
                                onPressed: () async {
                                  final confirmed = await showAppDialog<bool>(
                                    context: context,
                                    type: AppDialogType.confirmation,
                                    title: l10n.settingsAccountSignOut,
                                    content: Text(
                                      l10n.settingsAccountSignOutConfirm,
                                    ),
                                    primaryButtonText: l10n.commonConfirm,
                                    secondaryButtonText: l10n.commonCancel,
                                    primaryResult: true,
                                    secondaryResult: false,
                                  );
                                  if (confirmed != true || !mounted) return;

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
                              _Header(title: l10n.settingsSectionAppearance),
                              CardExpanderItem(
                                icon: const Icon(FluentIcons.color),
                                heading: Text(l10n.settingsAppearanceThemeMode),
                                caption: Text(l10n.settingsAppearanceThemeModeCaption),
                                trailing: ToggleSwitch(
                                  checked: settings.followSystemTheme,
                                  onChanged: (v) =>
                                      settingsNotifier.setFollowSystemTheme(v),
                                  content: Text(
                                    settings.followSystemTheme
                                        ? l10n.settingsAppearanceFollowSystem
                                        : l10n.settingsAppearanceManual,
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
                                  heading: Text(l10n.settingsAppearanceColor),
                                  caption: Text(l10n.settingsAppearanceColorCaption),
                                  trailing: ToggleSwitch(
                                    checked: settings.darkMode,
                                    onChanged: (v) =>
                                        settingsNotifier.setDarkMode(v),
                                    content:
                                        Text(settings.darkMode
                                            ? l10n.settingsAppearanceDark
                                            : l10n.settingsAppearanceLight),
                                  ),
                                ),
                              ),
                              CardExpanderItem(
                                icon:
                                    const Icon(FluentIcons.navigation_flipper),
                                heading: Text(l10n.settingsAppearanceNavStyle),
                                caption: Text(l10n.settingsAppearanceNavStyleCaption),
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
                                            NavigationDisplayModeMapper.toValue(
                                              e,
                                            ),
                                          ),
                                          onPressed: () => settingsNotifier
                                              .setNavigationDisplayMode(
                                            NavigationDisplayModeMapper.toValue(
                                              e,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                              CardExpanderItem(
                                icon: const Icon(FluentIcons.blur),
                                heading: Text(
                                  l10n.settingsAppearanceDetailsLiquidGlass,
                                ),
                                caption: Text(
                                  l10n.settingsAppearanceDetailsLiquidGlassCaption,
                                ),
                                trailing: ToggleSwitch(
                                  key: const ValueKey(
                                    'settings-player-details-liquid-glass-toggle',
                                  ),
                                  checked: settings.playerDetailsLiquidGlass,
                                  onChanged: (v) => settingsNotifier
                                      .setPlayerDetailsLiquidGlass(v),
                                ),
                              ),
                              const SizedBox(height: 4),
                              _Header(title: l10n.settingsSectionGeneral),
                              CardExpanderItem(
                                icon: const Icon(FluentIcons.locale_language),
                                heading: Text(l10n.settingsLanguageTitle),
                                caption: Text(l10n.settingsLanguageCaption),
                                trailing: DropDownButton(
                                  key: const ValueKey(
                                    'settings-language-dropdown',
                                  ),
                                  title: Text(
                                    AppLanguage.labelFromValue(
                                      settings.language,
                                    ),
                                  ),
                                  items: AppLanguage.values
                                      .map(
                                        (value) => MenuFlyoutItem(
                                          text: Text(
                                            AppLanguage.labelFromValue(value),
                                          ),
                                          onPressed: () => settingsNotifier
                                              .setLanguage(value),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                              CardExpanderItem(
                                key: _fontScaleRowKey,
                                icon: const Icon(FluentIcons.font_size),
                                heading: Text(l10n.settingsGeneralFontSize),
                                caption: Text(l10n.settingsGeneralFontSizeCaption),
                                trailing: SegmentedSlider<String>(
                                  key: const ValueKey(
                                    'settings-ui-font-scale',
                                  ),
                                  values: UiFontScale.values,
                                  selected: settings.uiFontScale,
                                  labelBuilder: (value) =>
                                      UiFontScale.labelFromValue(value, l10n),
                                  onChanged: (value) => _applyUiFontScale(
                                    settingsNotifier,
                                    value,
                                  ),
                                ),
                              ),
                              CardExpanderItem(
                                icon: const Icon(FluentIcons.keyboard_classic),
                                heading: Text(l10n.settingsGeneralShortcuts),
                                caption: Text(l10n.settingsGeneralShortcutsCaption),
                                trailing: AppButton(
                                  key:
                                      const ValueKey('settings-shortcuts-open'),
                                  child: Text(l10n.settingsGeneralCustomize),
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
                              _Header(title: l10n.settingsSectionServer),
                              CardExpanderItem(
                                key: const ValueKey(
                                  'settings-fly-narwhal-enabled',
                                ),
                                icon: const Icon(FluentIcons.server),
                                heading: Text(l10n.settingsServerEnable),
                                caption: Text(
                                  l10n.settingsServerEnableCaption,
                                ),
                                trailing: ToggleSwitch(
                                  checked: settings.flyNarwhalServerEnabled,
                                  onChanged: settingsNotifier
                                      .setFlyNarwhalServerEnabled,
                                  content: Text(
                                    settings.flyNarwhalServerEnabled
                                        ? l10n.settingsAboutOpen
                                        : l10n.settingsAboutClose,
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
                                      heading: Text(l10n.settingsServerAddress),
                                      caption: Text(l10n.settingsServerAddressIncomplete),
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
                                                focusNode:
                                                    _flyNarwhalServerUrlFocusNode,
                                                placeholder:
                                                    'http://192.168.1.1:5365',
                                                placeholderStyle: TextStyle(
                                                  color: Colors.grey[130],
                                                ),
                                                onSubmitted: settingsNotifier
                                                    .setFlyNarwhalServerBaseUrl,
                                                onTapOutside: (_) {
                                                  _flyNarwhalServerUrlFocusNode
                                                      .unfocus();
                                                  settingsNotifier
                                                      .setFlyNarwhalServerBaseUrl(
                                                    _flyNarwhalServerUrlController
                                                        .text,
                                                  );
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            AppButton(
                                              key: const ValueKey(
                                                'settings-fly-narwhal-test',
                                              ),
                                              onPressed:
                                                  isTestingFlyNarwhalServer
                                                      ? null
                                                      : () async {
                                                          final baseUrl =
                                                              _flyNarwhalServerUrlController
                                                                  .text;
                                                          final missingUrl =
                                                              baseUrl
                                                                  .trim()
                                                                  .isEmpty;
                                                          final missingAuthCode =
                                                              !settings
                                                                  .hasFlyNarwhalAuthCode;
                                                          // Guard: require both URL and auth code before testing
                                                          if (missingUrl ||
                                                              missingAuthCode) {
                                                            ref
                                                                .read(toastManagerProvider
                                                                    .notifier)
                                                                .showToast(
                                                                  buildFlyNarwhalConfigWarning(
                                                                    AppLocalizations.of(
                                                                        context),
                                                                    missingUrl:
                                                                        missingUrl,
                                                                    missingAuthCode:
                                                                        missingAuthCode,
                                                                  ),
                                                                  type: ToastType
                                                                      .warning,
                                                                  category:
                                                                      'fly-narwhal-config',
                                                                );
                                                            return;
                                                          }
                                                          await settingsNotifier
                                                              .setFlyNarwhalServerBaseUrl(
                                                            baseUrl,
                                                          );
                                                          await ref
                                                              .read(
                                                                flyNarwhalConnectionTestProvider
                                                                    .notifier,
                                                              )
                                                              .testConnection(
                                                                baseUrl,
                                                              );
                                                        },
                                              child: Text(
                                                isTestingFlyNarwhalServer
                                                    ? l10n.settingsServerTesting
                                                    : l10n.settingsServerTest,
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
                                      icon: const Icon(FluentIcons.permissions),
                                      heading: Row(
                                        children: [
                                          Text(l10n.settingsServerAuthCode),
                                          const SizedBox(width: 6),
                                          HoverTip(
                                            tipText:
                                                l10n.settingsServerAuthCodeHelp,
                                          ),
                                        ],
                                      ),
                                      caption: Text(
                                        settings.hasFlyNarwhalAuthCode
                                            ? l10n.settingsServerAuthCodeFilled
                                            : l10n.settingsServerAuthCodePrompt,
                                      ),
                                      trailing: AppButton(
                                        onPressed:
                                            _openFlyNarwhalAuthCodeDialog,
                                        child: Text(l10n.settingsServerAuthCodePlaceholder),
                                      ),
                                    ),
                                    // Servers below 2.0.0 analyze segments but
                                    // expose no config API, so this card would
                                    // open onto a failing request.
                                    if (ref
                                            .watch(
                                              flyNarwhalServerCapabilitiesProvider,
                                            )
                                            .valueOrNull
                                            ?.supportsModernContract ??
                                        false)
                                      CardExpanderItem(
                                        key: const ValueKey(
                                          'settings-fly-narwhal-smart-skip-config',
                                        ),
                                        icon: const Icon(
                                          FluentIcons.auto_enhance_on,
                                        ),
                                        heading: Text(
                                          l10n.playerSettingsSmartSkipConfig,
                                        ),
                                        caption: Text(
                                          l10n.settingsSmartSkipConfigCaption,
                                        ),
                                        trailing: AppButton(
                                          key: const ValueKey(
                                            'settings-smart-skip-config-open',
                                          ),
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) =>
                                                  const SmartSkipConfigDialog(),
                                            );
                                          },
                                          child: Text(
                                            l10n.smartSkipConfigConfigure,
                                          ),
                                        ),
                                      ),
                                    // Danmu source config endpoints only exist
                                    // on servers 2.0.0 or newer.
                                    if (supportsModernContract) ...[
                                      CardExpanderItem(
                                        key: const ValueKey(
                                          'settings-fly-narwhal-dandan-source',
                                        ),
                                        icon: const Icon(FluentIcons.comment),
                                        heading: Text(
                                          l10n.settingsDanmuDandanSource,
                                        ),
                                        caption: Text(
                                          _dandanSourceSummary(l10n),
                                        ),
                                        trailing: AppButton(
                                          key: const ValueKey(
                                            'settings-danmu-dandan-open',
                                          ),
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) =>
                                                  const DanmuDandanSourceDialog(),
                                            );
                                          },
                                          child: Text(l10n.danmuSourceConfigure),
                                        ),
                                      ),
                                      CardExpanderItem(
                                        key: const ValueKey(
                                          'settings-fly-narwhal-fallback-servers',
                                        ),
                                        icon: const Icon(FluentIcons.database),
                                        heading: Text(
                                          l10n.settingsDanmuFallbackServers,
                                        ),
                                        caption: Text(
                                          l10n
                                              .settingsDanmuFallbackServersCaption,
                                        ),
                                        trailing: AppButton(
                                          key: const ValueKey(
                                            'settings-danmu-fallback-open',
                                          ),
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) =>
                                                  const DanmuFallbackServersDialog(),
                                            );
                                          },
                                          child: Text(
                                            l10n.danmuSourceConfigure,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              _Header(title: l10n.settingsSectionPrivacy),
                              CardExpanderItem(
                                key: const ValueKey('settings-ssl-whitelist'),
                                // `currentColor` in an SVG does not read
                                // IconTheme, so match the neighbouring Fluent
                                // icons explicitly or the stroke renders in a
                                // different shade.
                                icon: SemiIcons.sslCertificate(
                                  size: 18,
                                  color: IconTheme.of(context).color,
                                ),
                                heading: Text(l10n.settingsPrivacySslTitle),
                                caption: Text(
                                  settings.sslWhitelist.isEmpty
                                      ? l10n.settingsPrivacySslCaption
                                      : l10n.settingsPrivacySslTrustedCount(
                                          '${settings.sslWhitelist.length}',
                                        ),
                                ),
                                trailing: AppButton(
                                  key: const ValueKey(
                                    'settings-ssl-whitelist-open',
                                  ),
                                  onPressed: _openSslWhitelistDialog,
                                  child: Text(l10n.settingsPrivacyManage),
                                ),
                              ),
                              CardExpanderItem(
                                icon: Builder(
                                  builder: (context) {
                                    final iconColor =
                                        IconTheme.of(context).color;
                                    return SvgPicture.asset(
                                      'assets/images/statement.svg',
                                      width: 16,
                                      height: 16,
                                      colorFilter: iconColor == null
                                          ? null
                                          : ColorFilter.mode(
                                              iconColor,
                                              BlendMode.srcIn,
                                            ),
                                    );
                                  },
                                ),
                                heading: Text(l10n.settingsPrivacyStatement),
                                caption: Text(l10n.settingsPrivacyStatement),
                                onPressed: () {
                                  showAppDialog(
                                    context: context,
                                    title: l10n.settingsPrivacyStatement,
                                    content: Text(
                                      l10n.settingsPrivacyStatementBody,
                                    ),
                                    primaryButtonText: l10n.commonGotIt,
                                  );
                                },
                              ),
                              const SizedBox(height: 4),
                              _Header(title: l10n.settingsSectionAbout),
                              CardExpanderItem(
                                key: const ValueKey('settings-check-update'),
                                icon: const Icon(FluentIcons.info),
                                heading: Row(
                                  children: [
                                    Text(l10n.settingsAboutVersion),
                                    if (updateState.hasUpdateBadge) ...[
                                      const SizedBox(width: 6),
                                      const SharedUpdateBadge(
                                        key: ValueKey('settings-update-badge'),
                                      ),
                                    ],
                                  ],
                                ),
                                caption: currentVersionAsync.when(
                                  data: (version) => Text(version),
                                  loading: () => Text(l10n.settingsAboutVersionLoading),
                                  error: (error, _) => Text(l10n.settingsAboutVersionUnavailable),
                                ),
                                trailing: AppButton(
                                  key: const ValueKey(
                                      'settings-check-update-button'),
                                  onPressed: updateState.phase ==
                                          UpdatePhase.checking
                                      ? null
                                      : () {
                                          showUpdateDialog(context);
                                          ref
                                              .read(updateControllerProvider
                                                  .notifier)
                                              .checkForUpdates(isManual: true);
                                        },
                                  child:
                                      updateState.phase == UpdatePhase.checking
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: ProgressRing())
                                          : Text(l10n.settingsAboutCheckUpdate),
                                ),
                              ),
                              SettingsUpdateControls(
                                settings: updateSettings,
                                proxyUrlController: _updateProxyUrlController,
                                onIncludePrereleaseChanged: (value) async {
                                  await updateSettingsNotifier
                                      .setIncludePrerelease(value);
                                  await ref
                                      .read(updateControllerProvider.notifier)
                                      .handleIncludePrereleaseChanged(value);
                                },
                                onAutoDownloadChanged: (value) async {
                                  await updateSettingsNotifier
                                      .setAutoDownload(value);
                                  await ref
                                      .read(updateControllerProvider.notifier)
                                      .handleAutoDownloadChanged(value);
                                },
                                onProxyEnabledChanged: (value) async {
                                  await updateSettingsNotifier
                                      .setProxyEnabled(value);
                                  await ref
                                      .read(updateControllerProvider.notifier)
                                      .handleProxyChanged(
                                        isEnabled: value,
                                        proxyUrl: updateSettings!.proxyUrl,
                                      );
                                },
                                onProxyUrlSubmitted: (value) async {
                                  try {
                                    await updateSettingsNotifier
                                        .setProxyUrl(value);
                                    final currentSettings = ref
                                        .read(updateSettingsProvider)
                                        .asData
                                        ?.value;
                                    if (currentSettings != null) {
                                      await ref
                                          .read(
                                              updateControllerProvider.notifier)
                                          .handleProxyChanged(
                                            isEnabled:
                                                currentSettings.isProxyEnabled,
                                            proxyUrl: value,
                                          );
                                    }
                                  } on FormatException catch (error) {
                                    ref
                                        .read(toastManagerProvider.notifier)
                                        .showToast(
                                          error.message,
                                          type: ToastType.failed,
                                          category: 'update-proxy',
                                        );
                                  }
                                },
                              ),
                              const SupportAuthorItem(),
                              CardExpanderItem(
                                key: const ValueKey('settings-changelog'),
                                icon: const Icon(FluentIcons.history),
                                heading: Text(l10n.settingsAboutChangelog),
                                caption: Text(l10n.settingsAboutChangelogCaption),
                                onPressed: () => showChangelogDialog(context),
                              ),
                              if (canExportLogs)
                                CardExpanderItem(
                                  key: const ValueKey('settings-log-export'),
                                  icon: const Icon(FluentIcons.download),
                                  heading: Text(l10n.settingsAboutExportLogs),
                                  caption: Text(
                                    l10n.settingsAboutExportLogsCaption,
                                  ),
                                  trailing: Row(
                                    children: [
                                      DropDownButton(
                                        key: const ValueKey(
                                          'settings-log-date-dropdown',
                                        ),
                                        title: Text(_selectedLogDate ?? ''),
                                        items: _availableLogDates
                                            .map(
                                              (date) => MenuFlyoutItem(
                                                text: Text(date),
                                                onPressed: () {
                                                  setState(() {
                                                    _selectedLogDate = date;
                                                  });
                                                },
                                              ),
                                            )
                                            .toList(),
                                      ),
                                      const SizedBox(width: 8),
                                      AppButton(
                                        key: const ValueKey(
                                          'settings-log-export-button',
                                        ),
                                        onPressed: _isExportingLogs
                                            ? null
                                            : _exportErrorLogs,
                                        child: Text(l10n.settingsAboutExport),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ],
          ),
        ),
        if (_logExportErrorMessage != null)
          _DialogOverlay(
            child: ContentDialog(
              key: const ValueKey('settings-log-export-error-dialog'),
              title: Text(l10n.settingsAboutExportError),
              content: Text(_logExportErrorMessage!),
              actions: [
                AppButton(
                  child: Text(l10n.commonConfirm),
                  onPressed: () {
                    setState(() {
                      _logExportErrorMessage = null;
                    });
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DialogOverlay extends StatelessWidget {
  const _DialogOverlay({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0x66000000),
        child: Center(
          child: child,
        ),
      ),
    );
  }
}

class SettingsUpdateControls extends StatelessWidget {
  const SettingsUpdateControls({
    super.key,
    required this.settings,
    required this.proxyUrlController,
    required this.onIncludePrereleaseChanged,
    required this.onAutoDownloadChanged,
    required this.onProxyEnabledChanged,
    required this.onProxyUrlSubmitted,
  });

  final UpdateSettings? settings;
  final TextEditingController proxyUrlController;
  final ValueChanged<bool> onIncludePrereleaseChanged;
  final ValueChanged<bool> onAutoDownloadChanged;
  final ValueChanged<bool> onProxyEnabledChanged;
  final ValueChanged<String> onProxyUrlSubmitted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentSettings = settings;
    return Column(
      children: [
        CardExpanderItem(
          key: const ValueKey('settings-update-prerelease'),
          icon: const Icon(FluentIcons.test_beaker),
          heading: Text(l10n.settingsAboutPrereleaseEarly),
          caption: Text(l10n.settingsAboutPrerelease),
          trailing: ToggleSwitch(
            key: const ValueKey('settings-update-prerelease-toggle'),
            checked: currentSettings?.includePrerelease ?? false,
            onChanged:
                currentSettings == null ? null : onIncludePrereleaseChanged,
            content: Text(_toggleLabel(l10n, 
              isLoading: currentSettings == null,
              value: currentSettings?.includePrerelease ?? false,
            )),
          ),
        ),
        CardExpanderItem(
          key: const ValueKey('settings-update-auto-download'),
          icon: const Icon(FluentIcons.cloud_download),
          heading: Text(l10n.settingsAboutAutoDownload),
          caption: Text(l10n.settingsAboutAutoDownloadCaption),
          trailing: ToggleSwitch(
            key: const ValueKey('settings-update-auto-download-toggle'),
            checked: currentSettings?.autoDownload ?? false,
            onChanged: currentSettings == null ? null : onAutoDownloadChanged,
            content: Text(_toggleLabel(l10n, 
              isLoading: currentSettings == null,
              value: currentSettings?.autoDownload ?? false,
            )),
          ),
        ),
        CardExpanderItem(
          key: const ValueKey('settings-update-proxy-enabled'),
          icon: const Icon(FluentIcons.globe),
          heading: Text(l10n.settingsPrivacyGitHubProxy),
          caption: Text(l10n.settingsPrivacyGitHubProxyCaption),
          trailing: ToggleSwitch(
            key: const ValueKey('settings-update-proxy-enabled-toggle'),
            checked: currentSettings?.isProxyEnabled ?? false,
            onChanged: currentSettings == null ? null : onProxyEnabledChanged,
            content: Text(_toggleLabel(l10n, 
              isLoading: currentSettings == null,
              value: currentSettings?.isProxyEnabled ?? false,
            )),
          ),
        ),
        _AnimatedVisibility(
          visible: currentSettings?.isProxyEnabled ?? false,
          child: CardExpanderItem(
            key: const ValueKey('settings-update-proxy-url'),
            icon: const Icon(FluentIcons.link),
            heading: Text(l10n.settingsPrivacyProxyAddress),
            caption: Text(l10n.settingsServerAddressHttpsRequired),
            trailing: SizedBox(
              width: 360,
              child: TextBox(
                key: const ValueKey('settings-update-proxy-url-input'),
                controller: proxyUrlController,
                onSubmitted: onProxyUrlSubmitted,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _toggleLabel(
    AppLocalizations l10n, {
    required bool isLoading,
    required bool value,
  }) {
    if (isLoading) return l10n.commonLoading;
    return value ? l10n.settingsAboutOpen : l10n.settingsAboutClose;
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
        // FluentTheme's typography carries fixed font sizes, so it ignores the
        // app-wide textScaler; scale it here to keep headers in step.
        textScaler: MediaQuery.textScalerOf(context),
        style: FluentTheme.of(context).typography.bodyStrong,
      ),
    );
  }
}

