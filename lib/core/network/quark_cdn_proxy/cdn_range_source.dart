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
    String? ifRangeEtag,
  });

  void close();
}

/// Parsed entity tag. Weak tags are evidence, never an If-Range condition.
class CdnEntityTag {
  const CdnEntityTag({required this.opaqueValue, this.isWeak = false});
  final String opaqueValue;
  final bool isWeak;
  String get headerValue => '${isWeak ? 'W/' : ''}"$opaqueValue"';
  String? get strongValue => isWeak ? null : headerValue;

  @override
  bool operator ==(Object other) =>
      other is CdnEntityTag &&
      other.opaqueValue == opaqueValue &&
      other.isWeak == isWeak;
  @override
  int get hashCode => Object.hash(opaqueValue, isWeak);
}

class CdnRangeResponse {
  const CdnRangeResponse({
    required this.totalLength,
    this.contentType,
    required this.stream,
    this.entityTag,
    this.lastModified,
  });

  /// Validated resource metadata; zero denotes an empty resource probe.
  final int totalLength;
  final String? contentType;
  final Stream<Uint8List> stream;
  final CdnEntityTag? entityTag;
  final DateTime? lastModified;
}
