import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../domain/update/entities/update_models.dart';
import '../../../domain/update/repositories/update_repository_error.dart';
import '../../../providers/update_providers.dart';
import '../../shared/dialogs/app_dialog.dart';
import '../../shared/toast.dart';
import 'update_markdown_view.dart';
import 'update_state.dart';

/// Opens the shared state-driven update dialog.
Future<void> showUpdateDialog(BuildContext context) {
  final container = ProviderScope.containerOf(context, listen: false);
  container.read(updateControllerProvider.notifier).showCandidateDialog();
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Consumer(
      builder: (context, ref, child) {
        final updateState = ref.watch(updateControllerProvider);
        final controller = ref.read(updateControllerProvider.notifier);

        void popDialog() => Navigator.maybePop(dialogContext);

        return UpdateDialog(
          state: updateState,
          currentVersion: updateState.currentVersion?.toString() ?? '当前安装版本',
          onClose: () {
            controller.closeDialog();
            popDialog();
          },
          onSkip: () {
            unawaited(controller.skipCandidate());
            popDialog();
          },
          onDownload: () {
            unawaited(controller.startForegroundDownload());
          },
          onCancelDownload: () {
            unawaited(controller.cancelDownload());
            popDialog();
          },
          onRetryDownload: () {
            unawaited(controller.retryManualDownload());
          },
          onInstall: () {
            unawaited(controller.installDownloadedUpdate());
            popDialog();
          },
          onRetryInstall: () {
            unawaited(controller.retryInstallation());
            popDialog();
          },
          onManualDownload: () async {
            final releaseUrl = updateState.candidate?.releasePageUrl;
            popDialog();
            if (releaseUrl == null) return;
            final opened = await _launchReleasePage(releaseUrl);
            if (!opened) {
              container.read(toastManagerProvider.notifier).showToast(
                    '无法打开手动下载页面，请稍后重试。',
                    type: ToastType.failed,
                    category: 'update-link',
                  );
            }
          },
          onLinkFailure: (_) {
            container.read(toastManagerProvider.notifier).showToast(
                  '无法打开链接，请稍后重试。',
                  type: ToastType.failed,
                  category: 'update-link',
                );
          },
        );
      },
    ),
  );
}

Future<bool> _launchReleasePage(Uri releaseUrl) async {
  if (releaseUrl.scheme != 'https' || releaseUrl.host.isEmpty) return false;
  return launchUrl(releaseUrl, mode: LaunchMode.externalApplication);
}

class UpdateDialog extends StatelessWidget {
  const UpdateDialog({
    super.key,
    required this.state,
    required this.onClose,
    this.currentVersion = '当前安装版本',
    this.onSkip,
    this.onDownload,
    this.onCancelDownload,
    this.onRetryDownload,
    this.onInstall,
    this.onRetryInstall,
    this.onManualDownload,
    this.onLinkFailure,
  });

  final UpdateState state;
  final String currentVersion;
  final VoidCallback onClose;
  final VoidCallback? onSkip;
  final VoidCallback? onDownload;
  final VoidCallback? onCancelDownload;
  final VoidCallback? onRetryDownload;
  final VoidCallback? onInstall;
  final VoidCallback? onRetryInstall;
  final VoidCallback? onManualDownload;
  final UpdateLinkFailureCallback? onLinkFailure;

