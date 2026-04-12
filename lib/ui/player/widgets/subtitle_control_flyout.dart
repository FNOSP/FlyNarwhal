import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../data/models/movie_detail_models.dart';

const Color _subtitleFlyoutBackgroundColor = Color(0xE6000000);
const Color _subtitleFlyoutBorderColor = Color(0x80808080);
const Color _subtitleSelectedTextColor = Color(0xFF2073DF);
const Color _subtitleDefaultTextColor = Color(0xC8FFFFFF);
const Color _subtitleHoverBackgroundColor = Color(0x1AFFFFFF);
const int _subtitleHideDelayMs = 200;
const int _subtitleAnimationDurationMs = 200;

class SubtitleControlFlyout extends StatefulWidget {
  final List<SubtitleStream> subtitles;
  final String? selectedSubtitleGuid;
  final int yOffset;
  final void Function(String?) onSubtitleSelected;
  final void Function(bool)? onHoverStateChanged;

  const SubtitleControlFlyout({
    super.key,
    required this.subtitles,
    required this.selectedSubtitleGuid,
    this.yOffset = 0,
    required this.onSubtitleSelected,
    this.onHoverStateChanged,
  });

  @override
  State<SubtitleControlFlyout> createState() => _SubtitleControlFlyoutState();
}

class _SubtitleControlFlyoutState extends State<SubtitleControlFlyout>
    with SingleTickerProviderStateMixin {
  bool _showPopup = false;
  bool _isButtonHovered = false;
  bool _popupHovered = false;
  Timer? _hideTimer;
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: _subtitleAnimationDurationMs),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.4, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _showFlyout() {
    _hideTimer?.cancel();
    setState(() => _showPopup = true);
    _animationController.forward(from: 0);
    widget.onHoverStateChanged?.call(true);
  }

  void _hideFlyoutWithDelay() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: _subtitleHideDelayMs), () {
      if (!_isButtonHovered && !_popupHovered && mounted) {
        _animationController.reverse().then((_) {
          if (mounted) {
            setState(() => _showPopup = false);
          }
        });
        widget.onHoverStateChanged?.call(false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _isButtonHovered = true);
        _showFlyout();
      },
      onExit: (_) {
        setState(() => _isButtonHovered = false);
        _hideFlyoutWithDelay();
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SvgPicture.asset(
            'assets/images/subtitle.svg',
            width: 22,
            height: 22,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
          if (_showPopup)
            Positioned(
              bottom: 0,
              left: -190,
              child: MouseRegion(
                opaque: false,
                onEnter: (_) {
                  setState(() => _popupHovered = true);
                  _hideTimer?.cancel();
                },
                onExit: (_) {
                  setState(() => _popupHovered = false);
                  _hideFlyoutWithDelay();
                },
                child: SizedBox(
                  width: 250,
                  height: widget.yOffset + 40,
                ),
              ),
            ),
          if (_showPopup)
            Positioned(
              bottom: widget.yOffset + 40,
              left: -190,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) {
                  setState(() => _popupHovered = true);
                  _hideTimer?.cancel();
                },
                onExit: (_) {
                  setState(() => _popupHovered = false);
                  _hideFlyoutWithDelay();
                },
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: Transform.scale(
                        scale: _scaleAnimation.value,
                        alignment: Alignment.bottomCenter,
                        child: child,
                      ),
                    );
                  },
                  child: _SubtitleFlyoutContent(
                    subtitles: widget.subtitles,
                    selectedSubtitleGuid: widget.selectedSubtitleGuid,
                    onSubtitleSelected: widget.onSubtitleSelected,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SubtitleFlyoutContent extends StatelessWidget {
  final List<SubtitleStream> subtitles;
  final String? selectedSubtitleGuid;
  final void Function(String?) onSubtitleSelected;

  const _SubtitleFlyoutContent({
    required this.subtitles,
    required this.selectedSubtitleGuid,
    required this.onSubtitleSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: _subtitleFlyoutBackgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _subtitleFlyoutBorderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SubtitleItem(
              title: '无字幕',
              subtitle: '关闭当前字幕',
              isSelected:
                  selectedSubtitleGuid == null || selectedSubtitleGuid!.isEmpty,
              onTap: () => onSubtitleSelected(null),
            ),
            ...subtitles.map((subtitle) {
              final label = _buildLabel(subtitle);
              return _SubtitleItem(
                title: label,
                subtitle: subtitle.codecName.toUpperCase(),
                isSelected: selectedSubtitleGuid == subtitle.guid,
                onTap: () => onSubtitleSelected(subtitle.guid),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _buildLabel(SubtitleStream subtitle) {
    final language =
        subtitle.language.isNotEmpty ? subtitle.language.toUpperCase() : 'SUB';
    if (subtitle.isExternal == 1) {
      return '$language 外挂';
    }
    return subtitle.title.isNotEmpty ? subtitle.title : language;
  }
}

class _SubtitleItem extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _SubtitleItem({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SubtitleItem> createState() => _SubtitleItemState();
}

class _SubtitleItemState extends State<_SubtitleItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: _isHovered || widget.isSelected
                ? _subtitleHoverBackgroundColor
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: widget.isSelected
                            ? _subtitleSelectedTextColor
                            : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        color: _subtitleDefaultTextColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.isSelected)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(
                    FluentIcons.check_mark,
                    size: 14,
                    color: _subtitleSelectedTextColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
