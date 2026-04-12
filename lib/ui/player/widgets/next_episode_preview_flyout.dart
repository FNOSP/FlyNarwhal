import 'package:fluent_ui/fluent_ui.dart';
import '../../../data/models/episode_list_response.dart';
import 'player_action_button.dart';

class NextEpisodePreviewFlyout extends StatefulWidget {
  final EpisodeListResponse nextEpisode;
  final VoidCallback onClick;
  final void Function(bool)? onHoverStateChanged;

  const NextEpisodePreviewFlyout({
    super.key,
    required this.nextEpisode,
    required this.onClick,
    this.onHoverStateChanged,
  });

  @override
  State<NextEpisodePreviewFlyout> createState() =>
      _NextEpisodePreviewFlyoutState();
}

class _NextEpisodePreviewFlyoutState extends State<NextEpisodePreviewFlyout> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _isHovered = true);
        widget.onHoverStateChanged?.call(true);
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        widget.onHoverStateChanged?.call(false);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onClick,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _isHovered
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PlayerActionButton.icon(
                iconData: FluentIcons.next,
                size: 24,
                iconSize: 16,
                padding: EdgeInsets.all(2),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '下一集',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      'E${widget.nextEpisode.episodeNumber.toString().padLeft(2, '0')} ${widget.nextEpisode.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
