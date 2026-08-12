import 'package:json_annotation/json_annotation.dart';

part 'movie_detail_models.g.dart';

@JsonSerializable()
class ItemResponse {
  final String guid;
  @JsonKey(name: 'imdb_id')
  final String? imdbId;
  @JsonKey(name: 'trim_id')
  final String? trimId;
  @JsonKey(name: 'tv_title')
  final String tvTitle;
  @JsonKey(name: 'parent_title')
  final String parentTitle;
  final String title;
  @JsonKey(name: 'original_title')
  final String? originalTitle;
  final String? backdrops;
  @JsonKey(defaultValue: '')
  final String posters;
  @JsonKey(name: 'poster_width', defaultValue: 0)
  final int posterWidth;
  @JsonKey(name: 'poster_height', defaultValue: 0)
  final int posterHeight;
  @JsonKey(name: 'vote_average')
  final String voteAverage;
  final List<int>? genres;
  @JsonKey(name: 'content_ratings')
  final String? contentRatings;
  @JsonKey(name: 'release_date')
  final String? releaseDate;
  @JsonKey(name: 'production_countries')
  final List<String>? productionCountries;
  final String? overview;
  @JsonKey(name: 'is_favorite', defaultValue: 0)
  final int isFavorite;
  @JsonKey(name: 'is_watched', defaultValue: 0)
  final int isWatched;
  @JsonKey(name: 'watched_ts', defaultValue: 0)
  final int watchedTs;
  @JsonKey(name: 'season_number', defaultValue: 0)
  final int seasonNumber;
  @JsonKey(name: 'number_of_seasons', defaultValue: 0)
  final int numberOfSeasons;
  @JsonKey(name: 'number_of_episodes', defaultValue: 0)
  final int numberOfEpisodes;
  @JsonKey(name: 'local_number_of_episodes', defaultValue: 0)
  final int localNumberOfEpisodes;
  @JsonKey(name: 'local_number_of_seasons', defaultValue: 0)
  final int localNumberOfSeasons;
  @JsonKey(name: 'can_play', defaultValue: 0)
  final int canPlay;
  final String type;
  @JsonKey(name: 'play_error')
  final String playError;
  @JsonKey(name: 'parent_guid')
  final String parentGuid;
  @JsonKey(name: 'ancestor_name')
  final String ancestorName;
  @JsonKey(name: 'play_item_guid')
  final String playItemGuid;
  @JsonKey(defaultValue: 0)
  final int duration;
  @JsonKey(name: 'logic_type', defaultValue: 0)
  final int logicType;
  @JsonKey(name: 'episode_number', defaultValue: 0)
  final int episodeNumber;
  final String? logos;
  @JsonKey(name: 'air_date')
  final String? airDate;

  ItemResponse({
    required this.guid,
    this.imdbId,
    required this.trimId,
    required this.tvTitle,
    required this.parentTitle,
    required this.title,
    this.originalTitle,
    this.backdrops,
    required this.posters,
    required this.posterWidth,
    required this.posterHeight,
    required this.voteAverage,
    this.genres,
    this.contentRatings,
    this.releaseDate,
    this.productionCountries,
    this.overview,
    required this.isFavorite,
    required this.isWatched,
    required this.watchedTs,
    required this.seasonNumber,
    required this.numberOfSeasons,
    required this.numberOfEpisodes,
    required this.localNumberOfEpisodes,
    required this.localNumberOfSeasons,
    required this.canPlay,
    required this.type,
    required this.playError,
    required this.parentGuid,
    required this.ancestorName,
    required this.playItemGuid,
    required this.duration,
    required this.logicType,
    required this.episodeNumber,
    this.logos,
    this.airDate,
  });

  factory ItemResponse.fromJson(Map<String, dynamic> json) => _$ItemResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ItemResponseToJson(this);

