import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import 'ssl_trust_manager.dart';

/// An [HttpClient] that accepts a certificate only when the exact
/// (host, fingerprint) pair has already been approved.
///
/// This is the enforcement half of the feature. It is consulted during the TLS
/// handshake, so it must answer from memory and never block — the user is asked
/// by [SslTrustInterceptor] through a separate, asynchronous path.
HttpClient createTrustAwareHttpClient() {
  final client = HttpClient();
  client.badCertificateCallback = (certificate, host, port) {
    return SslTrustManager.instance.isApproved(
      host,
      SslTrustManager.fingerprintOf(certificate),
    );
  };
  return client;
}

/// A [HttpClient] that accepts any certificate, for one-off probe requests.
///
/// Only used to read a peer certificate so its fingerprint can be shown to the
/// user before they decide. Never used to carry real API traffic.
HttpClient createProbeHttpClient() {
  final client = HttpClient();
  client.badCertificateCallback = (_, __, ___) => true;
  return client;
}

/// Trust-aware Dio instances, cached so replaying a request reuses the same
/// connection pool instead of leaking a fresh [HttpClient] per retry.
final Expando<Dio> _trustedDioCache = Expando<Dio>('sslTrustAwareDio');

/// Wraps [origin]'s options in a Dio whose adapter consults the trust manager.
///
/// Cached against [origin] because replays are comparatively rare and a new
/// [HttpClient] each time would defeat keep-alive.
Dio trustedDioFor(Dio origin) {
  final cached = _trustedDioCache[origin];
  if (cached != null) return cached;

  final dio = Dio(origin.options)
    ..httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: createTrustAwareHttpClient,
    )
    // The replay carries the original request options, including headers, so
    // the auth interceptor must not run a second time and re-sign the request.
    ..interceptors.clear();

  _trustedDioCache[origin] = dio;
  return dio;
}

/// Reads the peer certificate for [uri] by making a throwaway connection that
/// accepts whatever the server presents.
///
/// Returns null when the certificate cannot be read (connection refused, plain
/// HTTP, or a non-TLS failure), in which case the caller must not offer trust.
Future<X509Certificate?> probePeerCertificate(Uri uri) async {
  final client = createProbeHttpClient();
  try {
    final request = await client
        .openUrl('GET', uri)
        .timeout(const Duration(seconds: 10));
    final response = await request.close().timeout(const Duration(seconds: 10));
    final certificate = response.certificate;
    // Drain so the connection can be released.
    await response.drain<void>();
    return certificate;
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

/// Convenience for tests and probes that need the DER bytes directly.
Uint8List certificateDer(X509Certificate certificate) => certificate.der;
