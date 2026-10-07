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
/// Edits are held in a local draft and only reach the server when the dialog's
/// Save button is pressed; Cancel (and the barrier) leave the stored config
/// untouched.
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

  /// Local copies of the two rows, seeded from the server config once it
  /// loads. Switches and fields edit these; only Save writes them back.
  DandanAccount _draftAccount = const DandanAccount();
  DanmuDandanConfig _draftRelay = const DanmuDandanConfig();

  bool _secretVisible = false;
  bool _isTestingOfficial = false;
  bool _isTestingRelay = false;
  bool _draftSynced = false;

  /// Guards against a second save landing while one is in flight.
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
      if (!mounted) return;
      // The controller only clears actionError when the next mutation starts,
      // so an error from a previous visit would otherwise reappear on entry.
      ref.read(danmuSourceConfigControllerProvider.notifier).clearActionError();
      ref.read(danmuSourceConfigControllerProvider.notifier).load();
    });
  }

  /// Surfaces a failed save as a toast. Errors used to be rendered inline
  /// below the cards, which read as a broken row rather than a rejected input.
  void _showActionError() {
    final message =
        ref.read(danmuSourceConfigControllerProvider.notifier).actionError;
    if (message == null || message.isEmpty) return;
    ref.read(toastManagerProvider.notifier).showToast(
          message,
          type: ToastType.failed,
          category: 'danmu-source-config',
        );
  }

  @override
  void dispose() {
    _appIdController.dispose();
    _appSecretController.dispose();
    _relayUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(danmuSourceConfigControllerProvider);
    final config = state.config.valueOrNull;
    if (config != null && !_draftSynced) {
      // The text fields have listeners (and this runs during build), so fill
      // them after the frame rather than mutating controllers mid-build.
      _draftSynced = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _draftAccount = config.dandanAccount;
        _draftRelay = config.dandan;
        _appIdController.text = config.dandanAccount.appId;
        _appSecretController.text = config.dandanAccount.appSecret;
        _relayUrlController.text = config.dandan.url;
      });
    }
    final account = _draftAccount;
    final relay = _draftRelay;

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
                  ],
                ),
              ),
      ),
      primaryButtonText: l10n.commonConfirm,
      onPrimaryPressed: _save,
      secondaryButtonText: l10n.commonCancel,
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
      onEnabledChanged: (value) => setState(
          () => _draftAccount = _draftAccount.copyWith(enabled: value)),
      onPreferredChanged: (value) =>
          _setDraftPreferred(officialPreferred: value),
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
          ),
          const SizedBox(height: 8),
          TextBox(
            key: const ValueKey('settings-danmu-official-secret'),
            controller: _appSecretController,
            placeholder: l10n.danmuDandanOfficialAppSecretHint,
            placeholderStyle: TextStyle(color: Colors.grey[130]),
            obscureText: !_secretVisible,
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
      onEnabledChanged: (value) =>
          setState(() => _draftRelay = _draftRelay.copyWith(enabled: value)),
      onPreferredChanged: (value) =>
          _setDraftPreferred(officialPreferred: !value),
      test: AppButton(
        key: const ValueKey('settings-danmu-relay-test'),
        onPressed: (_isTestingRelay || !relay.enabled) ? null : _testRelay,
        child: Text(
            _isTestingRelay ? l10n.danmuDandanTesting : l10n.danmuDandanTest),
      ),
      fields: TextBox(
        key: const ValueKey('settings-danmu-relay-url'),
        controller: _relayUrlController,
        placeholder: l10n.danmuDandanRelayUrlHint,
        placeholderStyle: TextStyle(color: Colors.grey[130]),
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

  /// Moves the "preferred" switch in the draft: whichever row the user picks
  /// takes priority 0 and the other 1, mirroring the server-side pair write.
  void _setDraftPreferred({required bool officialPreferred}) {
    setState(() {
      _draftAccount =
          _draftAccount.copyWith(priority: officialPreferred ? 0 : 1);
      _draftRelay = _draftRelay.copyWith(priority: officialPreferred ? 1 : 0);
    });
  }

  /// Applies the draft to the server: the two rows first (each keeping the
  /// stored priority), then the preference pair when it moved. On success the
  /// dialog closes; on failure it stays open with the controller's inline
  /// [DanmuSourceConfigState.actionError].
  Future<void> _save() async {
    if (_saveInFlight || !_draftSynced) return;
    _saveInFlight = true;
    try {
      final l10n = AppLocalizations.of(context);
      final notifier =
          ref.read(danmuSourceConfigControllerProvider.notifier);
      final server =
          ref.read(danmuSourceConfigControllerProvider).config.valueOrNull;
      final serverAccount = server?.dandanAccount ?? const DandanAccount();
      final serverRelay = server?.dandan ?? const DanmuDandanConfig();

      final accountCandidate = _draftAccount.copyWith(
        appId: _appIdController.text.trim(),
        appSecret: _appSecretController.text.trim(),
      );
      final relayCandidate = _draftRelay.copyWith(
        url: _relayUrlController.text.trim(),
      );

      var changed = false;
      if (accountCandidate.appId != serverAccount.appId ||
          accountCandidate.appSecret != serverAccount.appSecret ||
          accountCandidate.enabled != serverAccount.enabled) {
        if (!await notifier.saveDandanAccount(accountCandidate
            .copyWith(priority: serverAccount.priority))) {
          if (mounted) _showActionError();
          return;
        }
        changed = true;
      }
      if (relayCandidate.url != serverRelay.url ||
          relayCandidate.enabled != serverRelay.enabled) {
        if (!await notifier
            .saveDandanRelay(relayCandidate.copyWith(priority: serverRelay.priority))) {
          if (mounted) _showActionError();
          return;
        }
        changed = true;
      }
      if (_draftAccount.priority != serverAccount.priority ||
          _draftRelay.priority != serverRelay.priority) {
        if (!await notifier.setPreferredDandanSource(
            officialPreferred: _draftAccount.priority == 0)) {
          if (mounted) _showActionError();
          return;
        }
        changed = true;
      }

      if (!mounted) return;
      if (changed) {
        ref.read(toastManagerProvider.notifier).showToast(
              l10n.danmuSourceSaved,
              type: ToastType.success,
              category: 'danmu-source-config',
            );
      }
      Navigator.of(context).pop();
    } finally {
      _saveInFlight = false;
    }
  }

  /// Probes the official open API with the credentials currently typed in —
  /// testing never saves anything.
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
      if (account.appId.isEmpty) {
        ref.read(toastManagerProvider.notifier).showToast(
              l10n.danmuSourceAppIdRequired,
              type: ToastType.warning,
              category: 'danmu-source-config',
            );
        return;
      }
      if (account.appSecret.isEmpty) {
        ref.read(toastManagerProvider.notifier).showToast(
              l10n.danmuSourceAppSecretRequired,
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

  /// Probes the relay's public search endpoint (`?path=/v2/search/anime`)
  /// with the address currently typed in — no signing needed, the relay is an
  /// unauthenticated third party, and testing never saves anything.
  Future<void> _testRelay() async {
    final l10n = AppLocalizations.of(context);
    final url = _relayUrlController.text.trim();
    if (url.isEmpty) {
      ref.read(toastManagerProvider.notifier).showToast(
            l10n.danmuSourceRelayRequired,
            type: ToastType.warning,
            category: 'danmu-source-config',
          );
      return;
    }
    setState(() => _isTestingRelay = true);
    try {
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