  ItemResponse copyWith({
    String? guid,
    String? imdbId,
    String? trimId,
    String? tvTitle,
    String? parentTitle,
    String? title,
    String? originalTitle,
    String? backdrops,
    String? posters,
    int? posterWidth,
    int? posterHeight,
    String? voteAverage,
    List<int>? genres,
    String? contentRatings,
    String? releaseDate,
    List<String>? productionCountries,
    String? overview,
    int? isFavorite,
    int? isWatched,
    int? watchedTs,
    int? seasonNumber,
    int? numberOfSeasons,
    int? numberOfEpisodes,
    int? localNumberOfEpisodes,
    int? localNumberOfSeasons,
    int? canPlay,
    String? type,
    String? playError,
    String? parentGuid,
    String? ancestorName,
    String? playItemGuid,
    int? duration,
    int? logicType,
    int? episodeNumber,
    String? logos,
    String? airDate,
  }) {
    return ItemResponse(
      guid: guid ?? this.guid,
      imdbId: imdbId ?? this.imdbId,
      trimId: trimId ?? this.trimId,
      tvTitle: tvTitle ?? this.tvTitle,
      parentTitle: parentTitle ?? this.parentTitle,
      title: title ?? this.title,
      originalTitle: originalTitle ?? this.originalTitle,
      backdrops: backdrops ?? this.backdrops,
      posters: posters ?? this.posters,
      posterWidth: posterWidth ?? this.posterWidth,
      posterHeight: posterHeight ?? this.posterHeight,
      voteAverage: voteAverage ?? this.voteAverage,
      genres: genres ?? this.genres,
      contentRatings: contentRatings ?? this.contentRatings,
      releaseDate: releaseDate ?? this.releaseDate,
      productionCountries: productionCountries ?? this.productionCountries,
      overview: overview ?? this.overview,
      isFavorite: isFavorite ?? this.isFavorite,
      isWatched: isWatched ?? this.isWatched,
      watchedTs: watchedTs ?? this.watchedTs,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      numberOfSeasons: numberOfSeasons ?? this.numberOfSeasons,
      numberOfEpisodes: numberOfEpisodes ?? this.numberOfEpisodes,
      localNumberOfEpisodes: localNumberOfEpisodes ?? this.localNumberOfEpisodes,
      localNumberOfSeasons: localNumberOfSeasons ?? this.localNumberOfSeasons,
      canPlay: canPlay ?? this.canPlay,
      type: type ?? this.type,
      playError: playError ?? this.playError,
      parentGuid: parentGuid ?? this.parentGuid,
      ancestorName: ancestorName ?? this.ancestorName,
      playItemGuid: playItemGuid ?? this.playItemGuid,
      duration: duration ?? this.duration,
      logicType: logicType ?? this.logicType,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      logos: logos ?? this.logos,
      airDate: airDate ?? this.airDate,
    );
  }
}

@JsonSerializable()
class FileInfo {
  final String guid;
  final String path;
  @JsonKey(name: 'file_name')
  final String fileName;
  final int size;
  final int timestamp;
  final int type;
  @JsonKey(name: 'can_play')
  final int canPlay;
  @JsonKey(name: 'play_error')
  final String playError;
  @JsonKey(name: 'create_time')
  final int createTime;
  @JsonKey(name: 'update_time')
  final int updateTime;
  @JsonKey(name: 'file_birth_time')
  final int fileBirthTime;
  @JsonKey(name: 'progress_thumb_hash_dir')
  final String progressThumbHashDir;

  FileInfo({
    required this.guid,
    required this.path,
    required this.fileName,
    required this.size,
    required this.timestamp,
    required this.type,
    required this.canPlay,
    required this.playError,
    required this.createTime,
    required this.updateTime,
    required this.fileBirthTime,
    required this.progressThumbHashDir,
  });

  factory FileInfo.fromJson(Map<String, dynamic> json) => _$FileInfoFromJson(json);
  Map<String, dynamic> toJson() => _$FileInfoToJson(this);
}

