import 'dart:io' show Platform;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/storage/shortcut_settings_store.dart';
import '../../../../providers/providers.dart';
import '../../../shared/dialogs/app_dialog.dart';

class ShortcutSettingsDialog extends ConsumerStatefulWidget {
  const ShortcutSettingsDialog({super.key});

  @override
  ConsumerState<ShortcutSettingsDialog> createState() =>
      _ShortcutSettingsDialogState();
}

class _ShortcutCaptureTarget {
  final ShortcutActionId actionId;

  const _ShortcutCaptureTarget(this.actionId);
}

class _ShortcutSettingsDialogState
    extends ConsumerState<ShortcutSettingsDialog> {
  static const double _shortcutColumnWidth = 220;
  static const double _scrollbarOffset = 20;

  Map<ShortcutActionId, ShortcutBinding> _bindings = const {};
  _ShortcutCaptureTarget? _captureTarget;

  @override
  void initState() {
    super.initState();
    _reloadBindings();
  }

  void _reloadBindings() {
    _bindings = ref.read(shortcutSettingsStoreProvider).getAllBindings();
  }

  Future<void> _resetToDefaults() async {
    await ref.read(shortcutSettingsStoreProvider).resetToDefaults();
    if (!mounted) return;
    setState(() {
      _reloadBindings();
      _captureTarget = null;
    });
  }

  KeyEventResult _handleCaptureKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final target = _captureTarget;
    if (target == null) return KeyEventResult.ignored;

    final shortcutKey = ShortcutKeyBinding.fromKeyEvent(event);
    if (shortcutKey == null) return KeyEventResult.handled;

    final currentBinding = _bindings[target.actionId] ??
        ref.read(shortcutSettingsStoreProvider).getBinding(target.actionId);
    final updatedBinding = ShortcutBinding(
      primary: shortcutKey,
      secondary: currentBinding.secondary,
    );
    ref
        .read(shortcutSettingsStoreProvider)
        .setBinding(target.actionId, updatedBinding);
    setState(() {
      _bindings = Map<ShortcutActionId, ShortcutBinding>.from(_bindings)
        ..[target.actionId] = updatedBinding;
      _captureTarget = null;
    });
    return KeyEventResult.handled;
  }

  void _onConfirm() {
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: '快捷键设置',
      constraints: const BoxConstraints(
        minWidth: 520,
        maxWidth: 560,
        maxHeight: 480,
      ),
      primaryButtonText: '确定',
      onPrimaryPressed: _onConfirm,
      secondaryButtonText: '恢复默认',
      onSecondaryPressed: _resetToDefaults,
      content: Focus(
        autofocus: true,
        onKeyEvent: _handleCaptureKeyEvent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Expanded(child: Text('说明')),
                SizedBox(
                  width: _shortcutColumnWidth,
                  child: Text('快捷键'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ScrollbarTheme.merge(
                data: const ScrollbarThemeData(
                  crossAxisMargin: -_scrollbarOffset,
                  hoveringCrossAxisMargin: -_scrollbarOffset,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _buildCategorySection(ShortcutCategory.search),
                    const SizedBox(height: 12),
                    _buildCategorySection(ShortcutCategory.playback),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(ShortcutCategory category) {
    final definitions = ShortcutSettingsStore.definitions
        .where((definition) => definition.category == category)
        .toList();
    final title = switch (category) {
      ShortcutCategory.search => '搜索',
      ShortcutCategory.playback => '播放',
    };
    final theme = FluentTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: theme.typography.bodyStrong),
        const SizedBox(height: 8),
        for (final definition in definitions) _buildShortcutRow(definition),
      ],
    );
  }

  Widget _buildShortcutRow(ShortcutActionDefinition definition) {
    final theme = FluentTheme.of(context);
    final binding = _bindings[definition.id] ?? definition.defaultBinding;
    final isCapturing = _captureTarget?.actionId == definition.id;
    final borderColor = isCapturing
        ? theme.accentColor
        : theme.resources.controlStrokeColorDefault;
    final text = isCapturing
        ? '请在键盘按下快捷键或组合'
        : binding.primary.format(isMac: Platform.isMacOS);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(definition.title)),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  _captureTarget = _ShortcutCaptureTarget(definition.id);
                });
              },
              child: Container(
                key: ValueKey('shortcut-binding-${definition.id.name}'),
                width: _shortcutColumnWidth,
                height: 34,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: theme.resources.controlFillColorDefault,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.body?.copyWith(
                    color: isCapturing
                        ? theme.resources.textFillColorSecondary
                        : theme.resources.textFillColorPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
