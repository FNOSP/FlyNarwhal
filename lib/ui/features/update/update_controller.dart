import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/log/app_talker.dart';
import '../../../core/version/semantic_version.dart';
import '../../../data/storage/update_download_record_store.dart';
import '../../../data/storage/update_settings_store.dart';
import '../../../domain/update/entities/update_download_record.dart';
import '../../../domain/update/entities/verified_update_artifact.dart';
import '../../../domain/update/entities/update_models.dart';
import '../../../domain/update/repositories/cancellation_token.dart';
import '../../../domain/update/repositories/update_repository.dart';
import '../../../domain/update/repositories/update_repository_error.dart';
import '../../../domain/update/services/update_policy.dart';
import '../../../services/update/app_version_service.dart';
import '../../../services/update/download_url_resolver.dart';
import '../../../services/update/platform_update_installer.dart';
import '../../../services/update/sha256_verifier.dart';
import '../../../services/update/update_downloader.dart';
import '../../../services/update/update_file_store.dart';
import '../../../services/update/update_release_pagination_service.dart';
import '../../../services/update/update_retry_scheduler.dart';
import 'update_state.dart';

typedef CurrentVersionLoader = Future<SemanticVersion> Function();
typedef UpdatePlatformLoader = Future<UpdatePlatform> Function();
typedef UpdateExitRequester = Future<void> Function();
typedef UpdateInstallFailureRecovery = Future<PlatformUpdateInstallFailure?>
    Function();
typedef UpdateClock = DateTime Function();

/// Coordinates update work without coupling background tasks to presentation.
final class UpdateController extends StateNotifier<UpdateState> {
  UpdateController({
    required UpdateRepository repository,
    required UpdatePolicy policy,
    required UpdateSettingsStore settingsStore,
    required AppVersionService appVersionService,
    required UpdateDownloaderContract downloader,
    UpdateFileStoreContract? fileStore,
    UpdateDownloadRecordStore? downloadRecordStore,
    UpdatePackageVerifier? verifier,
    PlatformUpdateInstaller installer =
        const UnsupportedPlatformUpdateInstaller(),
    UpdateRetryScheduler retryScheduler = const TimerUpdateRetryScheduler(),
    CurrentVersionLoader? currentVersionLoader,
    UpdatePlatformLoader? platformLoader,
    UpdateExitRequester? exitRequester,
    UpdateInstallFailureRecovery? installFailureRecovery,
    UpdateClock? clock,
  })  : _repository = repository,
        _policy = policy,
        _settingsStore = settingsStore,
        _downloader = downloader,
        _verifier = verifier ?? const Sha256Verifier(),
        _fileStore = fileStore ??
            UpdateFileStore(
              sha256Verifier: verifier is Sha256Verifier
                  ? verifier
                  : const Sha256Verifier(),
              downloadRecordStore: downloadRecordStore,
            ),
        _downloadRecordStore =
            downloadRecordStore ?? JsonUpdateDownloadRecordStore(),
        _installer = installer,
        _retryScheduler = retryScheduler,
        _currentVersionLoader =
            currentVersionLoader ?? appVersionService.getCurrentVersion,
        _platformLoader =
            platformLoader ?? appVersionService.detectCurrentPlatform,
        _exitRequester = exitRequester ?? _doNothing,
        _installFailureRecovery = installFailureRecovery ?? _noRecoveredFailure,
        _clock = clock ?? DateTime.now,
        super(UpdateState.initial(
          lastSuccessfulCheckAt: settingsStore.lastSuccessfulCheckAt,
        )) {
    unawaited(_recoverInstallationFailure());
  }

  static const int _pageSize = 10;
  static const int _maximumPages = 20;
  static const UpdateReleasePaginationService _releasePaginationService =
      UpdateReleasePaginationService(
    pageSize: _pageSize,
    maximumPages: _maximumPages,
  );
  static const int _maximumAutomaticAttempts = 6;
  static const Duration _automaticRetryDelay = Duration(minutes: 30);

