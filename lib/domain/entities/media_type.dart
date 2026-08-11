enum MediaType {
  movie('Movie', '电影'),
  tv('TV', '电视节目'),
  directory('Directory', '目录'),
  video('Video', '其他'),
  liveChannel('LiveChannel', '电视直播'),
  episode('Episode', '剧集'),
  season('Season', '季');

  final String value;
  final String description;

  const MediaType(this.value, this.description);

  static const List<MediaType> commonlyUsed = [
    MediaType.movie,
    MediaType.tv,
    MediaType.directory,
    MediaType.video,
  ];

  static List<String> get commonlyUsedValues =>
      commonlyUsed.map((mediaType) => mediaType.value).toList(growable: false);

  /// 浏览某个具体媒体库（ancestor guid）时使用的类型全量，含直播频道。
  /// 直播库（IPTV，如"国内电视台"）的条目 type 为 LiveChannel，不在
  /// [commonlyUsed] 中，查询时需显式包含，否则该库只显示标题、无内容。
  static const List<MediaType> libraryBrowse = [
    MediaType.movie,
    MediaType.tv,
    MediaType.directory,
    MediaType.video,
    MediaType.liveChannel,
  ];

  static List<String> get libraryBrowseValues =>
      libraryBrowse.map((mediaType) => mediaType.value).toList(growable: false);

  static MediaType fromString(String? value) {
    return tryParse(value) ?? MediaType.video;
  }

  static MediaType? tryParse(String? value) {
    if (value == null) {
      return null;
    }

    for (final mediaType in MediaType.values) {
      if (mediaType.value == value) {
        return mediaType;
      }
    }
    return null;
  }

  static List<MediaType> fromCategory(String? category) {
    switch (category) {
      case 'movie':
        return const [MediaType.movie];
      case 'tv':
        return const [MediaType.tv];
      case 'video':
        return const [MediaType.directory, MediaType.video];
      case 'live':
        return const [MediaType.liveChannel];
      default:
        return commonlyUsed;
    }
  }

  static List<String> valuesFromCategory(String? category) {
    return fromCategory(category)
        .map((mediaType) => mediaType.value)
        .toList(growable: false);
  }
}
