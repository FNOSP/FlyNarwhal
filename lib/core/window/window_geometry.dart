import 'dart:ui';

class DesktopDisplayGeometry {
  const DesktopDisplayGeometry({
    required this.id,
    required this.monitorBounds,
    required this.workArea,
    required this.isPrimary,
    required this.scaleFactor,
  });

  final String id;
  final Rect monitorBounds;
  final Rect workArea;
  final bool isPrimary;
  final double scaleFactor;
}

class WindowGeometry {
  const WindowGeometry._();

  static bool isValidBounds(Rect bounds) {
    return bounds.left.isFinite &&
        bounds.top.isFinite &&
        bounds.width.isFinite &&
        bounds.height.isFinite &&
        bounds.width > 0 &&
        bounds.height > 0;
  }

  static DesktopDisplayGeometry? selectDisplay(
    Rect bounds,
    List<DesktopDisplayGeometry> displays,
  ) {
    if (displays.isEmpty) {
      return null;
    }

    final center = bounds.center;
    for (final display in displays) {
      if (display.monitorBounds.contains(center)) {
        return display;
      }
    }

    DesktopDisplayGeometry? displayWithLargestIntersection;
    double largestIntersectionArea = 0;
    for (final display in displays) {
      final intersection = bounds.intersect(display.monitorBounds);
      final intersectionArea =
          intersection.isEmpty ? 0.0 : intersection.width * intersection.height;
      if (intersectionArea > largestIntersectionArea) {
        largestIntersectionArea = intersectionArea;
        displayWithLargestIntersection = display;
      }
    }

    return displayWithLargestIntersection ?? _primaryDisplay(displays);
  }

  static Rect normalizeMainWindowBounds(
    Rect requestedBounds,
    List<DesktopDisplayGeometry> displays, {
    Size fallbackSize = const Size(1280, 720),
    Size minimumSize = const Size(640, 360),
  }) {
    if (displays.isEmpty) {
      return isValidBounds(requestedBounds)
          ? requestedBounds
          : Rect.fromLTWH(0, 0, fallbackSize.width, fallbackSize.height);
    }

    final hasValidBounds = isValidBounds(requestedBounds);
    final targetDisplay = hasValidBounds
        ? selectDisplay(requestedBounds, displays) ?? _primaryDisplay(displays)
        : _primaryDisplay(displays);
    final workArea = targetDisplay.workArea;
    final sourceSize = hasValidBounds ? requestedBounds.size : fallbackSize;
    final fittedSize = _fitSizeToWorkArea(sourceSize, workArea, minimumSize);

    if (!hasValidBounds || !_intersectsAnyDisplay(requestedBounds, displays)) {
      return _centerInWorkArea(fittedSize, workArea);
    }

    return _clampFullyVisible(
      Rect.fromLTWH(
        requestedBounds.left,
        requestedBounds.top,
        fittedSize.width,
        fittedSize.height,
      ),
      workArea,
    );
  }

  static Rect normalizePipBounds(
    Rect requestedBounds,
    List<DesktopDisplayGeometry> displays, {
    double margin = 24,
    Size fallbackSize = const Size(320, 180),
  }) {
    if (displays.isEmpty) {
      return isValidBounds(requestedBounds)
          ? requestedBounds
          : Rect.fromLTWH(
              margin, margin, fallbackSize.width, fallbackSize.height);
    }

    final hasValidBounds = isValidBounds(requestedBounds);
    final intersectsDisplay =
        hasValidBounds && _intersectsAnyDisplay(requestedBounds, displays);
    final targetDisplay = intersectsDisplay
        ? selectDisplay(requestedBounds, displays) ?? _primaryDisplay(displays)
        : _primaryDisplay(displays);
    final workArea = targetDisplay.workArea;
    final sourceSize = hasValidBounds ? requestedBounds.size : fallbackSize;
    final fittedSize = _fitSizeToWorkArea(
      sourceSize,
      workArea.deflate(margin),
      const Size(1, 1),
    );

    if (!intersectsDisplay) {
      return Rect.fromLTWH(
        workArea.right - fittedSize.width - margin,
        workArea.bottom - fittedSize.height - margin,
        fittedSize.width,
        fittedSize.height,
      );
    }

    return _clampFullyVisible(
      Rect.fromLTWH(
        requestedBounds.left,
        requestedBounds.top,
        fittedSize.width,
        fittedSize.height,
      ),
      workArea.deflate(margin),
    );
  }

  static DesktopDisplayGeometry _primaryDisplay(
    List<DesktopDisplayGeometry> displays,
  ) {
    return displays.firstWhere(
      (display) => display.isPrimary,
      orElse: () => displays.first,
    );
  }

  static bool _intersectsAnyDisplay(
    Rect bounds,
    List<DesktopDisplayGeometry> displays,
  ) {
    return displays.any(
      (display) => !bounds.intersect(display.monitorBounds).isEmpty,
    );
  }

  static Size _fitSizeToWorkArea(
    Size requestedSize,
    Rect workArea,
    Size minimumSize,
  ) {
    final availableWidth = workArea.width <= 0 ? 1.0 : workArea.width;
    final availableHeight = workArea.height <= 0 ? 1.0 : workArea.height;
    final minimumWidth =
        minimumSize.width.clamp(1.0, availableWidth).toDouble();
    final minimumHeight =
        minimumSize.height.clamp(1.0, availableHeight).toDouble();
    return Size(
      requestedSize.width.clamp(minimumWidth, availableWidth).toDouble(),
      requestedSize.height.clamp(minimumHeight, availableHeight).toDouble(),
    );
  }

  static Rect _centerInWorkArea(Size size, Rect workArea) {
    return Rect.fromLTWH(
      workArea.left + (workArea.width - size.width) / 2,
      workArea.top + (workArea.height - size.height) / 2,
      size.width,
      size.height,
    );
  }

  static Rect _clampFullyVisible(Rect bounds, Rect workArea) {
    final maximumLeft = workArea.right - bounds.width;
    final maximumTop = workArea.bottom - bounds.height;
    return Rect.fromLTWH(
      bounds.left.clamp(workArea.left, maximumLeft).toDouble(),
      bounds.top.clamp(workArea.top, maximumTop).toDouble(),
      bounds.width,
      bounds.height,
    );
  }
}