  final UpdateRepository _repository;
  final UpdatePolicy _policy;
  final UpdateSettingsStore _settingsStore;
  final UpdateDownloaderContract _downloader;
  final UpdateFileStoreContract _fileStore;
  final UpdateDownloadRecordStore _downloadRecordStore;
  final UpdatePackageVerifier _verifier;
  final PlatformUpdateInstaller _installer;
  final UpdateRetryScheduler _retryScheduler;
  final CurrentVersionLoader _currentVersionLoader;
  final UpdatePlatformLoader _platformLoader;
  final UpdateExitRequester _exitRequester;
  final UpdateInstallFailureRecovery _installFailureRecovery;
  final UpdateClock _clock;

  Future<void>? _activeCheck;
  Future<void>? _activeDownload;
  Future<void>? _activeInstallation;
  String? _activeInstallationOperationId;
  CancellationTokenSource? _checkCancellationSource;
  CancellationTokenSource? _downloadCancellationSource;
  UpdateRetryHandle? _retryHandle;
  bool _isDisposed = false;

  static Future<PlatformUpdateInstallFailure?> _noRecoveredFailure() async {
    return null;
  }

  Future<void> checkManually() {
    if (_activeInstallation != null) return Future<void>.value();
    return _activeCheck ??= _performCheck(manual: true).whenComplete(() {
      _activeCheck = null;
    });
  }

  Future<void> handleAutomaticCheck() {
    if (_activeInstallation != null) return Future<void>.value();
    return _activeCheck ??= _performCheck(manual: false).whenComplete(() {
      _activeCheck = null;
    });
  }

  Future<void> startForegroundDownload() {
    if (_activeInstallation != null) return Future<void>.value();
    final existingDownload = _activeDownload;
    if (existingDownload != null) {
      state = state.copyWith(
        task: state.task.copyWith(isForegroundTakeover: true),
        presentation: state.presentation.copyWith(
          dialogPhase: UpdateDialogPhase.downloading,
          isDialogVisible: true,
          isUpdatePromptVisible: true,
        ),
      );
      return existingDownload;
    }
    return _startDownload(UpdateDownloadMode.foreground, resetFailures: true);
  }

  Future<void> startAutomaticDownload() {
    if (_activeInstallation != null) return Future<void>.value();
    return _activeDownload ?? _startDownload(UpdateDownloadMode.automatic);
  }

  Future<void> retryManualDownload() async {
    final candidate = state.task.candidate;
    if (candidate == null) return;
    _retryHandle?.cancel();
    await _fileStore.clearForRedownload(candidate);
    await _saveFailureRecord(candidate, failureCount: 0, failureCode: null);
    await startForegroundDownload();
  }

  Future<void> cancelDownload() async {
    _retryHandle?.cancel();
    _downloadCancellationSource?.cancel();
    await _activeDownload;
  }

  Future<void> skipCandidate() async {
    final candidate = state.task.candidate;
    if (candidate == null) return;
    _retryHandle?.cancel();
    _downloadCancellationSource?.cancel();
    await _activeDownload;
    await _settingsStore.skipVersion(candidate.version.skipKey);
    await _fileStore.clearCandidate(candidate);
    await _downloadRecordStore.delete();
    if (!_isDisposed) {
      state = UpdateState.initial(
        lastSuccessfulCheckAt: state.lastSuccessfulCheckAt,
      );
    }
  }

  void closeDialog() {
    state = state.copyWith(
      presentation: state.presentation.copyWith(isDialogVisible: false),
    );
  }

  void showCandidateDialog() {
    final dialogPhase = switch (state.task.phase) {
      UpdateTaskPhase.automaticDownloadExhausted =>
        UpdateDialogPhase.automaticDownloadExhausted,
      UpdateTaskPhase.readyToInstall => UpdateDialogPhase.readyToInstall,
      UpdateTaskPhase.downloaded => UpdateDialogPhase.downloaded,
      UpdateTaskPhase.downloadFailed => UpdateDialogPhase.downloadFailed,
      UpdateTaskPhase.verificationFailed =>
        UpdateDialogPhase.verificationFailed,
      UpdateTaskPhase.installFailed => UpdateDialogPhase.installFailed,
      UpdateTaskPhase.downloading => UpdateDialogPhase.downloading,
      _ => UpdateDialogPhase.available,
    };
    state = state.copyWith(
      presentation: state.presentation.copyWith(
        dialogPhase: dialogPhase,
        isDialogVisible: true,
      ),
    );
  }

