import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../domain/update/repositories/cancellation_token.dart';

/// Identifies why the same verification contract is being executed.
enum VerificationSource { download, cacheRecovery, preInstall }

enum VerificationFailureReason {
  fileMissing,
  sizeMismatch,
  digestMissing,
  digestInvalid,
  hashMismatch,
  permissionDenied,
  cancelled,
  unknown,
}

final class VerificationRequest {
  const VerificationRequest({
    required this.file,
    required this.expectedDigest,
    required this.expectedSize,
    required this.source,
    required this.cancellationToken,
  });

  final File file;
  final String? expectedDigest;
  final int expectedSize;
  final VerificationSource source;
  final CancellationToken cancellationToken;
}

sealed class VerificationResult {
  const VerificationResult(this.source);

  final VerificationSource source;
}

final class VerificationSuccess extends VerificationResult {
  const VerificationSuccess({
    required VerificationSource source,
    required this.file,
    required this.sha256,
  }) : super(source);

  final File file;
  final String sha256;
}

final class VerificationFailure extends VerificationResult {
  const VerificationFailure({
    required VerificationSource source,
    required this.reason,
    required this.technicalDetail,
    this.cause,
  }) : super(source);

  final VerificationFailureReason reason;
  final String technicalDetail;
  final Object? cause;
}

/// Performs cancellable streaming SHA-256 verification.
abstract interface class UpdatePackageVerifier {
  Future<VerificationResult> verify(VerificationRequest request);
}

/// Performs cancellable streaming SHA-256 verification.
final class Sha256Verifier implements UpdatePackageVerifier {
  const Sha256Verifier();

  @override
  Future<VerificationResult> verify(VerificationRequest request) async {
    final normalizedDigest = _normalizeDigest(request.expectedDigest);
    if (request.expectedDigest == null ||
        request.expectedDigest!.trim().isEmpty) {
      return VerificationFailure(
        source: request.source,
        reason: VerificationFailureReason.digestMissing,
        technicalDetail: 'Expected SHA-256 digest is missing.',
      );
    }
    if (normalizedDigest == null) {
      return VerificationFailure(
        source: request.source,
        reason: VerificationFailureReason.digestInvalid,
        technicalDetail: 'Expected digest must use sha256 with 64 hex digits.',
      );
    }
    try {
      request.cancellationToken.throwIfCancelled();
      if (!await request.file.exists()) {
        return VerificationFailure(
          source: request.source,
          reason: VerificationFailureReason.fileMissing,
          technicalDetail: 'Verification target does not exist.',
        );
      }
      final actualSize = await request.file.length();
      if (actualSize != request.expectedSize) {
        return VerificationFailure(
          source: request.source,
          reason: VerificationFailureReason.sizeMismatch,
          technicalDetail:
              'Expected ${request.expectedSize} bytes but found $actualSize.',
        );
      }

      final digest = await sha256
          .bind(
            request.file.openRead().map((chunk) {
              request.cancellationToken.throwIfCancelled();
              return chunk;
            }),
          )
          .single;
      final actualDigest = digest.toString();
      if (actualDigest != normalizedDigest) {
        return VerificationFailure(
          source: request.source,
          reason: VerificationFailureReason.hashMismatch,
          technicalDetail: 'Computed SHA-256 does not match expected digest.',
        );
      }
      return VerificationSuccess(
        source: request.source,
        file: request.file,
        sha256: actualDigest,
      );
    } on UpdateOperationCancelledException catch (error) {
      return VerificationFailure(
        source: request.source,
        reason: VerificationFailureReason.cancelled,
        technicalDetail: 'Verification was cancelled.',
        cause: error,
      );
    } on FileSystemException catch (error) {
      return VerificationFailure(
        source: request.source,
        reason: VerificationFailureReason.permissionDenied,
        technicalDetail: error.message,
        cause: error,
      );
    } on Object catch (error) {
      return VerificationFailure(
        source: request.source,
        reason: VerificationFailureReason.unknown,
        technicalDetail: error.toString(),
        cause: error,
      );
    }
  }

  /// Compatibility adapter for M05 cache validation callers.
  Future<bool> verifyFile({
    required File file,
    required String expectedDigest,
    CancellationToken cancellationToken = const NonCancellableToken(),
  }) async {
    if (!await file.exists()) return false;
    final result = await verify(
      VerificationRequest(
        file: file,
        expectedDigest: expectedDigest,
        expectedSize: await file.length(),
        source: VerificationSource.cacheRecovery,
        cancellationToken: cancellationToken,
      ),
    );
    return result is VerificationSuccess;
  }

  String? _normalizeDigest(String? value) {
    return RegExp(r'^sha256:([a-fA-F0-9]{64})$')
        .firstMatch(value?.trim() ?? '')
        ?.group(1)
        ?.toLowerCase();
  }
}
