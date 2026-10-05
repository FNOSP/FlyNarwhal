import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
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
import 'widgets/danmu_fallback_servers_dialog.dart';
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
  final TextEditingController _danmuDandanRelayController =
      TextEditingController();
  final FocusNode _danmuDandanRelayFocusNode = FocusNode();
  bool _danmuSourceConfigLoadRequested = false;
  bool _isTestingDanmuDandanRelay = false;
  bool _isFlyNarwhalAuthCodeVisible = false;
  List<String> _availableLogDates = const <String>[];
  String? _selectedLogDate;
  bool _isExportingLogs = false;
  String? _logExportErrorMessage;

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
  }

  /// Persists the dandan relay field (empty = disabled), mirroring the
  /// server-address field's silent blur-save. The explicit button tests
  /// connectivity instead of saving.
  Future<bool> _saveDanmuDandanRelay() async {
    final ok = await ref
        .read(danmuSourceConfigControllerProvider.notifier)
        .saveDandanRelay(_danmuDandanRelayController.text);
    return ok && mounted;
  }

  /// Saves the field, then probes the relay's public search endpoint
  /// (`?path=/v2/search/anime`) directly — no signing needed, the relay is an
  /// unauthenticated third party.
  Future<void> _testDanmuDandanRelay() async {
    final l10n = AppLocalizations.of(context);
    final url = _danmuDandanRelayController.text.trim();
    if (url.isEmpty) {
      ref.read(toastManagerProvider.notifier).showToast(
            l10n.danmuSourceRelayRequired,
            type: ToastType.warning,
            category: 'danmu-source-config',
          );
      return;
    }
    setState(() => _isTestingDanmuDandanRelay = true);
    try {
      final saved = await _saveDanmuDandanRelay();
      if (!saved || !mounted) return;
      var reachable = false;
      String? detail;
      try {
        final dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          validateStatus: (_) => true,
        ));
        final response = await dio.get(
          '$url${url.contains('?') ? '&' : '?'}path=${Uri.encodeComponent('/v2/search/anime?keyword=test')}',
        );
        try {
          final json = jsonDecode(response.data?.toString() ?? '');
          reachable = json is Map &&
              (json['errorCode'] == 0 || json['animes'] is List);
          if (!reachable && json is Map) {
            detail = 'errorCode=${json['errorCode']}';
          }
        } catch (_) {
          detail = 'HTTP ${response.statusCode}';
        }
      } catch (error) {
        detail = error.toString();
      }
      if (!mounted) return;
      ref.read(toastManagerProvider.notifier).showToast(
            reachable
                ? l10n.danmuSourceRelayReachable
                : '${l10n.danmuSourceRelayUnreachable}${detail == null ? '' : ' ($detail)'}',
            type: reachable ? ToastType.success : ToastType.failed,
            category: 'danmu-source-config',
          );
    } finally {
      if (mounted) {
        setState(() => _isTestingDanmuDandanRelay = false);
      }
    }
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
    _danmuDandanRelayController.dispose();
    _danmuDandanRelayFocusNode.dispose();
    _flyNarwhalServerUrlController.dispose();
    _flyNarwhalServerUrlFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
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
    // pull the stored values a single time per screen life so the dandan field
    // can prefill with the current effective relay.
    final supportsDanmuSourceConfig = ref
            .watch(flyNarwhalServerCapabilitiesProvider)
            .valueOrNull
            ?.supportsDanmuSourceConfig ??
        false;
    if (supportsDanmuSourceConfig && !_danmuSourceConfigLoadRequested) {
      _danmuSourceConfigLoadRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(danmuSourceConfigControllerProvider.notifier).load();
        }
      });
    }
    // Mirror the server-side relay URL into the input without clobbering what
    // the user is typing: only overwrite when the field still shows the
    // previous stored value (or is empty).
    ref.listen(danmuSourceConfigControllerProvider, (prev, next) {
      final nextUrl = next.config.valueOrNull?.dandan.url ?? '';
      final prevUrl = prev?.config.valueOrNull?.dandan.url;
      final current = _danmuDandanRelayController.text;
      if (nextUrl != prevUrl && (current.isEmpty || current == prevUrl)) {
        _danmuDandanRelayController.text = nextUrl;
      }
    });
    final updateState = ref.watch(updateControllerProvider);
    final updateSettingsAsync = ref.watch(updateSettingsProvider);
    final updateSettings = updateSettingsAsync.asData?.value;
    final updateSettingsNotifier = ref.read(updateSettingsProvider.notifier);
    final currentVersionAsync = ref.watch(currentAppVersionProvider);
    final canExportLogs =
        errorLogExporter.isSupported && _availableLogDates.isNotEmpty;

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
                                icon: const Icon(FluentIcons.font_size),
                                heading: Text(l10n.settingsGeneralFontSize),
                                caption: Text(l10n.settingsGeneralFontSizeCaption),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 160,
                                      child: Slider(
                                        key: const ValueKey(
                                          'settings-ui-font-scale',
                                        ),
                                        value: UiFontScale.indexFromValue(
                                          settings.uiFontScale,
                                        ).toDouble(),
                                        min: 0,
                                        max:
                                            (UiFontScale.values.length - 1)
                                                .toDouble(),
                                        divisions:
                                            UiFontScale.values.length - 1,
                                        label: UiFontScale.labelFromValue(
                                          settings.uiFontScale,
                                          l10n,
                                        ),
                                        onChanged: (index) =>
                                            settingsNotifier.setUiFontScale(
                                          UiFontScale.valueFromIndex(
                                            index.round(),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 20,
                                      child: Text(
                                        UiFontScale.labelFromValue(
                                          settings.uiFontScale,
                                          l10n,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
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
                                    // Servers below 0.7.0 analyze segments but
                                    // expose no config API, so this card would
                                    // open onto a failing request.
                                    if (ref
                                            .watch(
                                              flyNarwhalServerCapabilitiesProvider,
                                            )
                                            .valueOrNull
                                            ?.supportsSmartSkipConfig ??
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
                                    // on servers newer than 0.7.0.
                                    if (supportsDanmuSourceConfig) ...[
                                      CardExpanderItem(
                                        key: const ValueKey(
                                          'settings-fly-narwhal-dandan-source',
                                        ),
                                        icon: const Icon(FluentIcons.comment),
                                        heading: Text(
                                          l10n.settingsDanmuDandanSource,
                                        ),
                                        caption: Text(
                                          l10n.settingsDanmuDandanSourceCaption,
                                        ),
                                        trailing: SizedBox(
                                          width: 360,
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: TextBox(
                                                  key: const ValueKey(
                                                    'settings-danmu-dandan-relay-input',
                                                  ),
                                                  controller:
                                                      _danmuDandanRelayController,
                                                  focusNode:
                                                      _danmuDandanRelayFocusNode,
                                                  placeholder:
                                                      'https://api.danmaku.weeblify.app/ddp/v1',
                                                  placeholderStyle: TextStyle(
                                                    color: Colors.grey[130],
                                                  ),
                                                  // Blur-save, same behavior
                                                  // as the server address
                                                  // field above.
                                                  onSubmitted: (_) =>
                                                      _saveDanmuDandanRelay(),
                                                  onTapOutside: (_) {
                                                    _danmuDandanRelayFocusNode
                                                        .unfocus();
                                                    _saveDanmuDandanRelay();
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              AppButton(
                                                key: const ValueKey(
                                                  'settings-danmu-dandan-relay-test',
                                                ),
                                                onPressed:
                                                    _isTestingDanmuDandanRelay
                                                        ? null
                                                        : _testDanmuDandanRelay,
                                                child: Text(
                                                  _isTestingDanmuDandanRelay
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
