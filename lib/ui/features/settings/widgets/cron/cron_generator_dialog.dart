import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../data/models/fly_narwhal/index.dart';
import '../../../../../l10n/generated/app_localizations.dart';
import '../../../../../providers/providers.dart';
import 'cron_generator_state.dart';

/// Quartz cron expression builder dialog, replicating the field/option layout
/// of the bejson cron generator: one tab per field (秒 分 时 日 月 周 年), each a
/// radio group of option shapes with inline numeric inputs and a
/// multi-select grid for "指定". The bottom bar previews the assembled
/// expression, validates it on the server (debounced) and lists the next fire
/// times. Pops the expression string on 确定, null on cancel.
class CronGeneratorDialog extends ConsumerStatefulWidget {
  const CronGeneratorDialog({super.key, this.initialExpression});

  /// Existing expression to reverse-fill; when it contains shapes the
  /// generator cannot represent the dialog resets to the default and says so.
  final String? initialExpression;

  @override
  ConsumerState<CronGeneratorDialog> createState() =>
      _CronGeneratorDialogState();
}

class _CronGeneratorDialogState extends ConsumerState<CronGeneratorDialog> {
  static const List<CronFieldKind> _tabs = CronFieldKind.values;

  late CronGeneratorState _state;
  CronFieldKind _tab = CronFieldKind.second;
  bool _showUnparseableNotice = false;

  Timer? _previewDebounce;
  CronPreviewResult? _preview;
  bool _previewLoading = false;
  String _previewedExpression = '';

  @override
  void initState() {
    super.initState();
    final initial = widget.initialExpression?.trim() ?? '';
    final parsed =
        initial.isEmpty ? null : CronGeneratorState.fromExpression(initial);
    _showUnparseableNotice = initial.isNotEmpty && parsed == null;
    _state = parsed ?? CronGeneratorState.dailyAt3Am();
    _schedulePreview(immediate: true);
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    super.dispose();
  }

  String get _expression => _state.buildExpression();

  void _setField(CronFieldKind kind, CronFieldState field) {
    setState(() {
      _state = _state.copyWithField(kind, field);
    });
    _schedulePreview();
  }

  void _schedulePreview({bool immediate = false}) {
    _previewDebounce?.cancel();
    final expression = _expression;
    if (expression == _previewedExpression) return;
    _previewDebounce = Timer(
      immediate
          ? const Duration(milliseconds: 60)
          : const Duration(milliseconds: 500),
      () => _runPreview(expression),
    );
  }