@JsonSerializable()
class VideoStream {
  @JsonKey(name: 'media_guid')
  final String mediaGuid;
  final String title;
  final String guid;
  @JsonKey(name: 'resolution_type')
  final String resolutionType;
  @JsonKey(name: 'color_range_type')
  final String colorRangeType;
  @JsonKey(name: 'codec_name')
  final String codecName;
  @JsonKey(name: 'codec_type')
  final String codecType;
  @JsonKey(name: 'color_range')
  final String colorRange;
  final String profile;
  final int index;
  final int width;
  final int height;
  @JsonKey(name: 'coded_width')
  final int codedWidth;
  @JsonKey(name: 'coded_height')
  final int codedHeight;
  @JsonKey(name: 'display_aspect_ratio')
  final String displayAspectRatio;
  @JsonKey(name: 'pix_fmt')
  final String pixFmt;
  final String level;
  @JsonKey(name: 'color_space')
  final String colorSpace;
  @JsonKey(name: 'color_transfer')
  final String colorTransfer;
  @JsonKey(name: 'color_primaries')
  final String colorPrimaries;
  final int duration;
  @JsonKey(name: 'dv_profile')
  final int dvProfile;
  final int refs;
  @JsonKey(name: 'r_frame_rate')
  final String rFrameRate;
  @JsonKey(name: 'avg_frame_rate')
  final String avgFrameRate;
  @JsonKey(name: 'bits_per_raw_sample')
  final String bitsPerRawSample;
  final int bps;
  final int progressive;
  @JsonKey(name: 'bit_depth')
  final int bitDepth;
  final String wrapper;
  @JsonKey(name: 'create_time')
  final int createTime;
  @JsonKey(name: 'update_time')
  final int updateTime;
  final int rotation;
  final int ext1;
  @JsonKey(name: 'is_bluray')
  final bool isBluray;

  VideoStream({
    required this.mediaGuid,
    required this.title,
    required this.guid,
    required this.resolutionType,
    required this.colorRangeType,
    required this.codecName,
    required this.codecType,
    required this.colorRange,
    required this.profile,
    required this.index,
    required this.width,
    required this.height,
    required this.codedWidth,
    required this.codedHeight,
    required this.displayAspectRatio,
    required this.pixFmt,
    required this.level,
    required this.colorSpace,
    required this.colorTransfer,
    required this.colorPrimaries,
    required this.duration,
    required this.dvProfile,
    required this.refs,
    required this.rFrameRate,
    required this.avgFrameRate,
    required this.bitsPerRawSample,
    required this.bps,
    required this.progressive,
    required this.bitDepth,
    required this.wrapper,
    required this.createTime,
    required this.updateTime,
    required this.rotation,
    required this.ext1,
    required this.isBluray,
  });

  factory VideoStream.fromJson(Map<String, dynamic> json) => _$VideoStreamFromJson(json);
  Map<String, dynamic> toJson() => _$VideoStreamToJson(this);
}

@JsonSerializable()
class AudioStream {
  @JsonKey(name: 'media_guid')
  final String mediaGuid;
  final String title;
  final String guid;
  @JsonKey(name: 'audio_type')
  final String audioType;
  @JsonKey(name: 'codec_name')
  final String codecName;
  @JsonKey(name: 'codec_type')
  final String codecType;
  final String language;
  final int channels;
  final String profile;
  @JsonKey(name: 'sample_rate')
  final String sampleRate;
  @JsonKey(name: 'is_default')
  final int isDefault;
  @JsonKey(name: 'channel_layout')
  final String channelLayout;
  final int duration;
  final int index;
  @JsonKey(name: 'bits_per_raw_sample')
  final String bitsPerRawSample;
  final int bps;
  @JsonKey(name: 'create_time')
  final int createTime;
  @JsonKey(name: 'update_time')
  final int updateTime;
  @JsonKey(name: 'is_fake')
  final bool isFake;

