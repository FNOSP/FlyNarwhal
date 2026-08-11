/// Stable update repository failure codes safe for application branching.
enum UpdateRepositoryErrorCode {
  network,
  timeout,
  http,
  rateLimited,
  tls,
  invalidJson,
  domainMapping,
  releasePaginationLimitExceeded,
  cancelled,
}

/// A typed repository failure whose technical details are for diagnostics only.
final class UpdateRepositoryException implements Exception {
  const UpdateRepositoryException({
    required this.code,
    required this.technicalDetails,
    required this.retryable,
    this.httpStatusCode,
  });

  final UpdateRepositoryErrorCode code;
  final String technicalDetails;
  final bool retryable;
  final int? httpStatusCode;

  @override
  String toString() => 'UpdateRepositoryException(code: ${code.name})';
}