  @override
  Widget build(BuildContext context) {
    final dialogPhase = state.presentation.dialogPhase;
    final actions = _actionsFor(dialogPhase);
    // Exclude the dialog from the semantics tree to avoid a Windows engine
    // accessibility-bridge bug that logs repeated AXTree update failures when
    // the dialog swaps content between phases (checking/available/upToDate).
    return ExcludeSemantics(
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.escape): onClose,
        },
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: AppDialog<void>(
            key: const ValueKey('update-dialog'),
            constraints: const BoxConstraints(minWidth: 520, maxWidth: 600),
            title: _titleFor(dialogPhase),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 390),
              child: SingleChildScrollView(
                key: const ValueKey('update-dialog-content-scroll'),
                child: _buildContent(context, dialogPhase),
              ),
            ),
            tertiaryButtonText: actions.tertiaryText,
            secondaryButtonText: actions.secondaryText,
            primaryButtonText: actions.primaryText,
            onTertiaryPressed: actions.onTertiaryPressed,
            onSecondaryPressed: actions.onSecondaryPressed,
            onPrimaryPressed: actions.onPrimaryPressed,
          ),
        ),
      ),
    );
  }

  String _titleFor(UpdateDialogPhase phase) {
    return switch (phase) {
      UpdateDialogPhase.checking => '检查更新',
      UpdateDialogPhase.available => '发现新版本',
      UpdateDialogPhase.downloading => '正在下载更新',
      UpdateDialogPhase.downloaded => '下载完成',
      UpdateDialogPhase.verifying => '正在校验更新',
      UpdateDialogPhase.readyToInstall => '更新已准备就绪',
      UpdateDialogPhase.upToDate => '检查更新',
      UpdateDialogPhase.installing => '正在启动安装',
      UpdateDialogPhase.checkFailed => '检查更新失败',
      UpdateDialogPhase.downloadFailed => '下载更新失败',
      UpdateDialogPhase.verificationFailed => '更新包校验失败',
      UpdateDialogPhase.installFailed => '启动安装失败',
      UpdateDialogPhase.automaticDownloadExhausted => '自动下载未完成',
      UpdateDialogPhase.none => '应用更新',
    };
  }

  _UpdateDialogActions _actionsFor(UpdateDialogPhase phase) {
    return switch (phase) {
      UpdateDialogPhase.checking => _UpdateDialogActions(
          secondaryText: '后台检查',
          onSecondaryPressed: onClose,
        ),
      UpdateDialogPhase.available => _UpdateDialogActions(
          tertiaryText: '跳过此版本',
          onTertiaryPressed: onSkip,
          secondaryText: '稍后再说',
          onSecondaryPressed: onClose,
          primaryText: '下载更新',
          onPrimaryPressed: onDownload,
        ),
      UpdateDialogPhase.downloading => _UpdateDialogActions(
          secondaryText: '后台下载',
          onSecondaryPressed: onClose,
          primaryText: '取消下载',
          onPrimaryPressed: onCancelDownload,
        ),
      UpdateDialogPhase.downloaded => _UpdateDialogActions(
          secondaryText: '稍后安装',
          onSecondaryPressed: onClose,
          primaryText: '退出并安装',
          onPrimaryPressed: onInstall,
        ),
      UpdateDialogPhase.readyToInstall => _UpdateDialogActions(
          tertiaryText: '跳过此版本',
          onTertiaryPressed: onSkip,
          secondaryText: '稍后安装',
          onSecondaryPressed: onClose,
          primaryText: '退出并安装',
          onPrimaryPressed: onInstall,
        ),
      UpdateDialogPhase.verifying ||
      UpdateDialogPhase.installing =>
        _UpdateDialogActions(
          secondaryText: '后台运行',
          onSecondaryPressed: onClose,
        ),
      UpdateDialogPhase.downloadFailed ||
      UpdateDialogPhase.verificationFailed =>
        _UpdateDialogActions(
          secondaryText: '稍后再说',
          onSecondaryPressed: onClose,
          primaryText: '重新下载',
          onPrimaryPressed: onRetryDownload,
        ),
      UpdateDialogPhase.installFailed => _UpdateDialogActions(
          secondaryText: '稍后再说',
          onSecondaryPressed: onClose,
          primaryText: '重试安装',
          onPrimaryPressed: onRetryInstall,
        ),
      UpdateDialogPhase.automaticDownloadExhausted => _UpdateDialogActions(
          tertiaryText: '跳过此版本',
          onTertiaryPressed: onSkip,
          secondaryText: '稍后再说',
          onSecondaryPressed: onClose,
          primaryText: '手动下载',
          onPrimaryPressed: onManualDownload,
        ),
      _ => _UpdateDialogActions(
          secondaryText: '关闭',
          onSecondaryPressed: onClose,
        ),
    };
  }

  Widget _buildContent(BuildContext context, UpdateDialogPhase phase) {
    final candidate = state.candidate;
    return switch (phase) {
      UpdateDialogPhase.checking => const _StatusContent(
          key: ValueKey('update-state-checking'),
          busy: true,
          message: '正在从 GitHub Releases 获取更新信息…',
        ),
      UpdateDialogPhase.upToDate => const _StatusContent(
          key: ValueKey('update-state-up-to-date'),
          message: '当前已是最新版本。',
        ),
      UpdateDialogPhase.available => _CandidateContent(
          key: const ValueKey('update-state-available'),
          candidate: candidate!,
          currentVersion: currentVersion,
          showMarkdown: true,
          onLinkFailure: onLinkFailure,
        ),
      UpdateDialogPhase.downloading => _DownloadContent(state: state),
      UpdateDialogPhase.downloaded => _CandidateContent(
          key: const ValueKey('update-state-downloaded'),
          candidate: candidate!,
          currentVersion: currentVersion,
          message: '更新包已下载完成，可以稍后安装或立即退出并安装。',
          showMarkdown: false,
          onLinkFailure: onLinkFailure,
        ),
      UpdateDialogPhase.readyToInstall => _CandidateContent(
          key: const ValueKey('update-state-ready-to-install'),
          candidate: candidate!,
          currentVersion: currentVersion,
          message: '已找到可用的已下载更新包。',
          showMarkdown: true,
          onLinkFailure: onLinkFailure,
        ),
      UpdateDialogPhase.verifying => const _StatusContent(
          key: ValueKey('update-state-verifying'),
          busy: true,
          message: '正在安全校验更新包，请稍候…',
        ),
      UpdateDialogPhase.installing => const _StatusContent(
          key: ValueKey('update-state-installing'),
          busy: true,
          message: '正在启动系统安装程序，请勿重复操作。',
        ),
      UpdateDialogPhase.checkFailed ||
      UpdateDialogPhase.downloadFailed ||
      UpdateDialogPhase.verificationFailed ||
      UpdateDialogPhase.installFailed =>
        _FailureContent(
          phase: phase,
          failure: state.failure,
        ),
      UpdateDialogPhase.automaticDownloadExhausted => _CandidateContent(
          key: const ValueKey('update-state-automatic-exhausted'),
          candidate: candidate!,
          currentVersion: currentVersion,
          message: _failureSummary(state.failure, phase),
          showMarkdown: true,
          onLinkFailure: onLinkFailure,
        ),
      UpdateDialogPhase.none => const _StatusContent(
          key: ValueKey('update-state-idle'),
          message: '尚未执行更新检查。',
        ),
    };
  }
}

