import 'dart:convert';

import '../models/playback_source_spec.dart';

/// Player-facing headers. The bounded Quark transport serves a local URL;
/// its CDN headers are applied separately by the range data source.
Map<String, String> buildPlaybackHttpHeaders({
  required PlaybackTransport transport,
  required String playUri,
  required String? baseUrl,
  required Map<String, String> Function() buildNasHeaders,
  required Map<String, dynamic>? cloudHeaders,
}) {
  if (transport == PlaybackTransport.quarkCdnRange) return const {};

  // Preserve the original NAS proxy and same-host rules for standard playback,
  // including HLS playlists/segments and the legacy cloud quality endpoint.
  final isNasProxy = playUri.contains('/v/api/v1/media/range') ||
      playUri.contains('/v/api/v1/wp/m3u8') ||
      _isNasHostedUrl(playUri, baseUrl);
  if (isNasProxy) {
    final headers = Map<String, String>.of(buildNasHeaders());
    if (cloudHeaders != null && cloudHeaders.isNotEmpty) {
      headers['X-Wp-Header'] = jsonEncode(cloudHeaders);
    }
    return headers;
  }

  final headers = <String, String>{};
  if (cloudHeaders != null) {
    for (final entry in cloudHeaders.entries) {
      final value = entry.value;
      if (value != null) headers[entry.key] = value.toString();
    }
  }
  return headers;
}

bool _isNasHostedUrl(String playUri, String? baseUrl) {
  if (baseUrl == null || baseUrl.isEmpty) return false;
  final baseUri = Uri.tryParse(baseUrl);
  final targetUri = Uri.tryParse(playUri);
  if (baseUri == null || targetUri == null || baseUri.host.isEmpty) {
    return false;
  }
  return targetUri.host == baseUri.host && targetUri.port == baseUri.port;
}
