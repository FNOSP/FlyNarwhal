class SubtitleSearchRequest {
  final String lan;
  final String mediaGuid;

  const SubtitleSearchRequest({
    required this.lan,
    required this.mediaGuid,
  });

  Map<String, dynamic> toJson() => {
        'lan': lan,
        'media_guid': mediaGuid,
      };
}

class SubtitleSearchResponse {
  final String lan;
  final List<SearchingSubtitleInfo> subtitles;

  const SubtitleSearchResponse({
    required this.lan,
    required this.subtitles,
  });

  factory SubtitleSearchResponse.fromJson(Map<String, dynamic> json) {
    final subtitles = (json['subtitles'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SearchingSubtitleInfo.fromJson)
        .toList();
    return SubtitleSearchResponse(
      lan: json['lan'] as String? ?? '',
      subtitles: subtitles,
    );
  }
}

class SearchingSubtitleInfo {
  final String filename;
  final int download;
  final String sourceId;
  final String source;
  final String trimId;
  final String format;

  const SearchingSubtitleInfo({
    required this.filename,
    required this.download,
    required this.sourceId,
    required this.source,
    required this.trimId,
    required this.format,
  });

  factory SearchingSubtitleInfo.fromJson(Map<String, dynamic> json) {
    return SearchingSubtitleInfo(
      filename: json['filename'] as String? ?? '',
      download: (json['download'] as num?)?.toInt() ?? 0,
      sourceId: json['source_id'] as String? ?? '',
      source: (json['source'] ?? json['Source']) as String? ?? '',
      trimId: json['trim_id'] as String? ?? '',
      format: json['format'] as String? ?? '',
    );
  }
}

class SubtitleDownloadRequest {
  final String mediaGuid;
  final String trimId;

  // Whether the download should be performed synchronously on the server side.
  final int syncDownload;

  const SubtitleDownloadRequest({
    required this.mediaGuid,
    required this.trimId,
    this.syncDownload = 1,
  });

  Map<String, dynamic> toJson() => {
        'media_guid': mediaGuid,
        'trim_id': trimId,
        'sync_download': syncDownload,
      };
}
