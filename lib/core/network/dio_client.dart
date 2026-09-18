import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import '../error/error_handler.dart';
import '../network/api_result.dart';
import 'external_http_adapter.dart'
    if (dart.library.io) 'external_http_adapter_io.dart';
import 'response_decoder.dart' as response_decoder;
import 'interceptors/index.dart';

/// Configuration for DioClient
class DioClientConfig {
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sendTimeout;
  final int maxRetries;
  final Duration retryDelay;
  final bool enableLogging;
  final bool enableRetry;
  final bool enableErrorHandling;

  const DioClientConfig({
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 10),
    this.sendTimeout = const Duration(seconds: 10),
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 1),
    this.enableLogging = true,
    this.enableRetry = true,
    this.enableErrorHandling = true,
  });
}

/// A binary HTTP response whose body remains a stream.
class DioStreamResponse {
  const DioStreamResponse({
    required this.statusCode,
    required this.headers,
    required this.stream,
  });

  final int statusCode;
  final Map<String, List<String>> headers;
  final Stream<Uint8List> stream;
}

/// Enhanced Dio client with interceptors and error handling
class DioClient {
  final Dio _dio;
  final DioClientConfig _config;

  /// An isolated client for provider URLs. NAS credentials, request signing,
  /// retries and body logging must never be inherited by these requests.
  DioClient.external({
    DioClientConfig config = const DioClientConfig(),
    HttpClientAdapter? adapter,
  })  : _dio = Dio(BaseOptions(
          connectTimeout: config.connectTimeout,
          receiveTimeout: config.receiveTimeout,
          sendTimeout: config.sendTimeout,
          responseType: ResponseType.stream,
          followRedirects: true,
        )),
        _config = config {
    _dio.httpClientAdapter = adapter ?? createExternalHttpAdapter();
  }

  /// Constructor with callback functions for auth
  DioClient.withCallbacks({
    required String Function()? getToken,
    required String Function()? getCookie,
    required String Function()? getBaseUrl,
    DioClientConfig config = const DioClientConfig(),
    Dio? dio,
  })  : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: config.connectTimeout,
              receiveTimeout: config.receiveTimeout,
              sendTimeout: config.sendTimeout,
              responseType: ResponseType.json,
              followRedirects: true,
            )),
        _config = config {
    _setupInterceptorsWithCallbacks(
      getToken: getToken,
      getCookie: getCookie,
      getBaseUrl: getBaseUrl,
    );
  }

  void _setupInterceptorsWithCallbacks({
    String Function()? getToken,
    String Function()? getCookie,
    String Function()? getBaseUrl,
  }) {
    // Add interceptors in order
    // 1. Auth interceptor (adds authentication headers)
    _dio.interceptors.add(AuthInterceptor(
      getToken: getToken,
      getCookie: getCookie,
      getBaseUrl: getBaseUrl,
    ));

    // 2. Retry interceptor (handles automatic retry)
    if (_config.enableRetry) {
      _dio.interceptors.add(RetryInterceptor(
        maxRetries: _config.maxRetries,
        retryDelay: _config.retryDelay,
      ));
    }

    // 3. Error interceptor (converts errors to Failure)
    if (_config.enableErrorHandling) {
      _dio.interceptors.add(ErrorInterceptor());
    }

    // 4. Logging interceptor (debug logging)
    if (_config.enableLogging) {
      _dio.interceptors.add(LoggingInterceptor(
        printRequestBody: true,
        printResponseBody: true,
        printError: true,
      ));
    }
  }

  /// Get underlying Dio instance for advanced usage
  Dio get dio => _dio;

  /// Update base URL dynamically
  void updateBaseUrl(String url) {
    _dio.options.baseUrl = url;
  }

  /// Opens a raw response without decoding JSON or buffering the whole body.
  /// HTTP statuses remain available to the caller for range validation.
  /// [cancelToken] also cancels body reception after headers have arrived.
  Future<ApiResult<DioStreamResponse>> getStream(
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
      return Success(DioStreamResponse(
        statusCode: body.statusCode,
        headers: body.headers,
        stream: body.stream,
      ));
    } on DioException catch (error) {
      // A CDN URL may contain signed credentials. Keep provider errors and
      // request details out of user-visible/loggable failure strings.
      final failure = ErrorHandler.handleDioError(error.copyWith(
        message: 'CDN network request failed',
      ));
      return ResultFailure(FailureInfo(
        message: failure.message,
        code: failure.code,
        displayMessage: failure.displayMessage,
      ));
    } catch (_) {
      return ResultFailure(
        FailureInfo.fromMessage('CDN network request failed'),
      );
    }
  }

  /// Releases sockets and cancels outstanding requests owned by this client.
  void close() => _dio.close(force: true);

  /// GET request with ApiResult
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic data)? converter,
  }) async {
    return _safeRequest(
      () => _dio.get(
        path,
        queryParameters: queryParameters,
        options: _withBytesResponseType(options),
      ),
      converter: converter,
    );
  }

  /// POST request with ApiResult
  Future<ApiResult<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic data)? converter,
  }) async {
    return _safeRequest(
      () => _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: _withBytesResponseType(options),
      ),
      converter: converter,
    );
  }

  /// PUT request with ApiResult
  Future<ApiResult<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic data)? converter,
  }) async {
    return _safeRequest(
      () => _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: _withBytesResponseType(options),
      ),
      converter: converter,
    );
  }

  /// DELETE request with ApiResult
  Future<ApiResult<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic data)? converter,
  }) async {
    return _safeRequest(
      () => _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: _withBytesResponseType(options),
      ),
      converter: converter,
    );
  }

  /// Execute request safely and return ApiResult
  Future<ApiResult<T>> _safeRequest<T>(
    Future<Response> Function() request, {
    T Function(dynamic data)? converter,
  }) async {
    final requestStopwatch = Stopwatch()..start();
    try {
      final response = await request();
      final normalizedData =
          response_decoder.ResponseDecoder.normalizeResponseData(response.data);

      // Convert response data if converter is provided
      final data = converter != null
          ? converter(normalizedData)
          : _castResponseData<T>(normalizedData);
      return Success(data);
    } on DioException catch (e) {
      // Error was already converted by ErrorInterceptor
      if (e.error is FailureInfo) {
        return ResultFailure(e.error as FailureInfo);
      }
      final failure = ErrorHandler.handleDioError(e);
      return ResultFailure(FailureInfo(
        message: failure.message,
        code: failure.code,
        displayMessage: failure.displayMessage,
      ));
    } on FailureInfo catch (e) {
      return ResultFailure(e);
    } catch (e) {
      final failure = ErrorHandler.handle(e);
      return ResultFailure(FailureInfo(
        message: failure.message,
        code: failure.code,
        displayMessage: failure.displayMessage,
      ));
    } finally {
      requestStopwatch.stop();
    }
  }

  Options _withBytesResponseType(Options? options) {
    return (options ?? Options()).copyWith(responseType: ResponseType.bytes);
  }

  T _castResponseData<T>(dynamic data) {
    if (data is T) {
      return data;
    }
    if (T == String) {
      if (data is String) {
        return data as T;
      }
      return jsonEncode(data) as T;
    }
    throw FailureInfo.fromMessage(
      'Unexpected response type: expected=$T, actual=${data.runtimeType}',
    );
  }
}
