import 'package:canvas_danmaku/canvas_danmaku.dart' as canvas;
import 'package:flutter/material.dart';

import '../../../../core/utils/app_fonts.dart';
import '../../../../data/models/fly_narwhal/index.dart';
import '../../../../providers/danmaku_controller.dart';

enum PlayerDanmakuType {
  scroll,
  top,
  bottom,
}

class PlayerDanmakuRenderItem {
  final String text;
  final Color color;
  final PlayerDanmakuType type;

  const PlayerDanmakuRenderItem({
    required this.text,
    required this.color,
    required this.type,
  });
}

class PlayerDanmakuRenderOptions {
  final double fontSize;
  final double area;
  final double durationSeconds;
  final double staticDurationSeconds;
  final double opacity;

  const PlayerDanmakuRenderOptions({
    required this.fontSize,
    required this.area,
    required this.durationSeconds,
    required this.staticDurationSeconds,
    required this.opacity,
  });
}

abstract interface class PlayerDanmakuRenderController {
  Widget buildView(Key key, PlayerDanmakuRenderOptions options);
  void add(PlayerDanmakuRenderItem item);
  void updateOptions(PlayerDanmakuRenderOptions options);
  void pause();
  void resume();
  void clear();
  void dispose();
}

typedef PlayerDanmakuRenderControllerFactory =
    PlayerDanmakuRenderController Function();

class PlayerDanmakuOverlay extends StatefulWidget {
  final List<Danmaku> danmakuList;
  final Duration position;
  final bool isPlaying;
  final double playbackRate;
  final bool isVisible;
  final DanmakuSettings settings;
  final DanmakuLoadStatus loadStatus;
  final int resetGeneration;
  final PlayerDanmakuRenderControllerFactory? renderControllerFactory;

  const PlayerDanmakuOverlay({
    super.key = const ValueKey('player-danmaku-overlay'),
    required this.danmakuList,
    required this.position,
    required this.isPlaying,
    required this.playbackRate,
    required this.isVisible,
    required this.settings,
    required this.loadStatus,
    required this.resetGeneration,
    this.renderControllerFactory,
  });

  @override
  State<PlayerDanmakuOverlay> createState() => _PlayerDanmakuOverlayState();
}

class _PlayerDanmakuOverlayState extends State<PlayerDanmakuOverlay> {
  static const int _dispatchLookBehindMs = 500;
  static const int _backwardJumpThresholdMs = 200;
  static const int _forwardJumpThresholdMs = 3000;

  late final PlayerDanmakuRenderController _renderController;
  List<Danmaku> _preparedDanmaku = const [];
  List<int> _startTimesMs = const [];
  int _nextDanmakuIndex = 0;
  int? _lastPositionMs;
  bool? _lastRunningState;

  @override
  void initState() {
    super.initState();
    _renderController = widget.renderControllerFactory?.call() ??
        CanvasPlayerDanmakuRenderController();
    _replaceDanmakuList();
    _renderController.updateOptions(_buildOptions());
    _synchronizePlaybackState(force: true);
  }

  @override
  void didUpdateWidget(covariant PlayerDanmakuOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.danmakuList != widget.danmakuList) {
      _replaceDanmakuList();
    }

    if (oldWidget.settings != widget.settings ||
        oldWidget.playbackRate != widget.playbackRate) {
      _renderController.updateOptions(_buildOptions());
    }

    final visibilityChanged = oldWidget.isVisible != widget.isVisible;
    final resetRequested = oldWidget.resetGeneration != widget.resetGeneration;
    final positionMs = widget.position.inMilliseconds;
    final positionJumped = _didPositionJump(positionMs);
    if (visibilityChanged || resetRequested || positionJumped) {
      _resetTimeline(positionMs);
    }

