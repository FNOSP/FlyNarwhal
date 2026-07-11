import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/fly_narwhal_auth_helper.dart';
import '../../../core/network/fly_narwhal_response_crypto.dart';
import '../../../core/network/sse_event_parser.dart';
import '../../models/fly_narwhal/index.dart';

class FlyNarwhalRemoteDataSource {
  static const Duration _connectTimeout = Duration(seconds: 15);
  static const Duration _requestReceiveTimeout = Duration(seconds: 30);
  static const Duration _sseReceiveTimeout = Duration(seconds: 240);

  final String Function() getToken;
  final String Function() getCookie;
  final String Function() getFnBaseUrl;
  final String Function() getFlyNarwhalBaseUrl;
  final bool Function() getFlyNarwhalServerEnabled;
  final String Function() getAuthCode;
  final FlyNarwhalResponseCrypto _crypto;
  final Dio _dio;

  FlyNarwhalRemoteDataSource({
    required this.getToken,
    required this.getCookie,
    required this.getFnBaseUrl,
    required this.getFlyNarwhalBaseUrl,
    bool Function()? getFlyNarwhalServerEnabled,
    required this.getAuthCode,
    Dio? dio,
    FlyNarwhalResponseCrypto? crypto,
  })  : getFlyNarwhalServerEnabled = getFlyNarwhalServerEnabled ?? (() => true),
        _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: _connectTimeout,
              receiveTimeout: _requestReceiveTimeout,
              sendTimeout: _requestReceiveTimeout,
              responseType: ResponseType.plain,
              followRedirects: true,
            )),
        _crypto = crypto ?? FlyNarwhalResponseCrypto.instance;

  Future<ApiResult<SmartAnalysisResult<String>>> getVersion({
    String? baseUrl,
  }) {
    return _get(
      ApiEndpoints.flyNarwhalVersion,
      baseUrl: baseUrl,
      fromJsonT: (json) => json?.toString() ?? '',
    );
  }

  Stream<String> startUpdate({
    required String downloadUrl,
    String? hash,
    String? proxyUrl,
  }) async* {
    final data = <String, dynamic>{
      'download_url': downloadUrl,
      if (hash != null && hash.isNotEmpty) 'hash': hash,
      if (proxyUrl != null && proxyUrl.isNotEmpty) 'proxy_url': proxyUrl,
    };
    final events =
        await _ssePost(ApiEndpoints.flyNarwhalUpdateStart, data: data);
    await for (final event in events) {
      if (event.name == 'error') {
        throw Exception(event.data);
      }
      if (event.name == 'update_start' || event.name == 'update_status') {
        yield event.data;
      }
    }
  }

  Future<ApiResult<SmartAnalysisResult<String>>> analyze(
      AnalyzeRequest request) {
    return _post(ApiEndpoints.flyNarwhalAnalyze,
        data: request.toJson(), fromJsonT: (json) => json?.toString() ?? '');
  }

  Future<ApiResult<SmartAnalysisResult<String>>> updateSeasonStatus(
      UpdateSeasonStatusRequest request) {
    return _post(ApiEndpoints.flyNarwhalSeasonStatus,
        data: request.toJson(), fromJsonT: (json) => json?.toString() ?? '');
  }

  Future<ApiResult<SmartAnalysisResult<AnalysisStatus>>> getStatus(
      {required String type, required String guid}) {
    return _get(ApiEndpoints.flyNarwhalAnalysisStatus,
        parameters: <String, dynamic>{'type': type, 'guid': guid},
        fromJsonT: (json) => AnalysisStatus.fromString(json?.toString()));
  }

  Future<ApiResult<SmartAnalysisResult<EpisodeSegmentsResponse>>> getSegments(
      String episodeGuid) {
    return _get(ApiEndpoints.flyNarwhalSegments,
        parameters: <String, dynamic>{'guid': episodeGuid},
        fromJsonT: (json) => EpisodeSegmentsResponse.fromJson(
            Map<String, dynamic>.from(json as Map)));
  }

  Future<ApiResult<SmartAnalysisResult<String>>> setFnBaseUrl(
      SetFnBaseUrlRequest request) {
    return _post(ApiEndpoints.flyNarwhalFnBaseUrl,
        data: request.toJson(), fromJsonT: (json) => json?.toString() ?? '');
  }

  Future<ApiResult<Map<String, List<Danmaku>>>> getDanmaku(
      DanmakuRequest request) async {
    try {
      _ensureDanmakuRequestConfigured();
      final events = await _sseGet(ApiEndpoints.flyNarwhalDanmaku,
          parameters: request.toQueryParameters());
      await for (final event in events) {
        if (event.name == 'error') {
          throw Exception(event.data);
        }
        if (event.name == 'danmu') {
          return Success(_parseDanmakuPayload(event.data));
        }
      }
      return const Success(<String, List<Danmaku>>{});
    } catch (error) {
      return ResultFailure(FailureInfo.fromMessage(error.toString()));
    }
  }

  Future<ApiResult<SmartAnalysisResult<T>>> _get<T>(String path,
      {String? baseUrl,
      Map<String, dynamic>? parameters,
      required T Function(Object? json) fromJsonT}) async {
    try {
      final url = _buildFullUrl(path, baseUrl: baseUrl);
      final response = await _dio.get<String>(url,
          queryParameters: parameters,
          options: Options(
              headers: await _buildHeaders(
                signaturePath: path,
                parameters: parameters,
              ),
              responseType: ResponseType.plain));
      return Success(await _decodeSmartResult(response.data ?? '', fromJsonT));
    } catch (error) {
      return ResultFailure(FailureInfo.fromMessage(error.toString()));
    }
  }

  Future<ApiResult<SmartAnalysisResult<T>>> _post<T>(String path,
      {dynamic data, required T Function(Object? json) fromJsonT}) async {
    try {
      final url = _buildFullUrl(path);
      final response = await _dio.post<String>(url,
          data: data,
          options: Options(
              headers: await _buildHeaders(
                signaturePath: path,
                data: data,
                isPost: true,
              ),
              responseType: ResponseType.plain));
      return Success(await _decodeSmartResult(response.data ?? '', fromJsonT));
    } catch (error) {
      return ResultFailure(FailureInfo.fromMessage(error.toString()));
    }
  }

  Future<Stream<SseEvent>> _sseGet(String path,
      {Map<String, dynamic>? parameters}) async {
    final url = _buildFullUrl(path);
    final response = await _dio.get<ResponseBody>(url,
        queryParameters: parameters,
        options: Options(
            headers: await _buildHeaders(
              signaturePath: path,
              parameters: parameters,
              isSse: true,
            ),
            responseType: ResponseType.stream,
            receiveTimeout: _sseReceiveTimeout));
    return _parseResponseBodyEvents(response.data!);
  }

  Future<Stream<SseEvent>> _ssePost(String path, {dynamic data}) async {
    final url = _buildFullUrl(path);
    final response = await _dio.post<ResponseBody>(url,
        data: data,
        options: Options(
            headers: await _buildHeaders(
              signaturePath: path,
              data: data,
              isPost: true,
              isSse: true,
            ),
            responseType: ResponseType.stream,
            receiveTimeout: _sseReceiveTimeout));
    return _parseResponseBodyEvents(response.data!);
  }

  void _ensureDanmakuRequestConfigured() {
    if (!getFlyNarwhalServerEnabled()) {
      throw StateError('FlyNarwhal 服务端未启用');
    }
    if (getFlyNarwhalBaseUrl().trim().isEmpty) {
      throw StateError('请填写飞鲸服务端地址');
    }
    if (getAuthCode().trim().isEmpty) {
      throw StateError('请填写飞鲸服务端授权码');
    }
  }

  String _buildFullUrl(String path, {String? baseUrl}) {
    var normalizedBaseUrl = (baseUrl ?? getFlyNarwhalBaseUrl()).trim();
    if (normalizedBaseUrl.isEmpty) {
      throw Exception('FlyNarwhal server base url is empty');
    }
    while (normalizedBaseUrl.endsWith('/')) {
      normalizedBaseUrl =
          normalizedBaseUrl.substring(0, normalizedBaseUrl.length - 1);
    }
    var normalizedPath = path;
    while (normalizedPath.startsWith('/')) {
      normalizedPath = normalizedPath.substring(1);
    }
    return '$normalizedBaseUrl/$normalizedPath';
  }

  Future<Map<String, String>> _buildHeaders({
    required String signaturePath,
    Map<String, dynamic>? parameters,
    dynamic data,
    bool isPost = false,
    bool isSse = false,
  }) async {
    final authCode = getAuthCode();
    final authx = FlyNarwhalAuthHelper.generateAuthx(
      signaturePath,
      parameters: parameters,
      data: data,
    );
    final headers = <String, String>{
      'Accept': isSse ? 'text/event-stream' : 'application/json',
      'User-Agent': AppConstants.userAgent,
      'Authx': authx,
      'Signx': FlyNarwhalAuthHelper.generateSignx(
        url: signaturePath,
        authx: authx,
        parameters: parameters,
        data: data,
        authCode: authCode,
      ),
    };
    final token = getToken();
    final cookie = getCookie();
    if (token.isNotEmpty) {
      headers['Authorization'] = token;
    }
    if (cookie.isNotEmpty) {
      headers['Cookie'] = cookie;
    }
    if (isPost || isSse || authCode.startsWith('FN1_')) {
      headers['Keyx'] = await _crypto.clientKeyxBase64Url();
    }
    return headers;
  }

  Future<SmartAnalysisResult<T>> _decodeSmartResult<T>(
      String raw, T Function(Object? json) fromJsonT) async {
    final decoded = jsonDecode(raw);
    final result = SmartAnalysisResult<dynamic>.fromJson(
        Map<String, dynamic>.from(decoded as Map), (json) => json);
    if (!result.isSuccess()) {
      throw FailureInfo(
          message: result.msg, code: result.code, displayMessage: result.msg);
    }
    final rawData = result.data;
    final resolvedData = result.encrypted == true && rawData is String
        ? jsonDecode(
            await _crypto.decryptAesGcmBase64Url(rawData, getAuthCode()))
        : rawData;
    return SmartAnalysisResult<T>(
        code: result.code,
        msg: result.msg,
        data: resolvedData == null ? null : fromJsonT(resolvedData),
        success: result.success,
        encrypted: result.encrypted);
  }

  Stream<SseEvent> _parseResponseBodyEvents(ResponseBody responseBody) {
    final byteStream = responseBody.stream.map<List<int>>((chunk) => chunk);
    final lines =
        byteStream.transform(utf8.decoder).transform(const LineSplitter());
    return SseEventParser.parse(lines);
  }

  Map<String, List<Danmaku>> _parseDanmakuPayload(String data) {
    final decoded = jsonDecode(data);
    if (decoded is List) {
      return <String, List<Danmaku>>{'default': _parseDanmakuList(decoded)};
    }
    if (decoded is Map) {
      return decoded.map((key, value) {
        final rawList = value is List ? value : const <dynamic>[];
        return MapEntry(key.toString(), _parseDanmakuList(rawList));
      });
    }
    return <String, List<Danmaku>>{};
  }

  List<Danmaku> _parseDanmakuList(List<dynamic> rawList) {
    return rawList
        .map((item) => Danmaku.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }
}
