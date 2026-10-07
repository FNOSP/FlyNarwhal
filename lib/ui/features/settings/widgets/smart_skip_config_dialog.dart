import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/fly_narwhal/index.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../providers/providers.dart';
import '../../../shared/dialogs/app_dialog.dart';
import '../../../shared/toast.dart';

/// Server-side smart skip analysis configuration dialog (per-user, stored on
/// the fly-narwhal server). Opened from the 「服务器」 section of the settings
/// page; the server is the single source of truth for these values.
class SmartSkipConfigDialog extends ConsumerStatefulWidget {
  const SmartSkipConfigDialog({super.key});

  @override
  ConsumerState<SmartSkipConfigDialog> createState() =>
      _SmartSkipConfigDialogState();
}

class _SmartSkipConfigDialogState extends ConsumerState<SmartSkipConfigDialog> {
  @override
  void initState() {
    super.initState();
    _loadIfNeeded();
  }

  void _loadIfNeeded() {
    final userGuid = ref.read(currentUserGuidProvider);
    if (userGuid == null || userGuid.isEmpty) return;
    ref.read(smartSkipConfigControllerProvider.notifier).load(userGuid);
  }

  void _update(SmartSkipConfig config) {
    ref.read(smartSkipConfigControllerProvider.notifier).update(config);
  }

  Future<void> _saveAndClose() async {
    final l10n = AppLocalizations.of(context);
    final userGuid = ref.read(currentUserGuidProvider);
    if (userGuid == null || userGuid.isEmpty) return;
    final ok = await ref
        .read(smartSkipConfigControllerProvider.notifier)
        .save(userGuid);
    if (!mounted) return;
    final saveError = ref.read(smartSkipConfigControllerProvider).saveError;
    ref.read(toastManagerProvider.notifier).showToast(
          ok ? l10n.smartSkipSaved : (saveError ?? l10n.smartSkipSaveFailed),
          type: ok ? ToastType.success : ToastType.failed,
          category: 'smart-skip-config-save',
        );
    if (ok) {
      Navigator.of(context).pop();
    }
  }

  void _resetToDefaults() {
    _update(const SmartSkipConfig());
  }

  void _cancel() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final userGuid = ref.watch(currentUserGuidProvider);
    final state = ref.watch(smartSkipConfigControllerProvider);
    final config = state.config.valueOrNull ?? const SmartSkipConfig();
    final loggedIn = userGuid != null && userGuid.isNotEmpty;
    final editable = loggedIn && state.loadError == null;

