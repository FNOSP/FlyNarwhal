// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movie_detail_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ItemResponse _$ItemResponseFromJson(Map<String, dynamic> json) => ItemResponse(
      guid: json['guid'] as String,
      imdbId: json['imdb_id'] as String?,
      trimId: json['trim_id'] as String,
      tvTitle: json['tv_title'] as String,
      parentTitle: json['parent_title'] as String,
      title: json['title'] as String,
      originalTitle: json['original_title'] as String?,
      backdrops: json['backdrops'] as String?,
      posters: json['posters'] as String,
      posterWidth: (json['poster_width'] as num?)?.toInt() ?? 0,
      posterHeight: (json['poster_height'] as num?)?.toInt() ?? 0,
      voteAverage: json['vote_average'] as String,
      genres: (json['genres'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      contentRatings: json['content_ratings'] as String?,
      releaseDate: json['release_date'] as String?,
      productionCountries: (json['production_countries'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      overview: json['overview'] as String?,
      isFavorite: (json['is_favorite'] as num?)?.toInt() ?? 0,
      isWatched: (json['is_watched'] as num?)?.toInt() ?? 0,
      watchedTs: (json['watched_ts'] as num?)?.toInt() ?? 0,
      seasonNumber: (json['season_number'] as num?)?.toInt() ?? 0,
      numberOfSeasons: (json['number_of_seasons'] as num?)?.toInt() ?? 0,
      numberOfEpisodes: (json['number_of_episodes'] as num?)?.toInt() ?? 0,
      localNumberOfEpisodes:
          (json['local_number_of_episodes'] as num?)?.toInt() ?? 0,
      localNumberOfSeasons:
          (json['local_number_of_seasons'] as num?)?.toInt() ?? 0,
      canPlay: (json['can_play'] as num?)?.toInt() ?? 0,
      type: json['type'] as String,
      playError: json['play_error'] as String,
      parentGuid: json['parent_guid'] as String,
      ancestorName: json['ancestor_name'] as String,
      playItemGuid: json['play_item_guid'] as String,
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      logicType: (json['logic_type'] as num?)?.toInt() ?? 0,
      logos: json['logos'] as String?,
      airDate: json['air_date'] as String?,
    );

Map<String, dynamic> _$ItemResponseToJson(ItemResponse instance) =>
    <String, dynamic>{
      'guid': instance.guid,
      'imdb_id': instance.imdbId,
      'trim_id': instance.trimId,
      'tv_title': instance.tvTitle,
      'parent_title': instance.parentTitle,
      'title': instance.title,
      'original_title': instance.originalTitle,
      'backdrops': instance.backdrops,
      'posters': instance.posters,
      'poster_width': instance.posterWidth,
      'poster_height': instance.posterHeight,
      'vote_average': instance.voteAverage,
      'genres': instance.genres,
      'content_ratings': instance.contentRatings,
      'release_date': instance.releaseDate,
      'production_countries': instance.productionCountries,
      'overview': instance.overview,
      'is_favorite': instance.isFavorite,
      'is_watched': instance.isWatched,
      'watched_ts': instance.watchedTs,
      'season_number': instance.seasonNumber,
      'number_of_seasons': instance.numberOfSeasons,
      'number_of_episodes': instance.numberOfEpisodes,
      'local_number_of_episodes': instance.localNumberOfEpisodes,
      'local_number_of_seasons': instance.localNumberOfSeasons,
      'can_play': instance.canPlay,
      'type': instance.type,
      'play_error': instance.playError,
      'parent_guid': instance.parentGuid,
      'ancestor_name': instance.ancestorName,
      'play_item_guid': instance.playItemGuid,
      'duration': instance.duration,
      'logic_type': instance.logicType,
      'logos': instance.logos,
      'air_date': instance.airDate,
    };

FileInfo _$FileInfoFromJson(Map<String, dynamic> json) => FileInfo(
      guid: json['guid'] as String,
      path: json['path'] as String,
      fileName: json['file_name'] as String,
      size: (json['size'] as num).toInt(),
      timestamp: (json['timestamp'] as num).toInt(),
      type: (json['type'] as num).toInt(),
      canPlay: (json['can_play'] as num).toInt(),
      playError: json['play_error'] as String,
      createTime: (json['create_time'] as num).toInt(),
      updateTime: (json['update_time'] as num).toInt(),
      fileBirthTime: (json['file_birth_time'] as num).toInt(),
      progressThumbHashDir: json['progress_thumb_hash_dir'] as String,
    );

Map<String, dynamic> _$FileInfoToJson(FileInfo instance) => <String, dynamic>{
      'guid': instance.guid,
      'path': instance.path,
      'file_name': instance.fileName,
      'size': instance.size,
      'timestamp': instance.timestamp,
      'type': instance.type,
      'can_play': instance.canPlay,
      'play_error': instance.playError,
      'create_time': instance.createTime,
      'update_time': instance.updateTime,
      'file_birth_time': instance.fileBirthTime,
      'progress_thumb_hash_dir': instance.progressThumbHashDir,
    };

VideoStream _$VideoStreamFromJson(Map<String, dynamic> json) => VideoStream(
      mediaGuid: json['media_guid'] as String,
      title: json['title'] as String,
      guid: json['guid'] as String,
      resolutionType: json['resolution_type'] as String,
      colorRangeType: json['color_range_type'] as String,
      codecName: json['codec_name'] as String,
      codecType: json['codec_type'] as String,
      colorRange: json['color_range'] as String,
      profile: json['profile'] as String,
      index: (json['index'] as num).toInt(),
      width: (json['width'] as num).toInt(),
      height: (json['height'] as num).toInt(),
      codedWidth: (json['coded_width'] as num).toInt(),
      codedHeight: (json['coded_height'] as num).toInt(),
      displayAspectRatio: json['display_aspect_ratio'] as String,
      pixFmt: json['pix_fmt'] as String,
      level: json['level'] as String,
      colorSpace: json['color_space'] as String,
      colorTransfer: json['color_transfer'] as String,
      colorPrimaries: json['color_primaries'] as String,
      duration: (json['duration'] as num).toInt(),
      dvProfile: (json['dv_profile'] as num).toInt(),
      refs: (json['refs'] as num).toInt(),
      rFrameRate: json['r_frame_rate'] as String,
      avgFrameRate: json['avg_frame_rate'] as String,
      bitsPerRawSample: json['bits_per_raw_sample'] as String,
      bps: (json['bps'] as num).toInt(),
      progressive: (json['progressive'] as num).toInt(),
      bitDepth: (json['bit_depth'] as num).toInt(),
      wrapper: json['wrapper'] as String,
      createTime: (json['create_time'] as num).toInt(),
      updateTime: (json['update_time'] as num).toInt(),
      rotation: (json['rotation'] as num).toInt(),
      ext1: (json['ext1'] as num).toInt(),
      isBluray: json['is_bluray'] as bool,
    );

Map<String, dynamic> _$VideoStreamToJson(VideoStream instance) =>
    <String, dynamic>{
      'media_guid': instance.mediaGuid,
      'title': instance.title,
      'guid': instance.guid,
      'resolution_type': instance.resolutionType,
      'color_range_type': instance.colorRangeType,
      'codec_name': instance.codecName,
      'codec_type': instance.codecType,
      'color_range': instance.colorRange,
      'profile': instance.profile,
      'index': instance.index,
      'width': instance.width,
      'height': instance.height,
      'coded_width': instance.codedWidth,
      'coded_height': instance.codedHeight,
      'display_aspect_ratio': instance.displayAspectRatio,
      'pix_fmt': instance.pixFmt,
      'level': instance.level,
      'color_space': instance.colorSpace,
      'color_transfer': instance.colorTransfer,
      'color_primaries': instance.colorPrimaries,
      'duration': instance.duration,
      'dv_profile': instance.dvProfile,
      'refs': instance.refs,
      'r_frame_rate': instance.rFrameRate,
      'avg_frame_rate': instance.avgFrameRate,
      'bits_per_raw_sample': instance.bitsPerRawSample,
      'bps': instance.bps,
      'progressive': instance.progressive,
      'bit_depth': instance.bitDepth,
      'wrapper': instance.wrapper,
      'create_time': instance.createTime,
      'update_time': instance.updateTime,
      'rotation': instance.rotation,
      'ext1': instance.ext1,
      'is_bluray': instance.isBluray,
    };

AudioStream _$AudioStreamFromJson(Map<String, dynamic> json) => AudioStream(
      mediaGuid: json['media_guid'] as String,
      title: json['title'] as String,
      guid: json['guid'] as String,
      audioType: json['audio_type'] as String,
      codecName: json['codec_name'] as String,
      codecType: json['codec_type'] as String,
      language: json['language'] as String,
      channels: (json['channels'] as num).toInt(),
      profile: json['profile'] as String,
      sampleRate: json['sample_rate'] as String,
      isDefault: (json['is_default'] as num).toInt(),
      channelLayout: json['channel_layout'] as String,
      duration: (json['duration'] as num).toInt(),
      index: (json['index'] as num).toInt(),
      bitsPerRawSample: json['bits_per_raw_sample'] as String,
      bps: (json['bps'] as num).toInt(),
      createTime: (json['create_time'] as num).toInt(),
      updateTime: (json['update_time'] as num).toInt(),
      isFake: json['is_fake'] as bool,
    );

Map<String, dynamic> _$AudioStreamToJson(AudioStream instance) =>
    <String, dynamic>{
      'media_guid': instance.mediaGuid,
      'title': instance.title,
      'guid': instance.guid,
      'audio_type': instance.audioType,
      'codec_name': instance.codecName,
      'codec_type': instance.codecType,
      'language': instance.language,
      'channels': instance.channels,
      'profile': instance.profile,
      'sample_rate': instance.sampleRate,
      'is_default': instance.isDefault,
      'channel_layout': instance.channelLayout,
      'duration': instance.duration,
      'index': instance.index,
      'bits_per_raw_sample': instance.bitsPerRawSample,
      'bps': instance.bps,
      'create_time': instance.createTime,
      'update_time': instance.updateTime,
      'is_fake': instance.isFake,
    };

SubtitleStream _$SubtitleStreamFromJson(Map<String, dynamic> json) =>
    SubtitleStream(
      mediaGuid: json['media_guid'] as String,
      title: json['title'] as String,
      guid: json['guid'] as String,
      codecName: json['codec_name'] as String,
      codecType: json['codec_type'] as String,
      language: json['language'] as String,
      forced: (json['forced'] as num).toInt(),
      index: (json['index'] as num).toInt(),
      isDefault: (json['is_default'] as num).toInt(),
      isExternal: (json['is_external'] as num).toInt(),
      format: json['format'] as String,
      trimId: json['trim_id'] as String,
      sourceId: json['source_id'] as String,
      source: json['Source'] as String,
      createTime: (json['create_time'] as num).toInt(),
      updateTime: (json['update_time'] as num).toInt(),
      extraFile: (json['extra_file'] as num).toInt(),
      isBitmap: (json['is_bitmap'] as num).toInt(),
      fileSize: (json['file_size'] as num).toInt(),
    );

Map<String, dynamic> _$SubtitleStreamToJson(SubtitleStream instance) =>
    <String, dynamic>{
      'media_guid': instance.mediaGuid,
      'title': instance.title,
      'guid': instance.guid,
      'codec_name': instance.codecName,
      'codec_type': instance.codecType,
      'language': instance.language,
      'forced': instance.forced,
      'index': instance.index,
      'is_default': instance.isDefault,
      'is_external': instance.isExternal,
      'format': instance.format,
      'trim_id': instance.trimId,
      'source_id': instance.sourceId,
      'Source': instance.source,
      'create_time': instance.createTime,
      'update_time': instance.updateTime,
      'extra_file': instance.extraFile,
      'is_bitmap': instance.isBitmap,
      'file_size': instance.fileSize,
    };

StreamListResponse _$StreamListResponseFromJson(Map<String, dynamic> json) =>
    StreamListResponse(
      files: (json['files'] as List<dynamic>?)
          ?.map((e) => FileInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      videoStreams: (json['video_streams'] as List<dynamic>)
          .map((e) => VideoStream.fromJson(e as Map<String, dynamic>))
          .toList(),
      audioStreams: (json['audio_streams'] as List<dynamic>)
          .map((e) => AudioStream.fromJson(e as Map<String, dynamic>))
          .toList(),
      subtitleStreams: (json['subtitle_streams'] as List<dynamic>)
          .map((e) => SubtitleStream.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$StreamListResponseToJson(StreamListResponse instance) =>
    <String, dynamic>{
      'files': instance.files,
      'video_streams': instance.videoStreams,
      'audio_streams': instance.audioStreams,
      'subtitle_streams': instance.subtitleStreams,
    };

PlayConfig _$PlayConfigFromJson(Map<String, dynamic> json) => PlayConfig(
      guid: json['guid'] as String?,
      skipOpening: (json['skip_opening'] as num?)?.toInt(),
      skipEnding: (json['skip_ending'] as num?)?.toInt(),
    );

Map<String, dynamic> _$PlayConfigToJson(PlayConfig instance) =>
    <String, dynamic>{
      'guid': instance.guid,
      'skip_opening': instance.skipOpening,
      'skip_ending': instance.skipEnding,
    };

PlayInfoResponse _$PlayInfoResponseFromJson(Map<String, dynamic> json) =>
    PlayInfoResponse(
      grandGuid: json['grand_guid'] as String,
      guid: json['guid'] as String,
      parentGuid: json['parent_guid'] as String,
      playConfig: json['play_config'] == null
          ? null
          : PlayConfig.fromJson(json['play_config'] as Map<String, dynamic>),
      ts: (json['ts'] as num).toInt(),
      type: json['type'] as String,
      videoGuid: json['video_guid'] as String,
      audioGuid: json['audio_guid'] as String,
      subtitleGuid: json['subtitle_guid'] as String,
      mediaGuid: json['media_guid'] as String,
      item: ItemResponse.fromJson(json['item'] as Map<String, dynamic>),
      directLinkAudioIndex: (json['direct_link_audio_index'] as num).toInt(),
      episodeNumber: (json['episode_number'] as num?)?.toInt() ?? 0,
      seasonNumber: (json['season_number'] as num?)?.toInt() ?? 0,
      playItemGuid: json['play_item_guid'] as String? ?? '',
    );

Map<String, dynamic> _$PlayInfoResponseToJson(PlayInfoResponse instance) =>
    <String, dynamic>{
      'grand_guid': instance.grandGuid,
      'guid': instance.guid,
      'parent_guid': instance.parentGuid,
      'play_config': instance.playConfig,
      'ts': instance.ts,
      'type': instance.type,
      'video_guid': instance.videoGuid,
      'audio_guid': instance.audioGuid,
      'subtitle_guid': instance.subtitleGuid,
      'media_guid': instance.mediaGuid,
      'item': instance.item,
      'direct_link_audio_index': instance.directLinkAudioIndex,
      'episode_number': instance.episodeNumber,
      'season_number': instance.seasonNumber,
      'play_item_guid': instance.playItemGuid,
    };

PersonList _$PersonListFromJson(Map<String, dynamic> json) => PersonList(
      itemGuid: json['item_guid'] as String,
      personGuid: json['person_guid'] as String,
      role: json['role'] as String,
      job: json['job'] as String,
      order: (json['order'] as num).toInt(),
      department: json['department'] as String,
      trimId: json['trim_id'] as String,
      imdbId: json['imdb_id'] as String,
      tmdbId: (json['tmdb_id'] as num).toInt(),
      lan: json['lan'] as String,
      name: json['name'] as String,
      originalName: json['original_name'] as String,
      alsoKnowAs: json['also_know_as'] as String,
      biography: json['biography'] as String,
      knownForDepartment: json['known_for_department'] as String,
      profilePath: json['profile_path'] as String,
      gender: (json['gender'] as num).toInt(),
    );

Map<String, dynamic> _$PersonListToJson(PersonList instance) =>
    <String, dynamic>{
      'item_guid': instance.itemGuid,
      'person_guid': instance.personGuid,
      'role': instance.role,
      'job': instance.job,
      'order': instance.order,
      'department': instance.department,
      'trim_id': instance.trimId,
      'imdb_id': instance.imdbId,
      'tmdb_id': instance.tmdbId,
      'lan': instance.lan,
      'name': instance.name,
      'original_name': instance.originalName,
      'also_know_as': instance.alsoKnowAs,
      'biography': instance.biography,
      'known_for_department': instance.knownForDepartment,
      'profile_path': instance.profilePath,
      'gender': instance.gender,
    };

PersonListResponse _$PersonListResponseFromJson(Map<String, dynamic> json) =>
    PersonListResponse(
      list: (json['list'] as List<dynamic>)
          .map((e) => PersonList.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
    );

Map<String, dynamic> _$PersonListResponseToJson(PersonListResponse instance) =>
    <String, dynamic>{
      'list': instance.list,
      'total': instance.total,
    };
