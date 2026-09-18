import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';

abstract interface class CdnRangeSource {
  Future<ApiResult<CdnRangeResponse>> open({
    required Uri uri,
    required Map<String, String> headers,
    required int start,
    required int end,
    required CancelToken cancelToken,
  });

  void close();
}

class CdnRangeResponse {
  const CdnRangeResponse({
    required this.statusCode,
    required this.headers,
    required this.stream,
  });

  final int statusCode;
  final Map<String, List<String>> headers;
  final Stream<Uint8List> stream;
}

/// Fetches bounded provider ranges through an isolated external HTTP client.
/// The URL and provider headers come from direct-play metadata, not NAS auth.
class CdnRangeRemoteDataSource implements CdnRangeSource {
  CdnRangeRemoteDataSource({DioClient? dioClient})
      : _dioClient = dioClient ?? DioClient.external();

  static const maxRangeBytes = 10 * 1024 * 1024;
  final DioClient _dioClient;

  /// Flattens metadata header values using HTTP syntax instead of List.toString.
  /// Header names are normalized to avoid case-variant duplicate credentials.
  static Map<String, String> normalizeHeaders(Map<String, dynamic> headers) {
    final result = <String, String>{};
    for (final entry in headers.entries) {
      final name = entry.key.trim().toLowerCase();
      if (name.isEmpty || _isExcludedHeader(name) || entry.value == null) {
        continue;
      }
      final value = entry.value;
      final values = value is Iterable ? value : <dynamic>[value];
      final separator = name == 'cookie' ? '; ' : ', ';
      final text = values
          .where((value) => value != null)
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .join(separator);
      if (text.isNotEmpty) {
        result.update(name, (previous) => '$previous$separator$text',
            ifAbsent: () => text);
      }
    }
    return result;
  }

  static bool _isExcludedHeader(String name) {
    return const {
          'host',
          'content-length',
          'connection',
          'keep-alive',
          'proxy-authenticate',
          'proxy-authorization',
          'te',
          'trailer',
          'transfer-encoding',
          'upgrade',
          'range',
          'accept-encoding',
          'authorization',
          'authx',
          'signx',
          'x-wp-header',
        }.contains(name) ||
        name.startsWith('x-trim-') ||
        name.startsWith('x-fn-') ||
        name.startsWith('x-nas-');
  }

  @override
  Future<ApiResult<CdnRangeResponse>> open({
    required Uri uri,
    required Map<String, String> headers,
    required int start,
    required int end,
    required CancelToken cancelToken,
  }) async {
    if ((uri.scheme != 'https' && uri.scheme != 'http') || uri.host.isEmpty) {
      return ResultFailure(FailureInfo.fromMessage('Invalid CDN URL'));
    }
    if (start < 0 || end < start || end - start >= maxRangeBytes) {
      return ResultFailure(FailureInfo.fromMessage('Invalid CDN byte range'));
    }
    final requestHeaders = normalizeHeaders(headers)
      ..['range'] = 'bytes=$start-$end'
      ..['accept-encoding'] = 'identity';
    final response = await _dioClient.getStream(
      uri,
      headers: requestHeaders,
      cancelToken: cancelToken,
    );
    return response.map((response) => CdnRangeResponse(
          statusCode: response.statusCode,
          headers: response.headers,
          stream: response.stream,
        ));
  }

  @override
  void close() => _dioClient.close();
}