  Future<void> _runPreview(String expression) async {
    if (!mounted) return;
    setState(() {
      _previewLoading = true;
      _previewedExpression = expression;
    });
    final controller = ref.read(thumbnailScanConfigControllerProvider.notifier);
    final result = await controller.previewCron(expression);
    if (!mounted || _previewedExpression != expression) return;
    setState(() {
      _preview = result;
      _previewLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
      title: Row(
        children: [
          Expanded(child: Text(l10n.cronGeneratorTitle)),
          Tooltip(
            message: l10n.cronGeneratorClose,
            child: IconButton(
              icon: const Icon(FluentIcons.chrome_close, size: 14),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 680,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTabBar(l10n),
            const SizedBox(height: 8),
            if (_showUnparseableNotice)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InfoBar(
                  title: Text(l10n.cronGeneratorUnparseable),
                  severity: InfoBarSeverity.warning,
                  isIconVisible: true,
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                child: _buildFieldPanel(_tab, l10n),
              ),
            ),
            const SizedBox(height: 8),
            _buildPreviewBar(l10n),
          ],
        ),
      ),
      actions: [
        Align(
          alignment: Alignment.centerRight,
          widthFactor: 1.0,
          child: FilledButton(
            key: const ValueKey('cron-generator-confirm'),
            onPressed: () => Navigator.of(context).pop(_expression),
            child: Text(l10n.commonConfirm),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          widthFactor: 1.0,
          child: Button(
            key: const ValueKey('cron-generator-cancel'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel),
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar(AppLocalizations l10n) {
    String label(CronFieldKind kind) => switch (kind) {
          CronFieldKind.second => l10n.cronGeneratorTabSecond,
          CronFieldKind.minute => l10n.cronGeneratorTabMinute,
          CronFieldKind.hour => l10n.cronGeneratorTabHour,
          CronFieldKind.dayOfMonth => l10n.cronGeneratorTabDayOfMonth,
          CronFieldKind.month => l10n.cronGeneratorTabMonth,
          CronFieldKind.dayOfWeek => l10n.cronGeneratorTabDayOfWeek,
          CronFieldKind.year => l10n.cronGeneratorTabYear,
        };
    return Row(
      children: [
        for (final kind in _tabs) ...[
          ToggleButton(
            key: ValueKey('cron-tab-${kind.name}'),
            checked: _tab == kind,
            onChanged: (_) => setState(() => _tab = kind),
            child: Text(label(kind)),
          ),
          const SizedBox(width: 6),
        ],
      ],
    );
  }

  Widget _buildFieldPanel(CronFieldKind kind, AppLocalizations l10n) {
    final field = _state.field(kind);
    switch (kind) {
      case CronFieldKind.second:
      case CronFieldKind.minute:
        return _TimeLikePanel(
          kind: kind,
          field: field,
          l10n: l10n,
          onChanged: (f) => _setField(kind, f),
        );
      case CronFieldKind.hour:
        return _TimeLikePanel(
          kind: kind,
          field: field,
          l10n: l10n,
          amPmGroups: true,
          onChanged: (f) => _setField(kind, f),
        );
      case CronFieldKind.dayOfMonth:
        return _DayOfMonthPanel(
            field: field, l10n: l10n, onChanged: (f) => _setField(kind, f));
      case CronFieldKind.month:
        return _MonthPanel(
            field: field, l10n: l10n, onChanged: (f) => _setField(kind, f));
      case CronFieldKind.dayOfWeek:
        return _DayOfWeekPanel(
            field: field, l10n: l10n, onChanged: (f) => _setField(kind, f));
      case CronFieldKind.year:
        return _YearPanel(
            field: field, l10n: l10n, onChanged: (f) => _setField(kind, f));
    }
  }

  Widget _buildPreviewBar(AppLocalizations l10n) {
    final theme = FluentTheme.of(context);
    final matchesPreview = _previewedExpression == _expression;
    final preview = matchesPreview ? _preview : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l10n.cronGeneratorPreviewLabel,
                style: theme.typography.bodyStrong),
            const SizedBox(width: 8),
            Expanded(
              child: SelectableText(
                _expression,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
              ),
            ),
            if (_previewLoading && preview == null)
              const ProgressRing(strokeWidth: 2.5)
            else if (preview != null)
              preview.valid
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.skype_circle_check,
                            color: Colors.green, size: 16),
                        const SizedBox(width: 4),
                        Text(l10n.cronGeneratorValid,
                            style: TextStyle(color: Colors.green)),
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.error_badge,
                            color: Colors.red, size: 16),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            preview.error ?? l10n.cronGeneratorInvalid,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
          ],
        ),
        if (preview != null && preview.valid && preview.nextRuns.isNotEmpty) ...[
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
                    child: Text(_formatRunTime(run)),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static String _formatRunTime(DateTime time) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)} '
        '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }
}

// ── 共享小部件 ──────────────────────────────────────────────

/// One radio row of an option shape; the row body carries the inline inputs.
/// The radio dot itself is driven by the enclosing [RadioGroup]; taps on the
/// label/input area select the option through [onSelected].
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.value,
    required this.checked,
    required this.onSelected,
    required this.child,
  });

  final CronOptionType value;
  final bool checked;
  final VoidCallback onSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          RadioButton<CronOptionType>(
            // Only the active tab's panel is rendered, so the option name is
            // a unique key — used by driver tests to hit the radio directly
            // (the label sits under an IgnorePointer when unselected).
            key: ValueKey('cron-radio-${value.name}'),
            value: value,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onSelected,
              child: IgnorePointer(ignoring: !checked, child: child),
            ),
          ),
        ],
      ),
    );
  }
}

/// Narrow numeric box used inside option rows. Owns a controller so typing is
/// smooth; external value changes (option switches, clamping) resync the text
/// while the box is not focused.
class _NumberBox extends StatefulWidget {
  const _NumberBox({
    required this.keyId,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.width = 64,
  });

  final String keyId;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final double width;

  @override
  State<_NumberBox> createState() => _NumberBoxState();
}

class _NumberBoxState extends State<_NumberBox> {
  late final TextEditingController _controller =
      TextEditingController(text: '${widget.value}');
  late final FocusNode _focusNode = FocusNode();

