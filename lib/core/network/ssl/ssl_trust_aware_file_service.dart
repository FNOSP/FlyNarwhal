import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'ssl_http_client.dart';

/// A [FileService] for `cached_network_image` that honours the trusted
/// certificate list.
///
/// The image stack opens its own `HttpClient`, so the Dio-level trust work does
/// not reach it: without this, a user who trusted their NAS would still see
/// broken posters. It shares [createTrustAwareHttpClient] with the API path, so
/// both accept exactly the same (host, fingerprint) pairs.
///
/// This only *accepts* certificates that are already approved; it cannot
/// prompt. A dialog for a poster load would be surprising, and the same host
/// still raises one through the API path when the user acts.
class SslTrustAwareFileService extends FileService {
  SslTrustAwareFileService({HttpClient? httpClient})
      : _client = httpClient ?? createTrustAwareHttpClient();

  final HttpClient _client;

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    final request = await _client.getUrl(Uri.parse(url));
    headers?.forEach(request.headers.set);
    final response = await request.close();
    return _HttpClientFileResponse(response);
  }
}

/// Adapts a [HttpClientResponse] to [FileServiceResponse].
///
/// `HttpGetResponse` from flutter_cache_manager wraps `package:http` instead,
/// which would mean pulling that in just for the adapter.
class _HttpClientFileResponse implements FileServiceResponse {
  _HttpClientFileResponse(this._response);

  final HttpClientResponse _response;
  final DateTime _receivedTime = DateTime.now();

  @override
  int get statusCode => _response.statusCode;

  @override
  Stream<List<int>> get content => _response;

  @override
  int? get contentLength {
    // `HttpClientResponse.contentLength` returns -1 when the response carries no
    // Content-Length (chunked or streamed), which the image server does for
    // posters. Forwarding that sentinel as a byte count makes Flutter's image
    // loader assert `expectedTotalBytes >= 0` and discard the bytes, so an
    // unknown length must be reported as null, as the interface intends.
    final length = _response.contentLength;
    return length < 0 ? null : length;
  }

  @override
  String? get eTag => _response.headers.value(HttpHeaders.etagHeader);

  @override
  String get fileExtension {
    // Derived from the MIME subtype rather than pulled from http_parser's
    // ContentType extension, which is only a transitive dependency here.
    final mimeType = _response.headers.contentType?.mimeType;
    if (mimeType == null) return '';
    final subtype = mimeType.split('/').last;
    return switch (subtype) {
      'jpeg' => 'jpg',
      'svg+xml' => 'svg',
      _ => subtype,
    };
  }

  @override
  DateTime get validTill {
    // Mirrors flutter_cache_manager: honour max-age / no-cache, else a week.
    var ageDuration = const Duration(days: 7);
    final control = _response.headers.value(HttpHeaders.cacheControlHeader);
    if (control != null) {
      for (final setting in control.split(',')) {
        final sanitized = setting.trim().toLowerCase();
        if (sanitized == 'no-cache') {
          ageDuration = Duration.zero;
        }
        if (sanitized.startsWith('max-age=')) {
          final seconds = int.tryParse(sanitized.split('=')[1]) ?? 0;
          if (seconds > 0) ageDuration = Duration(seconds: seconds);
        }
      }
    }
    return _receivedTime.add(ageDuration);
  }
}
