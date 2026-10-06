import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/fly_narwhal/index.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../providers/danmu_source_config_controller.dart';
import '../../../../providers/providers.dart';
import '../../../shared/app_button.dart';
import '../../../shared/dialogs/app_dialog.dart';
import '../../../shared/toast.dart';

/// Configures the two dandanplay channels side by side: the official open
/// network and a third-party ddp relay. Each can be switched on independently;
/// a mutually exclusive "preferred" switch picks which one the server searches
/// first, falling back to the other only when it finds nothing.
///
/// The server is the single source of truth — every switch goes through
/// [DanmuSourceConfigController] and the config reloads afterwards.
class DanmuDandanSourceDialog extends ConsumerStatefulWidget {
  const DanmuDandanSourceDialog({super.key});

  /// Whether a relay probe response indicates a healthy ddp relay, plus a
  /// failure detail for the toast. dio's default json responseType may have
  /// already decoded the body into a Map — only jsonDecode raw Strings.
  static (bool, String?) parseRelayProbe(dynamic raw, int? statusCode) {
    try {
      final json = raw is String ? jsonDecode(raw) : raw;
      if (json is Map && (json['errorCode'] == 0 || json['animes'] is List)) {
        return (true, null);
      }
      if (json is Map) {
        return (false, 'errorCode=${json['errorCode']}');
      }
      return (false, 'HTTP $statusCode');
    } catch (_) {
      return (false, 'HTTP $statusCode');
    }
  }

  @override
  ConsumerState<DanmuDandanSourceDialog> createState() =>
      _DanmuDandanSourceDialogState();
}

