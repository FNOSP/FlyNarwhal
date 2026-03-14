import 'package:flutter/material.dart';
import '../../../core/network/api_result.dart';
import '../extensions/api_result_ui_extension.dart';

/// Common error widget for displaying failures
class ErrorDisplayWidget extends StatelessWidget {
  final FailureInfo failure;
  final VoidCallback? onRetry;
  final bool showIcon;
  final bool compact;

  const ErrorDisplayWidget({
    super.key,
    required this.failure,
    this.onRetry,
    this.showIcon = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompact(context);
    }
    return _buildFull(context);
  }

  Widget _buildCompact(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showIcon) ...[
          const Icon(Icons.error_outline, size: 16, color: Colors.red),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            failure.displayMessage,
            style: const TextStyle(color: Colors.red),
          ),
        ),
        if (onRetry != null && failure.isRetryable) ...[
          const SizedBox(width: 8),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ],
    );
  }

  Widget _buildFull(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon)
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.grey,
            ),
          const SizedBox(height: 16),
          Text(
            failure.displayMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          if (onRetry != null && failure.isRetryable) ...[
            const SizedBox(height: 16),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ElevatedButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}