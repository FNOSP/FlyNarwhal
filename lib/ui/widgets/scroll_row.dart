import 'package:fluent_ui/fluent_ui.dart';

class ScrollRow extends StatefulWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double height;
  final EdgeInsetsGeometry padding;
  final double itemSpacing;
  final Duration scrollDuration;
  final Curve scrollCurve;
  final double scrollFactor;
  final ScrollController? controller;

  const ScrollRow({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.height,
    this.padding = EdgeInsets.zero,
    this.itemSpacing = 0,
    this.scrollDuration = const Duration(milliseconds: 1000),
    this.scrollCurve = Curves.fastOutSlowIn,
    this.scrollFactor = 0.8,
    this.controller,
  });

  @override
  State<ScrollRow> createState() => _ScrollRowState();
}

class _ScrollRowState extends State<ScrollRow> {
  late ScrollController _controller;
  bool _hovered = false;
  bool _canScrollBack = false;
  bool _canScrollForward = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ScrollController();
    _controller.addListener(_updateScrollState);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollState());
  }

  @override
  void didUpdateWidget(covariant ScrollRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_updateScrollState);
      if (widget.controller != null) {
        _controller = widget.controller!;
        _controller.addListener(_updateScrollState);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollState());
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_updateScrollState);
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _updateScrollState() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final canBack = position.pixels > position.minScrollExtent + 0.5;
    final canForward = position.pixels < position.maxScrollExtent - 0.5;
    if (canBack != _canScrollBack || canForward != _canScrollForward) {
      setState(() {
        _canScrollBack = canBack;
        _canScrollForward = canForward;
      });
    }
  }

  void _scrollBy(double offset) {
    if (!_controller.hasClients) return;
    _controller.animateTo(
      (_controller.offset + offset).clamp(
        _controller.position.minScrollExtent,
        _controller.position.maxScrollExtent,
      ),
      duration: widget.scrollDuration,
      curve: widget.scrollCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final resolved = widget.padding.resolve(Directionality.of(context));
          final horizontalPadding = resolved.horizontal;
          final scrollAmount =
              (constraints.maxWidth - horizontalPadding).clamp(0, double.infinity) * widget.scrollFactor;

          return MouseRegion(
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: Stack(
              children: [
                ListView.separated(
                  controller: _controller,
                  padding: widget.padding,
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.itemCount,
                  separatorBuilder: (context, index) => SizedBox(width: widget.itemSpacing),
                  itemBuilder: widget.itemBuilder,
                ),
                _ScrollButton(
                  visible: _hovered && _canScrollBack,
                  alignment: Alignment.centerLeft,
                  icon: FluentIcons.chevron_left,
                  onTap: () => _scrollBy(-scrollAmount),
                ),
                _ScrollButton(
                  visible: _hovered && _canScrollForward,
                  alignment: Alignment.centerRight,
                  icon: FluentIcons.chevron_right,
                  onTap: () => _scrollBy(scrollAmount),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ScrollButton extends StatefulWidget {
  final bool visible;
  final Alignment alignment;
  final IconData icon;
  final VoidCallback onTap;

  const _ScrollButton({
    required this.visible,
    required this.alignment,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_ScrollButton> createState() => _ScrollButtonState();
}

class _ScrollButtonState extends State<_ScrollButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !widget.visible,
      child: AnimatedOpacity(
        opacity: widget.visible ? 1 : 0,
        duration: const Duration(milliseconds: 120),
        child: Align(
          alignment: widget.alignment,
          child: MouseRegion(
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
              child: Container(
                width: 30,
                color: Colors.black.withValues(alpha: 0.45),
                alignment: Alignment.center,
                child: AnimatedScale(
                  scale: _hovered ? 1.2 : 1,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: Icon(widget.icon, size: 18),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
