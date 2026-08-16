import 'package:fluent_ui/fluent_ui.dart';
import 'package:fly_narwhal/ui/shared/app_button.dart';

const playerPlaybackEndOverlayKey = ValueKey('player-playback-end-overlay');
const playerPlaybackEndReplayKey = ValueKey('player-playback-end-replay');
const playerPlaybackEndHomeKey = ValueKey('player-playback-end-home');
const playerPlaybackEndPipOverlayKey =
    ValueKey('player-playback-end-pip-overlay');
const playerPlaybackEndPipReplayKey =
    ValueKey('player-playback-end-pip-replay');
const playerPlaybackEndPipHomeKey = ValueKey('player-playback-end-pip-home');

class PlaybackEndOverlay extends StatelessWidget {
  const PlaybackEndOverlay({
    super.key,
    required this.episodeNumber,
    required this.episodeTitle,
    required this.runtimeMinutes,
    required this.onReplay,
    required this.onReturnHome,
    this.isPip = false,
  });

  final int episodeNumber;
  final String episodeTitle;
  final int runtimeMinutes;
  final VoidCallback onReplay;
  final VoidCallback onReturnHome;
  final bool isPip;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      key: isPip ? playerPlaybackEndPipOverlayKey : playerPlaybackEndOverlayKey,
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.95),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(isPip ? 16 : 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${episodeNumber.toString().padLeft(2, '0')}. $episodeTitle',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${runtimeMinutes < 0 ? 0 : runtimeMinutes} 分钟',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: isPip ? 16 : 24),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    _EndActionButton(
                      key: isPip
                          ? playerPlaybackEndPipReplayKey
                          : playerPlaybackEndReplayKey,
                      icon: FluentIcons.refresh,
                      label: '重新播放',
                      onPressed: onReplay,
                    ),
                    _EndActionButton(
                      key: isPip
                          ? playerPlaybackEndPipHomeKey
                          : playerPlaybackEndHomeKey,
                      icon: FluentIcons.home,
                      label: '回到首页',
                      onPressed: onReturnHome,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EndActionButton extends StatelessWidget {
  const _EndActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      onPressed: onPressed,
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(
          Colors.white.withValues(alpha: 0.1),
        ),
        foregroundColor: const WidgetStatePropertyAll(Colors.white),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}
