import 'dart:io';

import 'package:path/path.dart' as path;

import '../../core/utils/log/app_talker.dart';
import 'windows_update_transaction_store.dart';

typedef WindowsNativeHelperProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

/// Describes the native helper state without exposing installation commands.
enum WindowsNativeTransactionStatus {
  prepared,
  restaged,
  recoveryArmed,
  commitAccepted,
  completed,
  failed,
  recoveryRequired,
  manualActionRequired,
  cancelled,
  unknown,
}

/// Immutable response returned by the sealed Windows helper endpoints.
final class WindowsNativeUpdaterResponse {
  const WindowsNativeUpdaterResponse({
    required this.status,
    this.code,
    this.technicalDetail,
  });

  final WindowsNativeTransactionStatus status;
  final String? code;
  final String? technicalDetail;

  bool get isAccepted =>
      status == WindowsNativeTransactionStatus.prepared ||
      status == WindowsNativeTransactionStatus.restaged ||
      status == WindowsNativeTransactionStatus.recoveryArmed ||
      status == WindowsNativeTransactionStatus.commitAccepted;
}

abstract interface class WindowsNativeUpdaterBridge {
  Future<WindowsNativeUpdaterResponse> prepare(
    WindowsPendingInstallReceipt receipt,
  );

  Future<WindowsNativeUpdaterResponse> commit(
    WindowsPendingInstallReceipt receipt,
  );

  Future<WindowsNativeUpdaterResponse> query(String transactionId);

  Future<WindowsNativeUpdaterResponse> recover(String transactionId);

  Future<WindowsNativeUpdaterResponse> cancel(String transactionId);
}

