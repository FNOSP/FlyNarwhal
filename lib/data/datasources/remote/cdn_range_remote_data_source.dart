import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/api_result.dart';
import '../../../core/network/cdn_proxy/cdn_http_transport.dart';
import '../../../core/network/cdn_proxy/cdn_proxy_constants.dart';
import '../../../core/network/cdn_proxy/cdn_proxy_errors.dart';
import '../../../core/network/cdn_proxy/cdn_range_source.dart';
import '../../../core/network/cdn_proxy/cdn_request_headers.dart';

/// Fetches bounded provider ranges through an isolated external HTTP client.
/// The URL and provider headers come from direct-play metadata, not NAS auth.
class CdnRangeRemoteDataSource implements CdnRangeSource {
  CdnRangeRemoteDataSource({required CdnHttpTransport transport})
      : _transport = transport;

  static const maxRangeBytes = CdnProxyDefaults.chunkSize;
  final CdnHttpTransport _transport;

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
    final response = await _transport.getStream(
      uri,
      headers: requestHeaders,
      cancelToken: cancelToken,
    );
    return response.whenAsync(
      failure: (failure) async => ResultFailure(failure),
      success: (response) async {
        try {
          final parsed = _parseResponse(response, start: start, end: end);
          if (parsed.totalLength == 0) {
            await _cancelResponse(response, cancelToken);
          }
          return Success(parsed);
        } on FailureInfo catch (failure) {
          // Reject invalid metadata before the scheduler can consume any bytes.
          await _cancelResponse(response, cancelToken);
          return ResultFailure(failure);
        }
      },
    );
  }

  CdnRangeResponse _parseResponse(CdnHttpResponse response,
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
      CdnHttpResponse response, CancelToken cancelToken) async {
    cancelToken.cancel('CDN response rejected or empty');
    try {
      await response.stream.listen((_) {}, onError: (Object _) {}).cancel();
    } catch (_) {
      // Cancellation may race a remote disconnect.
    }
  }

  @override
  void close() => _transport.close();
}
