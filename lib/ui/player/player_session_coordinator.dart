import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/episode_list_response.dart';
import '../../data/models/movie_detail_models.dart';
import '../../data/models/player_models.dart';
import '../../data/storage/preferences_manager.dart';
import '../../providers/providers.dart';
import 'hls_playlist_resolver.dart';
import 'mp4_parser.dart';
import 'player_service.dart';

class PreparedPlaySource {
  final String playUri;
  final bool useHlsSubtitleOverlay;
  final String? subtitlePlaylistUrl;

  const PreparedPlaySource({
    required this.playUri,
    required this.useHlsSubtitleOverlay,
    this.subtitlePlaylistUrl,
  });
}

class PlayerRouteTarget {
  final String guid;
  final String? mediaGuid;
  final String? audioGuid;
  final String? subtitleGuid;

  const PlayerRouteTarget({
    required this.guid,
    this.mediaGuid,
    this.audioGuid,
    this.subtitleGuid,
  });
}

class PlayerSessionLoadResult {
  final PlayInfoResponse playInfo;
  final StreamResponse streamInfo;
  final PlayingInfoCache playingInfoCache;
  final List<QualityResponse> qualities;
  final QualityResponse? currentQuality;
  final List<EpisodeListResponse> episodeList;
  final EpisodeListResponse? currentEpisode;
  final EpisodeListResponse? nextEpisode;
  final String? audioGuid;
  final String? subtitleGuid;
  final PreparedPlaySource preparedPlaySource;
  final int effectiveStartPositionMs;

  const PlayerSessionLoadResult({
    required this.playInfo,
    required this.streamInfo,
    required this.playingInfoCache,
    required this.qualities,
    required this.currentQuality,
    required this.episodeList,
    required this.currentEpisode,
    required this.nextEpisode,
    required this.audioGuid,
    required this.subtitleGuid,
    required this.preparedPlaySource,
    required this.effectiveStartPositionMs,
  });
}

class PlayerSubtitleRefreshResult {
  final StreamResponse streamInfo;
  final PlayingInfoCache playingInfoCache;
  final SubtitleStream? selectedSubtitle;

  const PlayerSubtitleRefreshResult({
    required this.streamInfo,
    required this.playingInfoCache,
    required this.selectedSubtitle,
  });
}

class _ResolvedPlayLink {
  final String playUri;
  final String playLinkRaw;
  final int effectiveStartMs;
  final bool isDirectLink;

  const _ResolvedPlayLink({
    required this.playUri,
    required this.playLinkRaw,
    required this.effectiveStartMs,
    required this.isDirectLink,
  });
}

class DirectPlayLinkResult {
  final String playUri;
  final String playLinkRaw;
  final int effectiveStartMs;

  const DirectPlayLinkResult({
    required this.playUri,
    required this.playLinkRaw,
    required this.effectiveStartMs,
  });
}

class PlayerSessionCoordinator {
  PlayerSessionCoordinator({
    required PlayerService playerService,
    required PreferencesManager preferencesManager,
    required Dio dio,
  })  : _playerService = playerService,
        _preferencesManager = preferencesManager,
        _dio = dio;

  final PlayerService _playerService;
  final PreferencesManager _preferencesManager;
  final Dio _dio;

