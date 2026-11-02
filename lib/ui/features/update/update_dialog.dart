import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../domain/update/entities/update_models.dart';
import '../../../domain/update/repositories/update_repository_error.dart';
import '../../../l10n/generated/app_localizations.dart';
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
        final l10n = AppLocalizations.of(context);
        final updateState = ref.watch(updateControllerProvider);
        final controller = ref.read(updateControllerProvider.notifier);

        void popDialog() => Navigator.maybePop(dialogContext);

        return UpdateDialog(
          state: updateState,
          currentVersion: updateState.currentVersion?.toString() ??
              l10n.updateCurrentVersionLabel,
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
                    l10n.updateManualDownloadOpenFailed,
                    type: ToastType.failed,
                    category: 'update-link',
                  );
            }
          },
          onLinkFailure: (_) {
            container.read(toastManagerProvider.notifier).showToast(
                  l10n.updateOpenLinkFailed,
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
    this.currentVersion,
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
  final String? currentVersion;
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
    final l10n = AppLocalizations.of(context);
    final dialogPhase = state.presentation.dialogPhase;
    final actions = _actionsFor(l10n, dialogPhase);
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
            title: _titleFor(l10n, dialogPhase),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 390),
              child: SingleChildScrollView(
                key: const ValueKey('update-dialog-content-scroll'),
                child: _buildContent(context, l10n, dialogPhase),
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

  String _titleFor(AppLocalizations l10n, UpdateDialogPhase phase) {
    return switch (phase) {
      UpdateDialogPhase.checking => l10n.updateDialogTitleChecking,
      UpdateDialogPhase.available => l10n.updateDialogTitleAvailable,
      UpdateDialogPhase.downloading => l10n.updateDialogTitleDownloading,
      UpdateDialogPhase.downloaded => l10n.updateDialogTitleDownloaded,
      UpdateDialogPhase.verifying => l10n.updateDialogTitleVerifying,
      UpdateDialogPhase.readyToInstall => l10n.updateDialogTitleReadyToInstall,
      UpdateDialogPhase.upToDate => l10n.updateDialogTitleChecking,
      UpdateDialogPhase.installing => l10n.updateDialogTitleInstalling,
      UpdateDialogPhase.checkFailed => l10n.updateDialogTitleCheckFailed,
      UpdateDialogPhase.downloadFailed => l10n.updateDialogTitleDownloadFailed,
      UpdateDialogPhase.verificationFailed =>
        l10n.updateDialogTitleVerificationFailed,
      UpdateDialogPhase.installFailed => l10n.updateDialogTitleInstallFailed,
      UpdateDialogPhase.automaticDownloadExhausted =>
        l10n.updateDialogTitleAutomaticDownloadExhausted,
      UpdateDialogPhase.none => l10n.updateDialogTitleNone,
    };
  }

  _UpdateDialogActions _actionsFor(AppLocalizations l10n, UpdateDialogPhase phase) {
    return switch (phase) {
      UpdateDialogPhase.checking => _UpdateDialogActions(
          secondaryText: l10n.updateActionCheckInBackground,
          onSecondaryPressed: onClose,
        ),
      UpdateDialogPhase.available => _UpdateDialogActions(
          tertiaryText: l10n.updateActionSkipVersion,
          onTertiaryPressed: onSkip,
          secondaryText: l10n.updateActionLater,
          onSecondaryPressed: onClose,
          primaryText: l10n.updateActionDownload,
          onPrimaryPressed: onDownload,
        ),
      UpdateDialogPhase.downloading => _UpdateDialogActions(
          secondaryText: l10n.updateActionDownloadInBackground,
          onSecondaryPressed: onClose,
          primaryText: l10n.updateActionCancelDownload,
          onPrimaryPressed: onCancelDownload,
        ),
      UpdateDialogPhase.downloaded => _UpdateDialogActions(
          secondaryText: l10n.updateActionInstallLater,
          onSecondaryPressed: onClose,
          primaryText: l10n.updateActionQuitAndInstall,
          onPrimaryPressed: onInstall,
        ),
      UpdateDialogPhase.readyToInstall => _UpdateDialogActions(
          tertiaryText: l10n.updateActionSkipVersion,
          onTertiaryPressed: onSkip,
          secondaryText: l10n.updateActionInstallLater,
          onSecondaryPressed: onClose,
          primaryText: l10n.updateActionQuitAndInstall,
          onPrimaryPressed: onInstall,
        ),
      UpdateDialogPhase.verifying ||
      UpdateDialogPhase.installing =>
        _UpdateDialogActions(
          secondaryText: l10n.updateActionRunInBackground,
          onSecondaryPressed: onClose,
        ),
      UpdateDialogPhase.downloadFailed ||
      UpdateDialogPhase.verificationFailed =>
        _UpdateDialogActions(
          secondaryText: l10n.updateActionLater,
          onSecondaryPressed: onClose,
          primaryText: l10n.updateActionRetryDownload,
          onPrimaryPressed: onRetryDownload,
        ),
      UpdateDialogPhase.installFailed => _UpdateDialogActions(
          secondaryText: l10n.updateActionLater,
          onSecondaryPressed: onClose,
          primaryText: l10n.updateActionRetryInstall,
          onPrimaryPressed: onRetryInstall,
        ),
      UpdateDialogPhase.automaticDownloadExhausted => _UpdateDialogActions(
          tertiaryText: l10n.updateActionSkipVersion,
          onTertiaryPressed: onSkip,
          secondaryText: l10n.updateActionLater,
          onSecondaryPressed: onClose,
          primaryText: l10n.updateActionManualDownload,
          onPrimaryPressed: onManualDownload,
        ),
      _ => _UpdateDialogActions(
          secondaryText: l10n.updateActionClose,
          onSecondaryPressed: onClose,
        ),
    };
  }

  Widget _buildContent(
      BuildContext context, AppLocalizations l10n, UpdateDialogPhase phase) {
    final candidate = state.candidate;
    final resolvedCurrentVersion =
        currentVersion ?? l10n.updateCurrentVersionLabel;
    return switch (phase) {
      UpdateDialogPhase.checking => _StatusContent(
          key: const ValueKey('update-state-checking'),
          busy: true,
          message: l10n.updateStatusCheckingMessage,
        ),
      UpdateDialogPhase.upToDate => _StatusContent(
          key: const ValueKey('update-state-up-to-date'),
          message: l10n.updateStatusUpToDate,
        ),
      UpdateDialogPhase.available => _CandidateContent(
          key: const ValueKey('update-state-available'),
          candidate: candidate!,
          currentVersion: resolvedCurrentVersion,
          showMarkdown: true,
          onLinkFailure: onLinkFailure,
        ),
      UpdateDialogPhase.downloading => _DownloadContent(state: state),
      UpdateDialogPhase.downloaded => _CandidateContent(
          key: const ValueKey('update-state-downloaded'),
          candidate: candidate!,
          currentVersion: resolvedCurrentVersion,
          message: l10n.updateStatusDownloadedMessage,
          showMarkdown: false,
          onLinkFailure: onLinkFailure,
        ),
      UpdateDialogPhase.readyToInstall => _CandidateContent(
          key: const ValueKey('update-state-ready-to-install'),
          candidate: candidate!,
          currentVersion: resolvedCurrentVersion,
          message: l10n.updateStatusReadyMessage,
          showMarkdown: true,
          onLinkFailure: onLinkFailure,
        ),
      UpdateDialogPhase.verifying => _StatusContent(
          key: const ValueKey('update-state-verifying'),
          busy: true,
          message: l10n.updateStatusVerifyingMessage,
        ),
      UpdateDialogPhase.installing => _StatusContent(
          key: const ValueKey('update-state-installing'),
          busy: true,
          message: l10n.updateStatusInstallingMessage,
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
          currentVersion: resolvedCurrentVersion,
          message: _failureSummary(l10n, state.failure, phase),
          showMarkdown: true,
          onLinkFailure: onLinkFailure,
        ),
      UpdateDialogPhase.none => _StatusContent(
          key: const ValueKey('update-state-idle'),
          message: l10n.updateStatusIdleMessage,
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
            AppLocalizations.of(context)
                .updateVersionLine('${candidate.version}', currentVersion),
            style: FluentTheme.of(context).typography.bodyStrong,
          ),
          const SizedBox(height: 6),
          Text(AppLocalizations.of(context)
              .updatePackageSize(_formatFileSize(candidate.asset.sizeInBytes))),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(message!),
          ],
          if (showMarkdown) ...[
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context).updateReleaseNotesHeader,
                style: FluentTheme.of(context).typography.bodyStrong),
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
          Text(state.candidate?.asset.name ??
              AppLocalizations.of(context).updateDownloadingPackage),
          const SizedBox(height: 12),
          ProgressBar(value: progress == null ? null : progress * 100),
          const SizedBox(height: 8),
          Text(progress == null
              ? AppLocalizations.of(context)
                  .updateDownloadedSize(_formatFileSize(state.receivedBytes))
              : AppLocalizations.of(context).updateDownloadProgress(
                  _formatFileSize(state.receivedBytes),
                  _formatFileSize(state.totalBytes))),
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
      _failureSummary(
          AppLocalizations.of(context), failure, phase),
      key: const ValueKey('update-state-failure-summary'),
    );
  }
}

