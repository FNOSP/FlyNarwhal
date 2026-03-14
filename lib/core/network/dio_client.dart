import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../error/error_handler.dart';
import '../network/api_result.dart';
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
    this.enableLogging = kDebugMode,
    this.enableRetry = true,
    this.enableErrorHandling = true,
  });
}

/// Enhanced Dio client with interceptors and error handling
class DioClient {
  final Dio _dio;
  final DioClientConfig _config;

  /// Constructor with callback functions for auth
  DioClient.withCallbacks({
    required String Function()? getToken,
    required String Function()? getCookie,
    required String Function()? getAuthCode,
    required String Function()? getBaseUrl,
    DioClientConfig config = const DioClientConfig(),
    Dio? dio,
  })  : _dio = dio ?? Dio(BaseOptions(
          connectTimeout: config.connectTimeout,
          receiveTimeout: config.receiveTimeout,
          sendTimeout: config.sendTimeout,
          responseType: ResponseType.json,
        )),
        _config = config {
    _setupInterceptorsWithCallbacks(
      getToken: getToken,
      getCookie: getCookie,
      getAuthCode: getAuthCode,
      getBaseUrl: getBaseUrl,
    );
  }

  void _setupInterceptorsWithCallbacks({
    String Function()? getToken,
    String Function()? getCookie,
    String Function()? getAuthCode,
    String Function()? getBaseUrl,
  }) {
    // Add interceptors in order
    // 1. Auth interceptor (adds authentication headers)
    _dio.interceptors.add(AuthInterceptor(
      getToken: getToken,
      getCookie: getCookie,
      getAuthCode: getAuthCode,
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
        printRequestBody: kDebugMode,
        printResponseBody: false,
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

  /// GET request with ApiResult
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic data)? converter,
  }) async {
    return _safeRequest(
      () => _dio.get(path, queryParameters: queryParameters, options: options),
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
      () => _dio.post(path, data: data, queryParameters: queryParameters, options: options),
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
      () => _dio.put(path, data: data, queryParameters: queryParameters, options: options),
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
      () => _dio.delete(path, data: data, queryParameters: queryParameters, options: options),
      converter: converter,
    );
  }

  /// Execute request safely and return ApiResult
  Future<ApiResult<T>> _safeRequest<T>(
    Future<Response> Function() request, {
    T Function(dynamic data)? converter,
  }) async {
    try {
      final response = await request();

      // Convert response data if converter is provided
      final data = converter != null ? converter(response.data) : response.data as T;
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
    } catch (e) {
      final failure = ErrorHandler.handle(e);
      return ResultFailure(FailureInfo(
        message: failure.message,
        code: failure.code,
        displayMessage: failure.displayMessage,
      ));
    }
  }
}