    _synchronizePlaybackState(force: visibilityChanged);
    if (widget.isPlaying && widget.isVisible) {
      _dispatchDueDanmaku(positionMs);
    }
    _lastPositionMs = positionMs;
  }

  @override
  void dispose() {
    _renderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) {
      return const SizedBox.expand();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        _renderController.buildView(
          const ValueKey('player-danmaku-canvas'),
          _buildOptions(),
        ),
        if (widget.settings.debugEnabled)
          Positioned(
            top: 16,
            right: 16,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'Danmaku ${widget.loadStatus.name}\n'
                    'position ${widget.position.inMilliseconds} ms\n'
                    'playing ${widget.isPlaying} · rate ${widget.playbackRate}\n'
                    'index $_nextDanmakuIndex / ${_preparedDanmaku.length}\n'
                    'reset ${widget.resetGeneration}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _replaceDanmakuList() {
    _renderController.clear();
    _preparedDanmaku = List<Danmaku>.unmodifiable(widget.danmakuList);
    _startTimesMs = List<int>.unmodifiable(
      _preparedDanmaku.map((danmaku) => (danmaku.time * 1000).round()),
    );
    _nextDanmakuIndex = _lowerBound(
      _startTimesMs,
      widget.position.inMilliseconds - _dispatchLookBehindMs,
    );
    _lastPositionMs = widget.position.inMilliseconds;
  }

  void _resetTimeline(int positionMs) {
    _renderController.clear();
    _nextDanmakuIndex = _lowerBound(
      _startTimesMs,
      positionMs - _dispatchLookBehindMs,
    );
    _lastPositionMs = positionMs;
  }

  bool _didPositionJump(int positionMs) {
    final lastPositionMs = _lastPositionMs;
    if (lastPositionMs == null) {
      return false;
    }
    final differenceMs = positionMs - lastPositionMs;
    return differenceMs < -_backwardJumpThresholdMs ||
        differenceMs > _forwardJumpThresholdMs;
  }

  void _dispatchDueDanmaku(int positionMs) {
    while (_nextDanmakuIndex < _preparedDanmaku.length) {
      final startTimeMs = _startTimesMs[_nextDanmakuIndex];
      if (startTimeMs > positionMs) {
        break;
      }

      final danmaku = _preparedDanmaku[_nextDanmakuIndex];
      _nextDanmakuIndex++;
      if (startTimeMs < positionMs - _dispatchLookBehindMs) {
        continue;
      }
      _renderController.add(_mapDanmaku(danmaku));
    }
  }

  void _synchronizePlaybackState({required bool force}) {
    final shouldRun = widget.isVisible && widget.isPlaying;
    if (!force && _lastRunningState == shouldRun) {
      return;
    }
    if (shouldRun) {
      _renderController.resume();
    } else {
      _renderController.pause();
    }
    _lastRunningState = shouldRun;
  }

  PlayerDanmakuRenderOptions _buildOptions() {
    final effectivePlaybackRate = widget.playbackRate.clamp(0.5, 16.0);
    final effectiveSpeed = widget.settings.syncPlaybackSpeed
        ? widget.settings.speed * effectivePlaybackRate
        : widget.settings.speed;
    final durationSeconds = (10.0 / effectiveSpeed).clamp(2.5, 20.0);
    final staticDurationSeconds = widget.settings.syncPlaybackSpeed
        ? 5.0 / effectivePlaybackRate
        : 5.0;
    return PlayerDanmakuRenderOptions(
      fontSize: 20.0 * widget.settings.fontSizeScale,
      area: widget.settings.area,
      durationSeconds: durationSeconds,
      staticDurationSeconds: staticDurationSeconds,
      opacity: widget.settings.opacity,
    );
  }

  PlayerDanmakuRenderItem _mapDanmaku(Danmaku danmaku) {
    return PlayerDanmakuRenderItem(
      text: danmaku.text,
      color: parseDanmakuColor(danmaku.color),
      type: mapDanmakuType(danmaku.mode),
    );
  }
}

PlayerDanmakuType mapDanmakuType(int mode) {
  switch (mode) {
    case 4:
      return PlayerDanmakuType.bottom;
    case 5:
      return PlayerDanmakuType.top;
    case 6:
      // Reverse scrolling is unsupported by canvas_danmaku.
      return PlayerDanmakuType.scroll;
    default:
      return PlayerDanmakuType.scroll;
  }
}

Color parseDanmakuColor(String value) {
  final normalizedValue = value.trim().replaceFirst('#', '');
  final parsedValue = int.tryParse(normalizedValue, radix: 16);
  if (parsedValue == null) {
    return Colors.white;
  }
  if (normalizedValue.length == 6) {
    return Color(0xFF000000 | parsedValue);
  }
  if (normalizedValue.length == 8) {
    return Color(parsedValue);
  }
  return Colors.white;
}

int _lowerBound(List<int> values, int target) {
  var lower = 0;
  var upper = values.length;
  while (lower < upper) {
    final middle = lower + ((upper - lower) >> 1);
    if (values[middle] < target) {
      lower = middle + 1;
    } else {
      upper = middle;
    }
  }
  return lower;
}

class CanvasPlayerDanmakuRenderController
    implements PlayerDanmakuRenderController {
  canvas.DanmakuController<void>? _controller;
  PlayerDanmakuRenderOptions? _latestOptions;
  bool _shouldRun = true;

  @override
  Widget buildView(Key key, PlayerDanmakuRenderOptions options) {
    _latestOptions = options;
    return canvas.DanmakuScreen<void>(
      key: key,
      option: _toCanvasOptions(options),
      createdController: (controller) {
        _controller = controller;
        controller.updateOption(_toCanvasOptions(_latestOptions ?? options));
        if (_shouldRun) {
          controller.resume();
        } else {
          controller.pause();
        }
      },
    );
  }

  @override
  void add(PlayerDanmakuRenderItem item) {
    _controller?.addDanmaku(
      canvas.DanmakuContentItem<void>(
        item.text,
        color: item.color,
        type: switch (item.type) {
          PlayerDanmakuType.scroll => canvas.DanmakuItemType.scroll,
          PlayerDanmakuType.top => canvas.DanmakuItemType.top,
          PlayerDanmakuType.bottom => canvas.DanmakuItemType.bottom,
        },
      ),
    );
  }

  @override
  void updateOptions(PlayerDanmakuRenderOptions options) {
    _latestOptions = options;
    _controller?.updateOption(_toCanvasOptions(options));
  }

  @override
  void pause() {
    _shouldRun = false;
    _controller?.pause();
  }

  @override
  void resume() {
    _shouldRun = true;
    _controller?.resume();
  }

  @override
  void clear() {
    _controller?.clear();
  }

  @override
  void dispose() {
    _controller = null;
  }

  canvas.DanmakuOption _toCanvasOptions(
    PlayerDanmakuRenderOptions options,
  ) {
    return canvas.DanmakuOption(
      fontSize: options.fontSize,
      fontWeight: 5,
      fontFamily: AppFonts.primary,
      area: options.area,
      duration: options.durationSeconds,
      staticDuration: options.staticDurationSeconds,
      opacity: options.opacity,
      strokeWidth: 1.5,
      safeArea: true,
      massiveMode: false,
      lineHeight: 1.6,
    );
  }
}
