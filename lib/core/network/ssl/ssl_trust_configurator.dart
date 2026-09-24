import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../interceptors/ssl_trust_interceptor.dart';
import 'ssl_http_client.dart';
import 'ssl_trust_manager.dart';

/// Installs certificate-trust handling on [dio].
///
/// Two halves, both required:
///
/// * the adapter enforces the decision synchronously during the handshake, and
/// * the interceptor asks the user after a request has failed and replays it.
///
/// Idempotent, and it inserts the interceptor at index 0 so it always runs
/// before the retry interceptor regardless of when this is called.
void configureSslTrust(
  Dio dio, {
  SslTrustManager? trustManager,
  Future<void> Function(SslTrustEntry entry)? persistEntry,
}) {
  final manager = trustManager ?? SslTrustManager.instance;

  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: createTrustAwareHttpClient,
  );

  final alreadyInstalled = dio.interceptors.any(
    (interceptor) => interceptor is SslTrustInterceptor,
  );
  if (alreadyInstalled) return;

  dio.interceptors.insert(
    0,
    SslTrustInterceptor(
      trustManager: manager,
      originDio: dio,
      persistEntry: persistEntry,
    ),
  );
}