  @override
  void didUpdateWidget(covariant _NumberBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus &&
        _controller.text != '${widget.value}') {
      _controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: 28,
      child: TextBox(
        key: ValueKey('cron-num-${widget.keyId}'),
        controller: _controller,
        focusNode: _focusNode,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(4),
        ],
        onChanged: (text) {
          final parsed = int.tryParse(text);
          if (parsed == null) return;
          widget.onChanged(parsed.clamp(widget.min, widget.max));
        },
      ),
    );
  }
}

/// Multi-select value grid ("指定").
class _SpecificGrid extends StatelessWidget {
  const _SpecificGrid({
    required this.values,
    required this.selected,
    required this.onToggle,
    required this.itemWidth,
    this.labels,
  });

  final List<int> values;
  final Set<int> selected;
  final ValueChanged<int> onToggle;
  final double itemWidth;
  final String Function(int value)? labels;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 2,
      runSpacing: 0,
      children: [
        for (final value in values)
          SizedBox(
            width: itemWidth,
            child: Checkbox(
              key: ValueKey('cron-spec-${values.first}-$value'),
              checked: selected.contains(value),
              onChanged: (_) => onToggle(value),
              content: Text(
                labels?.call(value) ?? '$value',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }
}

CronFieldState _toggleSpecific(CronFieldState field, int value) {
  final next = Set<int>.of(field.specific);
  if (!next.remove(value)) next.add(value);
  return field.copyWith(type: CronOptionType.specific, specific: next);
}

/// Wraps a panel's option rows so the radio dots reflect [CronFieldState.type]
/// and clicking a dot switches the option.
class _OptionGroup extends StatelessWidget {
  const _OptionGroup({required this.field, required this.onChanged, required this.child});

  final CronFieldState field;
  final ValueChanged<CronFieldState> onChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RadioGroup<CronOptionType>(
      groupValue: field.type,
      onChanged: (type) {
        if (type != null && type != field.type) {
          onChanged(field.copyWith(type: type));
        }
      },
      child: child,
    );
  }
}

// ── 秒 / 分 / 时 ────────────────────────────────────────────

class _TimeLikePanel extends StatelessWidget {
  const _TimeLikePanel({
    required this.kind,
    required this.field,
    required this.l10n,
    required this.onChanged,
    this.amPmGroups = false,
  });

  final CronFieldKind kind;
  final CronFieldState field;
  final AppLocalizations l10n;
  final ValueChanged<CronFieldState> onChanged;
  final bool amPmGroups;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final values = [
      for (var v = kind.minValue; v <= kind.maxValue; v++) v
    ];
    return _OptionGroup(
      field: field,
      onChanged: onChanged,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OptionRow(
            value: CronOptionType.every,
            checked: field.type == CronOptionType.every,
            onSelected: () =>
                onChanged(field.copyWith(type: CronOptionType.every)),
            child: Text(l10n.cronGeneratorEvery),
          ),
          _OptionRow(
            value: CronOptionType.range,
            checked: field.type == CronOptionType.range,
            onSelected: () =>
                onChanged(field.copyWith(type: CronOptionType.range)),
            child: Row(
              children: [
                Text(l10n.cronGeneratorRangePrefix),
                const SizedBox(width: 6),
                _NumberBox(
                  keyId: '${kind.name}-range-from',
                  value: field.from,
                  min: kind.minValue,
                  max: kind.maxValue,
                  onChanged: (v) => onChanged(
                      field.copyWith(type: CronOptionType.range, from: v)),
                ),
                const SizedBox(width: 6),
                Text(l10n.cronGeneratorRangeTo),
                const SizedBox(width: 6),
                _NumberBox(
                  keyId: '${kind.name}-range-to',
                  value: field.to,
                  min: kind.minValue,
                  max: kind.maxValue,
                  onChanged: (v) => onChanged(
                      field.copyWith(type: CronOptionType.range, to: v)),
                ),
              ],
            ),
          ),
          _OptionRow(
            value: CronOptionType.increment,
            checked: field.type == CronOptionType.increment,
            onSelected: () =>
                onChanged(field.copyWith(type: CronOptionType.increment)),
            child: Row(
              children: [
                Text(l10n.cronGeneratorIncrementPrefix),
                const SizedBox(width: 6),
                _NumberBox(
                  keyId: '${kind.name}-inc-from',
                  value: field.from,
                  min: kind.minValue,
                  max: kind.maxValue,
                  onChanged: (v) => onChanged(
                      field.copyWith(type: CronOptionType.increment, from: v)),
                ),
                const SizedBox(width: 6),
                Text(l10n.cronGeneratorIncrementEvery),
                const SizedBox(width: 6),
                _NumberBox(
                  keyId: '${kind.name}-inc-step',
                  value: field.step,
                  min: 1,
                  max: kind.maxValue,
                  onChanged: (v) => onChanged(
                      field.copyWith(type: CronOptionType.increment, step: v)),
                ),
              ],
            ),
          ),
          _OptionRow(
            value: CronOptionType.specific,
            checked: field.type == CronOptionType.specific,
            onSelected: () =>
                onChanged(field.copyWith(type: CronOptionType.specific)),
            child: Text(l10n.cronGeneratorSpecific),
          ),
          if (field.type == CronOptionType.specific)
            Padding(
              padding: const EdgeInsets.only(left: 30, top: 4),
              child: amPmGroups
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.cronGeneratorAm,
                            style: theme.typography.caption),
                        _SpecificGrid(
                          values: values.where((v) => v < 12).toList(),
                          selected: field.specific,
                          onToggle: (v) => onChanged(_toggleSpecific(field, v)),
                          itemWidth: 56,
                        ),
                        const SizedBox(height: 4),
                        Text(l10n.cronGeneratorPm,
                            style: theme.typography.caption),
                        _SpecificGrid(
                          values: values.where((v) => v >= 12).toList(),
                          selected: field.specific,
                          onToggle: (v) => onChanged(_toggleSpecific(field, v)),
                          itemWidth: 56,
                        ),
                      ],
                    )
                  : _SpecificGrid(
                      values: values,
                      selected: field.specific,
                      onToggle: (v) => onChanged(_toggleSpecific(field, v)),
                      itemWidth: 56,
                    ),
            ),
        ],
      ),
    );
  }
}