  Future<void> installDownloadedUpdate({String? operationId}) {
    final resolvedOperationId = operationId ??
        '${state.task.candidate?.version.skipKey}-${_clock().microsecondsSinceEpoch}';
    if (_activeInstallation != null) {
      return _activeInstallationOperationId == resolvedOperationId
          ? _activeInstallation!
          : Future<void>.value();
    }
    _activeInstallationOperationId = resolvedOperationId;
    return _activeInstallation =
        _performInstallation(resolvedOperationId).whenComplete(() {
      _activeInstallation = null;
      _activeInstallationOperationId = null;
    });
  }

  Future<void> retryInstallation() => installDownloadedUpdate();

  Future<void> _recoverInstallationFailure() async {
    final failure = await _installFailureRecovery();
    if (_isDisposed ||
        failure == null ||
        state.task.phase != UpdateTaskPhase.idle ||
        state.presentation.isDialogVisible) {
      return;
    }
    state = state.copyWith(
      presentation: const UpdatePresentationState(
        dialogPhase: UpdateDialogPhase.installFailed,
        isDialogVisible: true,
        isUpdatePromptVisible: true,
      ),
      failure: UpdateInstallFailure(
        code: failure.code,
        userMessageKey: failure.userMessageKey,
        technicalDetail: failure.technicalDetail,
        isRetryable: failure.isRetryable,
        cause: failure.cause,
      ),
    );
  }

  Future<void> restoreCachedUpdate(UpdateCandidate candidate) async {
    if (!await _fileStore.hasValidCachedFile(candidate)) return;
    final file = await _fileStore.getFinalFile(candidate);
    final result =
        await _verify(candidate, file, VerificationSource.cacheRecovery);
    if (result is! VerificationSuccess || _isDisposed) return;
    state = state.copyWith(
      task: UpdateTaskState(
        phase: UpdateTaskPhase.readyToInstall,
        candidate: candidate,
        localFile: file,
        verificationSource: VerificationSource.cacheRecovery,
      ),
      presentation: const UpdatePresentationState(
        dialogPhase: UpdateDialogPhase.readyToInstall,
        isUpdatePromptVisible: true,
      ),
      clearFailure: true,
    );
  }

  Future<void> handleIncludePrereleaseChanged(bool value) async {
    await _settingsStore.setIncludePrerelease(value);
    _checkCancellationSource?.cancel();
    await _activeCheck;
    await checkManually();
  }

  Future<void> handleProxyChanged({
    required bool isEnabled,
    required String proxyUrl,
  }) async {
    await _settingsStore.setProxyUrl(proxyUrl);
    await _settingsStore.setProxyEnabled(isEnabled);
  }

  Future<void> handleAutoDownloadChanged(bool value) async {
    await _settingsStore.setAutoDownload(value);
    if (value) {
      if (state.task.phase == UpdateTaskPhase.available &&
          _activeDownload == null) {
        await startAutomaticDownload();
      }
      return;
    }
    final isUnclaimedAutomatic =
        state.task.downloadMode == UpdateDownloadMode.automatic &&
            !state.task.isForegroundTakeover;
    if (isUnclaimedAutomatic) {
      await cancelDownload();
    }
  }

  /// Compatibility bridge for scheduler and existing UI call sites.
  Future<void> checkForUpdates({required bool isManual}) =>
      isManual ? checkManually() : handleAutomaticCheck();

  /// Compatibility bridge for the existing dialog.
  Future<void> downloadAvailableUpdate({bool isAutomaticDownload = false}) =>
      isAutomaticDownload
          ? startAutomaticDownload()
          : startForegroundDownload();

  /// Compatibility bridge for the existing dialog.
  Future<void> skipAvailableVersion() => skipCandidate();

