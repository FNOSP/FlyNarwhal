import 'dart:ui' show lerpDouble;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// A top-right anchored liquid glass panel that morphs open and closed the
/// same way `GlassMenu` morphs from its trigger button.
///
/// The panel grows out of [anchor] (its top-right corner) toward the
/// bottom-left, driven by the iOS 26 underdamped spring, while the spawn
/// blob ghosts [spawnRect] (the trigger button's rect) exactly the way
/// `GlassMenu`'s Blob A stays centered on its trigger — the open blooms from
/// the button and the close collapses back into it. The final size is the
/// child's natural size clamped to [maxSize], so the glass never exceeds its
/// content. The child renders at full size inside the morphing shape and is
/// clipped to it, fading in while the glass settles — the content itself is
/// unchanged, matching how `GlassMenu` staggers its items in.
///
/// The morph only exists while the panel is open; it opens itself once the
/// child has been measured. Call [PlaybackDetailsMorphController.close] to
/// collapse it; [onSettled] reports when the surface has come to rest in
/// either state (use it to dispose the subtree on close).
class PlaybackDetailsMorph extends StatefulWidget {
  final PlaybackDetailsMorphController controller;

  /// Maximum size the panel may grow to; the child's natural size below
  /// these bounds wins.
  final Size maxSize;

  /// The panel's top-right corner, in the local coordinate space of the
  /// parent `Stack`.
  final Offset anchor;

  /// The trigger button's rect in the same coordinate space. The spawn blob
  /// covers it while open starts and the body collapses back into it on
  /// close, mirroring `GlassMenu`'s trigger ghost.
  final Rect spawnRect;
  final VoidCallback onSettled;
  final Widget child;

  /// A widget pinned to the top-right of the panel; it does not scroll with
  /// the body (e.g. the close button).
  final Widget? header;

  const PlaybackDetailsMorph({
    super.key,
    required this.controller,
    required this.maxSize,
    required this.anchor,
    required this.spawnRect,
    required this.onSettled,
    required this.child,
    this.header,
  });

  @override
  State<PlaybackDetailsMorph> createState() => _PlaybackDetailsMorphState();
}

