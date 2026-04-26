import 'package:fluent_ui/fluent_ui.dart';

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
    this.minHeaderHeight = 32,
    this.margin = const EdgeInsets.only(bottom: 8),
    this.padding = const EdgeInsetsDirectional.only(end: 2, top: 2, bottom: 2),
  });

  static const EdgeInsetsDirectional _cardPadding =
      EdgeInsetsDirectional.all(12);

  @override
  Widget build(BuildContext context) {
    final isClickable = onPressed != null;
    final cardChild = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeaderHeight),
      child: _buildBody(context),
    );

    return Card(
      padding: isClickable ? EdgeInsets.zero : _cardPadding,
      margin: margin,
      child: cardChild,
    );
  }

  Widget _buildBody(BuildContext context) {
    final resolvedPadding = padding.resolve(Directionality.of(context));
    final effectivePadding = onPressed == null
        ? resolvedPadding
        // Merge the card inset into the tile so hover can cover the full card.
        : resolvedPadding.add(_cardPadding.resolve(Directionality.of(context)));

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
          : Transform.translate(
              offset: const Offset(-8, 0),
              // Shift the icon visually without using negative padding.
              child: IconTheme.merge(
                data: const IconThemeData(size: 16),
                child: icon!,
              ),
            ),
      title: heading,
      subtitle: caption,
      trailing: trailingWidget,
      contentPadding: effectivePadding,
      margin: EdgeInsets.zero,
      onPressed: onPressed,
    );
  }
}