  Future<void> _performCheck({required bool manual}) async {
    _checkCancellationSource = CancellationTokenSource();
    if (manual && !_isDisposed) {
      state = state.copyWith(
        presentation: state.presentation.copyWith(
          dialogPhase: UpdateDialogPhase.checking,
          isDialogVisible: true,
        ),
        clearFailure: true,
      );
    }
    try {
      AppTalker.info(
        'UpdateCheck',
        'Starting ${manual ? 'manual' : 'automatic'} update check.',
      );
      final currentVersion = await _currentVersionLoader();
      AppTalker.info(
        'UpdateCheck',
        'Current application version is ${currentVersion.skipKey}.',
      );
      final releases = await _releasePaginationService.fetchAll(
        repository: _repository,
        currentVersion: currentVersion,
        cancellationToken: _checkCancellationSource!,
      );
      final platform = await _platformLoader();
      AppTalker.info(
        'UpdateCheck',
        'Selecting update candidate from ${releases.length} fetched releases for ${platform.operatingSystem.name}/${platform.architecture.name}.',
      );
      final candidate = _policy.selectCandidate(
        releases: releases,
        currentVersion: currentVersion,
        platform: platform,
        includePrerelease: _settingsStore.includePrerelease,
        skippedVersions: _settingsStore.skippedVersions,
      );
      final successfulCheckAt = _clock();
      await _settingsStore.setLastSuccessfulCheckAt(successfulCheckAt);
      if (_isDisposed) return;
      if (candidate == null) {
        AppTalker.info(
          'UpdateCheck',
          'Update check completed: the application is up to date.',
        );
        state = state.copyWith(
          task: UpdateTaskState(phase: UpdateTaskPhase.upToDate),
          presentation: manual
              ? const UpdatePresentationState(
                  dialogPhase: UpdateDialogPhase.upToDate,
                  isDialogVisible: true,
                )
              : state.presentation,
          lastSuccessfulCheckAt: successfulCheckAt,
          clearFailure: true,
        );
        return;
      }

      AppTalker.info(
        'UpdateCheck',
        'Update check found version ${candidate.version.skipKey}.',
      );
      final activeDownloadCandidate = state.task.downloadCandidate;
      if (activeDownloadCandidate != null) {
        state = state.copyWith(
          task: state.task.copyWith(candidate: state.task.candidate),
          lastSuccessfulCheckAt: successfulCheckAt,
          clearFailure: true,
        );
        return;
      }

      // Revalidate the durable cache before replacing the current task.
      final cachedFile = await _resolveVerifiedCachedFile(candidate);
      if (_isDisposed) return;
      if (cachedFile != null) {
        state = state.copyWith(
          task: UpdateTaskState(
            phase: UpdateTaskPhase.readyToInstall,
            candidate: candidate,
            localFile: cachedFile,
            verificationSource: VerificationSource.cacheRecovery,
          ),
          presentation: UpdatePresentationState(
            dialogPhase: UpdateDialogPhase.readyToInstall,
            isDialogVisible: manual,
            isUpdatePromptVisible: true,
          ),
          lastSuccessfulCheckAt: successfulCheckAt,
          clearFailure: true,
        );
        return;
      }

      state = state.copyWith(
        task: UpdateTaskState(
          phase: UpdateTaskPhase.available,
          candidate: candidate,
        ),
        presentation: manual
            ? const UpdatePresentationState(
                dialogPhase: UpdateDialogPhase.available,
                isDialogVisible: true,
                isUpdatePromptVisible: true,
              )
            : state.presentation.copyWith(
                isDialogVisible: false,
                isUpdatePromptVisible: !_settingsStore.autoDownload,
              ),
        lastSuccessfulCheckAt: successfulCheckAt,
        clearFailure: true,
      );
      if (!manual && _settingsStore.autoDownload && _activeDownload == null) {
        await startAutomaticDownload();
      }
    } on UpdateOperationCancelledException {
      AppTalker.info('UpdateCheck', 'Update check was cancelled.');
      return;
    } on Object catch (error, stackTrace) {
      AppTalker.error(
        'UpdateCheck',
        error: error,
        stackTrace: stackTrace,
        message: 'Update check failed.',
      );
      if (_isDisposed) return;
      final failure = _mapCheckFailure(error);
      state = state.copyWith(
        task: state.task.candidate == null
            ? UpdateTaskState(phase: UpdateTaskPhase.checkFailed)
            : state.task,
        presentation: manual
            ? const UpdatePresentationState(
                dialogPhase: UpdateDialogPhase.checkFailed,
                isDialogVisible: true,
              )
            : state.presentation,
        failure: failure,
      );
    } finally {
      _checkCancellationSource = null;
    }
  }

