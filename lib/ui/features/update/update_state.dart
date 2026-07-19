import 'dart:io';

import '../../../domain/update/entities/update_models.dart';
import '../../../services/update/sha256_verifier.dart';

/// Internal lifecycle of the update task independently from UI visibility.
enum UpdateTaskPhase {
  idle,
  available,
  downloading,
  verifying,
  downloaded,
  readyToInstall,
  installing,
  upToDate,
  checkFailed,
  downloadFailed,
  verificationFailed,
  installFailed,
  automaticDownloadExhausted,
}

/// User-facing dialog content independently from background task progress.
enum UpdateDialogPhase {
  none,
  checking,
  available,
  downloading,
  downloaded,
  verifying,
  readyToInstall,
  upToDate,
  checkFailed,
  downloadFailed,
  verificationFailed,
  installing,
  installFailed,
  automaticDownloadExhausted,
}

enum UpdateDownloadMode { foreground, automatic }

sealed class UpdateWorkflowFailure {
  const UpdateWorkflowFailure({
    required this.code,
    required this.userMessageKey,
    required this.technicalDetail,
    required this.isRetryable,
    this.cause,
  });

  final String code;
  final String userMessageKey;
  final String technicalDetail;
  final bool isRetryable;
  final Object? cause;
}

final class UpdateCheckFailure extends UpdateWorkflowFailure {
  const UpdateCheckFailure({
    required super.code,
    required super.userMessageKey,
    required super.technicalDetail,
    required super.isRetryable,
    super.cause,
  });
}

final class UpdateDownloadFailure extends UpdateWorkflowFailure {
  const UpdateDownloadFailure({
    required super.code,
    required super.userMessageKey,
    required super.technicalDetail,
    required super.isRetryable,
    super.cause,
  });
}

final class UpdateVerificationFailure extends UpdateWorkflowFailure {
  const UpdateVerificationFailure({
    required this.reason,
    required super.code,
    required super.userMessageKey,
    required super.technicalDetail,
    required super.isRetryable,
    super.cause,
  });

  final VerificationFailureReason reason;
}

final class UpdateInstallFailure extends UpdateWorkflowFailure {
  const UpdateInstallFailure({
    required super.code,
    required super.userMessageKey,
    required super.technicalDetail,
    required super.isRetryable,
    super.cause,
  });
}

final class AutomaticDownloadExhaustedFailure extends UpdateWorkflowFailure {
  const AutomaticDownloadExhaustedFailure({
    required this.failureCount,
    required super.code,
    required super.userMessageKey,
    required super.technicalDetail,
    super.cause,
  }) : super(isRetryable: false);

  final int failureCount;
}

/// Immutable task data with constructor-level invariant validation.
final class UpdateTaskState {
  UpdateTaskState({
    this.phase = UpdateTaskPhase.idle,
    this.candidate,
    this.downloadCandidate,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.localFile,
    this.verificationSource,
    this.downloadMode,
    this.isForegroundTakeover = false,
    this.automaticFailureCount = 0,
  }) {
    final candidateRequired = switch (phase) {
      UpdateTaskPhase.available ||
      UpdateTaskPhase.downloading ||
      UpdateTaskPhase.verifying ||
      UpdateTaskPhase.downloaded ||
      UpdateTaskPhase.readyToInstall ||
      UpdateTaskPhase.installing ||
      UpdateTaskPhase.downloadFailed ||
      UpdateTaskPhase.verificationFailed ||
      UpdateTaskPhase.installFailed ||
      UpdateTaskPhase.automaticDownloadExhausted =>
        true,
      _ => false,
    };
    final fileRequired = switch (phase) {
      UpdateTaskPhase.downloaded ||
      UpdateTaskPhase.readyToInstall ||
      UpdateTaskPhase.installing ||
      UpdateTaskPhase.installFailed =>
        true,
      _ => false,
    };
    if (candidateRequired && candidate == null) {
      throw ArgumentError('Update phase ${phase.name} requires a candidate.');
    }
    if (fileRequired && localFile == null) {
      throw ArgumentError('Update phase ${phase.name} requires a local file.');
    }
    if (receivedBytes < 0 || totalBytes < 0 || automaticFailureCount < 0) {
      throw ArgumentError('Update task counters cannot be negative.');
    }
  }

  final UpdateTaskPhase phase;
  final UpdateCandidate? candidate;
  final UpdateCandidate? downloadCandidate;
  final int receivedBytes;
  final int totalBytes;
  final File? localFile;
  final VerificationSource? verificationSource;
  final UpdateDownloadMode? downloadMode;
  final bool isForegroundTakeover;
  final int automaticFailureCount;

  double? get downloadProgress =>
      totalBytes > 0 ? receivedBytes / totalBytes : null;

  UpdateTaskState copyWith({
    UpdateTaskPhase? phase,
    UpdateCandidate? candidate,
    UpdateCandidate? downloadCandidate,
    int? receivedBytes,
    int? totalBytes,
    File? localFile,
    VerificationSource? verificationSource,
    UpdateDownloadMode? downloadMode,
    bool? isForegroundTakeover,
    int? automaticFailureCount,
    bool clearCandidate = false,
    bool clearDownloadCandidate = false,
    bool clearLocalFile = false,
    bool clearVerificationSource = false,
    bool clearDownloadMode = false,
  }) {
    return UpdateTaskState(
      phase: phase ?? this.phase,
      candidate: clearCandidate ? null : candidate ?? this.candidate,
      downloadCandidate: clearDownloadCandidate
          ? null
          : downloadCandidate ?? this.downloadCandidate,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      localFile: clearLocalFile ? null : localFile ?? this.localFile,
      verificationSource: clearVerificationSource
          ? null
          : verificationSource ?? this.verificationSource,
      downloadMode:
          clearDownloadMode ? null : downloadMode ?? this.downloadMode,
      isForegroundTakeover: isForegroundTakeover ?? this.isForegroundTakeover,
      automaticFailureCount:
          automaticFailureCount ?? this.automaticFailureCount,
    );
  }
}