// ── 日 ─────────────────────────────────────────────────────

class _DayOfMonthPanel extends StatelessWidget {
  const _DayOfMonthPanel(
      {required this.field, required this.l10n, required this.onChanged});

  final CronFieldState field;
  final AppLocalizations l10n;
  final ValueChanged<CronFieldState> onChanged;

  static final List<int> _days = [for (var v = 1; v <= 31; v++) v];

  @override
  Widget build(BuildContext context) {
    const kind = CronFieldKind.dayOfMonth;
    return _OptionGroup(
      field: field,
      onChanged: onChanged,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OptionRow(
            value: CronOptionType.every,
            checked: field.type == CronOptionType.every,
            onSelected: () =>
                onChanged(field.copyWith(type: CronOptionType.every)),
            child: Text(l10n.cronGeneratorEveryDay),
          ),
          _OptionRow(
            value: CronOptionType.unspecified,
            checked: field.type == CronOptionType.unspecified,
            onSelected: () =>
                onChanged(field.copyWith(type: CronOptionType.unspecified)),
            child: Text(l10n.cronGeneratorUnspecified),
          ),
          _OptionRow(
            value: CronOptionType.range,
            checked: field.type == CronOptionType.range,
            onSelected: () =>
                onChanged(field.copyWith(type: CronOptionType.range)),
            child: Row(
              children: [
                Text(l10n.cronGeneratorRangePrefix),
                const SizedBox(width: 6),
                _NumberBox(
                  keyId: 'day-range-from',
                  value: field.from,
                  min: kind.minValue,
                  max: kind.maxValue,
                  onChanged: (v) => onChanged(
                      field.copyWith(type: CronOptionType.range, from: v)),
                ),
                const SizedBox(width: 6),
                Text(l10n.cronGeneratorRangeTo),
                const SizedBox(width: 6),
                _NumberBox(
                  keyId: 'day-range-to',
                  value: field.to,
                  min: kind.minValue,
                  max: kind.maxValue,
                  onChanged: (v) => onChanged(
                      field.copyWith(type: CronOptionType.range, to: v)),
                ),
              ],
            ),
          ),
          _OptionRow(
            value: CronOptionType.increment,
            checked: field.type == CronOptionType.increment,
            onSelected: () =>
                onChanged(field.copyWith(type: CronOptionType.increment)),
            child: Row(
              children: [
                Text(l10n.cronGeneratorIncrementPrefix),
                const SizedBox(width: 6),
                _NumberBox(
                  keyId: 'day-inc-from',
                  value: field.from,
                  min: kind.minValue,
                  max: kind.maxValue,
                  onChanged: (v) => onChanged(
                      field.copyWith(type: CronOptionType.increment, from: v)),
                ),
                const SizedBox(width: 6),
                Text(l10n.cronGeneratorIncrementEvery),
                const SizedBox(width: 6),
                _NumberBox(
                  keyId: 'day-inc-step',
                  value: field.step,
                  min: 1,
                  max: kind.maxValue,
                  onChanged: (v) => onChanged(
                      field.copyWith(type: CronOptionType.increment, step: v)),
                ),
              ],
            ),
          ),
          _OptionRow(
            value: CronOptionType.nearestWeekday,
            checked: field.type == CronOptionType.nearestWeekday,
            onSelected: () =>
                onChanged(field.copyWith(type: CronOptionType.nearestWeekday)),
            child: Row(
              children: [
                Text(l10n.cronGeneratorNearestWeekdayPrefix),
                const SizedBox(width: 6),
                _NumberBox(
                  keyId: 'day-work',
                  value: field.from,
                  min: kind.minValue,
                  max: kind.maxValue,
                  onChanged: (v) => onChanged(field.copyWith(
                      type: CronOptionType.nearestWeekday, from: v)),
                ),
                const SizedBox(width: 6),
                Text(l10n.cronGeneratorNearestWeekdaySuffix),
              ],
            ),
          ),
          _OptionRow(
            value: CronOptionType.lastDayOfMonth,
            checked: field.type == CronOptionType.lastDayOfMonth,
            onSelected: () => onChanged(
                field.copyWith(type: CronOptionType.lastDayOfMonth)),
            child: Text(l10n.cronGeneratorLastDay),
          ),
          _OptionRow(
            value: CronOptionType.specific,
            checked: field.type == CronOptionType.specific,
            onSelected: () =>
                onChanged(field.copyWith(type: CronOptionType.specific)),
            child: Text(l10n.cronGeneratorSpecific),
          ),
          if (field.type == CronOptionType.specific)
            Padding(
              padding: const EdgeInsets.only(left: 30, top: 4),
              child: _SpecificGrid(
                values: _days,
                selected: field.specific,
                onToggle: (v) => onChanged(_toggleSpecific(field, v)),
                itemWidth: 56,
              ),
            ),
        ],
      ),
    );
  }
}