  AudioStream({
    required this.mediaGuid,
    required this.title,
    required this.guid,
    required this.audioType,
    required this.codecName,
    required this.codecType,
    required this.language,
    required this.channels,
    required this.profile,
    required this.sampleRate,
    required this.isDefault,
    required this.channelLayout,
    required this.duration,
    required this.index,
    required this.bitsPerRawSample,
    required this.bps,
    required this.createTime,
    required this.updateTime,
    required this.isFake,
  });

  factory AudioStream.fromJson(Map<String, dynamic> json) => _$AudioStreamFromJson(json);
  Map<String, dynamic> toJson() => _$AudioStreamToJson(this);
}

@JsonSerializable()
class SubtitleStream {
  @JsonKey(name: 'media_guid')
  final String mediaGuid;
  final String title;
  final String guid;
  @JsonKey(name: 'codec_name')
  final String codecName;
  @JsonKey(name: 'codec_type')
  final String codecType;
  final String language;
  final int forced;
  final int index;
  @JsonKey(name: 'is_default')
  final int isDefault;
  @JsonKey(name: 'is_external')
  final int isExternal;
  final String format;
  @JsonKey(name: 'trim_id')
  final String trimId;
  @JsonKey(name: 'source_id')
  final String sourceId;
  @JsonKey(name: 'Source')
  final String source;
  @JsonKey(name: 'create_time')
  final int createTime;
  @JsonKey(name: 'update_time')
  final int updateTime;
  @JsonKey(name: 'extra_file')
  final int extraFile;
  @JsonKey(name: 'is_bitmap')
  final int isBitmap;
  @JsonKey(name: 'file_size')
  final int fileSize;

  SubtitleStream({
    required this.mediaGuid,
    required this.title,
    required this.guid,
    required this.codecName,
    required this.codecType,
    required this.language,
    required this.forced,
    required this.index,
    required this.isDefault,
    required this.isExternal,
    required this.format,
    required this.trimId,
    required this.sourceId,
    required this.source,
    required this.createTime,
    required this.updateTime,
    required this.extraFile,
    required this.isBitmap,
    required this.fileSize,
  });

  factory SubtitleStream.fromJson(Map<String, dynamic> json) => _$SubtitleStreamFromJson(json);
  Map<String, dynamic> toJson() => _$SubtitleStreamToJson(this);
}

@JsonSerializable()
class StreamListResponse {
  final List<FileInfo>? files;
  @JsonKey(name: 'video_streams')
  final List<VideoStream> videoStreams;
  @JsonKey(name: 'audio_streams')
  final List<AudioStream> audioStreams;
  @JsonKey(name: 'subtitle_streams')
  final List<SubtitleStream> subtitleStreams;

  StreamListResponse({
    this.files,
    required this.videoStreams,
    required this.audioStreams,
    required this.subtitleStreams,
  });

  factory StreamListResponse.fromJson(Map<String, dynamic> json) => _$StreamListResponseFromJson(json);
  Map<String, dynamic> toJson() => _$StreamListResponseToJson(this);
}

@JsonSerializable()
class PlayConfig {
  final String? guid;
  @JsonKey(name: 'skip_opening')
  final int? skipOpening;
  @JsonKey(name: 'skip_ending')
  final int? skipEnding;

  PlayConfig({this.guid, this.skipOpening, this.skipEnding});

  factory PlayConfig.fromJson(Map<String, dynamic> json) => _$PlayConfigFromJson(json);
  Map<String, dynamic> toJson() => _$PlayConfigToJson(this);

  PlayConfig copyWith({
    String? guid,
    int? skipOpening,
    int? skipEnding,
  }) {
    return PlayConfig(
      guid: guid ?? this.guid,
      skipOpening: skipOpening ?? this.skipOpening,
      skipEnding: skipEnding ?? this.skipEnding,
    );
  }
}

