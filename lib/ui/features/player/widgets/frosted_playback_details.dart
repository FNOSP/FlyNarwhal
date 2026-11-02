import 'dart:ui' show ImageFilter;

import 'package:fluent_ui/fluent_ui.dart';

import '../../../../data/models/player_models.dart';
import 'playback_details_overlay.dart';
import 'player_action_button.dart';

/// The pre-liquid-glass playback details surface: a static frosted panel with
/// no morph animation, anchored to the top-right of the player. Uses the same
/// [PlaybackDetailsPanel] content as the liquid glass style, with the close
/// button pinned to the panel's top-right corner.
///
/// Selected when the “播放详细信息动画” appearance setting is off.
class FrostedPlaybackDetails extends StatelessWidget {
  final PlayingInfoCache cache;
  final MediaTranscodeResponse? transcodeStatus;
  final double? bufferedSeconds;
  final VoidCallback onClose;
  final String closeTooltip;

  const FrostedPlaybackDetails({
    super.key,
    required this.cache,
    required this.transcodeStatus,
    required this.bufferedSeconds,
    required this.onClose,
    required this.closeTooltip,
  });

  static const Color _background = Color(0x99000000);
  static const Color _border = Color(0x33FFFFFF);
  static const double _maxWidth = 560;
  static const double _maxHeight = 530;
  static const double _radius = 16;
  static const double _contentPadding = 16;

  @override
  Widget build(BuildContext context) {
    final panelSize = MediaQuery.of(context).size;
    const radius = BorderRadius.all(Radius.circular(_radius));
    // The caller already wraps this in a full-size `Positioned.fill`; anchor
    // the panel to the top-right inside that box instead of returning another
    // `Positioned` (which would not be a direct child of the player's Stack).
    // `Align` without explicit width/height lets the panel shrink to its
    // content, and `ConstrainedBox` only caps that intrinsic size.
    return Padding(
      padding: const EdgeInsets.only(top: 56, right: 20),
      child: Align(
        alignment: Alignment.topRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: (panelSize.width - 32).clamp(0.0, _maxWidth),
            maxHeight: (panelSize.height - 76).clamp(0.0, _maxHeight),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
              child: Container(
                decoration: BoxDecoration(
                  color: _background,
                  borderRadius: radius,
                  border: Border.all(color: _border),
                ),
                padding: const EdgeInsets.all(_contentPadding),
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      child: IntrinsicWidth(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PlaybackDetailsPanel(
                              key: const ValueKey(
                                'player-playback-details-panel',
                              ),
                              cache: cache,
                              transcodeStatus: transcodeStatus,
                              bufferedSeconds: bufferedSeconds,
                            ),
                            // Keeps the content clear of the absolutely
                            // positioned close button's column.
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: PlayerActionButton.icon(
                        key: const ValueKey('player-playback-details-close'),
                        iconData: FluentIcons.chrome_close,
                        onPressed: onClose,
                        tooltip: closeTooltip,
                        size: 30,
                        iconSize: 14,
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