// ── 月 ─────────────────────────────────────────────────────

class _MonthPanel extends StatelessWidget {
  const _MonthPanel(
      {required this.field, required this.l10n, required this.onChanged});

  final CronFieldState field;
  final AppLocalizations l10n;
  final ValueChanged<CronFieldState> onChanged;

  static final List<int> _months = [for (var v = 1; v <= 12; v++) v];

  @override
  Widget build(BuildContext context) {
    const kind = CronFieldKind.month;
    return _OptionGroup(
      field: field,
      onChanged: onChanged,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OptionRow(
            value: CronOptionType.every,
            checked: field.type == CronOptionType.every,
            onSelected: () =>
                onChanged(field.copyWith(type: CronOptionType.every)),
            child: Text(l10n.cronGeneratorEveryMonth),
          ),
          _OptionRow(
            value: CronOptionType.range,
            checked: field.type == CronOptionType.range,
            onSelected: () =>
                onChanged(field.copyWith(type: CronOptionType.range)),
            child: Row(
              children: [
                Text(l10n.cronGeneratorRangePrefix),
                const SizedBox(width: 6),
                _NumberBox(
                  keyId: 'month-range-from',
                  value: field.from,
                  min: kind.minValue,
                  max: kind.maxValue,
                  onChanged: (v) => onChanged(
                      field.copyWith(type: CronOptionType.range, from: v)),
                ),
                const SizedBox(width: 6),
                Text(l10n.cronGeneratorRangeTo),
                const SizedBox(width: 6),
                _NumberBox(
                  keyId: 'month-range-to',
                  value: field.to,
                  min: kind.minValue,
                  max: kind.maxValue,
                  onChanged: (v) => onChanged(
                      field.copyWith(type: CronOptionType.range, to: v)),
                ),
              ],
            ),
          ),
          _OptionRow(
            value: CronOptionType.increment,
            checked: field.type == CronOptionType.increment,
            onSelected: () =>
                onChanged(field.copyWith(type: CronOptionType.increment)),
            child: Row(
              children: [
                Text(l10n.cronGeneratorIncrementPrefix),
                const SizedBox(width: 6),
                _NumberBox(
                  keyId: 'month-inc-from',
                  value: field.from,
                  min: kind.minValue,
                  max: kind.maxValue,
                  onChanged: (v) => onChanged(
                      field.copyWith(type: CronOptionType.increment, from: v)),
                ),
                const SizedBox(width: 6),
                Text(l10n.cronGeneratorIncrementEvery),
                const SizedBox(width: 6),
                _NumberBox(
                  keyId: 'month-inc-step',
                  value: field.step,
                  min: 1,
                  max: kind.maxValue,
                  onChanged: (v) => onChanged(
                      field.copyWith(type: CronOptionType.increment, step: v)),
                ),
              ],
            ),
          ),
          _OptionRow(
            value: CronOptionType.specific,
            checked: field.type == CronOptionType.specific,
            onSelected: () =>
                onChanged(field.copyWith(type: CronOptionType.specific)),
            child: Text(l10n.cronGeneratorSpecific),
          ),
          if (field.type == CronOptionType.specific)
            Padding(
              padding: const EdgeInsets.only(left: 30, top: 4),
              child: _SpecificGrid(
                values: _months,
                selected: field.specific,
                onToggle: (v) => onChanged(_toggleSpecific(field, v)),
                itemWidth: 72,
                labels: (v) => l10n.cronGeneratorMonthN(v),
              ),
            ),
        ],
      ),
    );
  }
}

