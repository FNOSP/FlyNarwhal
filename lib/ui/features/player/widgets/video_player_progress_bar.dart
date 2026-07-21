import 'package:fluent_ui/fluent_ui.dart';

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
  final int currentPosition;
  final int totalDuration;
  final double buffered;
  final void Function(double progress) onSeek;
  final VoidCallback? onInteractionEnd;
  final (int, int)? introSegmentMillis;
  final (int, int)? creditsSegmentMillis;

  const VideoPlayerProgressBar({
    super.key,
    required this.currentPosition,
    required this.totalDuration,
    this.buffered = 0.0,
    required this.onSeek,
    this.onInteractionEnd,
    this.introSegmentMillis,
    this.creditsSegmentMillis,
  });

  @override
  State<VideoPlayerProgressBar> createState() => _VideoPlayerProgressBarState();
}

class _VideoPlayerProgressBarState extends State<VideoPlayerProgressBar> {
  bool _isHovered = false;
  bool _isDragging = false;
  double _hoverPositionX = 0.0;
  double _layoutWidth = 0.0;

  bool get _showDetails => _isHovered || _isDragging;

  double get _progress {
    if (widget.totalDuration <= 0) return 0.0;
    return widget.currentPosition / widget.totalDuration;
  }

  (double, double)? get _introRangeRatio {
    if (widget.totalDuration <= 0) return null;
    final segment = widget.introSegmentMillis;
    if (segment == null) return null;
    final start = segment.$1.clamp(0, widget.totalDuration);
    final end = segment.$2.clamp(0, widget.totalDuration);
    if (end <= start) return null;
    return (start / widget.totalDuration, end / widget.totalDuration);
  }

  (double, double)? get _creditsRangeRatio {
    if (widget.totalDuration <= 0) return null;
    final segment = widget.creditsSegmentMillis;
    if (segment == null) return null;
    final start = segment.$1.clamp(0, widget.totalDuration);
    final end = segment.$2.clamp(0, widget.totalDuration);
    if (end <= start) return null;
    return (start / widget.totalDuration, end / widget.totalDuration);
  }

  void _handleTap(Offset offset, double width) {
    final progress = (offset.dx / width).clamp(0.0, 1.0);
    widget.onSeek(progress);
    widget.onInteractionEnd?.call();
  }

  void _handleDrag(Offset offset, double width) {
    final progress = (offset.dx / width).clamp(0.0, 1.0);
    widget.onSeek(progress);
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
          final RenderBox box = context.findRenderObject() as RenderBox;
          _handleTap(details.localPosition, box.size.width);
        },
        onHorizontalDragStart: (_) => setState(() => _isDragging = true),
        onHorizontalDragUpdate: (details) {
          final RenderBox box = context.findRenderObject() as RenderBox;
          _handleDrag(details.localPosition, box.size.width);
        },
        onHorizontalDragEnd: (_) {
          setState(() => _isDragging = false);
          widget.onInteractionEnd?.call();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              _layoutWidth = constraints.maxWidth;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Progress bar canvas
                  CustomPaint(
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
                  // Hover timestamp
                  if (_showDetails && _layoutWidth > 0)
                    Positioned(
                      left: _calculateTimestampPosition(),
                      bottom: barHeight + 8,
                      child: _HoverTimestamp(
                        hoverProgress: _hoverPositionX / _layoutWidth,
                        totalDuration: widget.totalDuration,
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
    const timestampWidth = 60.0;
    final position = _hoverPositionX - timestampWidth / 2;
    return position.clamp(0.0, _layoutWidth - timestampWidth);
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
      _drawSegmentMarker(canvas, size, introRangeRatio!, trackYCenter, trackStrokeWidth);
    }

    // 3. Credits segment marker
    if (creditsRangeRatio != null) {
      _drawSegmentMarker(canvas, size, creditsRangeRatio!, trackYCenter, trackStrokeWidth);
    }

    // 4. Buffered progress
    final bufferedEndX = buffered.clamp(0.0, 1.0) * size.width;
    if (bufferedEndX > 0) {
      final bufferedPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
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
    final activeEndX = progress.clamp(0.0, 1.0) * size.width;
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
    required this.hoverProgress,
    required this.totalDuration,
  });

  @override
  Widget build(BuildContext context) {
    final hoverTimeMillis = (hoverProgress.clamp(0.0, 1.0) * totalDuration).toInt();
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
