import 'package:dio/dio.dart';

import '../../../../data/models/movie_detail_models.dart';

class HlsResolvedMedia {
  final String originalUrl;
  final bool isHls;
  final bool hasSubtitleMedia;
  final String playUrl;
  final String? subtitlePlaylistUrl;

  const HlsResolvedMedia({
    required this.originalUrl,
    required this.isHls,
    required this.hasSubtitleMedia,
    required this.playUrl,
    this.subtitlePlaylistUrl,
  });
}

/// Resolves HLS master playlists before opening them with media_kit.
class HlsPlaylistResolver {
  final Dio _dio;
  final Map<String, String> _headers;

  const HlsPlaylistResolver({
    required Dio dio,
    required Map<String, String> headers,
  })  : _dio = dio,
        _headers = headers;

  Future<HlsResolvedMedia> resolve(
    String playUrl, {
    SubtitleStream? subtitleStream,
  }) async {
    if (!_looksLikeM3u8(playUrl)) {
      return HlsResolvedMedia(
        originalUrl: playUrl,
        isHls: false,
        hasSubtitleMedia: false,
        playUrl: playUrl,
      );
    }

    final playlistContent = await fetchContent(playUrl);
    final subtitlePlaylistUrl = subtitleStream == null
        ? null
        : findSubtitlePlaylistUrl(playlistContent, playUrl, subtitleStream);
    final hasSubtitleMedia =
        playlistContent.contains('#EXT-X-MEDIA:TYPE=SUBTITLES');
    final videoStreamUrl = hasSubtitleMedia
        ? extractVideoStreamUrl(playlistContent, playUrl)
        : null;

    return HlsResolvedMedia(
      originalUrl: playUrl,
      isHls: true,
      hasSubtitleMedia: hasSubtitleMedia,
      playUrl: videoStreamUrl ?? playUrl,
      subtitlePlaylistUrl: subtitlePlaylistUrl,
    );
  }

  Future<String> fetchContent(String url) async {
    final response = await _dio.get<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        headers: _headers,
      ),
    );
    return response.data ?? '';
  }

  String? extractVideoStreamUrl(String playlistContent, String presetUrl) {
    final lines = playlistContent.split(RegExp(r'\r?\n'));
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (!line.startsWith('#EXT-X-STREAM-INF')) {
        continue;
      }
      if (i + 1 >= lines.length) {
        continue;
      }
      final candidate = lines[i + 1].trim();
      if (candidate.isEmpty || candidate.startsWith('#')) {
        continue;
      }
      return resolveUrl(presetUrl, candidate);
    }
    return null;
  }

  String? findSubtitlePlaylistUrl(
    String playlistContent,
    String presetUrl,
    SubtitleStream subtitleStream,
  ) {
    final lines = playlistContent.split(RegExp(r'\r?\n'));
    final targetLanguage = subtitleStream.language.trim();
    String? fallbackUrl;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (!line.startsWith('#EXT-X-MEDIA:TYPE=SUBTITLES')) {
        continue;
      }
      final attributes = _parseAttributeList(
        line.substring(line.indexOf(':') + 1),
      );
      final uri = attributes['URI'];
      if (uri == null || uri.isEmpty) {
        continue;
      }
      final resolved = resolveUrl(presetUrl, uri);
      final language = attributes['LANGUAGE']?.trim() ?? '';
      if (targetLanguage.isNotEmpty && language == targetLanguage) {
        return resolved;
      }
      fallbackUrl ??= resolved;
    }

    return fallbackUrl;
  }

  String resolveUrl(String baseUrl, String relativeUrl) {
    if (relativeUrl.startsWith('http://') ||
        relativeUrl.startsWith('https://')) {
      return relativeUrl;
    }

    final baseUri = Uri.parse(baseUrl);
    return baseUri.resolve(relativeUrl).toString();
  }

  bool _looksLikeM3u8(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return url.contains('.m3u8');
    }
    return uri.path.toLowerCase().contains('.m3u8');
  }

  Map<String, String> _parseAttributeList(String input) {
    final result = <String, String>{};
    final buffer = StringBuffer();
    final segments = <String>[];
    var inQuotes = false;

    for (final codeUnit in input.codeUnits) {
      final char = String.fromCharCode(codeUnit);
      if (char == '"') {
        inQuotes = !inQuotes;
      }
      if (char == ',' && !inQuotes) {
        segments.add(buffer.toString());
        buffer.clear();
        continue;
      }
      buffer.write(char);
    }
    if (buffer.isNotEmpty) {
      segments.add(buffer.toString());
    }

    for (final segment in segments) {
      final separator = segment.indexOf('=');
      if (separator <= 0) {
        continue;
      }
      final key = segment.substring(0, separator).trim();
      final value = segment
          .substring(separator + 1)
          .trim()
          .replaceAll(RegExp(r'^"|"$'), '');
      if (key.isNotEmpty) {
        result[key] = value;
      }
    }
    return result;
  }
}