// ── 周 ─────────────────────────────────────────────────────

class _DayOfWeekPanel extends StatelessWidget {
  const _DayOfWeekPanel(
      {required this.field, required this.l10n, required this.onChanged});

  final CronFieldState field;
  final AppLocalizations l10n;
  final ValueChanged<CronFieldState> onChanged;

  static const List<int> _weekdays = [1, 2, 3, 4, 5, 6, 7];

  /// Quartz day-of-week numbering: 1=Sunday … 7=Saturday.
  String weekdayName(int value) => switch (value) {
        1 => l10n.cronWeekdaySun,
        2 => l10n.cronWeekdayMon,
        3 => l10n.cronWeekdayTue,
        4 => l10n.cronWeekdayWed,
        5 => l10n.cronWeekdayThu,
        6 => l10n.cronWeekdayFri,
        _ => l10n.cronWeekdaySat,
      };

  @override
  Widget build(BuildContext context) {
    return _OptionGroup(
      field: field,
      onChanged: onChanged,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OptionRow(
            value: CronOptionType.unspecified,
            checked: field.type == CronOptionType.unspecified,
            onSelected: () =>
                onChanged(field.copyWith(type: CronOptionType.unspecified)),
            child: Text(l10n.cronGeneratorUnspecified),
          ),
          _OptionRow(
            value: CronOptionType.range,
            checked: field.type == CronOptionType.range,
            onSelected: () =>
                onChanged(field.copyWith(type: CronOptionType.range)),
            child: Row(
              children: [
                Text(l10n.cronGeneratorRangePrefix),
                const SizedBox(width: 6),
                _WeekdayDropdown(
                  keyId: 'week-range-from',
                  value: field.from,
                  nameOf: weekdayName,
                  onChanged: (v) => onChanged(
                      field.copyWith(type: CronOptionType.range, from: v)),
                ),
                const SizedBox(width: 6),
                Text(l10n.cronGeneratorRangeTo),
                const SizedBox(width: 6),
                _WeekdayDropdown(
                  keyId: 'week-range-to',
                  value: field.to,
                  nameOf: weekdayName,
                  onChanged: (v) => onChanged(
                      field.copyWith(type: CronOptionType.range, to: v)),
                ),
              ],
            ),
          ),
          _OptionRow(
            value: CronOptionType.nthWeekday,
            checked: field.type == CronOptionType.nthWeekday,
            onSelected: () =>
                onChanged(field.copyWith(type: CronOptionType.nthWeekday)),
            child: Row(
              children: [
                Text(l10n.cronGeneratorNthPrefix),
                const SizedBox(width: 6),
                _NumberBox(
                  keyId: 'week-nth',
                  value: field.nth,
                  min: 1,
                  max: 5,
                  width: 48,
                  onChanged: (v) => onChanged(
                      field.copyWith(type: CronOptionType.nthWeekday, nth: v)),
                ),
                const SizedBox(width: 6),
                Text(l10n.cronGeneratorNthMiddle),
                const SizedBox(width: 6),
                _WeekdayDropdown(
                  keyId: 'week-nth-day',
                  value: field.from,
                  nameOf: weekdayName,
                  onChanged: (v) => onChanged(field.copyWith(
                      type: CronOptionType.nthWeekday, from: v)),
                ),
              ],
            ),
          ),
          _OptionRow(
            value: CronOptionType.lastWeekday,
            checked: field.type == CronOptionType.lastWeekday,
            onSelected: () =>
                onChanged(field.copyWith(type: CronOptionType.lastWeekday)),
            child: Row(
              children: [
                Text(l10n.cronGeneratorLastWeekdayPrefix),
                const SizedBox(width: 6),
                _WeekdayDropdown(
                  keyId: 'week-last-day',
                  value: field.from,
                  nameOf: weekdayName,
                  onChanged: (v) => onChanged(field.copyWith(
                      type: CronOptionType.lastWeekday, from: v)),
                ),
              ],
            ),
          ),
          _OptionRow(
            value: CronOptionType.specific,
            checked: field.type == CronOptionType.specific,
            onSelected: () =>
                onChanged(field.copyWith(type: CronOptionType.specific)),
            child: Text(l10n.cronGeneratorSpecific),
          ),
          if (field.type == CronOptionType.specific)
            Padding(
              padding: const EdgeInsets.only(left: 30, top: 4),
              child: _SpecificGrid(
                values: _weekdays,
                selected: field.specific,
                onToggle: (v) => onChanged(_toggleSpecific(field, v)),
                itemWidth: 88,
                labels: weekdayName,
              ),
            ),
        ],
      ),
    );
  }
}

