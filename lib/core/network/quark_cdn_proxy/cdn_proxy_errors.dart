import '../api_result.dart';

class CdnRangeCancelled implements Exception {
  const CdnRangeCancelled();
}

class CdnRangeFailure implements Exception {
  const CdnRangeFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// CDN-only retry metadata, kept outside the application's common API result.
class CdnRequestFailure extends FailureInfo {
  const CdnRequestFailure({
    required super.message,
    super.code,
    required super.displayMessage,
    this.isTimeout = false,
  });

  final bool isTimeout;
}
