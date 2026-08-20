import 'package:fluent_ui/fluent_ui.dart';
import 'package:fly_narwhal/ui/shared/app_button.dart';

// Soft blue for toggle default checked state
const Color playerSettingsAccentColor = Color(0xFF3D84E0);
// Lighter blue for toggle hover state
const Color playerSettingsAccentHoverColor = Color(0xFF5CA0FF);
const Color playerSettingsTextColor = Color(0xE6FFFFFF);
const Color playerSettingsHoverColor = Color(0x1AFFFFFF);
const Color playerSettingsDividerColor = Color(0x33FFFFFF);

class PlayerSettingsHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final String? actionLabel;
  final VoidCallback? onAction;

  const PlayerSettingsHeader({
    super.key,
    required this.title,
    this.onBack,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 34,
          child: Row(
            children: [
              if (onBack != null) ...[
                AppIconButton(
                  key: const ValueKey('player-settings-header-back'),
                  icon: const Icon(FluentIcons.chevron_left, size: 16),
                  onPressed: onBack,
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (actionLabel != null)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    key: const ValueKey('player-settings-header-action'),
                    onTap: onAction,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            actionLabel!,
                            style: const TextStyle(
                              color: playerSettingsTextColor,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Icon(
                            FluentIcons.chevron_right,
                            size: 12,
                            color: playerSettingsTextColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Divider(
          key: ValueKey('player-settings-header-divider'),
          style: DividerThemeData(
            decoration: BoxDecoration(color: playerSettingsDividerColor),
          ),
        ),
      ],
    );
  }
}

class PlayerSettingsSlider extends StatelessWidget {
  final String label;
  final double value;
  final double minimum;
  final double maximum;
  final int? divisions;
  final ValueChanged<double> onChanged;

  const PlayerSettingsSlider({
    super.key,
    required this.label,
    required this.value,
    required this.minimum,
    required this.maximum,
    this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: playerSettingsTextColor)),
          const SizedBox(height: 6),
          Slider(
            value: value,
            min: minimum,
            max: maximum,
            divisions: divisions,
            style: const SliderThemeData(
              activeColor: WidgetStatePropertyAll(playerSettingsAccentColor),
              thumbColor: WidgetStatePropertyAll(playerSettingsAccentColor),
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class PlayerSettingsToggleRow extends StatefulWidget {
  final String title;
  final String? description;
  final bool checked;
  final ValueChanged<bool>? onChanged;
  final EdgeInsetsGeometry padding;
  // Shown as a tooltip over the switch when the row is disabled.
  final String? disabledReason;

  const PlayerSettingsToggleRow({
    super.key,
    required this.title,
    this.description,
    required this.checked,
    required this.onChanged,
    this.padding = const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
    this.disabledReason,
  });

  @override
  State<PlayerSettingsToggleRow> createState() =>
      _PlayerSettingsToggleRowState();
}

class _PlayerSettingsToggleRowState extends State<PlayerSettingsToggleRow> {
  bool _isHovered = false;

  ToggleSwitchThemeData get _toggleStyle => ToggleSwitchThemeData(
        // White knob for all states
        checkedKnobDecoration: WidgetStateProperty.resolveWith((states) {
          final knobColor = states.isDisabled
              ? Colors.white.withValues(alpha: 0.6)
              : Colors.white;
          return BoxDecoration(
            color: knobColor,
            borderRadius: BorderRadius.circular(100),
          );
        }),
        checkedDecoration: WidgetStateProperty.resolveWith((states) {
          // Use dimmed color when disabled
          if (states.isDisabled) {
            final color = playerSettingsAccentColor.withValues(alpha: 0.45);
            return BoxDecoration(
              color: color,
              border: Border.all(color: color),
              borderRadius: BorderRadius.circular(100),
            );
          }
          // Use lighter blue when hovered
          final color = states.isHovered
              ? playerSettingsAccentHoverColor
              : playerSettingsAccentColor;
          return BoxDecoration(
            color: color,
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(100),
          );
        }),
      );

  void _changeValue(bool value) => widget.onChanged?.call(value);

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onChanged != null;
    Widget toggle = ToggleSwitch(
      checked: widget.checked,
      style: _toggleStyle,
      onChanged: widget.onChanged,
    );
    if (!isEnabled && widget.disabledReason != null) {
      toggle = Tooltip(message: widget.disabledReason!, child: toggle);
    }
    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isEnabled ? () => _changeValue(!widget.checked) : null,
        child: Container(
          padding: widget.padding,
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: _isHovered && isEnabled
                ? playerSettingsHoverColor
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: isEnabled
                            ? playerSettingsTextColor
                            : playerSettingsTextColor.withValues(alpha: 0.45),
                        fontSize: 14,
                      ),
                    ),
                    if (widget.description != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          widget.description!,
                          style: TextStyle(
                            color: playerSettingsTextColor.withValues(
                              alpha: 0.55,
                            ),
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              toggle,
            ],
          ),
        ),
      ),
    );
  }
}
