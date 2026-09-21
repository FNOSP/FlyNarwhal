import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../error/error_handler.dart';
import '../api_result.dart';
import 'cdn_proxy_constants.dart';
import 'cdn_proxy_errors.dart';
import 'external_http_adapter.dart'
    if (dart.library.io) 'external_http_adapter_io.dart';

/// A binary HTTP response whose body remains a stream.
class CdnHttpResponse {
  const CdnHttpResponse({
    required this.statusCode,
    required this.headers,
    required this.stream,
  });

  final int statusCode;
  final Map<String, List<String>> headers;
  final Stream<Uint8List> stream;
}

/// An owned HTTP client for provider URLs, isolated from NAS authentication,
/// certificate-trust prompts, application retries and request/body logging.
class CdnHttpTransport {
  CdnHttpTransport({
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

  /// Opens a raw response without decoding JSON or buffering the whole body.
  /// HTTP statuses remain available to the caller for range validation.
  /// [cancelToken] also cancels body reception after headers have arrived.
  Future<ApiResult<CdnHttpResponse>> getStream(
    Uri uri, {
    required Map<String, String> headers,
    required CancelToken cancelToken,
  }) async {
    try {
      final response = await _dio.getUri<ResponseBody>(
        uri,
        cancelToken: cancelToken,
        options: Options(
          headers: headers,
          responseType: ResponseType.stream,
          validateStatus: (_) => true,
        ),
      );
      final body = response.data;
      if (body == null) {
        return ResultFailure(FailureInfo.fromMessage('Empty HTTP response'));
      }
      return Success(CdnHttpResponse(
        statusCode: body.statusCode,
        headers: body.headers,
        stream: body.stream,
      ));
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

  /// Releases sockets and cancels outstanding requests owned by this client.
  void close() => _dio.close(force: true);
}
