import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import '../../../data/models/episode_list_response.dart';

const Color _episodeFlyoutBackgroundColor = Color(0xE6000000);
const Color _episodeFlyoutBorderColor = Color(0x80808080);
const Color _episodeSelectedTextColor = Color(0xFF2073DF);
const Color _episodeDefaultTextColor = Color(0xC8FFFFFF);
const Color _episodeHoverBackgroundColor = Color(0x1AFFFFFF);
const int _episodeHideDelayMs = 200;
const int _episodeAnimationDurationMs = 200;

class EpisodeSelectionFlyout extends StatefulWidget {
  final List<EpisodeListResponse> episodes;
  final String currentEpisodeGuid;
  final bool isAutoPlay;
  final int yOffset;
  final void Function(EpisodeListResponse) onEpisodeSelected;
  final void Function(bool)? onHoverStateChanged;
  final void Function(bool)? onAutoPlayChanged;

  const EpisodeSelectionFlyout({
    super.key,
    required this.episodes,
    required this.currentEpisodeGuid,
    this.isAutoPlay = true,
    this.yOffset = 0,
    required this.onEpisodeSelected,
    this.onHoverStateChanged,
    this.onAutoPlayChanged,
  });

  @override
  State<EpisodeSelectionFlyout> createState() => _EpisodeSelectionFlyoutState();
}

class _EpisodeSelectionFlyoutState extends State<EpisodeSelectionFlyout>
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
      duration: const Duration(milliseconds: _episodeAnimationDurationMs),
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
    _hideTimer = Timer(const Duration(milliseconds: _episodeHideDelayMs), () {
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
          Text(
            '选集',
            style: TextStyle(
              color: _isButtonHovered ? Colors.white : _episodeDefaultTextColor,
              fontSize: 17,
            ),
          ),
          if (_showPopup)
            Positioned(
              bottom: 0,
              left: -220,
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
                  width: 280,
                  height: widget.yOffset + 40,
                ),
              ),
            ),
          if (_showPopup)
            Positioned(
              bottom: widget.yOffset + 40,
              left: -220,
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
                  child: _EpisodeFlyoutContent(
                    episodes: widget.episodes,
                    currentEpisodeGuid: widget.currentEpisodeGuid,
                    isAutoPlay: widget.isAutoPlay,
                    onEpisodeSelected: (episode) {
                      widget.onEpisodeSelected(episode);
                      _hideFlyoutWithDelay();
                    },
                    onAutoPlayChanged: widget.onAutoPlayChanged,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EpisodeFlyoutContent extends StatelessWidget {
  final List<EpisodeListResponse> episodes;
  final String currentEpisodeGuid;
  final bool isAutoPlay;
  final void Function(EpisodeListResponse) onEpisodeSelected;
  final void Function(bool)? onAutoPlayChanged;

  const _EpisodeFlyoutContent({
    required this.episodes,
    required this.currentEpisodeGuid,
    required this.isAutoPlay,
    required this.onEpisodeSelected,
    required this.onAutoPlayChanged,
  });

  @override
  Widget build(BuildContext context) {
    final visibleEpisodes = episodes.take(18).toList();
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: _episodeFlyoutBackgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _episodeFlyoutBorderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Text(
                  '选集',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                ToggleSwitch(
                  checked: isAutoPlay,
                  onChanged: onAutoPlayChanged,
                  content: const Text(
                    '自动',
                    style: TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 8),
              shrinkWrap: true,
              itemCount: visibleEpisodes.length,
              itemBuilder: (context, index) {
                final episode = visibleEpisodes[index];
                final isSelected = episode.guid == currentEpisodeGuid;
                return _EpisodeItem(
                  episode: episode,
                  isSelected: isSelected,
                  onTap: () => onEpisodeSelected(episode),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EpisodeItem extends StatefulWidget {
  final EpisodeListResponse episode;
  final bool isSelected;
  final VoidCallback onTap;

  const _EpisodeItem({
    required this.episode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_EpisodeItem> createState() => _EpisodeItemState();
}

class _EpisodeItemState extends State<_EpisodeItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final episode = widget.episode;
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
                ? _episodeHoverBackgroundColor
                : Colors.transparent,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 54,
                child: Text(
                  'E${episode.episodeNumber.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: widget.isSelected
                        ? _episodeSelectedTextColor
                        : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  episode.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.isSelected
                        ? _episodeSelectedTextColor
                        : _episodeDefaultTextColor,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
