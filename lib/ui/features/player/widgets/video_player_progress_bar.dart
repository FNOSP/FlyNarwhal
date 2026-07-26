import 'package:fluent_ui/fluent_ui.dart';

import '../models/resolved_skip_segments.dart';

const playerProgressBarKey = ValueKey('player-progress-bar');
const playerProgressBarCanvasKey = ValueKey('player-progress-bar-canvas');
const playerProgressBarTimestampKey = ValueKey('player-progress-bar-timestamp');
const _hoverTimestampWidth = 60.0;

// Format duration to HH:MM:SS or MM:SS
String formatDurationToDateTime(int milliseconds) {
  final totalSeconds = milliseconds ~/ 1000;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;

  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

class VideoPlayerProgressBar extends StatefulWidget {
  const VideoPlayerProgressBar({
    super.key = playerProgressBarKey,
    required this.currentPosition,
    required this.totalDuration,
    this.buffered = 0.0,
    required this.onSeek,
    this.onInteractionStart,
    this.onInteractionEnd,
    this.onInteractionCancel,
    this.introSegment,
    this.creditsSegment,
    @Deprecated('Use introSegment instead.') this.introSegmentMillis,
    @Deprecated('Use creditsSegment instead.') this.creditsSegmentMillis,
    this.showHoverTimestamp = true,
  });

  final int currentPosition;
  final int totalDuration;
  final double buffered;
  final ValueChanged<double> onSeek;
  final VoidCallback? onInteractionStart;
  final VoidCallback? onInteractionEnd;
  final VoidCallback? onInteractionCancel;
  final SkipSegmentMillis? introSegment;
  final SkipSegmentMillis? creditsSegment;
  final (int, int)? introSegmentMillis;
  final (int, int)? creditsSegmentMillis;
  final bool showHoverTimestamp;

  SkipSegmentMillis? get effectiveIntroSegment =>
      introSegment ?? _convertLegacySegment(introSegmentMillis);

  SkipSegmentMillis? get effectiveCreditsSegment =>
      creditsSegment ?? _convertLegacySegment(creditsSegmentMillis);

  static SkipSegmentMillis? _convertLegacySegment((int, int)? segment) {
    if (segment == null || segment.$1 < 0 || segment.$2 <= segment.$1) {
      return null;
    }
    return SkipSegmentMillis(
      startMilliseconds: segment.$1,
      endMilliseconds: segment.$2,
    );
  }

  @override
  State<VideoPlayerProgressBar> createState() => _VideoPlayerProgressBarState();
}

class _VideoPlayerProgressBarState extends State<VideoPlayerProgressBar> {
  bool _isHovered = false;
  bool _isDragging = false;
  bool _hasActiveInteraction = false;
  double _hoverPositionX = 0.0;
  double _layoutWidth = 0.0;

  bool get _showDetails => _isHovered || _isDragging;

  double get _progress {
    if (widget.totalDuration <= 0) return 0.0;
    return widget.currentPosition / widget.totalDuration;
  }

  (double, double)? get _introRangeRatio =>
      _calculateRangeRatio(widget.effectiveIntroSegment);

  (double, double)? get _creditsRangeRatio =>
      _calculateRangeRatio(widget.effectiveCreditsSegment);

  (double, double)? _calculateRangeRatio(SkipSegmentMillis? segment) {
    if (widget.totalDuration <= 0 || segment == null) return null;
    final start = segment.startMilliseconds.clamp(0, widget.totalDuration);
    final end = segment.endMilliseconds.clamp(0, widget.totalDuration);
    if (end <= start) return null;
    return (start / widget.totalDuration, end / widget.totalDuration);
  }

  void _seekAt(Offset offset, double width) {
    if (width <= 0) return;
    final progress = (offset.dx / width).clamp(0.0, 1.0);
    widget.onSeek(progress);
  }

  void _startInteraction() {
    if (_hasActiveInteraction) return;
    _hasActiveInteraction = true;
    widget.onInteractionStart?.call();
  }

  void _finishInteraction({required bool wasCancelled}) {
    if (!_hasActiveInteraction) return;
    _hasActiveInteraction = false;
    if (wasCancelled) {
      (widget.onInteractionCancel ?? widget.onInteractionEnd)?.call();
      return;
    }
    widget.onInteractionEnd?.call();
  }

  void _finishDrag({required bool wasCancelled}) {
    if (mounted) {
      setState(() => _isDragging = false);
    }
    _finishInteraction(wasCancelled: wasCancelled);
  }

  @override
  Widget build(BuildContext context) {
    final barHeight = _showDetails ? 6.0 : 3.0;
    final thumbRadius = _showDetails ? 8.0 : 0.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      onHover: (event) {
        setState(() => _hoverPositionX = event.localPosition.dx);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {
          _startInteraction();
          final renderBox = context.findRenderObject() as RenderBox;
          _seekAt(details.localPosition, renderBox.size.width);
        },
        onTapUp: (_) => _finishInteraction(wasCancelled: false),
        onTapCancel: () => _finishInteraction(wasCancelled: true),
        onHorizontalDragStart: (details) {
          _startInteraction();
          setState(() {
            _isDragging = true;
            _hoverPositionX = details.localPosition.dx;
          });
          final renderBox = context.findRenderObject() as RenderBox;
          _seekAt(details.localPosition, renderBox.size.width);
        },
        onHorizontalDragUpdate: (details) {
          setState(() => _hoverPositionX = details.localPosition.dx);
          final renderBox = context.findRenderObject() as RenderBox;
          _seekAt(details.localPosition, renderBox.size.width);
        },
        onHorizontalDragEnd: (_) => _finishDrag(wasCancelled: false),
        onHorizontalDragCancel: () => _finishDrag(wasCancelled: true),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              _layoutWidth = constraints.maxWidth;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  CustomPaint(
                    key: playerProgressBarCanvasKey,
                    size: Size(constraints.maxWidth, barHeight),
                    painter: _ProgressBarPainter(
                      progress: _progress,
                      buffered: widget.buffered,
                      introRangeRatio: _introRangeRatio,
                      creditsRangeRatio: _creditsRangeRatio,
                      showDetails: _showDetails,
                      barHeight: barHeight,
                      thumbRadius: thumbRadius,
                    ),
                  ),
                  if (_showDetails &&
                      widget.showHoverTimestamp &&
                      _layoutWidth > 0)
                    Positioned(
                      left: _calculateTimestampPosition(),
                      bottom: barHeight + 8,
                      child: SizedBox(
                        width: _hoverTimestampWidth,
                        child: _HoverTimestamp(
                          key: playerProgressBarTimestampKey,
                          hoverProgress: _hoverPositionX / _layoutWidth,
                          totalDuration: widget.totalDuration,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  double _calculateTimestampPosition() {
    if (_layoutWidth <= 0) return 0;
    final position = _hoverPositionX - _hoverTimestampWidth / 2;
    return position.clamp(0.0, _layoutWidth - _hoverTimestampWidth);
  }
}

class _ProgressBarPainter extends CustomPainter {
  final double progress;
  final double buffered;
  final (double, double)? introRangeRatio;
  final (double, double)? creditsRangeRatio;
  final bool showDetails;
  final double barHeight;
  final double thumbRadius;

  _ProgressBarPainter({
    required this.progress,
    required this.buffered,
    this.introRangeRatio,
    this.creditsRangeRatio,
    required this.showDetails,
    required this.barHeight,
    required this.thumbRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final trackYCenter = size.height / 2;
    final trackStrokeWidth = barHeight;

    // 1. Background track (unplayed part)
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = trackStrokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(0, trackYCenter),
      Offset(size.width, trackYCenter),
      bgPaint,
    );

    // 2. Intro segment marker
    if (introRangeRatio != null) {
      _drawSegmentMarker(
          canvas, size, introRangeRatio!, trackYCenter, trackStrokeWidth);
    }

    // 3. Credits segment marker
    if (creditsRangeRatio != null) {
      _drawSegmentMarker(
          canvas, size, creditsRangeRatio!, trackYCenter, trackStrokeWidth);
    }

    // 4. Buffered progress
    final bufferedEndX = buffered.clamp(0.0, 1.0) * size.width;
    final activeEndX = progress.clamp(0.0, 1.0) * size.width;
    if (bufferedEndX > 0) {
      final bufferedPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..strokeWidth = trackStrokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(0, trackYCenter),
        Offset(bufferedEndX, trackYCenter),
        bufferedPaint,
      );
    }

    // 5. Active progress (blue)
    if (activeEndX > 0) {
      final activePaint = Paint()
        ..color = const Color(0xFF3B82F6)
        ..strokeWidth = trackStrokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(0, trackYCenter),
        Offset(activeEndX, trackYCenter),
        activePaint,
      );
    }

    // 6. Segment markers (vertical lines or dots)
    _drawSegmentMarkers(canvas, size, trackYCenter);

    // 7. Thumb (white circle)
    if (showDetails) {
      final thumbPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(activeEndX, trackYCenter),
        thumbRadius / 2,
        thumbPaint,
      );
    }
  }

  void _drawSegmentMarker(
    Canvas canvas,
    Size size,
    (double, double) range,
    double trackYCenter,
    double trackStrokeWidth,
  ) {
    final segmentColor = const Color(0xFF22C55E).withValues(alpha: 0.45);
    final startX = range.$1.clamp(0.0, 1.0) * size.width;
    final endX = range.$2.clamp(0.0, 1.0) * size.width;

    if (endX <= startX) return;

    final segmentPaint = Paint()
      ..color = segmentColor
      ..strokeWidth = trackStrokeWidth
      ..strokeCap = StrokeCap.butt
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(startX, trackYCenter),
      Offset(endX, trackYCenter),
      segmentPaint,
    );
  }

  void _drawSegmentMarkers(Canvas canvas, Size size, double trackYCenter) {
    final markerXList = <double>[];

    if (introRangeRatio != null) {
      final startX = introRangeRatio!.$1.clamp(0.0, 1.0) * size.width;
      final endX = introRangeRatio!.$2.clamp(0.0, 1.0) * size.width;
      if (endX > startX) {
        markerXList.add(startX);
        markerXList.add(endX);
      }
    }

    if (creditsRangeRatio != null) {
      final startX = creditsRangeRatio!.$1.clamp(0.0, 1.0) * size.width;
      final endX = creditsRangeRatio!.$2.clamp(0.0, 1.0) * size.width;
      if (endX > startX) {
        markerXList.add(startX);
        markerXList.add(endX);
      }
    }

    for (final x in markerXList) {
      if (showDetails) {
        // Draw vertical line when expanded
        final linePaint = Paint()
          ..color = Colors.white
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, size.height),
          linePaint,
        );
      } else {
        // Draw small dot when collapsed
        final dotPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset(x, trackYCenter),
          1.0,
          dotPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressBarPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        buffered != oldDelegate.buffered ||
        introRangeRatio != oldDelegate.introRangeRatio ||
        creditsRangeRatio != oldDelegate.creditsRangeRatio ||
        showDetails != oldDelegate.showDetails ||
        barHeight != oldDelegate.barHeight ||
        thumbRadius != oldDelegate.thumbRadius;
  }
}

class _HoverTimestamp extends StatelessWidget {
  final double hoverProgress;
  final int totalDuration;

  const _HoverTimestamp({
    super.key,
    required this.hoverProgress,
    required this.totalDuration,
  });

  @override
  Widget build(BuildContext context) {
    final hoverTimeMillis =
        (hoverProgress.clamp(0.0, 1.0) * totalDuration).toInt();
    final timeText = formatDurationToDateTime(hoverTimeMillis);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 2,
            offset: const Offset(1, 1),
          ),
        ],
      ),
      child: Text(
        timeText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