class _DanmuDandanSourceDialogState
    extends ConsumerState<DanmuDandanSourceDialog> {
  final TextEditingController _appIdController = TextEditingController();
  final TextEditingController _appSecretController = TextEditingController();
  final TextEditingController _relayUrlController = TextEditingController();
  final FocusNode _relayUrlFocusNode = FocusNode();

  bool _secretVisible = false;
  bool _isTestingOfficial = false;
  bool _isTestingRelay = false;
  bool _fieldsSynced = false;

  /// Guards against a second save landing while one is in flight; the switches
  /// stay enabled during a save so their appearance never flickers.
  bool _saveInFlight = false;

  @override
  void initState() {
    super.initState();
    // load() flips the provider state on its first line; doing that
    // synchronously in initState throws Riverpod's "modify a provider while
    // the widget tree is building" because the settings screen is already
    // watching this controller. Defer to after the frame, the same pattern the
    // fallback servers dialog uses.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(danmuSourceConfigControllerProvider.notifier).load();
      }
    });
  }

  @override
  void dispose() {
    _appIdController.dispose();
    _appSecretController.dispose();
    _relayUrlController.dispose();
    _relayUrlFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(danmuSourceConfigControllerProvider);
    final config = state.config.valueOrNull;
    if (config != null && !_fieldsSynced) {
      // The text fields have listeners (and this runs during build), so fill
      // them after the frame rather than mutating controllers mid-build.
      _fieldsSynced = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _appIdController.text = config.dandanAccount.appId;
        _appSecretController.text = config.dandanAccount.appSecret;
        _relayUrlController.text = config.dandan.url;
      });
    }
    final account = config?.dandanAccount ?? const DandanAccount();
    final relay = config?.dandan ?? const DanmuDandanConfig();

    // The preferred switch is mutual: whichever row holds priority 0 owns it.
    // A null priority means the server was never told, which reads as
    // "official first" — the pre-0.13.0 behavior.
    final officialPreferred =
        account.priority == 0 || (account.priority == null && relay.priority != 0);
    // A source that is off cannot be the preferred one, and with both off there
    // is nothing to prefer at all.
    final anyEnabled = account.enabled || relay.enabled;
    final canPreferOfficial = account.enabled && anyEnabled;
    final canPreferRelay = relay.enabled && anyEnabled;

    // The stored priority can point at a source the user has since switched
    // off. The server skips an unusable channel, so the OTHER one is what
    // actually gets searched — show the switch where the search really goes,
    // not where the stale priority points.
    final officialWins = canPreferOfficial &&
        (officialPreferred || !canPreferRelay);
    final relayWins = canPreferRelay && !officialWins;

    return AppDialog(
      title: l10n.danmuDandanDialogTitle,
      constraints: const BoxConstraints(
        minWidth: 560,
        maxWidth: 620,
        maxHeight: 640,
      ),
      content: SizedBox(
        width: 560,
        child: state.config is AsyncLoading && config == null
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: ProgressRing()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (state.loadError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(_shortError(state.loadError!)),
                      ),
                    _officialCard(
                      l10n,
                      account,
                      preferred: officialWins,
                      enabled: account.enabled,
                      canPrefer: canPreferOfficial,
                    ),
                    const SizedBox(height: 12),
                    _relayCard(
                      l10n,
                      relay,
                      preferred: relayWins,
                      enabled: relay.enabled,
                      canPrefer: canPreferRelay,
                    ),
                    if (state.actionError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(_shortError(state.actionError!)),
                      ),
                  ],
                ),
              ),
      ),
      primaryButtonText: l10n.settingsAboutClose,
    );
  }

  Widget _officialCard(
    AppLocalizations l10n,
    DandanAccount account, {
    required bool enabled,
    required bool preferred,
    required bool canPrefer,
  }) {
    return _sourceCard(
      heading: l10n.danmuDandanOfficialTitle,
      caption: l10n.danmuDandanOfficialCaption,
      enabled: enabled,
      preferred: preferred,
      canPrefer: canPrefer,
      enableKey: const ValueKey('settings-danmu-official-enable'),
      preferredKey: const ValueKey('settings-danmu-official-preferred'),
      onEnabledChanged: (value) => _mutate(() => ref
          .read(danmuSourceConfigControllerProvider.notifier)
          .setDandanOfficialEnabled(value)),
      onPreferredChanged: (value) =>
          _setPreferred(officialPreferred: value),
      test: AppButton(
        key: const ValueKey('settings-danmu-official-test'),
        onPressed: (_isTestingOfficial || !account.enabled)
            ? null
            : _testOfficial,
        child: Text(_isTestingOfficial
            ? l10n.danmuDandanTesting
            : l10n.danmuDandanTest),
      ),
      fields: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextBox(
            key: const ValueKey('settings-danmu-official-appid'),
            controller: _appIdController,
            placeholder: l10n.danmuDandanOfficialAppIdHint,
            placeholderStyle: TextStyle(color: Colors.grey[130]),
            onSubmitted: (_) => _saveOfficial(),
            onTapOutside: (_) => _saveOfficial(),
          ),
          const SizedBox(height: 8),
          TextBox(
            key: const ValueKey('settings-danmu-official-secret'),
            controller: _appSecretController,
            placeholder: l10n.danmuDandanOfficialAppSecretHint,
            placeholderStyle: TextStyle(color: Colors.grey[130]),
            obscureText: !_secretVisible,
            onSubmitted: (_) => _saveOfficial(),
            onTapOutside: (_) => _saveOfficial(),
            suffix: AppIconButton(
              icon: Icon(_secretVisible ? FluentIcons.hide3 : FluentIcons.view),
              onPressed: () =>
                  setState(() => _secretVisible = !_secretVisible),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.danmuDandanOfficialHint,
            style: TextStyle(fontSize: 12, color: Colors.grey[130]),
          ),
        ],
      ),
    );
  }

  Widget _relayCard(
    AppLocalizations l10n,
    DanmuDandanConfig relay, {
    required bool enabled,
    required bool preferred,
    required bool canPrefer,
  }) {
    return _sourceCard(
      heading: l10n.danmuDandanRelayTitle,
      caption: l10n.danmuDandanRelayCaption,
      enabled: enabled,
      preferred: preferred,
      canPrefer: canPrefer,
      enableKey: const ValueKey('settings-danmu-relay-enable'),
      preferredKey: const ValueKey('settings-danmu-relay-preferred'),
      onEnabledChanged: (value) => _mutate(() => ref
          .read(danmuSourceConfigControllerProvider.notifier)
          .setDandanRelayEnabled(value)),
      onPreferredChanged: (value) =>
          _setPreferred(officialPreferred: !value),
      test: AppButton(
        key: const ValueKey('settings-danmu-relay-test'),
        onPressed: (_isTestingRelay || !relay.enabled) ? null : _testRelay,
        child: Text(
            _isTestingRelay ? l10n.danmuDandanTesting : l10n.danmuDandanTest),
      ),
      fields: TextBox(
        key: const ValueKey('settings-danmu-relay-url'),
        controller: _relayUrlController,
        focusNode: _relayUrlFocusNode,
        placeholder: l10n.danmuDandanRelayUrlHint,
        placeholderStyle: TextStyle(color: Colors.grey[130]),
        onSubmitted: (_) => _saveRelay(),
        onTapOutside: (_) {
          _relayUrlFocusNode.unfocus();
          _saveRelay();
        },
      ),
    );
  }

  /// One source card: heading, caption, the two switches, the fields and the
  /// connectivity test button.
  Widget _sourceCard({
    required String heading,
    required String caption,
    required bool enabled,
    required bool preferred,
    required bool canPrefer,
    required Key enableKey,
    required Key preferredKey,
    required ValueChanged<bool> onEnabledChanged,
    required ValueChanged<bool> onPreferredChanged,
    required Widget test,
    required Widget fields,
  }) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: appDialogDarkSecondaryBorderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(heading,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      caption,
                      style: TextStyle(fontSize: 12, color: Colors.grey[130]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ToggleSwitch(
                key: enableKey,
                checked: enabled,
                // Left interactive during a save on purpose: disabling on the
                // global save flag flickered every switch on the card, not just
                // the one being changed. _mutate ignores taps while a save is in
                // flight, which is what the disabled state was standing in for.
                onChanged: (value) => onEnabledChanged(value),
                content: Text(l10n.danmuDandanEnable),
              ),
              const SizedBox(width: 12),
              Tooltip(
                message: canPrefer
                    ? l10n.danmuDandanPreferredTooltip
                    : l10n.danmuDandanPreferredNeedsEnable,
                child: ToggleSwitch(
                  key: preferredKey,
                  checked: preferred,
                  onChanged: canPrefer ? (value) => onPreferredChanged(value) : null,
                  content: Text(l10n.danmuDandanPreferred),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          fields,
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerLeft, child: test),
        ],
      ),
    );
  }

  /// Server errors here arrive as a raw exception (a stack trace when the
  /// server is an older build than the client), which swamps the dialog. Show
  /// the first line only — enough to act on, short enough to read.
  static String _shortError(String raw) {    final firstLine = raw.split('\n').first.trim();
    final cleaned = firstLine.replaceFirst(RegExp(r'^Error:\s*'), '');
    return cleaned.length <= 160 ? cleaned : '${cleaned.substring(0, 160)}…';
  }

  Future<void> _mutate(Future<bool> Function() action) async {
    // The switches stay interactive while a save is in flight (so their
    // appearance does not flicker), which makes this guard the thing that keeps
    // a double tap from firing two writes.
    if (_saveInFlight) return;
    _saveInFlight = true;
    final l10n = AppLocalizations.of(context);
    try {
      final ok = await action();
      if (!ok || !mounted) return;
      ref.read(toastManagerProvider.notifier).showToast(
            l10n.danmuSourceSaved,
            type: ToastType.success,
            category: 'danmu-source-config',
          );
    } finally {
      _saveInFlight = false;
    }
  }

  Future<void> _setPreferred({required bool officialPreferred}) {
    return _mutate(() => ref
        .read(danmuSourceConfigControllerProvider.notifier)
        .setPreferredDandanSource(officialPreferred: officialPreferred));
  }

  /// Persists the official credentials (and the current switch), so editing a
  /// field and leaving it applies without a separate Save button.
  Future<void> _saveOfficial() async {
    final current = ref
            .read(danmuSourceConfigControllerProvider)
            .config
            .valueOrNull
            ?.dandanAccount ??
        const DandanAccount();
    final candidate = current.copyWith(
      appId: _appIdController.text.trim(),
      appSecret: _appSecretController.text.trim(),
    );
    if (candidate.appId == current.appId &&
        candidate.appSecret == current.appSecret) {
      return;
    }
    await _mutate(() => ref
        .read(danmuSourceConfigControllerProvider.notifier)
        .saveDandanAccount(candidate));
  }

  Future<void> _saveRelay() async {
    final current = ref
            .read(danmuSourceConfigControllerProvider)
            .config
            .valueOrNull
            ?.dandan ??
        const DanmuDandanConfig();
    final address = _relayUrlController.text.trim();
    if (address == current.url) return;
    await _mutate(() => ref
        .read(danmuSourceConfigControllerProvider.notifier)
        .saveDandanRelay(current.copyWith(url: address)));
  }

  /// Saves the credentials first (the probe uses what is submitted), then asks
  /// the server to sign a request — the signature cannot be computed here.
  Future<void> _testOfficial() async {
    final l10n = AppLocalizations.of(context);
    if (!mounted) return;
    setState(() => _isTestingOfficial = true);
    try {
      final account = DandanAccount(
        appId: _appIdController.text.trim(),
        appSecret: _appSecretController.text.trim(),
        enabled: true,
      );
      if (account.appId.isEmpty || account.appSecret.isEmpty) {
        ref.read(toastManagerProvider.notifier).showToast(
              l10n.danmuDandanOfficialTestFailed,
              type: ToastType.warning,
              category: 'danmu-source-config',
            );
        return;
      }
      final detail = await ref
          .read(danmuSourceConfigControllerProvider.notifier)
          .testDandanAccount(account);
      if (!mounted) return;
      ref.read(toastManagerProvider.notifier).showToast(
            detail == null
                ? l10n.danmuDandanOfficialTestOk
                : '${l10n.danmuDandanOfficialTestFailed} ($detail)',
            type: detail == null ? ToastType.success : ToastType.failed,
            category: 'danmu-source-config',
          );
    } finally {
      if (mounted) setState(() => _isTestingOfficial = false);
    }
  }

  /// Saves the address, then probes the relay's public search endpoint
  /// (`?path=/v2/search/anime`) directly — no signing needed, the relay is an
  /// unauthenticated third party.
  Future<void> _testRelay() async {
    final l10n = AppLocalizations.of(context);
    final url = _relayUrlController.text.trim();
    if (url.isEmpty) {
      ref.read(toastManagerProvider.notifier).showToast(
            l10n.danmuDandanRelayTestFailed,
            type: ToastType.warning,
            category: 'danmu-source-config',
          );
      return;
    }
    setState(() => _isTestingRelay = true);
    try {
      await _saveRelay();
      if (!mounted) return;
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
        final (probeOk, probeDetail) = DanmuDandanSourceDialog.parseRelayProbe(
            response.data, response.statusCode);
        reachable = probeOk;
        detail = probeDetail;
      } catch (error) {
        detail = error.toString();
      }
      if (!mounted) return;
      ref.read(toastManagerProvider.notifier).showToast(
            reachable
                ? l10n.danmuDandanRelayTestOk
                : '${l10n.danmuDandanRelayTestFailed}${detail == null ? '' : ' ($detail)'}',
            type: reachable ? ToastType.success : ToastType.failed,
            category: 'danmu-source-config',
          );
    } finally {
      if (mounted) setState(() => _isTestingRelay = false);
    }
  }
}
