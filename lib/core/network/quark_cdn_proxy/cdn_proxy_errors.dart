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

/// A verified change of the resource invalidates every read of that source.
class CdnResourceChanged extends CdnRangeFailure {
  const CdnResourceChanged(super.message);
}

enum CdnRequestFailureKind { transport, httpStatus, protocol, cancelled }

enum CdnRequestFailurePhase { request, headers, body }

/// Safe transport facts. The range scheduler, not this type, chooses retries.
class CdnRequestFailure extends FailureInfo {
  const CdnRequestFailure({
    required super.message,
    super.code,
    required super.displayMessage,
    this.kind = CdnRequestFailureKind.transport,
    this.phase = CdnRequestFailurePhase.request,
    this.statusCode,
    this.isTimeout = false,
  });

  final CdnRequestFailureKind kind;
  final CdnRequestFailurePhase phase;
  final int? statusCode;

  /// Diagnostic fact only; this does not grant an unlimited retry budget.
  final bool isTimeout;
}
