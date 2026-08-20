import '../../core/utils/log/app_talker.dart';
import 'platform_update_installer.dart';
import 'windows_native_updater_bridge.dart';
import 'windows_update_install_stage_store.dart';
import 'windows_update_transaction_store.dart';

/// Reconciles an app-owned receipt with the native durable journal at startup.
final class WindowsPlatformUpdateRecovery {
  const WindowsPlatformUpdateRecovery({
    required WindowsUpdateInstallStageStore stageStore,
    required WindowsUpdateTransactionStore transactionStore,
    required WindowsNativeUpdaterBridge bridge,
  })  : _stageStore = stageStore,
        _transactionStore = transactionStore,
        _bridge = bridge;

  final WindowsUpdateInstallStageStore _stageStore;
  final WindowsUpdateTransactionStore _transactionStore;
  final WindowsNativeUpdaterBridge _bridge;

  Future<PlatformUpdateInstallFailure?> recoverFailure() async {
    try {
      final indexedReceipt = await _transactionStore.loadActive();
      if (indexedReceipt == null) return null;
      AppTalker.info(
        'WindowsUpdateRecovery',
        'Recovering active transaction ${indexedReceipt.transactionId}.',
      );

      // Re-verify both durable app-owned copies before trusting the journal.
      final stage =
          await _stageStore.loadAndVerifyStage(indexedReceipt.stagePath);
      final stageReceipt = await _transactionStore.load(stage);
      if (stageReceipt == null ||
          stageReceipt.transactionId != indexedReceipt.transactionId ||
          stageReceipt.operationId != indexedReceipt.operationId ||
          stageReceipt.stagePath != indexedReceipt.stagePath ||
          stageReceipt.stageProvenanceSha256 !=
              indexedReceipt.stageProvenanceSha256) {
        return _failure(
          'windows_stage_provenance_failure',
          'The active Windows transaction index does not match its stage receipt.',
          retryable: false,
        );
      }

      final queryResponse = await _bridge.query(indexedReceipt.transactionId);
      AppTalker.info(
        'WindowsUpdateRecovery',
        'Helper query returned ${queryResponse.status.name} during recovery.',
      );
      if (queryResponse.code == 'windows_transaction_not_found') {
        await _transactionStore.clearActive(
          transactionId: indexedReceipt.transactionId,
        );
        return null;
      }
      switch (queryResponse.status) {
        case WindowsNativeTransactionStatus.completed:
          await _transactionStore.clearActive(
            transactionId: indexedReceipt.transactionId,
          );
          return null;
        case WindowsNativeTransactionStatus.prepared:
        case WindowsNativeTransactionStatus.restaged:
        case WindowsNativeTransactionStatus.recoveryArmed:
        case WindowsNativeTransactionStatus.commitAccepted:
        case WindowsNativeTransactionStatus.recoveryRequired:
          final recoveryResponse =
              await _bridge.recover(indexedReceipt.transactionId);
          AppTalker.info(
            'WindowsUpdateRecovery',
            'Helper recover returned ${recoveryResponse.status.name}.',
          );
          if (recoveryResponse.status ==
              WindowsNativeTransactionStatus.completed) {
            await _transactionStore.clearActive(
              transactionId: indexedReceipt.transactionId,
            );
            return null;
          }
          return _mapRecoveryResponse(indexedReceipt, recoveryResponse);
        case WindowsNativeTransactionStatus.manualActionRequired:
        case WindowsNativeTransactionStatus.failed:
        case WindowsNativeTransactionStatus.cancelled:
          // Terminal transactions can never resume; release the receipt so
          // future installs are not blocked by the stale record.
          AppTalker.warning(
            'WindowsUpdateRecovery',
            'Clearing stale terminal transaction ${indexedReceipt.transactionId} '
            '(${queryResponse.status.name}) so new installs are not blocked.',
          );
          await _transactionStore.clearActive(
            transactionId: indexedReceipt.transactionId,
          );
          if (queryResponse.status ==
              WindowsNativeTransactionStatus.manualActionRequired) {
            return _manualFailure(indexedReceipt, queryResponse);
          }
          return _failure(
            queryResponse.code ?? 'windows_helper_trust_failure',
            queryResponse.technicalDetail ??
                'The durable Windows update transaction ended unsuccessfully.',
            retryable: false,
          );
        case WindowsNativeTransactionStatus.unknown:
          return _failure(
            queryResponse.code ?? 'windows_recovery_required',
            queryResponse.technicalDetail ??
                'The durable Windows update transaction could not be queried.',
            retryable: true,
          );
      }
    } on WindowsUpdateInstallStageException catch (error) {
      AppTalker.error(
        'WindowsUpdateRecovery',
        error: error,
        message: 'Stage verification failed during recovery: ${error.message}',
      );
      return _failure(
        'windows_stage_provenance_failure',
        error.message,
        retryable: false,
        cause: error,
      );
    } on WindowsUpdateTransactionException catch (error) {
      AppTalker.error(
        'WindowsUpdateRecovery',
        error: error,
        message:
            'Transaction receipt verification failed during recovery: ${error.message}',
      );
      return _failure(
        'windows_stage_provenance_failure',
        error.message,
        retryable: false,
        cause: error,
      );
    } on Object catch (error) {
      AppTalker.error(
        'WindowsUpdateRecovery',
        error: error,
        message: 'Unexpected Windows recovery failure.',
      );
      return _failure(
        'windows_helper_unavailable',
        error.toString(),
        retryable: true,
        cause: error,
      );
    }
  }

  PlatformUpdateInstallFailure? _mapRecoveryResponse(
    WindowsPendingInstallReceipt receipt,
    WindowsNativeUpdaterResponse response,
  ) {
    return switch (response.status) {
      WindowsNativeTransactionStatus.completed => null,
      WindowsNativeTransactionStatus.manualActionRequired =>
        _manualFailure(receipt, response),
      WindowsNativeTransactionStatus.restaged ||
      WindowsNativeTransactionStatus.recoveryArmed ||
      WindowsNativeTransactionStatus.recoveryRequired =>
        _failure(
          'windows_recovery_required',
          response.technicalDetail ??
              'Windows update recovery has been handed off to the recovery host.',
          retryable: true,
        ),
      WindowsNativeTransactionStatus.failed ||
      WindowsNativeTransactionStatus.cancelled =>
        _failure(
          response.code ?? 'windows_helper_trust_failure',
          response.technicalDetail ?? 'Windows update recovery failed.',
          retryable: false,
        ),
      _ => _failure(
        'windows_recovery_required',
        response.technicalDetail ??
            'Windows update recovery has been accepted by the helper.',
        retryable: true,
      ),
    };
  }

  PlatformUpdateInstallFailure _manualFailure(
    WindowsPendingInstallReceipt receipt,
    WindowsNativeUpdaterResponse response,
  ) {
    return _failure(
      'windows_manual_action_required',
      response.technicalDetail ??
          'Transaction ${receipt.transactionId} requires manual action; evidence was retained.',
      retryable: false,
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
}
