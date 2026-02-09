import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/widgets.dart';
class CardExpanderItem extends StatelessWidget {
  final Widget heading;

  final Widget? icon;

  final Widget? caption;

  final Widget? trailing;

  final Widget? dropdown;

  final VoidCallback? onPressed;

  final double minHeaderHeight;

  final EdgeInsetsGeometry margin;

  final EdgeInsetsGeometry padding;

  const CardExpanderItem({
    super.key,
    required this.heading,
    this.icon,
    this.caption,
    this.trailing,
    this.dropdown,
    this.onPressed,
    this.minHeaderHeight = 44,
    this.margin = const EdgeInsets.only(bottom: 12),
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  });

  @override
  Widget build(BuildContext context) {
    final cardChild = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeaderHeight),
      child: _buildBody(context),
    );

    return Card(
      margin: margin,
      child: cardChild,
    );
  }

  Widget _buildBody(BuildContext context) {
    final trailingWidgets = <Widget>[
      if (trailing != null) trailing!,
      if (dropdown != null) ...[
        const SizedBox(width: 6),
        dropdown!,
      ],
    ];

    final trailingWidget = trailingWidgets.isEmpty
        ? null
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: trailingWidgets,
          );

    return ListTile(
      leading: icon == null
          ? null
          : IconTheme.merge(
              data: const IconThemeData(size: 18),
              child: icon!,
            ),
      title: heading,
      subtitle: caption,
      trailing: trailingWidget,
      contentPadding: padding,
      onPressed: onPressed,
    );
  }
}
