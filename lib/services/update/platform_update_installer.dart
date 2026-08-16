import 'dart:io';

import '../../domain/update/entities/update_models.dart';
import '../../domain/update/entities/verified_update_artifact.dart';

final class PlatformUpdateInstallRequest {
  const PlatformUpdateInstallRequest({
    required this.operationId,
    required this.artifact,
  });

  final String operationId;
  final VerifiedUpdateArtifact artifact;

  UpdateCandidate get candidate => artifact.candidate;
  File get packageFile => artifact.file;
}

sealed class PlatformUpdateInstallResult {
  const PlatformUpdateInstallResult();
}

final class PlatformUpdateHelperLaunched extends PlatformUpdateInstallResult {
  const PlatformUpdateHelperLaunched();
}

/// Indicates that the Windows helper durably accepted commit-after-exit.
final class PlatformUpdateCommitAccepted extends PlatformUpdateInstallResult {
  const PlatformUpdateCommitAccepted();
}

/// Indicates that the existing Windows transaction must be recovered.
final class PlatformUpdateRecoveryRequired extends PlatformUpdateInstallResult {
  const PlatformUpdateRecoveryRequired({
    required this.transactionId,
    required this.technicalDetail,
  });

  final String transactionId;
  final String technicalDetail;
}

/// Indicates that automatic mutation and cleanup must stop for manual action.
final class PlatformUpdateManualActionRequired
    extends PlatformUpdateInstallResult {
  const PlatformUpdateManualActionRequired({
    required this.transactionId,
    required this.technicalDetail,
  });

  final String transactionId;
  final String technicalDetail;
}

final class PlatformUpdateInstallFailure extends PlatformUpdateInstallResult {
  const PlatformUpdateInstallFailure({
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

abstract interface class PlatformUpdateInstaller {
  Future<PlatformUpdateInstallResult> launch(
    PlatformUpdateInstallRequest request,
  );
}

final class UnsupportedPlatformUpdateInstaller
    implements PlatformUpdateInstaller {
  const UnsupportedPlatformUpdateInstaller();

  @override
  Future<PlatformUpdateInstallResult> launch(
    PlatformUpdateInstallRequest request,
  ) async {
    return const PlatformUpdateInstallFailure(
      code: 'installer_not_configured',
      userMessageKey: 'update.install.error.notConfigured',
      technicalDetail: 'No platform update installer is configured.',
      isRetryable: false,
    );
  }
}
