import 'package:fluent_ui/fluent_ui.dart';
import 'package:fly_narwhal/domain/entities/media_type.dart';
import 'package:fly_narwhal/ui/shared/app_button.dart';
import 'package:fly_narwhal/ui/shared/common/fn_cached_image.dart';
import 'package:fly_narwhal/ui/shared/common/media_poster_placeholder.dart';

const playerPlaybackEndOverlayKey = ValueKey('player-playback-end-overlay');
const playerPlaybackEndReplayKey = ValueKey('player-playback-end-replay');
const playerPlaybackEndHomeKey = ValueKey('player-playback-end-home');
const playerPlaybackEndPipOverlayKey =
    ValueKey('player-playback-end-pip-overlay');
const playerPlaybackEndPipReplayKey =
    ValueKey('player-playback-end-pip-replay');
const playerPlaybackEndPipHomeKey = ValueKey('player-playback-end-pip-home');

/// 播放结束覆盖层:16:9 背景图卡片 + 右下角“已观看”角标,
/// 下方左对齐标题与时长,底部“重播 / 回到首页”两个按钮。
class PlaybackEndOverlay extends StatelessWidget {
  const PlaybackEndOverlay({
    super.key,
    required this.title,
    this.episodeNumber = 0,
    this.backdropPath,
    this.isWatched = false,
    this.durationSeconds = 0,
    this.mediaType,
    required this.onReplay,
    required this.onReturnHome,
    this.isPip = false,
  });

  final String title;
  final int episodeNumber;
  final String? backdropPath;
  final bool isWatched;
  final int durationSeconds;
  final String? mediaType;
  final VoidCallback onReplay;
  final VoidCallback onReturnHome;
  final bool isPip;

  @override
  Widget build(BuildContext context) {
    final s = isPip ? 0.7 : 1.0;
    final type = MediaType.tryParse(mediaType);
    final displayTitle = episodeNumber > 0
        ? (title.isEmpty
            ? '第 $episodeNumber 集'
            : '第 $episodeNumber 集 $title')
        : title;
    final durationText = _formatRuntime(durationSeconds);

    return Positioned.fill(
      key: isPip ? playerPlaybackEndPipOverlayKey : playerPlaybackEndOverlayKey,
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.95),
        child: Center(
          child: SizedBox(
            width: 410 * s,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 16:9 背景图卡片
                Container(
                  width: 400 * s,
                  height: 225 * s,
                  decoration: BoxDecoration(
                    color: const Color(0xCC202021),
                    borderRadius: BorderRadius.circular(8 * s),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8 * s),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (backdropPath?.trim().isNotEmpty == true)
                          FnCachedImage(
                            posterPath: backdropPath!,
                            fit: BoxFit.cover,
                            errorWidget: MediaPosterPlaceholder(type: type),
                          )
                        else
                          Center(
                            child: MediaPosterPlaceholder(type: type),
                          ),
                        if (isWatched)
                          Positioned(
                            right: 28 * s,
                            bottom: 10 * s,
                            child: Container(
                              height: 20 * s,
                              constraints: BoxConstraints(minWidth: 46 * s),
                              padding: EdgeInsets.symmetric(horizontal: 8 * s),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(4 * s),
                              ),
                              child: Text(
                                '已观看',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12 * s,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 12 * s),
                // 标题 + 时长,左对齐
                SizedBox(
                  width: 400 * s,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20 * s,
                          fontWeight: FontWeight.w600,
                          height: 28 / 20,
                        ),
                      ),
                      if (durationSeconds > 0)
                        Text(
                          durationText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 13 * s,
                            height: 18 / 13,
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 12 * s),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _EndActionButton(
                      key: isPip
                          ? playerPlaybackEndPipReplayKey
                          : playerPlaybackEndReplayKey,
                      icon: FluentIcons.refresh,
                      label: '重播',
                      scaleFactor: s,
                      onPressed: onReplay,
                    ),
                    SizedBox(width: 32 * s),
                    _EndActionButton(
                      key: isPip
                          ? playerPlaybackEndPipHomeKey
                          : playerPlaybackEndHomeKey,
                      icon: FluentIcons.home,
                      label: '回到首页',
                      scaleFactor: s,
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

  static String _formatRuntime(int seconds) {
    final minutes = seconds ~/ 60;
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (hours > 0 && rest > 0) return '$hours 小时 $rest 分钟';
    if (hours > 0) return '$hours 小时';
    return '$rest 分钟';
  }
}

class _EndActionButton extends StatelessWidget {
  const _EndActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.scaleFactor,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final double scaleFactor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      onPressed: onPressed,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.hovered)
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.06)),
        foregroundColor:
            WidgetStatePropertyAll(Colors.white.withValues(alpha: 0.8)),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8 * scaleFactor),
          ),
        ),
      ),
      child: SizedBox(
        width: 185 * scaleFactor,
        height: 54 * scaleFactor,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20 * scaleFactor),
            SizedBox(width: 8 * scaleFactor),
            Text(
              label,
              style: TextStyle(
                fontSize: 18 * scaleFactor,
                fontWeight: FontWeight.w600,
                height: 28 / 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