class _WeekdayDropdown extends StatelessWidget {
  const _WeekdayDropdown({
    required this.keyId,
    required this.value,
    required this.nameOf,
    required this.onChanged,
  });

  final String keyId;
  final int value;
  final String Function(int) nameOf;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ComboBox<int>(
      key: ValueKey('cron-dd-$keyId'),
      value: value.clamp(1, 7),
      isExpanded: false,
      items: [
        for (var v = 1; v <= 7; v++)
          ComboBoxItem(value: v, child: Text('${nameOf(v)} ($v)')),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

// ── 年 ─────────────────────────────────────────────────────

class _YearPanel extends StatelessWidget {
  const _YearPanel(
      {required this.field, required this.l10n, required this.onChanged});

  final CronFieldState field;
  final AppLocalizations l10n;
  final ValueChanged<CronFieldState> onChanged;

  @override
  Widget build(BuildContext context) {
    const kind = CronFieldKind.year;
    final theme = FluentTheme.of(context);
    return _OptionGroup(
      field: field,
      onChanged: onChanged,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OptionRow(
            value: CronOptionType.unspecified,
            checked: field.type == CronOptionType.unspecified,
            onSelected: () =>
                onChanged(field.copyWith(type: CronOptionType.unspecified)),
            child: Text(l10n.cronGeneratorYearUnspecified),
          ),
          _OptionRow(
            value: CronOptionType.every,
            checked: field.type == CronOptionType.every,
            onSelected: () =>
                onChanged(field.copyWith(type: CronOptionType.every)),
            child: Text(l10n.cronGeneratorEveryYear),
          ),
          _OptionRow(
            value: CronOptionType.range,
            checked: field.type == CronOptionType.range,
            onSelected: () =>
                onChanged(field.copyWith(type: CronOptionType.range)),
            child: Row(
              children: [
                Text(l10n.cronGeneratorRangePrefix),
                const SizedBox(width: 6),
                _NumberBox(
                  keyId: 'year-range-from',
                  value: field.from,
                  min: kind.minValue,
                  max: kind.maxValue,
                  width: 80,
                  onChanged: (v) => onChanged(
                      field.copyWith(type: CronOptionType.range, from: v)),
                ),
                const SizedBox(width: 6),
                Text(l10n.cronGeneratorRangeTo),
                const SizedBox(width: 6),
                _NumberBox(
                  keyId: 'year-range-to',
                  value: field.to,
                  min: kind.minValue,
                  max: kind.maxValue,
                  width: 80,
                  onChanged: (v) => onChanged(
                      field.copyWith(type: CronOptionType.range, to: v)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 30),
            child: Text(
              l10n.cronGeneratorYearHint,
              style: theme.typography.caption
                  ?.copyWith(color: theme.inactiveColor),
            ),
          ),
        ],
      ),
    );
  }
}