@JsonSerializable()
class LiveChannelSource {
  final String guid;
  final String path;
  @JsonKey(name: 'file_name')
  final String fileName;
  @JsonKey(name: 'sort_num', defaultValue: 0)
  final int sortNum;
  @JsonKey(name: 'can_play', defaultValue: 1)
  final int canPlay;
  @JsonKey(name: 'play_error')
  final String? playError;

  LiveChannelSource({
    required this.guid,
    required this.path,
    required this.fileName,
    this.sortNum = 0,
    this.canPlay = 1,
    this.playError,
  });

  factory LiveChannelSource.fromJson(Map<String, dynamic> json) =>
      _$LiveChannelSourceFromJson(json);
  Map<String, dynamic> toJson() => _$LiveChannelSourceToJson(this);
}

@JsonSerializable()
class PlayInfoResponse {
  @JsonKey(name: 'grand_guid')
  final String grandGuid;
  final String guid;
  @JsonKey(name: 'parent_guid')
  final String parentGuid;
  @JsonKey(name: 'play_config')
  final PlayConfig? playConfig;
  final int ts;
  final String type;
  @JsonKey(name: 'video_guid')
  final String videoGuid;
  @JsonKey(name: 'audio_guid')
  final String audioGuid;
  @JsonKey(name: 'subtitle_guid')
  final String subtitleGuid;
  @JsonKey(name: 'media_guid')
  final String mediaGuid;
  final ItemResponse item;
  @JsonKey(name: 'live_channels')
  final List<LiveChannelSource>? liveChannels;
  @JsonKey(name: 'direct_link_audio_index')
  final int directLinkAudioIndex;

  PlayInfoResponse({
    required this.grandGuid,
    required this.guid,
    required this.parentGuid,
    this.playConfig,
    required this.ts,
    required this.type,
    required this.videoGuid,
    required this.audioGuid,
    required this.subtitleGuid,
    required this.mediaGuid,
    required this.item,
    this.liveChannels,
    required this.directLinkAudioIndex,
  });

  factory PlayInfoResponse.fromJson(Map<String, dynamic> json) => _$PlayInfoResponseFromJson(json);
  Map<String, dynamic> toJson() => _$PlayInfoResponseToJson(this);
}

@JsonSerializable()
class PersonList {
  @JsonKey(name: 'item_guid')
  final String itemGuid;
  @JsonKey(name: 'person_guid')
  final String personGuid;
  final String role;
  final String job;
  final int order;
  final String department;
  @JsonKey(name: 'trim_id')
  final String trimId;
  @JsonKey(name: 'imdb_id')
  final String imdbId;
  @JsonKey(name: 'tmdb_id')
  final int tmdbId;
  final String lan;
  final String name;
  @JsonKey(name: 'original_name')
  final String originalName;
  @JsonKey(name: 'also_know_as')
  final String alsoKnowAs;
  final String biography;
  @JsonKey(name: 'known_for_department')
  final String knownForDepartment;
  @JsonKey(name: 'profile_path')
  final String profilePath;
  final int gender;

  PersonList({
    required this.itemGuid,
    required this.personGuid,
    required this.role,
    required this.job,
    required this.order,
    required this.department,
    required this.trimId,
    required this.imdbId,
    required this.tmdbId,
    required this.lan,
    required this.name,
    required this.originalName,
    required this.alsoKnowAs,
    required this.biography,
    required this.knownForDepartment,
    required this.profilePath,
    required this.gender,
  });

  factory PersonList.fromJson(Map<String, dynamic> json) => _$PersonListFromJson(json);
  Map<String, dynamic> toJson() => _$PersonListToJson(this);
}

@JsonSerializable()
class PersonListResponse {
  final List<PersonList> list;
  final int total;

  PersonListResponse({required this.list, required this.total});

  factory PersonListResponse.fromJson(Map<String, dynamic> json) => _$PersonListResponseFromJson(json);
  Map<String, dynamic> toJson() => _$PersonListResponseToJson(this);
}