  Future<void> _startDownload(
    UpdateDownloadMode mode, {
    bool resetFailures = false,
  }) {
    final candidate = state.task.candidate;
    if (candidate == null) return Future<void>.value();
    if (resetFailures) {
      _retryHandle?.cancel();
    }
    _activeDownload = _performDownload(
      candidate,
      mode,
      resetFailures: resetFailures,
    ).whenComplete(() {
      _activeDownload = null;
      _downloadCancellationSource = null;
    });
    return _activeDownload!;
  }

  Future<void> _performDownload(
    UpdateCandidate candidate,
    UpdateDownloadMode mode, {
    required bool resetFailures,
  }) async {
    _downloadCancellationSource = CancellationTokenSource();
    var failureCount = resetFailures ? 0 : await _loadFailureCount(candidate);
    if (resetFailures) {
      await _saveFailureRecord(candidate, failureCount: 0, failureCode: null);
    }
    if (_isDisposed) return;
    state = state.copyWith(
      task: UpdateTaskState(
        phase: UpdateTaskPhase.downloading,
        candidate: candidate,
        downloadCandidate: candidate,
        totalBytes: candidate.asset.sizeInBytes,
        downloadMode: mode,
        automaticFailureCount: failureCount,
      ),
      presentation: mode == UpdateDownloadMode.foreground
          ? const UpdatePresentationState(
              dialogPhase: UpdateDialogPhase.downloading,
              isDialogVisible: true,
              isUpdatePromptVisible: true,
            )
          : const UpdatePresentationState(),
      clearFailure: true,
    );
    try {
      final result = await _downloader.downloadVerified(
        UpdateDownloadRequest(
          candidate: candidate,
          proxySnapshot: UpdateProxySnapshot(
            isEnabled: _settingsStore.isProxyEnabled,
            baseUrl: _settingsStore.proxyUrl,
          ),
          cancellationToken: _downloadCancellationSource!,
        ),
        onProgress: (progress) {
          if (_isDisposed ||
              state.task.downloadCandidate?.version.skipKey !=
                  candidate.version.skipKey) {
            return;
          }
          state = state.copyWith(
            task: state.task.copyWith(
              receivedBytes: progress.receivedBytes,
              totalBytes: progress.totalBytes,
            ),
          );
        },
      );
      if (_isDisposed) return;
      state = state.copyWith(
        task: state.task.copyWith(
          phase: UpdateTaskPhase.verifying,
          localFile: result.file,
          verificationSource: VerificationSource.download,
        ),
        presentation: _showsForegroundDownload
            ? state.presentation.copyWith(
                dialogPhase: UpdateDialogPhase.verifying,
              )
            : state.presentation,
      );
      final verification = await _verify(
        candidate,
        result.file,
        VerificationSource.download,
      );
      if (verification is VerificationFailure) {
        await _handleVerificationFailure(candidate, verification);
        return;
      }
      await _saveVerifiedRecord(candidate, result.file);
      if (_isDisposed) return;
      final isForeground = _showsForegroundDownload;
      state = state.copyWith(
        task: state.task.copyWith(
          phase: isForeground
              ? UpdateTaskPhase.downloaded
              : UpdateTaskPhase.readyToInstall,
          localFile: result.file,
          clearDownloadCandidate: true,
          automaticFailureCount: 0,
        ),
        presentation: UpdatePresentationState(
          dialogPhase: isForeground
              ? UpdateDialogPhase.downloaded
              : UpdateDialogPhase.readyToInstall,
          isDialogVisible: isForeground,
          isUpdatePromptVisible: true,
        ),
        clearFailure: true,
      );
    } on UpdateDownloadException catch (error, stackTrace) {
      AppTalker.instance.handle(error, stackTrace);
      final cancelled = error.type == UpdateDownloadFailureType.cancelled;
      if (cancelled) {
        await _fileStore.deletePartialFile(candidate);
        if (!_isDisposed) _publishAvailableAfterCancellation(candidate);
        return;
      }
      final failure = UpdateDownloadFailure(
        code: error.type.name,
        userMessageKey: error.userMessageKey,
        technicalDetail: error.technicalDetail,
        isRetryable: error.isRetryable,
        cause: error.cause,
      );
      if (mode == UpdateDownloadMode.automatic &&
          !state.task.isForegroundTakeover) {
        failureCount++;
        await _handleAutomaticFailure(candidate, failure, failureCount);
      } else if (!_isDisposed) {
        state = state.copyWith(
          task: state.task.copyWith(
            phase: UpdateTaskPhase.downloadFailed,
            clearDownloadCandidate: true,
          ),
          presentation: const UpdatePresentationState(
            dialogPhase: UpdateDialogPhase.downloadFailed,
            isDialogVisible: true,
            isUpdatePromptVisible: true,
          ),
          failure: failure,
        );
      }
    } on Object catch (error, stackTrace) {
      AppTalker.instance.handle(error, stackTrace);
      final failure = UpdateDownloadFailure(
        code: 'unknown',
        userMessageKey: 'update.download.error.unknown',
        technicalDetail: error.toString(),
        isRetryable: true,
        cause: error,
      );
      if (mode == UpdateDownloadMode.automatic &&
          !state.task.isForegroundTakeover) {
        failureCount++;
        await _handleAutomaticFailure(candidate, failure, failureCount);
      } else if (!_isDisposed) {
        state = state.copyWith(failure: failure);
      }
    }
  }

