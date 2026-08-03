enum MediaType {
  movie('Movie', '电影'),
  tv('TV', '电视节目'),
  directory('Directory', '目录'),
  video('Video', '其他'),
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
