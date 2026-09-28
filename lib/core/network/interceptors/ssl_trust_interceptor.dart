import 'dart:io' show X509Certificate;

import 'package:dio/dio.dart';

import '../../utils/log/app_talker.dart';
import '../ssl/ssl_error_detector.dart';
import '../ssl/ssl_http_client.dart';
import '../ssl/ssl_trust_manager.dart';

/// Turns a failed TLS handshake into a question for the user.
///
/// The handshake itself cannot ask: [HttpClient.badCertificateCallback] is
/// synchronous. This interceptor runs after the request has already failed, so
/// it has an asynchronous context — it can await the user's decision, record it
/// in [SslTrustManager], and replay the request through a trust-aware client.
///
/// Register it *before* the retry interceptor so a certificate failure prompts
/// immediately instead of burning through the retry budget first.
class SslTrustInterceptor extends Interceptor {
  SslTrustInterceptor({
    required this.trustManager,
    required this.originDio,
    this.persistEntry,
    this.certificateProbe = probePeerCertificate,
  });

  final SslTrustManager trustManager;

  /// The Dio these requests are issued on; the replay inherits its options so
  /// the base URL, headers and timeouts stay identical.
  final Dio originDio;

  /// Called when the user chooses [SslTrustDecision.allowPersist]. Injected so
  /// this interceptor stays free of storage concerns.
  final Future<void> Function(SslTrustEntry entry)? persistEntry;

  /// Reads the peer certificate so its fingerprint can be shown. Injected for
  /// tests.
  final Future<X509Certificate?> Function(Uri uri) certificateProbe;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final uri = err.requestOptions.uri;
    final host = uri.host;
    if (host.isEmpty || !isCertificateException(err.error ?? err)) {
      return super.onError(err, handler);
    }

    // The handshake callback rejected this certificate, so the exact
    // (host, fingerprint) pair is not approved. Prefer the certificate the
    // handshake itself reported: that is the one enforcement will be asked
    // about again, whereas the probe reads the leaf and the verifier may have
    // objected to a different certificate in the chain.
    final handshakeFingerprint = trustManager.rejectedFingerprintFor(host);
    final fingerprint =
        handshakeFingerprint ?? await _probeFingerprint(uri);
    if (fingerprint == null) {
      AppTalker.warning(
        'SslTrust',
        'certificate failure could not be probed for host=$host',
      );
      return super.onError(err, handler);
    }

    final decision = await trustManager.requestTrust(host, fingerprint);
    if (decision == SslTrustDecision.reject) {
      AppTalker.info('SslTrust', 'user rejected certificate for host=$host');
      // Propagate the ORIGINAL error so its cause chain stays intact for the
      // UI's own message mapping.
      return super.onError(err, handler);
    }

    final entry = SslTrustEntry(
      host: SslTrustManager.normalizeHost(host),
      fingerprintSha256: fingerprint,
      addedAt: DateTime.now(),
    );
    if (decision == SslTrustDecision.allowPersist) {
      try {
        await persistEntry?.call(entry);
      } catch (error) {
        AppTalker.warning('SslTrust', 'persisting trust entry failed: $error');
      }
      trustManager.addPersisted(entry);
    } else {
      trustManager.addTemporary(entry);
    }

    AppTalker.info(
      'SslTrust',
      'allowed certificate host=$host fingerprint=${shortFingerprint(fingerprint)} '
          'persist=${decision == SslTrustDecision.allowPersist}',
    );

    try {
      final response = await trustedDioFor(originDio).fetch(
        err.requestOptions,
      );
      handler.resolve(response);
    } catch (replayError) {
      AppTalker.warning('SslTrust', 'trusted replay failed: $replayError');
      super.onError(err, handler);
    }
  }

  Future<String?> _probeFingerprint(Uri uri) async {
    if (!uri.isScheme('https')) return null;
    try {
      final certificate = await certificateProbe(uri);
      if (certificate == null) return null;
      return SslTrustManager.fingerprintOf(certificate);
    } catch (error) {
      AppTalker.warning('SslTrust', 'certificate probe threw: $error');
      return null;
    }
  }
}