    return AppDialog(
      title: l10n.smartSkipConfigTitle,
      constraints: const BoxConstraints(
        minWidth: 520,
        maxWidth: 560,
        maxHeight: 520,
      ),
      primaryButtonText: loggedIn ? l10n.commonConfirm : null,
      onPrimaryPressed: loggedIn ? _saveAndClose : null,
      secondaryButtonText: l10n.commonCancel,
      onSecondaryPressed: _cancel,
      tertiaryButtonText: loggedIn ? l10n.smartSkipRestoreDefaults : null,
      onTertiaryPressed: loggedIn ? _resetToDefaults : null,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          if (!loggedIn)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(l10n.smartSkipLoginRequired),
            )
          else if (state.loadError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(l10n.smartSkipLoadFailed),
            ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(right: 12),
              children: [
                _sectionLabel(l10n.smartSkipDetectMode),
                _toggleRow(
                  l10n.smartSkipDetectIntro,
                  checked: config.scanIntroduction,
                  editable: editable,
                  onChanged: (value) =>
                      _update(config.copyWith(scanIntroduction: value)),
                ),
                _toggleRow(
                  l10n.smartSkipDetectOutro,
                  checked: config.scanCredits,
                  editable: editable,
                  onChanged: (value) =>
                      _update(config.copyWith(scanCredits: value)),
                ),
                _toggleRow(
                  l10n.smartSkipDetectRecap,
                  checked: config.scanRecap,
                  editable: editable,
                  onChanged: (value) =>
                      _update(config.copyWith(scanRecap: value)),
                ),
                _toggleRow(
                  l10n.smartSkipDetectPreview,
                  checked: config.scanPreview,
                  editable: editable,
                  onChanged: (value) =>
                      _update(config.copyWith(scanPreview: value)),
                ),
                _toggleRow(
                  l10n.smartSkipDetectCommercial,
                  checked: config.scanCommercial,
                  editable: editable,
                  onChanged: (value) =>
                      _update(config.copyWith(scanCommercial: value)),
                ),
                const SizedBox(height: 4),
                const Divider(),
                const SizedBox(height: 8),
                _sectionLabel(l10n.smartSkipDurationLimit),
                _numberRow(
                  l10n.smartSkipIntroMinDuration,
                  config.minimumIntroDuration,
                  editable: editable,
                  onChanged: (value) =>
                      _update(config.copyWith(minimumIntroDuration: value)),
                ),
                _numberRow(
                  l10n.smartSkipIntroMaxDuration,
                  config.maximumIntroDuration,
                  editable: editable,
                  onChanged: (value) =>
                      _update(config.copyWith(maximumIntroDuration: value)),
                ),
                _numberRow(
                  l10n.smartSkipOutroMinDuration,
                  config.minimumCreditsDuration,
                  editable: editable,
                  onChanged: (value) =>
                      _update(config.copyWith(minimumCreditsDuration: value)),
                ),
                _numberRow(
                  l10n.smartSkipOutroMaxDuration,
                  config.maximumCreditsDuration,
                  editable: editable,
                  onChanged: (value) =>
                      _update(config.copyWith(maximumCreditsDuration: value)),
                ),
                const SizedBox(height: 4),
                const Divider(),
                const SizedBox(height: 8),
                _sectionLabel(l10n.smartSkipBoundaryOffset),
                _numberRow(
                  l10n.smartSkipIntroStartOffset,
                  config.introStartOffset,
                  editable: editable,
                  step: 1,
                  min: -60,
                  max: 60,
                  onChanged: (value) =>
                      _update(config.copyWith(introStartOffset: value)),
                ),
                _numberRow(
                  l10n.smartSkipIntroEndOffset,
                  config.introEndOffset,
                  editable: editable,
                  step: 1,
                  min: -60,
                  max: 60,
                  onChanged: (value) =>
                      _update(config.copyWith(introEndOffset: value)),
                ),
                _numberRow(
                  l10n.smartSkipOutroEndOffset,
                  config.creditsEndOffset,
                  editable: editable,
                  step: 1,
                  min: -60,
                  max: 60,
                  onChanged: (value) =>
                      _update(config.copyWith(creditsEndOffset: value)),
                ),
                const SizedBox(height: 4),
                const Divider(),
                const SizedBox(height: 8),
                _sectionLabel(l10n.smartSkipAdvanced),
                _toggleRow(
                  l10n.smartSkipPreferChromaprint,
                  checked: config.preferChromaprint,
                  editable: editable,
                  onChanged: (value) =>
                      _update(config.copyWith(preferChromaprint: value)),
                ),
                _toggleRow(
                  l10n.smartSkipAlternativeBlackFrame,
                  checked: config.useAlternativeBlackFrameAnalyzer,
                  editable: editable,
                  onChanged: (value) => _update(
                    config.copyWith(useAlternativeBlackFrameAnalyzer: value),
                  ),
                ),
                _toggleRow(
                  l10n.smartSkipAnimeMode,
                  checked: config.animeDetection,
                  editable: editable,
                  onChanged: (value) =>
                      _update(config.copyWith(animeDetection: value)),
                ),
                if (state.saveError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      state.saveError!,
                      style: const TextStyle(
                        color: Color(0xFFE0484D),
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    final theme = FluentTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text, style: theme.typography.bodyStrong),
    );
  }

  Widget _toggleRow(
    String title, {
    required bool checked,
    required bool editable,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(title)),
          ToggleSwitch(
            checked: checked,
            onChanged: editable ? onChanged : null,
          ),
        ],
      ),
    );
  }

  Widget _numberRow(
    String label,
    int value, {
    required bool editable,
    required ValueChanged<int> onChanged,
    int step = 5,
    int min = 0,
    int max = 3600,
  }) {
    final theme = FluentTheme.of(context);
    final textColor = editable
        ? theme.resources.textFillColorPrimary
        : theme.resources.textFillColorDisabled;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.typography.body?.copyWith(color: textColor),
            ),
          ),
          _stepButton(
            icon: FluentIcons.remove,
            enabled: editable && value > min,
            onTap: () => onChanged((value - step).clamp(min, max)),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: theme.typography.body?.copyWith(color: textColor),
            ),
          ),
          const SizedBox(width: 8),
          _stepButton(
            icon: FluentIcons.add,
            enabled: editable && value < max,
            onTap: () => onChanged((value + step).clamp(min, max)),
          ),
        ],
      ),
    );
  }

  Widget _stepButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final theme = FluentTheme.of(context);
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled
                ? theme.resources.controlFillColorDefault
                : theme.resources.controlFillColorDisabled,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: theme.resources.controlStrokeColorDefault,
            ),
          ),
          child: Icon(
            icon,
            size: 12,
            color: enabled
                ? theme.resources.textFillColorPrimary
                : theme.resources.textFillColorDisabled,
          ),
        ),
      ),
    );
  }
}