  Future<PlayerSessionLoadResult> loadSession(PlayerRouteTarget target) async {
    final baseUrl = _preferencesManager.getBaseUrl() ?? '';
    final playInfo = await _playerService.getPlayInfo(
      target.guid,
      mediaGuid: target.mediaGuid,
    );
    final streamInfo = await _playerService.getStreamInfo(
      playInfo.mediaGuid,
      ip: _playerService.getIpHash(_preferencesManager.getToken() ?? ''),
    );

    final currentVideoStream = streamInfo.videoStream;
    final fileStream = streamInfo.fileStream;
    if (currentVideoStream == null || fileStream == null) {
      throw Exception('Missing video_stream or file_stream');
    }

    final audioStreams = streamInfo.audioStreams ?? [];
    final subtitleStreams = streamInfo.subtitleStreams ?? [];

    final currentAudioStream = _selectAudioStream(
      audioStreams: audioStreams,
      requestedAudioGuid: target.audioGuid,
    );
    final currentSubtitleStream = _selectSubtitleStream(
      subtitleStreams: subtitleStreams,
      requestedSubtitleGuid: target.subtitleGuid,
    );

    final audioGuid =
        target.audioGuid ?? currentAudioStream?.guid ?? playInfo.audioGuid;
    final subtitleGuid = target.subtitleGuid ?? currentSubtitleStream?.guid;
    final episodeList =
        playInfo.item.type == 'Episode' && playInfo.parentGuid.isNotEmpty
            ? await _playerService.getEpisodeList(playInfo.parentGuid)
            : const <EpisodeListResponse>[];
    final currentEpisode =
        episodeList.where((episode) => episode.guid == target.guid).firstOrNull;
    final currentEpisodeIndex =
        episodeList.indexWhere((episode) => episode.guid == target.guid);
    final nextEpisode =
        currentEpisodeIndex >= 0 && currentEpisodeIndex + 1 < episodeList.length
            ? episodeList[currentEpisodeIndex + 1]
            : null;

    final qualities = streamInfo.qualities ?? [];
    final currentQuality = qualities.isNotEmpty ? qualities.first : null;
    final historyMs = playInfo.ts * 1000;

    final resolved = await _resolvePlayLink(
      playInfo: playInfo,
      videoStream: currentVideoStream,
      fileStream: fileStream,
      audioGuid: audioGuid,
      subtitleGuid: subtitleGuid,
      currentQuality: currentQuality,
      qualities: qualities,
      startPositionMs: historyMs,
      baseUrl: baseUrl,
    );
    final preparedPlaySource = await preparePlaySourceForMediaKit(
      playUri: resolved.playUri,
      currentSubtitleStream: currentSubtitleStream,
    );

    final playingInfoCache = PlayingInfoCache(
      itemGuid: target.guid,
      parentGuid: playInfo.parentGuid,
      item: playInfo.item,
      currentFileStream: fileStream,
      currentVideoStream: currentVideoStream,
      currentAudioStream: currentAudioStream,
      currentSubtitleStream: currentSubtitleStream,
      currentQualities: qualities,
      currentQuality: currentQuality,
      currentAudioStreamList: audioStreams,
      currentSubtitleStreamList: subtitleStreams,
      playLink: resolved.playLinkRaw,
      isUseDirectLink: resolved.isDirectLink,
      playConfig: playInfo.playConfig,
      streamInfo: streamInfo,
      isEpisode: playInfo.item.type == 'Episode',
      subhead: buildDisplaySubhead(
        playInfo.item,
        episodeNumber:
            currentEpisode?.episodeNumber ?? playInfo.item.episodeNumber,
      ),
    );

    return PlayerSessionLoadResult(
      playInfo: playInfo,
      streamInfo: streamInfo,
      playingInfoCache: playingInfoCache,
      qualities: qualities,
      currentQuality: currentQuality,
      episodeList: episodeList,
      currentEpisode: currentEpisode,
      nextEpisode: nextEpisode,
      audioGuid: audioGuid,
      subtitleGuid: subtitleGuid,
      preparedPlaySource: preparedPlaySource,
      effectiveStartPositionMs: resolved.effectiveStartMs,
    );
  }

  Future<PlayerSubtitleRefreshResult> refreshSubtitleStreams({
    required PlayingInfoCache cache,
    String? selectedSubtitleGuid,
    String? targetTrimId,
  }) async {
    final videoStream = cache.currentVideoStream;
    if (videoStream == null) {
      throw Exception('Missing current video stream');
    }

    final nextStreamInfo = await _playerService.getStreamInfo(
      videoStream.mediaGuid,
      ip: _playerService.getIpHash(_preferencesManager.getToken() ?? ''),
    );
    final subtitleStreams =
        nextStreamInfo.subtitleStreams ?? const <SubtitleStream>[];
    final currentGuid =
        selectedSubtitleGuid ?? cache.currentSubtitleStream?.guid;

    SubtitleStream? nextSelectedSubtitle;
    if (targetTrimId != null && targetTrimId.isNotEmpty) {
      nextSelectedSubtitle = subtitleStreams
          .where((subtitle) => subtitle.trimId == targetTrimId)
          .firstOrNull;
    }
    nextSelectedSubtitle ??= subtitleStreams
        .where((subtitle) => subtitle.guid == currentGuid)
        .firstOrNull;

    final nextCache = cache.copyWith(
      currentSubtitleStreamList: subtitleStreams,
      currentSubtitleStream: nextSelectedSubtitle,
      streamInfo: nextStreamInfo,
    );

    return PlayerSubtitleRefreshResult(
      streamInfo: nextStreamInfo,
      playingInfoCache: nextCache,
      selectedSubtitle: nextSelectedSubtitle,
    );
  }

