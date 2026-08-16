import 'dart:io';
import 'dart:math';

import 'platform_update_installer.dart';
import 'windows_native_updater_bridge.dart';
import 'windows_update_install_stage_store.dart';
import 'windows_update_transaction_store.dart';

typedef WindowsArchitectureLoader = Future<String> Function();

/// Coordinates app-owned staging with the native helper transaction contract.
final class WindowsNativeUpdateInstaller implements PlatformUpdateInstaller {
  WindowsNativeUpdateInstaller({
    required WindowsUpdateInstallStageStore stageStore,
    required WindowsUpdateTransactionStore transactionStore,
    required WindowsNativeUpdaterBridge bridge,
    WindowsArchitectureLoader? architectureLoader,
  })  : _stageStore = stageStore,
        _transactionStore = transactionStore,
        _bridge = bridge,
        _architectureLoader = architectureLoader ?? _loadArchitecture;

  final WindowsUpdateInstallStageStore _stageStore;
  final WindowsUpdateTransactionStore _transactionStore;
  final WindowsNativeUpdaterBridge _bridge;
  final WindowsArchitectureLoader _architectureLoader;
  final Map<String, Future<PlatformUpdateInstallResult>> _operations =
      <String, Future<PlatformUpdateInstallResult>>{};

  @override
  Future<PlatformUpdateInstallResult> launch(
    PlatformUpdateInstallRequest request,
  ) {
    return _operations.putIfAbsent(
      request.operationId,
      () => _launchNewTransaction(request),
    );
  }

  Future<PlatformUpdateInstallResult> _launchNewTransaction(
    PlatformUpdateInstallRequest request,
  ) async {
    try {
      final existingReceipt = await _transactionStore.loadActive();
      if (existingReceipt != null) {
        return _reuseExistingTransaction(request, existingReceipt);
      }
      final architecture = await _architectureLoader();
      final transactionId = _createLowercaseUuidV4();
      final stage = await _stageStore.createStage(
        artifact: request.artifact,
        transactionId: transactionId,
        operationId: request.operationId,
        architecture: architecture,
      );
      final receipt = _createReceipt(stage);

      // Persist both receipts before the helper sees the stage.
      await _transactionStore.save(stage: stage, receipt: receipt);
      await _transactionStore.saveActive(receipt);
      final verifiedReceipt = await _transactionStore.load(stage);
      final indexedReceipt = await _transactionStore.loadActive();
      if (verifiedReceipt == null ||
          indexedReceipt == null ||
          indexedReceipt.transactionId != verifiedReceipt.transactionId ||
          indexedReceipt.operationId != verifiedReceipt.operationId) {
        return _failure(
          'windows_stage_provenance_failure',
          'The pending Windows update receipt is missing after readback.',
          retryable: false,
        );
      }

      final prepareResponse = await _bridge.prepare(verifiedReceipt);
      if (prepareResponse.status != WindowsNativeTransactionStatus.prepared) {
        return _mapHelperResponse(prepareResponse);
      }
      final commitResponse = await _bridge.commit(verifiedReceipt);
      if (commitResponse.status ==
          WindowsNativeTransactionStatus.commitAccepted) {
        return const PlatformUpdateCommitAccepted();
      }
      return _mapHelperResponse(commitResponse);
    } on WindowsUpdateInstallStageException catch (error) {
      return _failure(
        'windows_stage_provenance_failure',
        error.message,
        retryable: false,
        cause: error,
      );
    } on WindowsUpdateTransactionException catch (error) {
      return _failure(
        'windows_stage_provenance_failure',
        error.message,
        retryable: false,
        cause: error,
      );
    } on Object catch (error) {
      return _failure(
        'windows_helper_unavailable',
        error.toString(),
        retryable: true,
        cause: error,
      );
    }
  }