  bool get _showsForegroundDownload =>
      state.task.downloadMode == UpdateDownloadMode.foreground ||
      state.task.isForegroundTakeover;

  Future<void> _handleAutomaticFailure(
    UpdateCandidate candidate,
    UpdateDownloadFailure failure,
    int failureCount,
  ) async {
    await _saveFailureRecord(
      candidate,
      failureCount: failureCount,
      failureCode: failure.code,
    );
    if (_isDisposed) return;
    if (failureCount >= _maximumAutomaticAttempts) {
      state = state.copyWith(
        task: state.task.copyWith(
          phase: UpdateTaskPhase.automaticDownloadExhausted,
          clearDownloadCandidate: true,
          automaticFailureCount: failureCount,
        ),
        presentation: const UpdatePresentationState(
          dialogPhase: UpdateDialogPhase.automaticDownloadExhausted,
          isUpdatePromptVisible: true,
        ),
        failure: AutomaticDownloadExhaustedFailure(
          failureCount: failureCount,
          code: failure.code,
          userMessageKey: 'update.download.error.automaticExhausted',
          technicalDetail: failure.technicalDetail,
          cause: failure.cause,
        ),
      );
      return;
    }
    state = state.copyWith(
      task: state.task.copyWith(
        phase: UpdateTaskPhase.downloadFailed,
        clearDownloadCandidate: true,
        automaticFailureCount: failureCount,
      ),
      presentation: const UpdatePresentationState(),
      failure: failure,
    );
    _retryHandle = _retryScheduler.schedule(_automaticRetryDelay, () async {
      if (_isDisposed ||
          state.task.candidate?.version.skipKey != candidate.version.skipKey) {
        return;
      }
      await startAutomaticDownload();
    });
  }

  Future<void> _handleVerificationFailure(
    UpdateCandidate candidate,
    VerificationFailure failure,
  ) async {
    await _fileStore.clearForRedownload(candidate);
    if (_isDisposed) return;
    final workflowFailure = UpdateVerificationFailure(
      reason: failure.reason,
      code: failure.reason.name,
      userMessageKey: 'update.verification.error.${failure.reason.name}',
      technicalDetail: failure.technicalDetail,
      isRetryable: failure.reason != VerificationFailureReason.digestMissing &&
          failure.reason != VerificationFailureReason.digestInvalid,
      cause: failure.cause,
    );
    state = state.copyWith(
      task: state.task.copyWith(
        phase: UpdateTaskPhase.verificationFailed,
        clearDownloadCandidate: true,
        clearLocalFile: true,
      ),
      presentation: UpdatePresentationState(
        dialogPhase: UpdateDialogPhase.verificationFailed,
        isDialogVisible: _showsForegroundDownload,
        isUpdatePromptVisible: _showsForegroundDownload,
      ),
      failure: workflowFailure,
    );
  }

