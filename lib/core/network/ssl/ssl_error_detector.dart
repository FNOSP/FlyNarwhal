import 'dart:io' show CertificateException, HandshakeException, TlsException;

import 'package:dio/dio.dart';

/// Message fragments that identify a certificate verification failure.
///
/// Deliberately *excludes* protocol-level wording such as "handshake failed" or
/// version mismatches: trusting the certificate cannot fix those, so prompting
/// would only mislead.
const List<String> _certificateNeedles = <String>[
  'pkix',
  'certificate',
  'not verified',
  'certificate_verify_failed',
  'self signed',
  'self-signed',
  'unknown ca',
  'hostname',
  'unable to get local issuer',
];

/// Whether [error] was caused by a TLS certificate that failed verification.
///
/// This must NOT key off `DioExceptionType.badCertificate`. Dio only produces
/// that type when the adapter is given a `validateCertificate` callback
/// (see `io_adapter.dart`); with a default adapter a handshake failure escapes
/// as a raw [HandshakeException] that Dio wraps into a `DioException` whose
/// default `type` is `unknown`. So the only reliable check is walking the cause
/// chain for a TLS exception type or certificate-specific wording.
bool isCertificateException(Object? error) {
  var current = error;
  var depth = 0;

  while (current != null && depth++ < 12) {
    if (current is HandshakeException ||
        current is TlsException ||
        current is CertificateException) {
      return true;
    }

    final text = _describe(current).toLowerCase();
    if (text.isNotEmpty) {
      for (final needle in _certificateNeedles) {
        if (text.contains(needle)) return true;
      }
    }

    current = _causeOf(current);
  }

  return false;
}

/// Follows a [DioException] to its inner error, then the generic cause chain.
Object? _causeOf(Object error) {
  if (error is DioException) {
    return error.error ?? error;
  }
  if (error is Error) {
    return error.stackTrace;
  }
  return null;
}

String _describe(Object error) {
  if (error is DioException) {
    return '${error.message ?? ''} ${error.error ?? ''}';
  }
  return error.toString();
}
