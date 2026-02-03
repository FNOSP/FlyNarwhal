import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SpeedItem {
  final String label;
  final double value;

  const SpeedItem(this.label, this.value);
}

const List<SpeedItem> speeds = [
  SpeedItem("2.0x", 2.0),
  SpeedItem("1.75x", 1.75),
  SpeedItem("1.5x", 1.5),
  SpeedItem("1.25x", 1.25),
  SpeedItem("1.0x", 1.0),
  SpeedItem("0.75x", 0.75),
  SpeedItem("0.5x", 0.5),
];

const int _flyoutAnimationDurationMs = 200;

class SpeedFlyoutState {
  final Size buttonSize;
  final bool isExpanded;
  final bool isButtonHovered;
  final bool isPopupHovered;
  final String? hoveredLabel;

  const SpeedFlyoutState({
    this.buttonSize = Size.zero,
    this.isExpanded = false,
    this.isButtonHovered = false,
    this.isPopupHovered = false,
    this.hoveredLabel,
  });

  SpeedFlyoutState copyWith({
    Size? buttonSize,
    bool? isExpanded,
    bool? isButtonHovered,
    bool? isPopupHovered,
    String? hoveredLabel,
  }) {
    return SpeedFlyoutState(
      buttonSize: buttonSize ?? this.buttonSize,
      isExpanded: isExpanded ?? this.isExpanded,
      isButtonHovered: isButtonHovered ?? this.isButtonHovered,
      isPopupHovered: isPopupHovered ?? this.isPopupHovered,
      hoveredLabel: hoveredLabel,
    );
  }
}

class SpeedFlyoutController extends StateNotifier<SpeedFlyoutState> {
  SpeedFlyoutController() : super(const SpeedFlyoutState());

  void setButtonSize(Size value) {
    state = state.copyWith(buttonSize: value);
  }

  void setExpanded(bool value) {
    state = state.copyWith(isExpanded: value);
  }

  void setButtonHovered(bool value) {
    state = state.copyWith(isButtonHovered: value);
  }

  void setPopupHovered(bool value) {
    state = state.copyWith(isPopupHovered: value);
  }

  void setHoveredLabel(String? value) {
    state = state.copyWith(hoveredLabel: value);
  }
}

final _speedFlyoutProvider = StateNotifierProvider.autoDispose<SpeedFlyoutController, SpeedFlyoutState>(
  (ref) => SpeedFlyoutController(),
);

class SpeedControlFlyout extends HookConsumerWidget {
  final double currentSpeed;
  final ValueChanged<double> onSpeedChanged;