  Future<void> _performInstallation(String operationId) async {
    final candidate = state.task.candidate;
    var file = state.task.localFile;
    if (candidate == null) return;
    if (file == null) {
      file = await _recoverMissingInstallFile(candidate);
      if (file == null) return;
    }
    state = state.copyWith(
      task: state.task.copyWith(
        phase: UpdateTaskPhase.verifying,
        verificationSource: VerificationSource.preInstall,
      ),
      presentation: state.presentation.copyWith(
        dialogPhase: UpdateDialogPhase.verifying,
        isDialogVisible: true,
      ),
      clearFailure: true,
    );
    final verification =
        await _verify(candidate, file, VerificationSource.preInstall);
    if (verification is! VerificationSuccess) {
      await _handleVerificationFailure(
        candidate,
        verification as VerificationFailure,
      );
      return;
    }
    if (_isDisposed) return;
    final verifiedArtifact = VerifiedUpdateArtifact(
      candidate: candidate,
      file: verification.file,
      length: candidate.asset.sizeInBytes,
      sha256: verification.sha256,
      verifiedAt: _clock().toUtc(),
    );
    state = state.copyWith(
      task: state.task.copyWith(phase: UpdateTaskPhase.installing),
      presentation: state.presentation.copyWith(
        dialogPhase: UpdateDialogPhase.installing,
      ),
    );
    final result = await _installer.launch(PlatformUpdateInstallRequest(
      operationId: operationId,
      artifact: verifiedArtifact,
    ));
    if (result is PlatformUpdateHelperLaunched) {
      await _exitRequester();
      return;
    }
    final failure = result as PlatformUpdateInstallFailure;
    if (_isDisposed) return;
    state = state.copyWith(
      task: state.task.copyWith(phase: UpdateTaskPhase.installFailed),
      presentation: const UpdatePresentationState(
        dialogPhase: UpdateDialogPhase.installFailed,
        isDialogVisible: true,
        isUpdatePromptVisible: true,
      ),
      failure: UpdateInstallFailure(
        code: failure.code,
        userMessageKey: failure.userMessageKey,
        technicalDetail: failure.technicalDetail,
        isRetryable: failure.isRetryable,
        cause: failure.cause,
      ),
    );
  }

  Future<File?> _resolveVerifiedCachedFile(UpdateCandidate candidate) async {
    if (!await _fileStore.hasValidCachedFile(candidate)) return null;
    final cachedFile = await _fileStore.getFinalFile(candidate);
    final verification = await _verify(
      candidate,
      cachedFile,
      VerificationSource.cacheRecovery,
    );
    return verification is VerificationSuccess ? cachedFile : null;
  }

  Future<File?> _recoverMissingInstallFile(
    UpdateCandidate candidate,
  ) async {
    final hasCachedFile = await _fileStore.hasValidCachedFile(candidate);
    if (!hasCachedFile) {
      if (_isDisposed) return null;
      state = state.copyWith(
        task: state.task.copyWith(phase: UpdateTaskPhase.available),
        presentation: const UpdatePresentationState(
          dialogPhase: UpdateDialogPhase.available,
          isDialogVisible: true,
          isUpdatePromptVisible: true,
        ),
      );
      return null;
    }
    final recoveredFile = await _fileStore.getFinalFile(candidate);
    if (_isDisposed) return null;
    state = state.copyWith(
      task: state.task.copyWith(
        phase: UpdateTaskPhase.readyToInstall,
        localFile: recoveredFile,
        verificationSource: VerificationSource.cacheRecovery,
      ),
      presentation: state.presentation.copyWith(
        dialogPhase: UpdateDialogPhase.readyToInstall,
        isDialogVisible: true,
        isUpdatePromptVisible: true,
      ),
      clearFailure: true,
    );
    return recoveredFile;
  }

  Future<VerificationResult> _verify(
    UpdateCandidate candidate,
    File file,
    VerificationSource source,
  ) {
    return _verifier.verify(VerificationRequest(
      file: file,
      expectedDigest: candidate.asset.digest,
      expectedSize: candidate.asset.sizeInBytes,
      source: source,
      cancellationToken: const NonCancellableToken(),
    ));
  }

