import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../api_result.dart';

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
    required this.totalLength,
    this.contentType,
    required this.stream,
  });

  /// Validated resource metadata; zero denotes an empty resource probe.
  final int totalLength;
  final String? contentType;
  final Stream<Uint8List> stream;
}
