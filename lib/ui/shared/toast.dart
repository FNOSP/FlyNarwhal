import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';

enum ToastType { success, failed, info }

class ToastMessage {
  final String id;
  final String message;
  final ToastType type;
  final int duration;
  final String? category;
  final int updateTime;

  ToastMessage({
    required this.id,
    required this.message,
    required this.type,
    required this.duration,
    required this.category,
    required this.updateTime,
  });

  ToastMessage copyWith({
    String? message,
    ToastType? type,
    int? duration,
    int? updateTime,
  }) {
    return ToastMessage(
      id: id,
      message: message ?? this.message,
      type: type ?? this.type,
      duration: duration ?? this.duration,
      category: category,
      updateTime: updateTime ?? this.updateTime,
    );
  }
}

class ToastManager extends ChangeNotifier {
  final List<ToastMessage> _toasts = [];

  List<ToastMessage> get toasts => List.unmodifiable(_toasts);

  void showToast(
    String message, {
    ToastType type = ToastType.success,
    int duration = 2000,
    String? category,
  }) {
    if (category != null) {
      final existingIndex = _toasts.indexWhere((t) => t.category == category);
      if (existingIndex != -1) {
        _toasts[existingIndex] = _toasts[existingIndex].copyWith(
          message: message,
          type: type,
          duration: duration,
          updateTime: DateTime.now().millisecondsSinceEpoch,
        );
        notifyListeners();
        return;
      }
    }
    final toast = ToastMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      message: message,
      type: type,
      duration: duration,
      category: category,
      updateTime: DateTime.now().millisecondsSinceEpoch,
    );
    _toasts.add(toast);
    notifyListeners();
  }

  void removeToast(String id) {
    _toasts.removeWhere((t) => t.id == id);
    notifyListeners();
  }
}

class ToastHost extends StatelessWidget {
  final ToastManager toastManager;

  const ToastHost({super.key, required this.toastManager});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: toastManager,
        builder: (context, _) {
          return Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: toastManager.toasts
                    .map(
                      (toast) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _ToastItem(
                          key: ValueKey('${toast.id}_${toast.updateTime}'),
                          message: toast.message,
                          type: toast.type,
                          duration: toast.duration,
                          updateTime: toast.updateTime,
                          onDismiss: () => toastManager.removeToast(toast.id),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ToastItem extends StatefulWidget {
  final String message;
  final ToastType type;
  final int duration;
  final int updateTime;
  final VoidCallback onDismiss;

  const _ToastItem({
    super.key,
    required this.message,
    required this.type,
    required this.duration,
    required this.updateTime,
    required this.onDismiss,
  });

  @override
  State<_ToastItem> createState() => _ToastItemState();
}

class _ToastItemState extends State<_ToastItem> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _offset = Tween<Offset>(begin: const Offset(0, -0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _startAnimation();
  }

  @override
  void didUpdateWidget(covariant _ToastItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.updateTime != widget.updateTime) {
      _startAnimation();
    }
  }

  void _startAnimation() {
    _timer?.cancel();
    _controller.forward(from: 0);
    _timer = Timer(Duration(milliseconds: widget.duration), () async {
      await _controller.reverse();
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = switch (widget.type) {
      ToastType.success => const Color(0xFF5BA85A),
      ToastType.failed => const Color(0xFFFF0421),
      ToastType.info => const Color(0xFF54A9FF),
    };
    final iconData = switch (widget.type) {
      ToastType.success => FluentIcons.completed,
      ToastType.failed => FluentIcons.warning,
      ToastType.info => FluentIcons.info,
    };
    return SlideTransition(
      position: _offset,
      child: FadeTransition(
        opacity: _opacity,
        child: Container(
          padding: const EdgeInsets.only(left: 10, right: 15, top: 8, bottom: 8),
          decoration: BoxDecoration(
            color: FluentTheme.of(context).resources.controlSolidFillColorDefault,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                iconData,
                color: iconColor,
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                widget.message,
                style: TextStyle(
                  color: FluentTheme.of(context).typography.body?.color,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