  UpdateCheckFailure _mapCheckFailure(Object error) {
    if (error is UpdateRepositoryException) {
      return UpdateCheckFailure(
        code: error.code.name,
        userMessageKey: 'update.check.error.${error.code.name}',
        technicalDetail: error.technicalDetails,
        isRetryable: error.retryable,
        cause: error,
      );
    }
    return UpdateCheckFailure(
      code: 'unknown',
      userMessageKey: 'update.check.error.unknown',
      technicalDetail: error.toString(),
      isRetryable: true,
      cause: error,
    );
  }

  Future<int> _loadFailureCount(UpdateCandidate candidate) async {
    final record = await _downloadRecordStore.load();
    if (record?.version == candidate.version.skipKey &&
        record?.assetName == candidate.asset.name) {
      return record!.automaticFailureCount;
    }
    return 0;
  }

  Future<void> _saveFailureRecord(
    UpdateCandidate candidate, {
    required int failureCount,
    required String? failureCode,
  }) async {
    final file = await _fileStore.getFinalFile(candidate);
    await _downloadRecordStore.save(UpdateDownloadRecord(
      schemaVersion: UpdateDownloadRecord.currentSchemaVersion,
      version: candidate.version.skipKey,
      assetName: candidate.asset.name,
      officialDownloadUrl: candidate.asset.officialDownloadUrl,
      expectedSize: candidate.asset.sizeInBytes,
      expectedSha256: candidate.asset.digest!,
      finalFilePath: file.path,
      stage: UpdateDownloadStage.failed,
      automaticFailureCount: failureCount,
      lastFailureCode: failureCode,
      lastFailureAt: failureCode == null ? null : _clock().toUtc(),
      updatedAt: _clock().toUtc(),
    ));
  }

  Future<void> _saveVerifiedRecord(
    UpdateCandidate candidate,
    File file,
  ) async {
    await _downloadRecordStore.save(UpdateDownloadRecord(
      schemaVersion: UpdateDownloadRecord.currentSchemaVersion,
      version: candidate.version.skipKey,
      assetName: candidate.asset.name,
      officialDownloadUrl: candidate.asset.officialDownloadUrl,
      expectedSize: candidate.asset.sizeInBytes,
      expectedSha256: candidate.asset.digest!,
      finalFilePath: file.path,
      stage: UpdateDownloadStage.verified,
      automaticFailureCount: 0,
      lastFailureCode: null,
      lastFailureAt: null,
      updatedAt: _clock().toUtc(),
    ));
  }

  void _publishAvailableAfterCancellation(UpdateCandidate candidate) {
    state = state.copyWith(
      task: UpdateTaskState(
        phase: UpdateTaskPhase.available,
        candidate: candidate,
      ),
      presentation: const UpdatePresentationState(
        dialogPhase: UpdateDialogPhase.available,
        isUpdatePromptVisible: true,
      ),
      clearFailure: true,
    );
  }

  /// Test seam for installation states without filesystem access.
  void debugSetReadyToInstall(UpdateCandidate candidate, File file) {
    state = state.copyWith(
      task: UpdateTaskState(
        phase: UpdateTaskPhase.readyToInstall,
        candidate: candidate,
        localFile: file,
      ),
      presentation: const UpdatePresentationState(
        dialogPhase: UpdateDialogPhase.readyToInstall,
        isUpdatePromptVisible: true,
      ),
    );
  }

  /// Test seam for persisted exhausted recovery.
  void debugSetAutomaticExhausted(UpdateCandidate candidate) {
    state = state.copyWith(
      task: UpdateTaskState(
        phase: UpdateTaskPhase.automaticDownloadExhausted,
        candidate: candidate,
        automaticFailureCount: _maximumAutomaticAttempts,
      ),
      presentation: const UpdatePresentationState(
        dialogPhase: UpdateDialogPhase.automaticDownloadExhausted,
        isUpdatePromptVisible: true,
      ),
    );
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _checkCancellationSource?.cancel();
    _retryHandle?.cancel();
    super.dispose();
  }

  static Future<void> _doNothing() async {}
}
