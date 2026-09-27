import 'package:fluent_ui/fluent_ui.dart';

import '../../../core/network/api_result.dart';
import '../app_button.dart';

/// 把异步加载抛出的任意 error 转成可读文案。
///
/// [FailureInfo] 没有覆写 `toString`，直接插值会打印 `Instance of 'FailureInfo'`；
/// 这里优先取 [FailureInfo.displayMessage]，其次 [FailureInfo.message]。
/// 网络类失败（[FailureInfo.code] 为空或网络错误）会给出补充说明。
String describeLoadError(Object? error) {
  if (error is FailureInfo) {
    final message =
        error.displayMessage.isNotEmpty ? error.displayMessage : error.message;
    return message.isNotEmpty ? message : '未知错误';
  }
  final text = error?.toString() ?? '';
  // Exception/错误对象的 toString 都带前缀，去掉后更接近服务端原文。
  return text.replaceFirst(RegExp(r'^(Exception|Error):\s*'), '').trim();
}

/// 详情页加载失败的统一占位视图：标题 + 可读原因 + 重试按钮。
class AppLoadErrorView extends StatelessWidget {
  final String title;
  final Object? error;
  final VoidCallback onRetry;

  const AppLoadErrorView({
    super.key,
    this.title = '加载失败',
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final bodyColor = theme.typography.body?.color ?? Colors.white;
    final reason = describeLoadError(error);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FluentIcons.error_badge,
              size: 28,
              color: bodyColor.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.typography.subtitle?.copyWith(
                fontWeight: FontWeight.w600,
                color: bodyColor,
              ),
            ),
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Text(
                  reason,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.body?.copyWith(
                    color: bodyColor.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            AppButton(
              onPressed: onRetry,
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
