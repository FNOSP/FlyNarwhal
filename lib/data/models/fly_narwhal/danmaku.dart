class Danmaku {
  final String text;
  final double time;
  final String color;
  final bool border;
  final int mode;

  const Danmaku({
    required this.text,
    required this.time,
    required this.color,
    this.border = false,
    this.mode = 0,
  });

  factory Danmaku.fromJson(Map<String, dynamic> json) {
    return Danmaku(
      text: json['text']?.toString() ?? '',
      time: _readDouble(json['time']),
      color: json['color']?.toString() ?? '#FFFFFF',
      border: json['border'] as bool? ?? false,
      mode: _readInt(json['mode']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'text': text,
      'time': time,
      'color': color,
      'border': border,
      'mode': mode,
    };
  }
}

class DanmakuRequest {
  final String doubanId;
  final int episodeNumber;
  final String episodeTitle;
  final String title;
  final int seasonNumber;
  final bool season;
  final String guid;
  final String parentGuid;

  const DanmakuRequest({
    required this.doubanId,
    required this.episodeNumber,
    required this.episodeTitle,
    required this.title,
    required this.seasonNumber,
    required this.season,
    required this.guid,
    required this.parentGuid,
  });

  factory DanmakuRequest.fromJson(Map<String, dynamic> json) {
    return DanmakuRequest(
      doubanId: json['douban_id']?.toString() ?? '',
      episodeNumber: _readInt(json['episode_number']),
      episodeTitle: json['episode_title']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      seasonNumber: _readInt(json['season_number']),
      season: json['season'] as bool? ?? false,
      guid: json['guid']?.toString() ?? '',
      parentGuid: json['parent_guid']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return toQueryParameters();
  }

  Map<String, dynamic> toQueryParameters() {
    return <String, dynamic>{
      'douban_id': doubanId,
      'episode_number': episodeNumber,
      'episode_title': episodeTitle,
      'title': title,
      'season_number': seasonNumber,
      'season': season,
      'guid': guid,
      'parent_guid': parentGuid,
    };
  }
}

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double _readDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}