class _PlaybackDetailsMorphState extends State<PlaybackDetailsMorph>
    with TickerProviderStateMixin {
  late final GlassMorphController _morph;
  bool _notifiedSettled = false;
  bool _hasOpened = false;
  Size? _naturalSize;

  // Matches the liquid glass toasts: no tint, no whitening veil and a low
  // blur, while a higher thickness plus refraction keeps the video backdrop
  // visibly warped through the glass.
  static const LiquidGlassSettings _glassSettings = LiquidGlassSettings(
    glassColor: Color.fromARGB(0, 255, 255, 255),
    thickness: 40,
    blur: 3,
    whitenStrength: 0,
    refractiveIndex: 30.0,
    lightIntensity: 0.5,
    ambientRim: 0.2,
    ambientStrength: 0.5,
    glowIntensity: 0.75,
    fresnelStrength: 0.8,
    edgeAbsorption: 0.41,
    backerColor: Color.fromARGB(50, 0, 0, 0),
  );

  static const double _panelRadius = 16;

  // The pre-glass panel kept its content 16px inside the surface; the padding
  // lives outside the scroll view (but inside the measurement probe) so the
  // glass grows to content + padding and scrolled content never touches the
  // glass edge.
  static const double _contentPadding = 16;

  /// The panel's destination size: the measured child size clamped to the
  /// caller's bounds.
  Size get _targetSize {
    final natural = _naturalSize;
    if (natural == null) return Size.zero;
    return Size(
      natural.width.clamp(0.0, widget.maxSize.width),
      natural.height.clamp(0.0, widget.maxSize.height),
    );
  }

  @override
  void initState() {
    super.initState();
    widget.controller._attach(this);
    _morph = GlassMorphController(vsync: this);
    _morph.addListener(_onMorphFrame);
  }

  @override
  void dispose() {
    widget.controller._detach(this);
    _morph.dispose();
    super.dispose();
  }

  void _open() {
    _notifiedSettled = false;
    _morph.open();
  }

  void _close() {
    _notifiedSettled = false;
    _morph.close();
  }

  void _onContentSizeMeasured(Size size) {
    if (!mounted) return;
    final firstMeasurement = _naturalSize == null;
    if (firstMeasurement || _naturalSize != size) {
      setState(() => _naturalSize = size);
    }
    // The destination geometry depends on the measured size, so the spring
    // starts only after the first measurement.
    if (!_hasOpened && firstMeasurement) {
      _hasOpened = true;
      _morph.open();
    }
  }

  void _onMorphFrame() {
    if (!mounted || !_hasOpened) return;
    setState(() {});

    // Settled detection must be direction-aware: at the first frame of a
    // close the body still equals the target size, so "reached target" would
    // report settled immediately and dispose the collapse animation. While
    // closing, only the spring resting at zero counts as settled.
    final target = _targetSize;
    final current = _currentSize();
    final settled = _morph.isClosing
        ? (_morph.value <= 0.001 && _morph.velocity.abs() < 0.5)
        : (target == Size.zero ||
              ((target.width - current.width).abs() < 0.5 &&
                  (target.height - current.height).abs() < 0.5));
    if (settled && !_notifiedSettled) {
      _notifiedSettled = true;
      widget.onSettled();
    }
  }

  Size _currentSize() {
    final t = _morph.value.clamp(0.0, 1.0);
    final target = _targetSize;
    return Size(
      lerpDouble(widget.spawnRect.width, target.width, t)!
          .clamp(0.0, double.infinity),
      lerpDouble(widget.spawnRect.height, target.height, t)!
          .clamp(0.0, double.infinity),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clampedValue = _morph.value.clamp(0.0, 1.0);
    final current = _currentSize();
    final currentWidth = current.width;
    final currentHeight = current.height;

    final maxRadius =
        currentWidth < currentHeight ? currentWidth : currentHeight;
    final radiusT = Curves.easeInExpo.transform(clampedValue);
    final currentRadius =
        lerpDouble(maxRadius / 2.0, _panelRadius, radiusT)!;

    // The spring value (with its underdamped overshoot) drives a squeeze
    // pulse on the body and the spawn blob's closing bounce.
    final state = _morph.computeState(finalDx: 0, finalDy: 0);

    // The body's top-right corner stays pinned to the anchor while the glass
    // grows toward the bottom-left.
    final bodyLeft = widget.anchor.dx - currentWidth;
    final bodyTop = widget.anchor.dy;

    return AdaptiveLiquidGlassLayer(
      settings: _glassSettings,
      clipBehavior: Clip.none,
      blendAmount: state.blend,
      child: LiquidGlassBlendGroup(
        blend: state.blend,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Spawn blob ghosting the trigger button; shrinks away as the
            // body takes over, and absorbs the closing momentum bounce.
            Positioned(
              left: widget.spawnRect.left + state.pushDx,
              top: widget.spawnRect.top + state.pushDy,
              child: Transform.scale(
                scale: state.anchorScale,
                child: GlassContainer(
                  width: widget.spawnRect.width,
                  height: widget.spawnRect.height,
                  settings: _glassSettings,
                  shape: LiquidRoundedRectangle(
                    borderRadius: widget.spawnRect.shortestSide / 2.0,
                  ),
                ),
              ),
            ),

            // The panel body growing out of the anchor.
            Positioned(
              left: bodyLeft,
              top: bodyTop,
              child: IgnorePointer(
                ignoring: clampedValue < 0.8,
                child: _buildPanelBody(
                  state,
                  currentWidth,
                  currentHeight,
                  currentRadius,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelBody(
    LiquidMorphState state,
    double width,
    double height,
    double radius,
  ) {
    // Sub-pixel bodies rasterize to a 0-area glass matte; skip them the same
    // way GlassMenu does. The body also stays hidden until the child has
    // been measured (destination size unknown).
    if (width < 1.0 || height < 1.0) return const SizedBox.shrink();

    final contentOpacity = Curves.easeOutCubic.transform(
      ((state.pathT - 0.3) / 0.7).clamp(0.0, 1.0),
    );
    final target = _targetSize;
    // Before the first measurement lands, lay the content out at the maximum
    // size so it reports a meaningful natural size.
    final boxWidth = target.width > 0 ? target.width : widget.maxSize.width;
    final boxHeight = target.height > 0 ? target.height : widget.maxSize.height;

    return GlassContainer(
      width: width,
      height: height,
      settings: _glassSettings,
      shape: LiquidRoundedRectangle(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      allowElevation: false,
      child: Transform.scale(
        scale: state.containerScale,
        alignment: Alignment.topRight,
        child: Opacity(
          opacity: contentOpacity,
          // The content keeps the panel's top-right corner aligned while
          // the glass grows, so the close button never drifts. The probe
          // lays the child out unconstrained to learn its natural size
          // (the scroll view alone would clamp the width to the growing
          // body); the glass clips the overflow while it is still growing.
          //
          // The header is layered above the scroll view via a Stack so it
          // stays fixed while the body scrolls.
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: SizedBox(
                  width: boxWidth,
                  height: boxHeight,
                  child: SingleChildScrollView(
                    child: _NaturalSizeProbe(
                      maxWidth: widget.maxSize.width,
                      onChange: _onContentSizeMeasured,
                      child: Padding(
                        padding: const EdgeInsets.all(_contentPadding),
                        child: widget.child,
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.header != null)
                Positioned(
                  top: _contentPadding,
                  right: _contentPadding,
                  child: widget.header!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lays its child out at its intrinsic (natural) size and reports it via
/// [onChange], while itself taking whatever size the parent allows. Inside
/// the panel's scroll view this is the only way to learn the content's true
/// size: the scroll view clamps its child's width to the (still growing)
/// glass body, which would feed the measurement back into itself. The
/// intrinsic pass mirrors the `IntrinsicWidth` the panel was originally
/// wrapped in — greedy children (e.g. `Expanded` rows) collapse to their
/// widest content instead of running to infinity.
class _NaturalSizeProbe extends SingleChildRenderObjectWidget {
  final double maxWidth;
  final void Function(Size) onChange;

  const _NaturalSizeProbe({
    required this.maxWidth,
    required this.onChange,
    required super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _NaturalSizeProbeRenderObject(maxWidth, onChange);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _NaturalSizeProbeRenderObject renderObject,
  ) {
    renderObject.maxWidth = maxWidth;
    renderObject.onChange = onChange;
  }
}

class _NaturalSizeProbeRenderObject extends RenderShiftedBox {
  _NaturalSizeProbeRenderObject(this.maxWidth, this.onChange) : super(null);

  double maxWidth;
  void Function(Size) onChange;
  Size? _previousSize;

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    final naturalWidth = child.getMaxIntrinsicWidth(double.infinity);
    final width = naturalWidth.clamp(0.0, maxWidth);
    child.layout(
      BoxConstraints.tightFor(width: width),
      parentUsesSize: true,
    );
    size = constraints.constrain(child.size);
    final childParentData = child.parentData as BoxParentData;
    childParentData.offset = Offset(
      size.width - child.size.width,
      0,
    );
    if (child.size != _previousSize) {
      _previousSize = child.size;
      WidgetsBinding.instance.addPostFrameCallback((_) => onChange(child.size));
    }
  }
}

/// Drives a [PlaybackDetailsMorph] open and closed with the liquid morph
/// spring, mirroring `GlassMenuController`.
class PlaybackDetailsMorphController {
  _PlaybackDetailsMorphState? _state;

  void _attach(_PlaybackDetailsMorphState state) => _state = state;

  void _detach(_PlaybackDetailsMorphState state) {
    if (identical(_state, state)) _state = null;
  }

  void open() => _state?._open();

  void close() => _state?._close();
}
