import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../error/error_handler.dart';
import '../api_result.dart';
import 'cdn_proxy_constants.dart';
import 'cdn_proxy_errors.dart';
import 'cdn_range_source.dart';
import 'cdn_request_headers.dart';
import 'external_http_adapter.dart'
    if (dart.library.io) 'external_http_adapter_io.dart';

/// Fetches and validates bounded provider ranges with an owned HTTP client.
/// NAS authentication, certificate-trust prompts, application retries and body
/// logging are deliberately outside this client; the scheduler owns retries.
class CdnHttpRangeSource implements CdnRangeSource {
  CdnHttpRangeSource({
    Duration connectTimeout = CdnProxyDefaults.connectTimeout,
    Duration receiveTimeout = CdnProxyDefaults.receiveTimeout,
    Duration sendTimeout = CdnProxyDefaults.sendTimeout,
    HttpClientAdapter? adapter,
  }) : _dio = Dio(BaseOptions(
          connectTimeout: connectTimeout,
          receiveTimeout: receiveTimeout,
          sendTimeout: sendTimeout,
          responseType: ResponseType.stream,
          followRedirects: true,
        )) {
    _dio.httpClientAdapter = adapter ?? createExternalHttpAdapter();
  }

  final Dio _dio;

  /// Exposes transport configuration for focused network-contract tests.
  Dio get dio => _dio;

  static const maxRangeBytes = CdnProxyDefaults.chunkSize;

  static Map<String, String> normalizeHeaders(Map<String, dynamic> headers) =>
      normalizeCdnRequestHeaders(headers);

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
    try {
      final response = await _dio.getUri<ResponseBody>(
        uri,
        cancelToken: cancelToken,
        options: Options(
          headers: requestHeaders,
          responseType: ResponseType.stream,
          validateStatus: (_) => true,
        ),
      );
      final body = response.data;
      if (body == null) {
        return ResultFailure(FailureInfo.fromMessage('Empty HTTP response'));
      }
      try {
        final parsed = _parseResponse(body, start: start, end: end);
        if (parsed.totalLength == 0) {
          await _cancelResponse(body, cancelToken);
        }
        return Success(parsed);
      } on FailureInfo catch (failure) {
        // Reject invalid metadata before the scheduler consumes any bytes.
        await _cancelResponse(body, cancelToken);
        return ResultFailure(failure);
      }
    } on DioException catch (error) {
      // A CDN URL may contain signed credentials. Keep provider errors and
      // request details out of user-visible/loggable failure strings.
      final failure = ErrorHandler.handleDioError(error.copyWith(
        message: 'CDN network request failed',
        response: error.response == null
            ? null
            : Response<dynamic>(
                requestOptions: error.requestOptions,
                statusCode: error.response!.statusCode,
              ),
      ));
      return ResultFailure(CdnRequestFailure(
        message: failure.message,
        code: failure.code,
        displayMessage: failure.displayMessage,
        isTimeout: switch (error.type) {
          DioExceptionType.connectionTimeout ||
          DioExceptionType.sendTimeout ||
          DioExceptionType.receiveTimeout =>
            true,
          DioExceptionType.unknown => error.error is TimeoutException,
          _ => false,
        },
      ));
    } catch (_) {
      return ResultFailure(
        FailureInfo.fromMessage('CDN network request failed'),
      );
    }
  }

  CdnRangeResponse _parseResponse(ResponseBody response,
      {required int start, required int end}) {
    String? header(String name) {
      final values = response.headers.entries
          .where((entry) => entry.key.toLowerCase() == name)
          .expand((entry) => entry.value)
          .toList();
      return values.isEmpty ? null : values.join(', ');
    }

    final contentType = header('content-type');
    // A 0-0 probe is the only request that can describe an empty resource.
    if (start == 0 &&
        end == 0 &&
        response.statusCode == 416 &&
        header('content-range')?.trim() == 'bytes */0') {
      return CdnRangeResponse(
        totalLength: 0,
        contentType: contentType,
        stream: const Stream<Uint8List>.empty(),
      );
    }
    if (response.statusCode != 206) {
      final message = 'CDN 分片请求失败（HTTP ${response.statusCode}）';
      throw CdnRequestFailure(
        message: message,
        displayMessage: message,
        isTimeout: response.statusCode == 408 || response.statusCode == 504,
      );
    }
    final encoding = header('content-encoding')?.trim().toLowerCase();
    if (encoding != null && encoding != 'identity') {
      throw FailureInfo.fromMessage('CDN 返回了不支持的压缩数据');
    }
    final match = RegExp(r'^bytes (\d+)-(\d+)/(\d+)$')
        .firstMatch(header('content-range')?.trim() ?? '');
    if (match == null) {
      throw FailureInfo.fromMessage('CDN 缺少有效的资源范围');
    }
    final responseStart = int.tryParse(match[1]!);
    final responseEnd = int.tryParse(match[2]!);
    final total = int.tryParse(match[3]!);
    if (responseStart != start ||
        responseEnd != end ||
        total == null ||
        total <= end) {
      throw FailureInfo.fromMessage('CDN 返回的资源范围或大小不一致');
    }
    final contentLength = header('content-length');
    if (contentLength != null &&
        int.tryParse(contentLength) != end - start + 1) {
      throw FailureInfo.fromMessage('CDN 返回的分片长度不一致');
    }
    return CdnRangeResponse(
      totalLength: total,
      contentType: contentType,
      stream: response.stream,
    );
  }

  Future<void> _cancelResponse(
      ResponseBody response, CancelToken cancelToken) async {
    cancelToken.cancel('CDN response rejected or empty');
    try {
      await response.stream.listen((_) {}, onError: (Object _) {}).cancel();
    } catch (_) {
      // Cancellation may race a remote disconnect.
    }
  }

  /// Releases sockets and cancels outstanding requests owned by this source.
  @override
  void close() => _dio.close(force: true);
}
