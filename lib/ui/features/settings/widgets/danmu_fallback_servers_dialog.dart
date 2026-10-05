import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/fly_narwhal/index.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../providers/danmu_source_config_controller.dart';
import '../../../../providers/providers.dart';
import '../../../shared/dialogs/app_dialog.dart';
import '../../../shared/toast.dart';

/// Management dialog for the third-party fallback danmu servers stored on the
/// fly-narwhal server: list with per-row enable toggle, add/edit via a
/// sub-dialog, delete behind a danger confirmation. The server is the single
/// source of truth — every mutation goes through [DanmuSourceConfigController]
/// and the list reloads afterwards.
class DanmuFallbackServersDialog extends ConsumerStatefulWidget {
  const DanmuFallbackServersDialog({super.key});

  @override
  ConsumerState<DanmuFallbackServersDialog> createState() =>
      _DanmuFallbackServersDialogState();
}

class _DanmuFallbackServersDialogState
    extends ConsumerState<DanmuFallbackServersDialog> {
  @override
  void initState() {
    super.initState();
    // load() flips the provider state on its first line; doing that
    // synchronously in initState throws Riverpod's "modify a provider while
    // the widget tree is building" because the settings screen is already
    // watching this controller. Defer to after the frame, the same pattern the
    // settings screen uses for its initial load.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(danmuSourceConfigControllerProvider.notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(danmuSourceConfigControllerProvider);
    final servers = state.config.valueOrNull?.fallbackServers ?? const [];

    return AppDialog(
      title: l10n.danmuSourceFallbackDialogTitle,
      constraints: const BoxConstraints(
        minWidth: 520,
        maxWidth: 560,
        maxHeight: 520,
      ),
      content: SizedBox(
        width: 520,
        child: state.config is AsyncLoading && servers.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: ProgressRing()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.loadError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(state.loadError!),
                    ),
                  if (servers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          l10n.danmuSourceFallbackEmpty,
                          key: const ValueKey('settings-danmu-fallback-empty'),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ScrollbarTheme.merge(
                        data: const ScrollbarThemeData(
                          crossAxisMargin: -24,
                          hoveringCrossAxisMargin: -24,
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.only(right: 12),
                          itemCount: servers.length,
                          itemBuilder: (context, index) =>
                              _serverRow(l10n, servers[index], state.isSaving),
                        ),
                      ),
                    ),
                  if (state.actionError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(state.actionError!),
                    ),
                ],
              ),
      ),
      primaryButtonText: l10n.settingsAboutClose,
      tertiaryButtonText: l10n.danmuSourceFallbackAdd,
      onTertiaryPressed: () => _openEditor(null),
    );
  }

  Widget _serverRow(
    AppLocalizations l10n,
    DanmuFallbackServer server,
    bool isSaving,
  ) {
    final id = server.id;
    final displayName = (server.name?.isNotEmpty ?? false)
        ? server.name!
        : server.url;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if ((server.name?.isNotEmpty ?? false))
                  Text(
                    server.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[100],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ToggleSwitch(
            key: ValueKey('settings-danmu-fallback-toggle-${id ?? server.url}'),
            checked: server.enabled,
            onChanged: isSaving || id == null
                ? null
                : (checked) => _toggle(server, checked),
            content: Text(server.enabled
                ? l10n.settingsAboutOpen
                : l10n.settingsAboutClose),
          ),
          const SizedBox(width: 4),
          IconButton(
            key: ValueKey('settings-danmu-fallback-edit-${id ?? server.url}'),
            icon: const Icon(FluentIcons.edit, size: 15),
            onPressed: isSaving ? null : () => _openEditor(server),
          ),
          IconButton(
            key: ValueKey('settings-danmu-fallback-delete-${id ?? server.url}'),
            icon: const Icon(FluentIcons.delete, size: 15),
            onPressed: isSaving || id == null
                ? null
                : () => _confirmDelete(server, id),
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(DanmuFallbackServer server, bool enabled) async {
    final l10n = AppLocalizations.of(context);
    final ok = await ref
        .read(danmuSourceConfigControllerProvider.notifier)
        .toggleFallbackServer(server, enabled);
    if (!ok) return;
    if (!mounted) return;
    ref.read(toastManagerProvider.notifier).showToast(
          l10n.danmuSourceSaved,
          type: ToastType.success,
          category: 'danmu-source-config',
        );
  }

  Future<void> _confirmDelete(DanmuFallbackServer server, int id) async {
    final l10n = AppLocalizations.of(context);
    final name = (server.name?.isNotEmpty ?? false) ? server.name! : server.url;
    final confirmed = await showAppDialog<bool>(
      context: context,
      type: AppDialogType.danger,
      title: l10n.danmuSourceFallbackDeleteTitle,
      content: Text(l10n.danmuSourceFallbackDeleteMessage(name)),
      secondaryButtonText: l10n.commonCancel,
      primaryButtonText: l10n.danmuSourceDelete,
      primaryButtonType: AppDialogButtonType.danger,
      primaryResult: true,
      secondaryResult: false,
      autoDismiss: true,
    );
    if (confirmed != true) return;
    final ok = await ref
        .read(danmuSourceConfigControllerProvider.notifier)
        .deleteFallbackServer(id);
    if (!ok || !mounted) return;
    ref.read(toastManagerProvider.notifier).showToast(
          l10n.danmuSourceDeleted,
          type: ToastType.success,
          category: 'danmu-source-config',
        );
  }

  /// Add (server == null) or edit sub-dialog with name + url fields.
  Future<void> _openEditor(DanmuFallbackServer? server) async {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController(text: server?.name ?? '');
    final urlController = TextEditingController(text: server?.url ?? '');
    // onPrimaryPressed lives outside the content builder's scope, so the
    // inline validation error travels through a notifier instead of
    // StatefulBuilder's setState.
    final urlError = ValueNotifier<bool>(false);

    final saved = await showAppDialog<bool>(
      context: context,
      title: server == null
          ? l10n.danmuSourceFallbackAdd
          : l10n.danmuSourceFallbackEdit,
      content: ValueListenableBuilder<bool>(
        valueListenable: urlError,
        builder: (context, hasUrlError, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextBox(
              key: const ValueKey('settings-danmu-fallback-name-input'),
              controller: nameController,
              placeholder: l10n.danmuSourceFallbackNameHint,
            ),
            const SizedBox(height: 12),
            TextBox(
              key: const ValueKey('settings-danmu-fallback-url-input'),
              controller: urlController,
              placeholder: 'https://dmku.hls.one',
              onChanged: (_) {
                if (urlError.value) urlError.value = false;
              },
            ),
            if (hasUrlError)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(l10n.danmuSourceUrlInvalid),
              ),
          ],
        ),
      ),
      secondaryButtonText: l10n.commonCancel,
      primaryButtonText: l10n.danmuSourceSave,
      secondaryResult: false,
      autoDismiss: false,
      onPrimaryPressed: () async {
        final url = urlController.text.trim();
        if (url.isEmpty ||
            !(url.startsWith('http://') || url.startsWith('https://'))) {
          urlError.value = true;
          return;
        }
        final candidate = DanmuFallbackServer(
          id: server?.id,
          name: nameController.text.trim().isEmpty
              ? null
              : nameController.text.trim(),
          url: url,
          enabled: server?.enabled ?? true,
        );
        final ok = await ref
            .read(danmuSourceConfigControllerProvider.notifier)
            .saveFallbackServer(candidate);
        if (!ok) return;
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pop(true);
      },
    );

    nameController.dispose();
    urlController.dispose();
    urlError.dispose();

    if (saved == true && mounted) {
      ref.read(toastManagerProvider.notifier).showToast(
            l10n.danmuSourceSaved,
            type: ToastType.success,
            category: 'danmu-source-config',
          );
    }
  }
}