  Future<PlatformUpdateInstallResult> _reuseExistingTransaction(
    PlatformUpdateInstallRequest request,
    WindowsPendingInstallReceipt receipt,
  ) async {
    if (receipt.operationId != request.operationId ||
        receipt.expectedArtifactSha256 != request.artifact.sha256 ||
        receipt.expectedArtifactLength != request.artifact.length) {
      return _failure(
        'windows_transaction_busy',
        'Another durable Windows update transaction is already active.',
        retryable: false,
      );
    }

    // Re-verify the durable stage before returning its native state.
    final stage = await _stageStore.loadAndVerifyStage(receipt.stagePath);
    final stageReceipt = await _transactionStore.load(stage);
    if (stageReceipt == null ||
        stageReceipt.transactionId != receipt.transactionId) {
      return _failure(
        'windows_stage_provenance_failure',
        'The existing Windows transaction receipt could not be verified.',
        retryable: false,
      );
    }
    final response = await _bridge.query(receipt.transactionId);
    if (response.status == WindowsNativeTransactionStatus.prepared) {
      return _commitExisting(stageReceipt);
    }
    return switch (response.status) {
      WindowsNativeTransactionStatus.commitAccepted =>
        const PlatformUpdateCommitAccepted(),
      WindowsNativeTransactionStatus.completed =>
        const PlatformUpdateCommitAccepted(),
      WindowsNativeTransactionStatus.recoveryRequired =>
        PlatformUpdateRecoveryRequired(
          transactionId: receipt.transactionId,
          technicalDetail: response.technicalDetail ??
              'The existing Windows transaction requires recovery.',
        ),
      WindowsNativeTransactionStatus.manualActionRequired =>
        PlatformUpdateManualActionRequired(
          transactionId: receipt.transactionId,
          technicalDetail: response.technicalDetail ??
              'The existing Windows transaction requires manual action.',
        ),
      _ => _mapHelperResponse(response),
    };
  }

  Future<PlatformUpdateInstallResult> _commitExisting(
    WindowsPendingInstallReceipt receipt,
  ) async {
    final response = await _bridge.commit(receipt);
    if (response.status == WindowsNativeTransactionStatus.commitAccepted) {
      return const PlatformUpdateCommitAccepted();
    }
    return _mapHelperResponse(response);
  }

  WindowsPendingInstallReceipt _createReceipt(WindowsUpdateInstallStage stage) {
    return WindowsPendingInstallReceipt(
      schemaVersion: WindowsPendingInstallReceipt.currentSchemaVersion,
      transactionId: stage.transactionId,
      operationId: stage.authority.operationId,
      stagePath: stage.stageDirectory.path,
      stageProvenanceSha256: stage.provenanceSha256,
      expectedArtifactSha256: stage.authority.artifactSha256,
      expectedArtifactLength: stage.authority.artifactLength,
      candidateVersion: stage.authority.version,
      packageId: stage.authority.packageId,
      architecture: stage.authority.architecture,
    );
  }

  PlatformUpdateInstallFailure _mapHelperResponse(
    WindowsNativeUpdaterResponse response,
  ) {
    final mappedCode = switch (response.status) {
      WindowsNativeTransactionStatus.recoveryRequired =>
        'windows_recovery_required',
      WindowsNativeTransactionStatus.manualActionRequired =>
        'windows_manual_action_required',
      WindowsNativeTransactionStatus.unknown =>
        response.code ?? 'windows_helper_unavailable',
      _ => response.code ?? 'windows_helper_trust_failure',
    };
    return _failure(
      mappedCode,
      response.technicalDetail ??
          'The Windows update helper rejected the transaction.',
      retryable:
          response.status == WindowsNativeTransactionStatus.recoveryRequired ||
              response.status == WindowsNativeTransactionStatus.unknown,
    );
  }

  PlatformUpdateInstallFailure _failure(
    String code,
    String detail, {
    required bool retryable,
    Object? cause,
  }) {
    return PlatformUpdateInstallFailure(
      code: code,
      userMessageKey: 'update.install.error.$code',
      technicalDetail: detail,
      isRetryable: retryable,
      cause: cause,
    );
  }

  static Future<String> _loadArchitecture() async {
    final architecture = Platform.environment['PROCESSOR_ARCHITEW6432'] ??
        Platform.environment['PROCESSOR_ARCHITECTURE'];
    return switch (architecture?.toLowerCase()) {
      'amd64' || 'x86_64' || 'x64' => 'x64',
      'arm64' || 'aarch64' => 'arm64',
      _ =>
        throw UnsupportedError('Windows update architecture is unsupported.'),
    };
  }

  static String _createLowercaseUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hexadecimal =
        bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${hexadecimal.substring(0, 8)}-'
        '${hexadecimal.substring(8, 12)}-'
        '${hexadecimal.substring(12, 16)}-'
        '${hexadecimal.substring(16, 20)}-'
        '${hexadecimal.substring(20)}';
  }
}