/// Button-slot configuration for one update dialog phase.
///
/// Maps onto [AppDialog]'s three action slots: tertiary sits on the left,
/// secondary and primary on the right.
class _UpdateDialogActions {
  const _UpdateDialogActions({
    this.tertiaryText,
    this.secondaryText,
    this.primaryText,
    this.onTertiaryPressed,
    this.onSecondaryPressed,
    this.onPrimaryPressed,
  });

  final String? tertiaryText;
  final String? secondaryText;
  final String? primaryText;
  final VoidCallback? onTertiaryPressed;
  final VoidCallback? onSecondaryPressed;
  final VoidCallback? onPrimaryPressed;
}

class _StatusContent extends StatelessWidget {
  const _StatusContent({
    super.key,
    required this.message,
    this.busy = false,
  });

  final String message;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (busy) ...[
              const ProgressRing(),
              const SizedBox(width: 12),
            ],
            Expanded(child: Text(message)),
          ],
        ),
      ],
    );
  }
}

class _CandidateContent extends StatelessWidget {
  const _CandidateContent({
    super.key,
    required this.candidate,
    required this.currentVersion,
    required this.showMarkdown,
    this.message,
    this.onLinkFailure,
  });

  final UpdateCandidate candidate;
  final String currentVersion;
  final bool showMarkdown;
  final String? message;
  final UpdateLinkFailureCallback? onLinkFailure;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 560,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '版本 ${candidate.version}（当前 $currentVersion）',
            style: FluentTheme.of(context).typography.bodyStrong,
          ),
          const SizedBox(height: 6),
          Text('安装包大小 ${_formatFileSize(candidate.asset.sizeInBytes)}'),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(message!),
          ],
          if (showMarkdown) ...[
            const SizedBox(height: 16),
            Text('更新内容', style: FluentTheme.of(context).typography.bodyStrong),
            const SizedBox(height: 8),
            UpdateMarkdownView(
              markdown: candidate.releaseNotes,
              releaseUrl: candidate.releasePageUrl,
              onOpenLinkFailed: onLinkFailure,
            ),
          ],
        ],
      ),
    );
  }
}

class _DownloadContent extends StatelessWidget {
  const _DownloadContent({required this.state});

  final UpdateState state;

  @override
  Widget build(BuildContext context) {
    final progress = state.downloadProgress;
    return SizedBox(
      key: const ValueKey('update-state-downloading'),
      width: 560,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(state.candidate?.asset.name ?? '正在下载更新包'),
          const SizedBox(height: 12),
          ProgressBar(value: progress == null ? null : progress * 100),
          const SizedBox(height: 8),
          Text(progress == null
              ? '已下载 ${_formatFileSize(state.receivedBytes)}'
              : '${_formatFileSize(state.receivedBytes)} / ${_formatFileSize(state.totalBytes)}'),
        ],
      ),
    );
  }
}

class _FailureContent extends StatelessWidget {
  const _FailureContent({required this.phase, required this.failure});

  final UpdateDialogPhase phase;
  final UpdateWorkflowFailure? failure;

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      _failureSummary(failure, phase),
      key: const ValueKey('update-state-failure-summary'),
    );
  }
}

String _failureSummary(
  UpdateWorkflowFailure? failure,
  UpdateDialogPhase phase,
) {
  if (failure is UpdateCheckFailure &&
      failure.code == UpdateRepositoryErrorCode.rateLimited.name) {
    return 'GitHub 接口访问频率超限，通常稍后会自动恢复，请稍后再试。';
  }
  if (failure is UpdateVerificationFailure) {
    return switch (failure.reason) {
      _ => '更新包未通过安全校验，请重新下载。',
    };
  }
  return switch (phase) {
    UpdateDialogPhase.checkFailed => '暂时无法获取更新信息，请检查网络后重试。',
    UpdateDialogPhase.downloadFailed => '更新包下载未完成，请稍后重试。',
    UpdateDialogPhase.installFailed => '无法启动系统安装程序，请稍后重试。',
    UpdateDialogPhase.automaticDownloadExhausted =>
      '自动下载多次未完成，你可以稍后重试或前往发布页手动下载。',
    _ => '更新操作未完成，请稍后重试。',
  };
}

String _formatFileSize(int bytes) {
  const megabyte = 1024 * 1024;
  if (bytes >= megabyte) return '${(bytes / megabyte).toStringAsFixed(1)} MB';
  const kilobyte = 1024;
  if (bytes >= kilobyte) return '${(bytes / kilobyte).toStringAsFixed(1)} KB';
  return '$bytes B';
}