  Map<String, String> buildPlayerHeaders() {
    final headers = <String, String>{};
    final cookie = _preferencesManager.getCookie();
    if (cookie != null && cookie.isNotEmpty) {
      headers['Cookie'] = cookie;
    }
    final token = _preferencesManager.getToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = token;
    }
    return headers;
  }

  PlayPlayRequest createPlayRequest({
    required VideoStream videoStream,
    required FileInfo fileStream,
    required String audioGuid,
    required String? subtitleGuid,
  }) {
    return PlayPlayRequest(
      mediaGuid: fileStream.guid,
      videoGuid: videoStream.guid,
      videoEncoder: videoStream.codecName,
      resolution: videoStream.resolutionType,
      bitrate: videoStream.bps,
      startTimestamp: 0,
      audioEncoder: 'aac',
      audioGuid: audioGuid,
      subtitleGuid: subtitleGuid ?? '',
      channels: 2,
      forcedSdr: 0,
    );
  }

  bool supportsDirectLink(
    VideoStream videoStream,
    QualityResponse? quality,
    List<QualityResponse> qualities,
  ) {
    final originalQuality = qualities.firstOrNull;
    final isOriginalQuality = quality != null &&
        originalQuality != null &&
        quality.resolution == originalQuality.resolution &&
        quality.bitrate == originalQuality.bitrate;
    return videoStream.wrapper == 'MP4' && isOriginalQuality;
  }

  String absolutePlayUrl(String baseUrl, String playLink) {
    if (playLink.startsWith('http://') || playLink.startsWith('https://')) {
      return playLink;
    }
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final path = playLink.startsWith('/') ? playLink : '/$playLink';
    return '$base$path';
  }

  bool looksLikeM3u8(String playUri) {
    final uri = Uri.tryParse(playUri);
    if (uri == null) {
      return playUri.contains('.m3u8');
    }
    return uri.path.toLowerCase().contains('.m3u8');
  }

  Future<PreparedPlaySource> preparePlaySourceForMediaKit({
    required String playUri,
    required SubtitleStream? currentSubtitleStream,
  }) async {
    if (!looksLikeM3u8(playUri)) {
      return PreparedPlaySource(
        playUri: playUri,
        useHlsSubtitleOverlay: false,
      );
    }

    final resolver = HlsPlaylistResolver(
      dio: _dio,
      headers: buildPlayerHeaders(),
    );
    final result = await resolver.resolve(
      playUri,
      subtitleStream: currentSubtitleStream,
    );

    // Always resolve HLS masters to the concrete video playlist because
    // media_kit can stall on subtitle-bearing master playlists.
    final useSubtitleOverlay = currentSubtitleStream != null &&
        currentSubtitleStream.isExternal != 1 &&
        result.subtitlePlaylistUrl != null &&
        result.subtitlePlaylistUrl!.isNotEmpty;

    return PreparedPlaySource(
      playUri: result.playUrl,
      useHlsSubtitleOverlay: useSubtitleOverlay,
      subtitlePlaylistUrl:
          useSubtitleOverlay ? result.subtitlePlaylistUrl : null,
    );
  }

  Future<DirectPlayLinkResult> getDirectPlayLink({
    required String mediaGuid,
    required int startPositionMs,
  }) async {
    final baseUrl = _preferencesManager.getBaseUrl() ?? '';
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final controlPlayLink = '/v/api/v1/media/range/$mediaGuid';
    final fullUrl = '$base$controlPlayLink';
    final ts = startPositionMs / 1000.0;
    try {
      final parser = Mp4Parser(_dio);
      final offset = await parser.getOffset(fullUrl, ts);
      if (offset > 0) {
        final rangedPlayLink = '$controlPlayLink?range=bytes=$offset-';
        return DirectPlayLinkResult(
          playUri: '$base$rangedPlayLink',
          playLinkRaw: rangedPlayLink,
          effectiveStartMs: 0,
        );
      }
      return DirectPlayLinkResult(
        playUri: fullUrl,
        playLinkRaw: controlPlayLink,
        effectiveStartMs: startPositionMs,
      );
    } catch (_) {
      return DirectPlayLinkResult(
        playUri: fullUrl,
        playLinkRaw: controlPlayLink,
        effectiveStartMs: startPositionMs,
      );
    }
  }

  String buildDisplaySubhead(
    ItemResponse item, {
    required int episodeNumber,
  }) {
    final season = item.parentTitle;
    final episodeLabel = episodeNumber > 0 ? '第$episodeNumber集' : '';
    final episodeTitle = item.title;
    final parts = <String>[
      if (season.isNotEmpty) season,
      if (episodeLabel.isNotEmpty) episodeLabel,
      if (episodeTitle.isNotEmpty) episodeTitle,
    ];
    return parts.join(' · ');
  }

  AudioStream? _selectAudioStream({
    required List<AudioStream> audioStreams,
    required String? requestedAudioGuid,
  }) {
    if (requestedAudioGuid != null) {
      return audioStreams
          .where((stream) => stream.guid == requestedAudioGuid)
          .firstOrNull;
    }
    return audioStreams.where((stream) => stream.isDefault == 1).firstOrNull ??
        audioStreams.firstOrNull;
  }

  SubtitleStream? _selectSubtitleStream({
    required List<SubtitleStream> subtitleStreams,
    required String? requestedSubtitleGuid,
  }) {
    if (requestedSubtitleGuid != null) {
      return subtitleStreams
          .where((stream) => stream.guid == requestedSubtitleGuid)
          .firstOrNull;
    }
    return subtitleStreams.where((stream) => stream.isDefault == 1).firstOrNull;
  }

  Future<_ResolvedPlayLink> _resolvePlayLink({
    required PlayInfoResponse playInfo,
    required VideoStream videoStream,
    required FileInfo fileStream,
    required String audioGuid,
    required String? subtitleGuid,
    required QualityResponse? currentQuality,
    required List<QualityResponse> qualities,
    required int startPositionMs,
    required String baseUrl,
  }) async {
    if (supportsDirectLink(videoStream, currentQuality, qualities)) {
      final directLink = await getDirectPlayLink(
        mediaGuid: videoStream.mediaGuid,
        startPositionMs: startPositionMs,
      );
      return _ResolvedPlayLink(
        playUri: directLink.playUri,
        playLinkRaw: directLink.playLinkRaw,
        effectiveStartMs: directLink.effectiveStartMs,
        isDirectLink: true,
      );
    }

    try {
      final request = createPlayRequest(
        videoStream: videoStream,
        fileStream: fileStream,
        audioGuid: audioGuid,
        subtitleGuid: subtitleGuid,
      );
      final response = await _playerService.playVideo(request);
      return _ResolvedPlayLink(
        playUri: absolutePlayUrl(baseUrl, response.playLink),
        playLinkRaw: response.playLink,
        effectiveStartMs: startPositionMs,
        isDirectLink: false,
      );
    } catch (error) {
      final message = error.toString();
      if (!message.contains('8192')) {
        rethrow;
      }

      final directLink = await getDirectPlayLink(
        mediaGuid: playInfo.mediaGuid,
        startPositionMs: startPositionMs,
      );
      return _ResolvedPlayLink(
        playUri: directLink.playUri,
        playLinkRaw: directLink.playLinkRaw,
        effectiveStartMs: directLink.effectiveStartMs,
        isDirectLink: false,
      );
    }
  }
}

final playerSessionCoordinatorProvider =
    Provider<PlayerSessionCoordinator>((ref) {
  return PlayerSessionCoordinator(
    playerService: ref.watch(playerServiceProvider),
    preferencesManager: ref.watch(preferencesManagerProvider),
    dio: ref.watch(dioClientProvider).dio,
  );
});
