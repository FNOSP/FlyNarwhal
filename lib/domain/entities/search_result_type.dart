import 'media_type.dart';

enum SearchResultType {
  movie,
  tv,
  directory,
  video,
  episode,
  season,
  person;

  const SearchResultType();

  String get value {
    switch (this) {
      case SearchResultType.movie:
        return MediaType.movie.value;
      case SearchResultType.tv:
        return MediaType.tv.value;
      case SearchResultType.directory:
        return MediaType.directory.value;
      case SearchResultType.video:
        return MediaType.video.value;
      case SearchResultType.episode:
        return MediaType.episode.value;
      case SearchResultType.season:
        return MediaType.season.value;
      case SearchResultType.person:
        return 'Person';
    }
  }

  static SearchResultType? tryParse(String? value) {
    if (value == null) {
      return null;
    }

    for (final resultType in SearchResultType.values) {
      if (resultType.value == value) {
        return resultType;
      }
    }
    return null;
  }

  MediaType? get mediaType {
    if (this == SearchResultType.person) {
      return null;
    }
    return MediaType.tryParse(value);
  }
}
