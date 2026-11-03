export 'cdn_proxy_errors.dart' show CdnRangeCancelled, CdnRangeFailure;
export 'cdn_range_source.dart';
export 'cdn_request_headers.dart' show normalizeCdnRequestHeaders;

/// The playback layer only owns a local proxy URL and its lifetime.
abstract interface class CdnProxy {
  Future<Uri> open({required Uri uri, required Map<String, String> headers});
  Future<void> close();
}
