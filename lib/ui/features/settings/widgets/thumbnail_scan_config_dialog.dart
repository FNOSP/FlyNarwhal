import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/fly_narwhal/index.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../providers/providers.dart';
import '../../../../providers/thumbnail/thumbnail_scan_config_controller.dart';
import '../../../shared/app_button.dart';
import '../../../shared/nas/nas_directory_picker_dialog.dart';
import '../../../shared/toast.dart';
import 'cron/cron_description.dart';
import 'cron/cron_generator_dialog.dart';

/// Configuration dialog of the scheduled thumbnail scan (server >= 2.1.0):
/// enable switch, cron schedule (hand-typed or built by the generator),
/// multi-select NAS scan directories, live scan state and a manual trigger.
class ThumbnailScanConfigDialog extends ConsumerStatefulWidget {
  const ThumbnailScanConfigDialog({super.key});

  @override
  ConsumerState<ThumbnailScanConfigDialog> createState() =>
      _ThumbnailScanConfigDialogState();
}

class _ThumbnailScanConfigDialogState
    extends ConsumerState<ThumbnailScanConfigDialog> {
  final TextEditingController _cronController = TextEditingController();

  bool _enabled = false;
  List<String> _dirs = const [];
  bool _draftInitialized = false;
  bool _dirty = false;

  Timer? _pollTimer;
  Timer? _cronDebounce;
  CronPreviewResult? _cronPreview;
  bool _cronChecking = false;
  String _cronCheckedText = '';

  ThumbnailScanConfigController get _controller =>
      ref.read(thumbnailScanConfigControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    _controller.clearActionError();
    unawaited(_controller.load());
    _cronController.addListener(_onCronTextChanged);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cronDebounce?.cancel();
    _cronController.removeListener(_onCronTextChanged);
    _cronController.dispose();
    super.dispose();
  }

  void _onCronTextChanged() {
    setState(() => _dirty = true);
    _cronDebounce?.cancel();
    final text = _cronController.text.trim();
    if (text.isEmpty) {
      _cronPreview = null;
      _cronCheckedText = '';
      _cronChecking = false;
      return;
    }
    _cronChecking = true;
    _cronDebounce = Timer(const Duration(milliseconds: 500), () async {
      final result = await _controller.previewCron(text);
      if (!mounted) return;
      setState(() {
        _cronChecking = false;
        _cronCheckedText = text;
        _cronPreview = result;
      });
    });
  }

  /// Adopt a freshly loaded snapshot into the draft unless the user has
  /// unsaved edits.
  void _syncDraft(ThumbnailScanConfig config) {
    if (_dirty) return;
    _enabled = config.enabled;
    _dirs = List<String>.of(config.dirs);
    if (_cronController.text != config.cron) {
      // Programmatic set: keep the dirty flag off.
      _cronController.removeListener(_onCronTextChanged);
      _cronController.text = config.cron;
      _cronController.addListener(_onCronTextChanged);
    }
    _draftInitialized = true;
  }

  Future<void> _save() async {
    final ok = await _controller.save(
      enabled: _enabled,
      cron: _cronController.text.trim(),
      dirs: _dirs,
    );
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    if (ok) {
      setState(() => _dirty = false);
      ref.read(toastManagerProvider.notifier).showToast(
            l10n.thumbnailScanDialogSaved,
            style: ToastStyle.fluent,
            type: ToastType.success,
            category: 'thumbnail-scan-save',
          );
    } else {
      ref.read(toastManagerProvider.notifier).showToast(
            _controller.actionError ?? l10n.thumbnailScanDialogSaveFailedGeneric,
            style: ToastStyle.fluent,
            type: ToastType.failed,
            category: 'thumbnail-scan-save',
          );
    }
  }

  Future<void> _triggerScan() async {
    final ok = await _controller.triggerScan();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    if (!ok) {
      ref.read(toastManagerProvider.notifier).showToast(
            _controller.actionError ??
                l10n.thumbnailScanDialogTriggerFailedGeneric,
            style: ToastStyle.fluent,
            type: ToastType.failed,
            category: 'thumbnail-scan-trigger',
          );
      return;
    }
    // Follow the queued/running scan to completion.
    _ensurePolling();
  }

  Future<void> _pickDirs() async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => NasDirectoryPickerDialog(
        initialSelection: _dirs.toSet(),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _dirs = result;
      _dirty = true;
    });
  }

  Future<void> _openGenerator() async {
    final expression = await showDialog<String>(
      context: context,
      builder: (_) =>
          CronGeneratorDialog(initialExpression: _cronController.text.trim()),
    );
    if (expression == null || !mounted) return;
    _cronController.text = expression; // listener marks dirty + previews
  }

  void _ensurePolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      await _controller.load();
      final config = ref.read(thumbnailScanConfigControllerProvider).config.valueOrNull;
      if (config != null && !config.isBusy) {
        _pollTimer?.cancel();
        _pollTimer = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controllerState = ref.watch(thumbnailScanConfigControllerProvider);
    final config = controllerState.config.valueOrNull;

    // Sync draft + polling from every fresh snapshot.
    if (config != null && !_draftInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _syncDraft(config));
      });
    } else if (config != null && !_dirty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncDraft(config);
      });
    }
    if (config?.isBusy == true && _pollTimer == null) {
      _ensurePolling();
    } else if (config?.isBusy == false && _pollTimer != null) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }

    final theme = FluentTheme.of(context);
    final cronText = _cronController.text.trim();
    final effectiveCron = (config != null && config.cron == cronText)
        ? config
        : null; // reuse the server snapshot only when the text matches

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
      title: Row(
        children: [
          Expanded(child: Text(l10n.thumbnailScanDialogTitle)),
          Tooltip(
            message: l10n.thumbnailScanDialogClose,
            child: IconButton(
              icon: const Icon(FluentIcons.chrome_close, size: 14),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        child: controllerState.config.isLoading && config == null
            ? const SizedBox(
                height: 240,
                child: Center(child: ProgressRing()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildEnableRow(l10n),
                    const SizedBox(height: 14),
                    _buildCronSection(l10n, theme, effectiveCron),
                    const SizedBox(height: 14),
                    _buildDirsSection(l10n, theme),
                    const SizedBox(height: 14),
                    _buildStatusCard(l10n, theme, config),
                    if (controllerState.loadError != null && config == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          controllerState.loadError!,
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        Align(
          alignment: Alignment.centerRight,
          widthFactor: 1.0,
          child: FilledButton(
            key: const ValueKey('thumbnail-scan-save'),
            onPressed: controllerState.isSaving ? null : _save,
            child: controllerState.isSaving
                ? const SizedBox(
                    width: 14, height: 14, child: ProgressRing(strokeWidth: 2))
                : Text(l10n.thumbnailScanDialogSave),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          widthFactor: 1.0,
          child: Tooltip(
            message: _dirty
                ? l10n.thumbnailScanDialogSaveFirst
                : l10n.thumbnailScanDialogScanNowTip,
            child: Button(
              key: const ValueKey('thumbnail-scan-trigger'),
              onPressed: (_dirty || controllerState.isTriggering || _dirs.isEmpty)
                  ? null
                  : _triggerScan,
              child: controllerState.isTriggering
                  ? const SizedBox(
                      width: 14, height: 14, child: ProgressRing(strokeWidth: 2))
                  : Text(l10n.thumbnailScanDialogScanNow),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEnableRow(AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.thumbnailScanDialogEnable,
                  style: FluentTheme.of(context).typography.bodyStrong),
              Text(
                l10n.thumbnailScanDialogEnableCaption,
                style: FluentTheme.of(context).typography.caption?.copyWith(
                      color: FluentTheme.of(context).inactiveColor,
                    ),
              ),
            ],
          ),
        ),
        ToggleSwitch(
          key: const ValueKey('thumbnail-scan-enabled'),
          checked: _enabled,
          onChanged: (value) => setState(() {
            _enabled = value;
            _dirty = true;
          }),
        ),
      ],
    );
  }

  Widget _buildCronSection(AppLocalizations l10n, FluentThemeData theme,
      ThumbnailScanConfig? serverSnapshot) {
    final cronText = _cronController.text.trim();
    final preview = (_cronCheckedText == cronText) ? _cronPreview : null;
    final description = cronText.isEmpty ? null : describeCron(cronText, l10n);
    final nextRun = (serverSnapshot != null && serverSnapshot.enabled)
        ? serverSnapshot.nextRunTime
        : (preview?.valid == true && preview!.nextRuns.isNotEmpty
            ? preview.nextRuns.first
            : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.thumbnailScanDialogCronLabel,
            style: theme.typography.bodyStrong),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextBox(
                key: const ValueKey('thumbnail-scan-cron-input'),
                controller: _cronController,
                placeholder: '0 0 3 * * ?',
                enabled: _enabled,
              ),
            ),
            const SizedBox(width: 8),
            AppButton(
              key: const ValueKey('thumbnail-scan-cron-generate'),
              onPressed: _enabled ? _openGenerator : null,
              child: Text(l10n.thumbnailScanDialogCronGenerate),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (cronText.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (_cronChecking && preview == null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                        width: 12, height: 12, child: ProgressRing(strokeWidth: 2)),
                    const SizedBox(width: 6),
                    Text(l10n.thumbnailScanDialogCronChecking,
                        style: theme.typography.caption),
                  ],
                )
              else if (preview != null && !preview.valid)
                Text(
                  l10n.thumbnailScanDialogCronInvalid(
                      preview.error ?? l10n.cronGeneratorInvalid),
                  style: theme.typography.caption
                      ?.copyWith(color: Colors.red),
                )
              else if (preview != null && preview.valid)
                Text(
                  description ?? l10n.thumbnailScanDialogCronCustom,
                  style: theme.typography.caption?.copyWith(
                        color: Colors.green,
                      ),
                ),
              if (nextRun != null)
                Text(
                  l10n.thumbnailScanDialogCronNextRun(_formatDateTime(nextRun)),
                  style: theme.typography.caption?.copyWith(
                        color: theme.inactiveColor,
                      ),
                ),
            ],
          ),
        if (preview?.valid == true && preview!.nextRuns.length > 1) ...[
          const SizedBox(height: 6),
          Expander(
            header: Text(l10n.cronGeneratorNextRuns(preview.nextRuns.length),
                style: theme.typography.caption),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final run in preview.nextRuns)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(_formatDateTime(run),
                        style: theme.typography.caption),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDirsSection(AppLocalizations l10n, FluentThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(l10n.thumbnailScanDialogDirsLabel,
                  style: theme.typography.bodyStrong),
            ),
            AppButton(
              key: const ValueKey('thumbnail-scan-dirs-pick'),
              onPressed: _enabled ? _pickDirs : null,
              child: Text(l10n.thumbnailScanDialogDirsPick),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (_dirs.isEmpty)
          Text(
            l10n.thumbnailScanDialogDirsEmpty,
            style: theme.typography.caption
                ?.copyWith(color: theme.inactiveColor),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 132),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _dirs.length,
              itemBuilder: (context, index) {
                final dir = _dirs[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Icon(FluentIcons.folder, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(dir,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typography.caption),
                      ),
                      if (_enabled)
                        IconButton(
                          key: ValueKey('thumbnail-scan-dir-remove-$index'),
                          icon: const Icon(FluentIcons.chrome_close, size: 10),
                          onPressed: () => setState(() {
                            _dirs = [..._dirs]..removeAt(index);
                            _dirty = true;
                          }),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildStatusCard(AppLocalizations l10n, FluentThemeData theme,
      ThumbnailScanConfig? config) {
    if (config == null) return const SizedBox.shrink();
    Widget content;
    switch (config.scanState) {
      case ThumbnailScanState.running:
        content = Row(
          children: [
            const SizedBox(
                width: 16, height: 16, child: ProgressRing(strokeWidth: 2.5)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.thumbnailScanDialogStatusRunning(
                  config.currentDir ?? '',
                  config.scannedFiles ?? 0,
                ),
                style: theme.typography.caption,
              ),
            ),
          ],
        );
      case ThumbnailScanState.queued:
        content = Text(l10n.thumbnailScanDialogStatusQueued,
            style: theme.typography.caption);
      case ThumbnailScanState.idle:
        content = _buildLastRunInfo(l10n, theme, config);
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0x0DFFFFFF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0x1AFDFDFD)),
      ),
      child: content,
    );
  }

  Widget _buildLastRunInfo(AppLocalizations l10n, FluentThemeData theme,
      ThumbnailScanConfig config) {
    if (config.lastStatus == ThumbnailScanConfig.lastStatusNever ||
        config.lastRunTime == null) {
      return Text(l10n.thumbnailScanDialogStatusNever,
          style:
              theme.typography.caption?.copyWith(color: theme.inactiveColor));
    }
    final time = _formatDateTime(config.lastRunTime!);
    if (config.lastStatus == ThumbnailScanConfig.lastStatusFailed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.thumbnailScanDialogStatusLastFailed(time),
              style: theme.typography.caption
                  ?.copyWith(color: Colors.red)),
          if (config.lastError != null && config.lastError!.isNotEmpty)
            SelectableText(config.lastError!,
                style: theme.typography.caption
                    ?.copyWith(color: Colors.red)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.thumbnailScanDialogStatusLastOk(
            time,
            config.lastScannedCount,
            config.lastQueuedCount,
          ),
          style: theme.typography.caption,
        ),
        if (config.lastError != null && config.lastError!.isNotEmpty)
          Text(config.lastError!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.caption
                  ?.copyWith(color: theme.inactiveColor)),
      ],
    );
  }

  static String _formatDateTime(DateTime time) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)} '
        '${two(time.hour)}:${two(time.minute)}';
  }
}