/// Invokes the bundled helper with its sealed endpoint contract.
final class ProcessWindowsNativeUpdaterBridge
    implements WindowsNativeUpdaterBridge {
  ProcessWindowsNativeUpdaterBridge({
    File? helperExecutable,
    WindowsNativeHelperProcessRunner? processRunner,
  })  : _helperExecutable = helperExecutable ?? _defaultHelperExecutable(),
        _processRunner = processRunner ?? Process.run;

  static const String helperExecutableName = 'FlyNarwhalInstallHelper.exe';

  final File _helperExecutable;
  final WindowsNativeHelperProcessRunner _processRunner;

  @override
  Future<WindowsNativeUpdaterResponse> prepare(
    WindowsPendingInstallReceipt receipt,
  ) {
    return _invokeWithBindings('prepare', receipt);
  }

  @override
  Future<WindowsNativeUpdaterResponse> commit(
    WindowsPendingInstallReceipt receipt,
  ) {
    return _invokeWithBindings('commit', receipt);
  }

  @override
  Future<WindowsNativeUpdaterResponse> query(String transactionId) {
    return _invoke(
      <String>['query', '--transaction-id', transactionId],
    );
  }

  @override
  Future<WindowsNativeUpdaterResponse> recover(String transactionId) {
    return _invoke(
      <String>['recover', '--transaction-id', transactionId],
    );
  }

  @override
  Future<WindowsNativeUpdaterResponse> cancel(String transactionId) {
    return _invoke(
      <String>['cancel', '--transaction-id', transactionId],
    );
  }

  Future<WindowsNativeUpdaterResponse> _invokeWithBindings(
    String command,
    WindowsPendingInstallReceipt receipt,
  ) {
    // Supply only receipt bindings and bridge-controlled caller identity.
    return _invoke(<String>[
      command,
      '--transaction-id',
      receipt.transactionId,
      '--stage',
      receipt.stagePath,
      '--provenance-sha256',
      receipt.stageProvenanceSha256,
      '--artifact-sha256',
      receipt.expectedArtifactSha256,
      '--artifact-length',
      receipt.expectedArtifactLength.toString(),
      '--caller-pid',
      pid.toString(),
      '--caller-executable',
      Platform.resolvedExecutable,
    ]);
  }

  Future<WindowsNativeUpdaterResponse> _invoke(
    List<String> arguments,
  ) async {
    if (!await _helperExecutable.exists()) {
      AppTalker.warning(
        'WindowsUpdateBridge',
        'Native helper is missing: ${_helperExecutable.path}',
      );
      return const WindowsNativeUpdaterResponse(
        status: WindowsNativeTransactionStatus.unknown,
        code: 'windows_helper_unavailable',
        technicalDetail: 'The Windows update helper is not available.',
      );
    }
    AppTalker.info(
      'WindowsUpdateBridge',
      'Invoking helper ${_helperExecutable.path} with ${arguments.join(' ')}.',
    );
    try {
      final result = await _processRunner(_helperExecutable.path, arguments);
      final standardOutput = result.stdout.toString().trim();
      final standardError = result.stderr.toString().trim();
      AppTalker.info(
        'WindowsUpdateBridge',
        'Helper exited with code ${result.exitCode}, stdout="$standardOutput", stderr="$standardError".',
      );
      if (result.exitCode != 0) {
        final technicalDetail =
            standardError.isEmpty ? standardOutput : standardError;
        final transactionWasNotFound =
            technicalDetail == 'No active transaction exists.';
        final transactionMismatch = technicalDetail ==
            'Active transaction belongs to a different transaction.';
        final code = transactionWasNotFound
            ? 'windows_transaction_not_found'
            : (transactionMismatch
                ? 'windows_active_transaction_mismatch'
                : _codeForFailure(result.exitCode, technicalDetail));
        return WindowsNativeUpdaterResponse(
          status: (transactionWasNotFound || transactionMismatch)
              ? WindowsNativeTransactionStatus.unknown
              : _statusForExitCode(result.exitCode),
          code: code,
          technicalDetail: technicalDetail,
        );
      }
      return _decodeStatus(standardOutput);
    } on Object catch (error) {
      AppTalker.error(
        'WindowsUpdateBridge',
        error: error,
        message: 'Failed to invoke native helper.',
      );
      return WindowsNativeUpdaterResponse(
        status: WindowsNativeTransactionStatus.unknown,
        code: 'windows_helper_unavailable',
        technicalDetail: error.toString(),
      );
    }
  }

  WindowsNativeUpdaterResponse _decodeStatus(String rawStatus) {
    final status = _parseStatus(rawStatus);
    if (status != WindowsNativeTransactionStatus.unknown) {
      return WindowsNativeUpdaterResponse(status: status);
    }
    return const WindowsNativeUpdaterResponse(
      status: WindowsNativeTransactionStatus.unknown,
      code: 'windows_helper_protocol_failure',
      technicalDetail: 'The Windows update helper returned an invalid status.',
    );
  }

  WindowsNativeTransactionStatus _statusForExitCode(int exitCode) {
    return switch (exitCode) {
      2 => WindowsNativeTransactionStatus.failed,
      3 => WindowsNativeTransactionStatus.failed,
      4 => WindowsNativeTransactionStatus.recoveryRequired,
      5 => WindowsNativeTransactionStatus.manualActionRequired,
      _ => WindowsNativeTransactionStatus.unknown,
    };
  }

  String _codeForFailure(int exitCode, String technicalDetail) {
    return switch (exitCode) {
      2 => _codeForTrustFailureDetail(technicalDetail),
      3 => 'windows_transaction_busy',
      4 => 'windows_recovery_required',
      5 => 'windows_manual_action_required',
      64 => 'windows_helper_protocol_failure',
      _ => 'windows_helper_unavailable',
    };
  }

  String _codeForTrustFailureDetail(String technicalDetail) {
    // Classify protected-endpoint failures more precisely than the exit code.
    if (technicalDetail.contains('Protected endpoint is unavailable.') ||
        technicalDetail.contains('Endpoint registry value is missing.') ||
        technicalDetail.contains('Endpoint registry schema is missing.')) {
      return 'windows_protected_endpoint_missing';
    }
    // Any protected-endpoint rejection beyond "unavailable" is an invalid
    // descriptor/policy condition, including the granular check messages.
    if (technicalDetail.contains('Protected endpoint') ||
        technicalDetail.contains('Endpoint policy is unreadable.') ||
        technicalDetail.contains('Endpoint policy target is invalid.') ||
        technicalDetail.contains('Endpoint descriptor target is invalid.')) {
      return 'windows_protected_endpoint_invalid';
    }
    if (technicalDetail.contains('Recovery host task could not be created.') ||
        technicalDetail.contains('Recovery host task could not be started.')) {
      return 'windows_recovery_host_arm_failed';
    }
    if (technicalDetail.contains('Restaged installer is missing or invalid.') ||
        technicalDetail.contains(
          'Restaged installer could not be verified.',
        )) {
      return 'windows_restaged_installer_invalid';
    }
    return 'windows_helper_trust_failure';
  }

  WindowsNativeTransactionStatus _parseStatus(String rawStatus) {
    return switch (rawStatus) {
      'prepared' => WindowsNativeTransactionStatus.prepared,
      'restaged' => WindowsNativeTransactionStatus.restaged,
      'recoveryArmed' || 'recoveryAccepted' =>
        WindowsNativeTransactionStatus.recoveryArmed,
      'commitAccepted' => WindowsNativeTransactionStatus.commitAccepted,
      'completed' => WindowsNativeTransactionStatus.completed,
      'failed' => WindowsNativeTransactionStatus.failed,
      'recoveryRequired' ||
      'waitingForExit' ||
      'managerStarted' ||
      'verificationPending' =>
        WindowsNativeTransactionStatus.recoveryRequired,
      'manualActionRequired' =>
        WindowsNativeTransactionStatus.manualActionRequired,
      'cancelled' => WindowsNativeTransactionStatus.cancelled,
      _ => WindowsNativeTransactionStatus.unknown,
    };
  }

  static File _defaultHelperExecutable() {
    final executable = File(Platform.resolvedExecutable);
    return File(path.join(executable.parent.path, helperExecutableName));
  }
}
