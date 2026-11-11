import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/file_models.dart';
import '../../../../data/models/fly_narwhal/index.dart';
import '../../../../data/utils/fn_data_convertor.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../providers/file_providers.dart';
import '../../../../providers/providers.dart';
import '../../../../providers/thumbnail/thumbnail_scan_config_controller.dart';
import '../../../shared/app_button.dart';
import '../../../shared/dialogs/app_dialog.dart';
import '../../../shared/hover_tip.dart';
import '../../../shared/nas/nas_directory_picker_dialog.dart';
import '../../../shared/tip_box.dart';
import '../../../shared/toast.dart';
import 'cron/cron_description.dart';
import 'cron/cron_generator_dialog.dart';

/// Separator between the folder names of a multi-folder permission toast; zh
/// uses the ideographic comma, English the regular one.
String get scanDirNameSeparator {
  final language = PlatformDispatcher.instance.locale.languageCode;
  return language == 'zh' || language == 'ja' ? '、' : ', ';
}

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
  /// A manual trigger request is in flight; the button reads as "running".
  bool _scanning = false;

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
    // The controller is synchronous and the dialog's initState runs inside the
    // parent's build phase, so touching its state here would trip Riverpod's
    // "modify a provider while the widget tree is building" guard.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.clearActionError();
      unawaited(_controller.load());
    });
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

  Future<bool> _save() async {
    if (ref.read(thumbnailScanConfigControllerProvider).isSaving) return false;
    final ok = await _controller.save(
      enabled: _enabled,
      cron: _cronController.text.trim(),
      dirs: _dirs,
    );
    if (!mounted) return false;
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
    return ok;
  }

  /// Guard in front of the manual trigger: AppDialog buttons cannot render a
  /// disabled state, so the preconditions (an idle worker, at least one
  /// directory) are checked here and explained with a toast. Folder edits the
  /// user has not saved yet are put to them first, because the scan would
  /// otherwise silently use the saved list instead of the one on screen.
  Future<void> _triggerScanGuarded() async {
    final l10n = AppLocalizations.of(context);
    final state = ref.read(thumbnailScanConfigControllerProvider);
    if (state.isTriggering || _scanning) return;
    if (state.config.valueOrNull?.isBusy == true) {
      ref.read(toastManagerProvider.notifier).showToast(
            l10n.thumbnailScanDialogAlreadyRunning,
            style: ToastStyle.fluent,
            type: ToastType.warning,
            category: 'thumbnail-scan-trigger',
          );
      return;
    }
    final savedDirs = state.config.valueOrNull?.dirs;
    final scanDirs = savedDirs != null && !_sameDirs(_dirs, savedDirs)
        ? await _resolveUnsavedDirs(savedDirs)
        : (_dirs.isEmpty ? null : _dirs);
    if (!mounted) return;
    if (scanDirs == null) return;
    if (scanDirs.isEmpty) {
      ref.read(toastManagerProvider.notifier).showToast(
            l10n.thumbnailScanDialogDirsRequired,
            style: ToastStyle.fluent,
            type: ToastType.warning,
            category: 'thumbnail-scan-trigger',
          );
      return;
    }
    await _triggerScan(scanDirs);
  }

  /// Asks how to resolve unsaved folder edits before scanning: save them and
  /// scan them, scan the saved list instead (the dialog goes back to it), or
  /// stop. Null when the user walked away; an empty list when the saved config
  /// has no folders to scan.
  Future<List<String>?> _resolveUnsavedDirs(List<String> savedDirs) async {
    final l10n = AppLocalizations.of(context);
    final save = await showAppDialog<bool>(
      context: context,
      title: l10n.thumbnailScanDialogUnsavedDirsTitle,
      content: Text(l10n.thumbnailScanDialogUnsavedDirsMessage),
      primaryButtonText: l10n.thumbnailScanDialogUnsavedDirsSave,
      secondaryButtonText: l10n.thumbnailScanDialogUnsavedDirsDiscard,
      secondaryButtonType: AppDialogButtonType.danger,
      tertiaryButtonText: l10n.commonCancel,
      primaryResult: true,
      secondaryResult: false,
      constraints: const BoxConstraints(minWidth: 420, maxWidth: 460),
    );
    if (save == null || !mounted) return null;
    if (save) {
      if (!await _save() || !mounted) return null;
      return List<String>.of(_dirs);
    }
    // Discard: accept the server as the truth and show it again, then scan it.
    final latest =
        ref.read(thumbnailScanConfigControllerProvider).config.valueOrNull;
    if (latest != null) {
      setState(() {
        _dirty = false;
        _syncDraft(latest);
      });
    }
    return List<String>.of(latest?.dirs ?? savedDirs);
  }

  static bool _sameDirs(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final left = [...a]..sort();
    final right = [...b]..sort();
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }

  Future<void> _triggerScan(List<String> scanDirs) async {
    setState(() => _scanning = true);
    final bool ok;
    try {
      ok = await _controller.triggerScan(dirs: scanDirs);
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final toast = ref.read(toastManagerProvider.notifier);
    if (!ok) {
      final raw = _controller.actionErrorRaw ?? '';
      if (raw.startsWith(ThumbnailScanConfigController.scanNotFoundPrefix)) {
        // A scanned video the server cannot read is almost always its folder
        // permission; the failing file names that folder.
        final path = ThumbnailScanConfigController.scanNotFoundPath(raw);
        toast.showToast(
            _inaccessibleToastMessage([_folderOf(path)], ref.read(authorizedDirsProvider).valueOrNull),
            style: ToastStyle.fluent,
            type: ToastType.failed,
            duration: const Duration(seconds: 10),
            category: 'thumbnail-scan-inaccessible');
        return;
      }
      toast.showToast(
        _controller.actionError ?? l10n.thumbnailScanDialogTriggerFailedGeneric,
        style: ToastStyle.fluent,
        type: ToastType.failed,
        category: 'thumbnail-scan-trigger',
      );
      return;
    }
    // Follow the queued/running scan to completion.
    _ensurePolling();
    // The server reports a folder it cannot open only after the run; name it
    // with its readable form once the run has settled.
    unawaited(_warnInaccessibleDirs(scanDirs));
  }

  Future<void> _warnInaccessibleDirs(List<String> scanDirs) async {
    final deadline = DateTime.now().add(_inaccessibleCheckWindow);
    final authDirs = ref.read(authorizedDirsProvider).valueOrNull;
    // The Worker thread never writes it while this process is alive, so the
    // snapshot can only come from an earlier run: wait for the current one to
    // report a non-empty list instead of blaming stale folders.
    final inherited =
        ref.read(thumbnailScanConfigControllerProvider).config.valueOrNull
                ?.lastInaccessibleDirs ??
            const <String>[];
    final inaccessible = <String>[];
    while (true) {
      final config =
          ref.read(thumbnailScanConfigControllerProvider).config.valueOrNull;
      final reported = config?.lastInaccessibleDirs ?? const <String>[];
      if (reported.isNotEmpty && !_samePaths(reported, inherited)) {
        inaccessible.addAll(reported);
        break;
      }
      final busy = config?.isBusy ?? true;
      if (!busy || DateTime.now().isAfter(deadline)) break;
      await Future<void>.delayed(_inaccessiblePollInterval);
      if (!mounted) return;
    }
    if (inaccessible.isEmpty || !mounted) return;
    ref.read(toastManagerProvider.notifier).showToast(
          _inaccessibleToastMessage(inaccessible, authDirs),
          style: ToastStyle.fluent,
          type: ToastType.failed,
          duration: const Duration(seconds: 10),
          category: 'thumbnail-scan-inaccessible',
        );
  }

  static bool _samePaths(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final left = [...a]..sort();
    final right = [...b]..sort();
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }

  /// The permission toast naming [dirs] by the readable form the dialog lists them in.
  String _inaccessibleToastMessage(List<String> dirs, List<AuthDir>? authDirs) {
    final names = dirs
        .map((dir) => FnDataConvertor.formatFileLocation(dir, authDirs: authDirs))
        .join(scanDirNameSeparator);
    return AppLocalizations.of(context).thumbnailScanDialogDirsInaccessible(names);
  }

  /// Folder of a file path: the part before its last segment.
  static String _folderOf(String path) {
    final cut = path.lastIndexOf('/');
    return path.startsWith('/') && cut > 0 ? path.substring(0, cut) : path;
  }

  static const Duration _inaccessibleCheckWindow = Duration(seconds: 90);
  static const Duration _inaccessiblePollInterval = Duration(seconds: 3);

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

    return AppDialog<void>(
      constraints: const BoxConstraints(
        minWidth: 648,
        maxWidth: 648,
        maxHeight: 720,
      ),
      title: l10n.thumbnailScanDialogTitle,
      // 确定 saves and closes; 立即扫描 stays open to follow the scan.
      autoDismiss: true,
      onClose: () {},
      primaryButtonText: l10n.commonConfirm,
      onPrimaryPressed: _save,
      secondaryButtonText: l10n.commonCancel,
      onSecondaryPressed: () {},
      tertiaryButtonText: l10n.thumbnailScanDialogScanNow,
      tertiaryButtonType: _scanning || config?.isBusy == true
          ? AppDialogButtonType.danger
          : AppDialogButtonType.primary,
      onTertiaryPressed: _triggerScanGuarded,
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
    // The stored value stays the raw absolute path; only the display is
    // converted to the readable form the movie detail "文件信息" panel uses.
    final authDirs = ref.watch(authorizedDirsProvider).valueOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l10n.thumbnailScanDialogDirsLabel,
                style: theme.typography.bodyStrong),
            const SizedBox(width: 6),
            HoverTip(tipText: l10n.settingsThumbnailScanPermHint),
            const Spacer(),
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
                final displayPath = FnDataConvertor.formatFileLocation(
                  dir,
                  authDirs: authDirs,
                );
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: TipBox(
                    // Hovering a row reveals the full readable path above the
                    // row; the row itself shows the width-fitted form.
                    message: displayPath,
                    maxWidth: 320,
                    child: Row(
                      children: [
                        Image.asset('assets/images/folder.png',
                            width: 16, height: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final style = theme.typography.caption;
                              // Drop parent segments only as far as the row's
                              // actual width requires — and end-ellipsize the
                              // innermost name instead of hiding it.
                              final text =
                                  _fitPath(displayPath, constraints.maxWidth, style);
                              return Text(
                                text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: style,
                              );
                            },
                          ),
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

  /// Fits [path] into [maxWidth] as far as the available space allows: the
  /// full path is kept when it fits, otherwise parent segments are replaced by
  /// a leading `…/` one at a time (deepest first, so the innermost directory
  /// always survives) until the shortened form fits. When even the innermost
  /// name alone is too wide, its middle is ellipsized while head and tail —
  /// the readable parts — are kept.
  static String _fitPath(String path, double maxWidth, TextStyle? style) {
    final painter = TextPainter(
      maxLines: 1,
      textDirection: TextDirection.ltr,
    );
    bool fits(String candidate) {
      painter.text = TextSpan(text: candidate, style: style);
      painter.layout(maxWidth: maxWidth);
      final result = !painter.didExceedMaxLines &&
          painter.width <= maxWidth;
      return result;
    }

    if (fits(path)) return path;
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    final prefix = path.startsWith('/') ? '/…/' : '…/';
    // Hide parents from the root side, keeping the last two segments first,
    // then the last one only — the deepest name is never removed.
    String candidate;
    for (var keep = segments.length - 1; keep >= 1; keep--) {
      candidate = '$prefix${segments.sublist(segments.length - keep).join('/')}';
      if (fits(candidate)) return candidate;
    }
    // Even `/…/<innermost>` alone does not fit: middle-ellipsize the innermost
    // name, keeping a head and a tail of it, so both the release tag and the
    // title end stay readable instead of losing everything but the start.
    final name = segments.isEmpty ? path : segments.last;
    final namePrefix = segments.length > 1 ? prefix : '';
    for (var visible = name.length - 1; visible >= 8; visible--) {
      final headLen = (visible * 2 ~/ 5).clamp(1, visible - 1);
      final candidate =
          '$namePrefix${name.substring(0, headLen)}…${name.substring(name.length - (visible - headLen))}';
      if (fits(candidate)) return candidate;
    }
    return name; // let the Text ellipsize its end as the last resort
  }

  static String _formatDateTime(DateTime time) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)} '
        '${two(time.hour)}:${two(time.minute)}';
  }
}
