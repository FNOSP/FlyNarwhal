import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:uuid/uuid.dart';

import 'window_caption.dart';

const Duration _defaultToastDuration = Duration(seconds: 2);
const Duration _toastAnimationDuration = Duration(milliseconds: 300);

enum ToastType {
  success,
  failed,
  info,
  warning,
}

// Build warning message based on missing FlyNarwhal config fields
String buildFlyNarwhalConfigWarning({
  required bool missingUrl,
  required bool missingAuthCode,
}) {
  if (missingUrl && missingAuthCode) return '请填写飞鲸服务端 URL 和授权码';
  if (missingUrl) return '请填写飞鲸服务端 URL';
  return '请填写飞鲸服务端授权码';
}

@immutable
class ToastMessage {
  const ToastMessage({
    required this.id,
    required this.message,
    required this.type,
    required this.duration,
    required this.category,
    required this.revision,
  });

  final String id;
  final String message;
  final ToastType type;
  final Duration duration;
  final String? category;
  final int revision;

  ToastMessage copyWith({
    String? message,
    ToastType? type,
    Duration? duration,
    int? revision,
  }) {
    return ToastMessage(
      id: id,
      message: message ?? this.message,
      type: type ?? this.type,
      duration: duration ?? this.duration,
      category: category,
      revision: revision ?? this.revision,
    );
  }
}

@immutable
class ToastPresentation {
  const ToastPresentation({
    required this.assetPath,
    required this.iconColor,
    required this.semanticLabel,
  });

  final String assetPath;
  final Color iconColor;
  final String semanticLabel;
}

extension ToastTypePresentation on ToastType {
  ToastPresentation get presentation {
    return switch (this) {
      ToastType.success => const ToastPresentation(
          assetPath: 'assets/images/toast_success.svg',
          iconColor: Color(0xFF5DC264),
          semanticLabel: '成功',
        ),
      ToastType.failed => const ToastPresentation(
          assetPath: 'assets/images/toast_error.svg',
          iconColor: Color(0xFFFF7864),
          semanticLabel: '错误',
        ),
      ToastType.info => const ToastPresentation(
          assetPath: 'assets/images/toast_info.svg',
          iconColor: Color(0xFF409EFF),
          semanticLabel: '信息',
        ),
      ToastType.warning => const ToastPresentation(
          assetPath: 'assets/images/toast_warning.svg',
          iconColor: Color(0xFFFFAA43),
          semanticLabel: '警告',
        ),
    };
  }
}

class ToastManager extends StateNotifier<List<ToastMessage>> {
  ToastManager({Uuid? uuid})
      : _uuid = uuid ?? const Uuid(),
        super(const []);

  final Uuid _uuid;
  int _nextRevision = 0;

  void showToast(
    String message, {
    ToastType type = ToastType.success,
    Duration duration = _defaultToastDuration,
    String? category,
  }) {
    final normalizedMessage = message.trim();
    if (normalizedMessage.isEmpty) {
      return;
    }

    final normalizedDuration =
        duration > Duration.zero ? duration : _defaultToastDuration;
    final existingIndex = category == null
        ? -1
        : state.indexWhere((toast) => toast.category == category);

    if (existingIndex >= 0) {
      final updatedToasts = [...state];
      updatedToasts[existingIndex] = updatedToasts[existingIndex].copyWith(
        message: normalizedMessage,
        type: type,
        duration: normalizedDuration,
        revision: _takeNextRevision(),
      );
      state = List.unmodifiable(updatedToasts);
      return;
    }

    state = List.unmodifiable([
      ...state,
      ToastMessage(
        id: _uuid.v4(),
        message: normalizedMessage,
        type: type,
        duration: normalizedDuration,
        category: category,
        revision: _takeNextRevision(),
      ),
    ]);
  }

  void removeToast(String id) {
    final remainingToasts = state.where((toast) => toast.id != id).toList();
    if (remainingToasts.length == state.length) {
      return;
    }
    state = List.unmodifiable(remainingToasts);
  }

  void clear() {
    if (state.isEmpty) {
      return;
    }
    state = const [];
  }

  int _takeNextRevision() {
    _nextRevision++;
    return _nextRevision;
  }
}

final toastManagerProvider =
    StateNotifierProvider<ToastManager, List<ToastMessage>>(
  (ref) => ToastManager(),
);

class ToastHost extends ConsumerWidget {
  const ToastHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toastMessages = ref.watch(toastManagerProvider);
    if (toastMessages.isEmpty) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              kWindowTitleBarHeight + 16,
              16,
              0,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maximumToastWidth =
                    constraints.maxWidth > 480 ? 480.0 : constraints.maxWidth;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final toast in toastMessages) ...[
                      RepaintBoundary(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: maximumToastWidth,
                          ),
                          child: _ToastItem(
                            key: ValueKey(toast.id),
                            toast: toast,
                            onDismiss: () => ref
                                .read(toastManagerProvider.notifier)
                                .removeToast(toast.id),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastItem extends StatefulWidget {
  const _ToastItem({
    super.key,
    required this.toast,
    required this.onDismiss,
  });

  final ToastMessage toast;
  final VoidCallback onDismiss;

  @override
  State<_ToastItem> createState() => _ToastItemState();
}

class _ToastItemState extends State<_ToastItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _opacityAnimation;
  late final Animation<Offset> _offsetAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: _toastAnimationDuration,
    );
    _opacityAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
    _showToastForTheFirstTime();
  }

  @override
  void didUpdateWidget(covariant _ToastItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.toast.revision != widget.toast.revision) {
      _refreshToastLifetime();
    }
  }

  int _dismissalGeneration = 0;

  void _showToastForTheFirstTime() {
    _animationController.forward(from: 0);
    _scheduleDismissal();
  }

  void _refreshToastLifetime() {
    _dismissTimer?.cancel();
    _dismissalGeneration++;

    if (_animationController.status != AnimationStatus.completed) {
      _animationController.forward();
    }

    _scheduleDismissal();
  }

  void _scheduleDismissal() {
    final dismissalGeneration = _dismissalGeneration;
    _dismissTimer = Timer(
      widget.toast.duration,
      () => _dismissToast(dismissalGeneration),
    );
  }

  Future<void> _dismissToast(int dismissalGeneration) async {
    try {
      await _animationController.reverse();
    } on TickerCanceled {
      return;
    }

    if (mounted && dismissalGeneration == _dismissalGeneration) {
      widget.onDismiss();
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final presentation = widget.toast.type.presentation;
    final isDarkTheme = FluentTheme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDarkTheme ? const Color(0xFF414249) : const Color(0xFFFFFFFF);
    final borderColor =
        isDarkTheme ? const Color(0xFF565860) : const Color(0xFFE5E6EB);
    final textColor =
        isDarkTheme ? const Color(0xFFF5F5F6) : const Color(0xFF1D2129);

    return Semantics(
      liveRegion: true,
      label: '${presentation.semanticLabel}：${widget.toast.message}',
      child: SlideTransition(
        position: _offsetAnimation,
        child: FadeTransition(
          opacity: _opacityAnimation,
          child: Container(
            constraints: const BoxConstraints(minHeight: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x2E000000),
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ExcludeSemantics(
                  child: SvgPicture.asset(
                    presentation.assetPath,
                    width: 16,
                    height: 16,
                    colorFilter: ColorFilter.mode(
                      presentation.iconColor,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    widget.toast.message,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
