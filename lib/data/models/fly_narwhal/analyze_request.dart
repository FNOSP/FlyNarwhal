class AnalyzeRequest {
  final String seasonGuid;
  final String seasonPath;
  final List<QueuedEpisode> episodes;
  final String tvTitle;
  final int seasonNumber;

  const AnalyzeRequest({
    required this.seasonGuid,
    required this.seasonPath,
    required this.episodes,
    required this.tvTitle,
    required this.seasonNumber,
  });

  factory AnalyzeRequest.fromJson(Map<String, dynamic> json) {
    final rawEpisodes = json['episodes'] as List<dynamic>? ?? const [];
    return AnalyzeRequest(
      seasonGuid: json['season_guid']?.toString() ?? '',
      seasonPath: json['season_path']?.toString() ?? '',
      episodes: rawEpisodes
          .map((episodeJson) => QueuedEpisode.fromJson(
                Map<String, dynamic>.from(episodeJson as Map),
              ))
          .toList(),
      tvTitle: json['tv_title']?.toString() ?? '',
      seasonNumber: _readInt(json['season_number']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'season_guid': seasonGuid,
      'season_path': seasonPath,
      'episodes': episodes.map((episode) => episode.toJson()).toList(),
      'tv_title': tvTitle,
      'season_number': seasonNumber,
    };
  }
}

class QueuedEpisode {
  final String guid;
  final String filePath;
  final int episodeNumber;
  final int seasonNumber;

  const QueuedEpisode({
    required this.guid,
    required this.filePath,
    required this.episodeNumber,
    required this.seasonNumber,
  });

  factory QueuedEpisode.fromJson(Map<String, dynamic> json) {
    return QueuedEpisode(
      guid: json['guid']?.toString() ?? '',
      filePath: json['file_path']?.toString() ?? '',
      episodeNumber: _readInt(json['episode_number']),
      seasonNumber: _readInt(json['season_number']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'guid': guid,
      'file_path': filePath,
      'episode_number': episodeNumber,
      'season_number': seasonNumber,
    };
  }
}

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