String _failureSummary(
  AppLocalizations l10n,
  UpdateWorkflowFailure? failure,
  UpdateDialogPhase phase,
) {
  if (failure is UpdateCheckFailure &&
      failure.code == UpdateRepositoryErrorCode.rateLimited.name) {
    return l10n.updateErrorRateLimited;
  }
  if (failure is UpdateVerificationFailure) {
    return switch (failure.reason) {
      _ => l10n.updateErrorVerificationFailed,
    };
  }
  return switch (phase) {
    UpdateDialogPhase.checkFailed => l10n.updateErrorCheckFailed,
    UpdateDialogPhase.downloadFailed => l10n.updateErrorDownloadFailed,
    UpdateDialogPhase.installFailed => l10n.updateErrorInstallFailed,
    UpdateDialogPhase.automaticDownloadExhausted =>
      l10n.updateErrorAutomaticDownloadExhausted,
    _ => l10n.updateErrorGeneric,
  };
}

String _formatFileSize(int bytes) {
  const megabyte = 1024 * 1024;
  if (bytes >= megabyte) return '${(bytes / megabyte).toStringAsFixed(1)} MB';
  const kilobyte = 1024;
  if (bytes >= kilobyte) return '${(bytes / kilobyte).toStringAsFixed(1)} KB';
  return '$bytes B';
}