  const SpeedControlFlyout({
    super.key,
    required this.currentSpeed,
    required this.onSpeedChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const int hideDelayMs = 200;
    const double flyoutWidth = 120;

    final buttonKey = useMemoized(GlobalKey.new);
    final hideTimer = useRef<Timer?>(null);
    final animationController = useAnimationController(
      duration: const Duration(milliseconds: _flyoutAnimationDurationMs),
    );
    final isMounted = useRef(true);

    void updateButtonSizeAfterFrame() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final ctx = buttonKey.currentContext;
        if (ctx == null) return;
        final renderObject = ctx.findRenderObject();
        if (renderObject is! RenderBox) return;
        if (!renderObject.hasSize) return;
        final nextSize = renderObject.size;
        final currentSize = ref.read(_speedFlyoutProvider).buttonSize;
        if (nextSize == currentSize) return;
        ref.read(_speedFlyoutProvider.notifier).setButtonSize(nextSize);
      });
    }

    void showFlyout() {
      hideTimer.value?.cancel();
      if (!ref.read(_speedFlyoutProvider).isExpanded) {
        ref.read(_speedFlyoutProvider.notifier).setExpanded(true);
      }
    }

    Future<void> animateClose() async {
      if (!ref.read(_speedFlyoutProvider).isExpanded) return;
      if (animationController.status == AnimationStatus.dismissed) {
        ref.read(_speedFlyoutProvider.notifier).setExpanded(false);
        return;
      }
      await animationController.reverse();
      if (!isMounted.value) return;
      ref.read(_speedFlyoutProvider.notifier).setExpanded(false);
    }

    void hideFlyoutWithDelay() {
      hideTimer.value?.cancel();
      hideTimer.value = Timer(const Duration(milliseconds: hideDelayMs), () {
        final state = ref.read(_speedFlyoutProvider);
        if (context.mounted && !state.isButtonHovered && !state.isPopupHovered) {
          animateClose();
        }
      });
    }

    useEffect(() {
      return () {
        isMounted.value = false;
        hideTimer.value?.cancel();
      };
    }, const []);

    final flyoutState = ref.watch(_speedFlyoutProvider);
    useEffect(() {
      if (flyoutState.isExpanded) {
        animationController.forward(from: 0);
      }
      return null;
    }, [flyoutState.isExpanded]);

    updateButtonSizeAfterFrame();

    String label = "倍速";
    try {
      final item = speeds.firstWhere((s) => (s.value - currentSpeed).abs() < 0.01);
      if (item.label != "1.0x") {
        label = item.label;
      }
    } catch (_) {}

    final button = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        ref.read(_speedFlyoutProvider.notifier).setButtonHovered(true);
        showFlyout();
      },
      onExit: (_) {
        ref.read(_speedFlyoutProvider.notifier).setButtonHovered(false);
        hideFlyoutWithDelay();
      },
      child: KeyedSubtree(
        key: buttonKey,
        child: GestureDetector(
          onTap: () async {
            if (flyoutState.isExpanded) {
              await animateClose();
            } else {
              showFlyout();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Text(
              label,
              style: TextStyle(
                color: flyoutState.isButtonHovered || flyoutState.isExpanded ? Colors.white : Colors.white.withAlpha(200),
                fontSize: 17,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );

    final popup = flyoutState.isExpanded
        ? Positioned(
            left: (flyoutState.buttonSize.width - flyoutWidth) / 2,
            bottom: flyoutState.buttonSize.height,
            child: MouseRegion(
              onEnter: (_) {
                ref.read(_speedFlyoutProvider.notifier).setPopupHovered(true);
                hideTimer.value?.cancel();
              },
              onExit: (_) {
                ref.read(_speedFlyoutProvider.notifier).setPopupHovered(false);
                hideFlyoutWithDelay();
              },
              cursor: SystemMouseCursors.basic,
              child: Material(
                color: Colors.transparent,
                elevation: 0,
                child: FlyoutWithAnimation(
                  controller: animationController,
                  speeds: speeds,
                  selectedSpeed: currentSpeed,
                  onSpeedClick: (speed) {
                    onSpeedChanged(speed);
                    ref.read(_speedFlyoutProvider.notifier).setPopupHovered(false);
                    animateClose();
                  },
                ),
              ),
            ),
          )
        : null;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        if (popup != null) popup,
      ],
    );
  }
}

class FlyoutWithAnimation extends HookWidget {
  final AnimationController controller;
  final List<SpeedItem> speeds;
  final double selectedSpeed;
  final ValueChanged<double> onSpeedClick;

  const FlyoutWithAnimation({
    super.key,
    required this.controller,
    required this.speeds,
    required this.selectedSpeed,
    required this.onSpeedClick,
  });

  @override
  Widget build(BuildContext context) {
    final alpha = useMemoized(
      () => Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.linear),
      ),
      [controller],
    );
    final scale = useMemoized(
      () => Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.linear),
      ),
      [controller],
    );
    final offsetY = useMemoized(
      () => Tween<double>(begin: 10.0, end: 0.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.linear),
      ),
      [controller],
    );

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Opacity(
          opacity: alpha.value,
          child: Transform.translate(
            offset: Offset(0, offsetY.value),
            child: Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.diagonal3Values(scale.value, scale.value, 1.0),
              child: child,
            ),
          ),
        );
      },
      child: FlyoutContent(
        speeds: speeds,
        selectedSpeed: selectedSpeed,
        onSpeedClick: onSpeedClick,
      ),
    );
  }
}

class FlyoutContent extends StatelessWidget {
  final List<SpeedItem> speeds;
  final double selectedSpeed;
  final ValueChanged<double> onSpeedClick;

  const FlyoutContent({
    super.key,
    required this.speeds,
    required this.selectedSpeed,
    required this.onSpeedClick,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(230),
        border: Border.all(
          color: const Color(0x809E9E9E),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: speeds.map((speed) {
          final isSelected = (speed.value - selectedSpeed).abs() < 0.01;
          return FlyoutItem(
            speed: speed,
            isSelected: isSelected,
            onClick: () => onSpeedClick(speed.value),
          );
        }).toList(),
      ),
    );
  }
}

class FlyoutItem extends ConsumerWidget {
  final SpeedItem speed;
  final bool isSelected;
  final VoidCallback onClick;

  const FlyoutItem({
    super.key,
    required this.speed,
    required this.isSelected,
    required this.onClick,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const hoverBackgroundColor = Color(0x1AFFFFFF);
    const selectedTextColor = Color(0xFF2073DF);
    const defaultTextColor = Color(0xC8FFFFFF);
    final isHovered = ref.watch(_speedFlyoutProvider).hoveredLabel == speed.label;

    return MouseRegion(
      onEnter: (_) => ref.read(_speedFlyoutProvider.notifier).setHoveredLabel(speed.label),
      onExit: (_) => ref.read(_speedFlyoutProvider.notifier).setHoveredLabel(null),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onClick,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isHovered ? hoverBackgroundColor : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                speed.label,
                style: TextStyle(
                  color: isSelected ? selectedTextColor : defaultTextColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check,
                  color: defaultTextColor,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