final class UpdatePresentationState {
  const UpdatePresentationState({
    this.dialogPhase = UpdateDialogPhase.none,
    this.isDialogVisible = false,
    this.isUpdatePromptVisible = false,
  });

  final UpdateDialogPhase dialogPhase;
  final bool isDialogVisible;
  final bool isUpdatePromptVisible;

  UpdatePresentationState copyWith({
    UpdateDialogPhase? dialogPhase,
    bool? isDialogVisible,
    bool? isUpdatePromptVisible,
  }) {
    return UpdatePresentationState(
      dialogPhase: dialogPhase ?? this.dialogPhase,
      isDialogVisible: isDialogVisible ?? this.isDialogVisible,
      isUpdatePromptVisible:
          isUpdatePromptVisible ?? this.isUpdatePromptVisible,
    );
  }
}

/// Compatibility phase projected from the separate task and presentation state.
enum UpdatePhase {
  idle,
  checking,
  available,
  downloading,
  downloaded,
  verifying,
  readyToInstall,
  upToDate,
  failed,
}

/// Root update state containing two immutable and independent state models.
final class UpdateState {
  const UpdateState({
    required this.task,
    required this.presentation,
    this.failure,
    this.lastSuccessfulCheckAt,
  });

  factory UpdateState.initial({DateTime? lastSuccessfulCheckAt}) {
    return UpdateState(
      task: UpdateTaskState(),
      presentation: const UpdatePresentationState(),
      lastSuccessfulCheckAt: lastSuccessfulCheckAt,
    );
  }

  final UpdateTaskState task;
  final UpdatePresentationState presentation;
  final UpdateWorkflowFailure? failure;
  final DateTime? lastSuccessfulCheckAt;

  UpdateCandidate? get candidate => task.candidate;
  int get receivedBytes => task.receivedBytes;
  int get totalBytes => task.totalBytes;
  String? get downloadedFilePath => task.localFile?.path;
  String? get failureMessage => failure?.userMessageKey;
  bool get isAutomaticDownload =>
      task.downloadMode == UpdateDownloadMode.automatic;
  bool get isUpdatePromptVisible => presentation.isUpdatePromptVisible;
  bool get hasUpdateBadge => presentation.isUpdatePromptVisible;
  double? get downloadProgress => task.downloadProgress;

  UpdatePhase get phase {
    if (presentation.isDialogVisible) {
      return switch (presentation.dialogPhase) {
        UpdateDialogPhase.checking => UpdatePhase.checking,
        UpdateDialogPhase.available => UpdatePhase.available,
        UpdateDialogPhase.downloading => UpdatePhase.downloading,
        UpdateDialogPhase.downloaded => UpdatePhase.downloaded,
        UpdateDialogPhase.verifying => UpdatePhase.verifying,
        UpdateDialogPhase.readyToInstall => UpdatePhase.readyToInstall,
        UpdateDialogPhase.installing => UpdatePhase.verifying,
        UpdateDialogPhase.upToDate => UpdatePhase.upToDate,
        UpdateDialogPhase.checkFailed ||
        UpdateDialogPhase.downloadFailed ||
        UpdateDialogPhase.verificationFailed ||
        UpdateDialogPhase.installFailed ||
        UpdateDialogPhase.automaticDownloadExhausted =>
          UpdatePhase.failed,
        UpdateDialogPhase.none => _projectTaskPhase(),
      };
    }
    return _projectTaskPhase();
  }

  UpdatePhase _projectTaskPhase() {
    return switch (task.phase) {
      UpdateTaskPhase.idle => UpdatePhase.idle,
      UpdateTaskPhase.available => UpdatePhase.available,
      UpdateTaskPhase.downloading => UpdatePhase.downloading,
      UpdateTaskPhase.verifying => UpdatePhase.verifying,
      UpdateTaskPhase.downloaded => UpdatePhase.downloaded,
      UpdateTaskPhase.readyToInstall => UpdatePhase.readyToInstall,
      UpdateTaskPhase.installing => UpdatePhase.verifying,
      UpdateTaskPhase.upToDate => UpdatePhase.upToDate,
      UpdateTaskPhase.checkFailed ||
      UpdateTaskPhase.downloadFailed ||
      UpdateTaskPhase.verificationFailed ||
      UpdateTaskPhase.installFailed ||
      UpdateTaskPhase.automaticDownloadExhausted =>
        UpdatePhase.failed,
    };
  }

  UpdateState copyWith({
    UpdateTaskState? task,
    UpdatePresentationState? presentation,
    UpdateWorkflowFailure? failure,
    DateTime? lastSuccessfulCheckAt,
    bool clearFailure = false,
  }) {
    return UpdateState(
      task: task ?? this.task,
      presentation: presentation ?? this.presentation,
      failure: clearFailure ? null : failure ?? this.failure,
      lastSuccessfulCheckAt:
          lastSuccessfulCheckAt ?? this.lastSuccessfulCheckAt,
    );
  }
}
