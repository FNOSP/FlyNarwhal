import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../domain/entities/media_type.dart';

import '../../../../data/models/episode_list_response.dart';
import '../../../../data/models/movie_detail_models.dart';
import '../../../../data/models/player_models.dart';
import '../../../../data/storage/preferences_manager.dart';
import '../../../../providers/providers.dart';
import '../services/hls_playlist_resolver.dart';
import '../services/player_service.dart';

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

class HlsPlayLinkResult {
  final String playUri;
  final String playLinkRaw;
  final int effectiveStartMs;

  const HlsPlayLinkResult({
    required this.playUri,
    required this.playLinkRaw,
    required this.effectiveStartMs,
  });
}

class EpisodeContext {
  final List<EpisodeListResponse> episodeList;
  final EpisodeListResponse? currentEpisode;
  final EpisodeListResponse? nextEpisode;

  const EpisodeContext({
    required this.episodeList,
    required this.currentEpisode,
    required this.nextEpisode,
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

  static const Duration _sessionRequestTimeout = Duration(seconds: 15);
  static const Uuid _uuid = Uuid();

  Future<PlayerSessionLoadResult> loadSession(PlayerRouteTarget target) async {
    final baseUrl = _preferencesManager.getBaseUrl() ?? '';
    // Guard each negotiation request so a stalled backend session never leaves
    // the player stuck on the loading indicator forever.
    final playInfo = await _playerService
        .getPlayInfo(
          target.guid,
          mediaGuid: target.mediaGuid,
        )
        .timeout(_sessionRequestTimeout);
    final streamInfo = await _playerService
        .getStreamInfo(
          playInfo.mediaGuid,
          ip: _playerService.getIpHash(_preferencesManager.getToken() ?? ''),
        )
        .timeout(_sessionRequestTimeout);

    final currentVideoStream = streamInfo.videoStream;
    final fileStream = streamInfo.fileStream;
    if (currentVideoStream == null || fileStream == null) {
      throw Exception('Missing video_stream or file_stream');
    }

    final audioStreams = streamInfo.audioStreams ?? [];
    final subtitleStreams = streamInfo.subtitleStreams ?? [];

    // Echo the audio/subtitle streams returned by the play-info endpoint so
    // resume restores the same tracks the backend negotiated last time.
    final currentAudioStream = _selectAudioStream(
      audioStreams: audioStreams,
      requestedAudioGuid: target.audioGuid,
      playInfoAudioGuid: playInfo.audioGuid,
    );
    final currentSubtitleStream = _selectSubtitleStream(
      subtitleStreams: subtitleStreams,
      requestedSubtitleGuid: target.subtitleGuid,
      playInfoSubtitleGuid: playInfo.subtitleGuid,
    );

    final audioGuid =
        target.audioGuid ?? currentAudioStream?.guid ?? playInfo.audioGuid;
    final subtitleGuid = target.subtitleGuid ?? currentSubtitleStream?.guid;

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
      itemGuid: playInfo.item.guid,
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
      playLink: resolved.isDirectLink ? null : resolved.playLinkRaw,
      playRecordLink:
          resolved.isDirectLink ? ensureDirectPlayRecordLink(null) : null,
      isUseDirectLink: resolved.isDirectLink,
      playConfig: playInfo.playConfig,
      streamInfo: streamInfo,
      isEpisode: MediaType.tryParse(playInfo.item.type) == MediaType.episode,
      subhead: buildDisplaySubhead(
        playInfo.item,
        episodeNumber: playInfo.item.episodeNumber,
      ),
    );

    return PlayerSessionLoadResult(
      playInfo: playInfo,
      streamInfo: streamInfo,
      playingInfoCache: playingInfoCache,
      qualities: qualities,
      currentQuality: currentQuality,
      episodeList: const [],
      currentEpisode: null,
      nextEpisode: null,
      audioGuid: audioGuid,
      subtitleGuid: subtitleGuid,
      preparedPlaySource: preparedPlaySource,
      effectiveStartPositionMs: resolved.effectiveStartMs,
    );
  }

  Future<EpisodeContext> loadEpisodeContext({
    required String parentGuid,
    required String currentGuid,
  }) async {
    final episodeList = await _playerService.getEpisodeList(parentGuid);
    final currentEpisode =
        episodeList.where((e) => e.guid == currentGuid).firstOrNull;
    final currentIndex = episodeList.indexWhere((e) => e.guid == currentGuid);
    final nextEpisode =
        currentIndex >= 0 && currentIndex + 1 < episodeList.length
            ? episodeList[currentIndex + 1]
            : null;
    return EpisodeContext(
      episodeList: episodeList,
      currentEpisode: currentEpisode,
      nextEpisode: nextEpisode,
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
    if (_requiresHlsPlayback(videoStream)) {
      return false;
    }
    final originalQuality = qualities.firstOrNull;
    final isOriginalQuality = quality != null &&
        originalQuality != null &&
        quality.resolution == originalQuality.resolution &&
        quality.bitrate == originalQuality.bitrate;
    return isOriginalQuality;
  }

  bool _requiresHlsPlayback(VideoStream videoStream) {
    return videoStream.colorRangeType == 'DolbyVision' &&
        videoStream.dvProfile == 5;
  }

  String ensureDirectPlayRecordLink(String? currentLink) {
    // Reuse the current direct-link record session when possible.
    if (currentLink != null && currentLink.isNotEmpty) {
      return currentLink;
    }
    return _uuid.v4();
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
    // mpv (media_kit) cannot open the backend's "?range=bytes=offset-"
    // query-style direct link; it does not translate the query into a real
    // HTTP Range request, so the stream fails to open. The backend, however,
    // honours the standard HTTP Range header (verified: probing the base URL
    // returns 206 Partial Content). So always hand mpv the plain base URL and
    // let it resume by time via the mpv "start" property + on-demand Range
    // requests, instead of embedding the byte offset in the query string.
    return DirectPlayLinkResult(
      playUri: fullUrl,
      playLinkRaw: controlPlayLink,
      effectiveStartMs: startPositionMs,
    );
  }

  /// Request an HLS transcode play link from the backend. Used as a fallback
  /// when direct-link playback fails (e.g. unsupported container format).
  Future<HlsPlayLinkResult> requestHlsPlayLink({
    required VideoStream videoStream,
    required FileInfo fileStream,
    required String audioGuid,
    required String? subtitleGuid,
    required int startPositionMs,
  }) async {
    final baseUrl = _preferencesManager.getBaseUrl() ?? '';
    final request = createPlayRequest(
      videoStream: videoStream,
      fileStream: fileStream,
      audioGuid: audioGuid,
      subtitleGuid: subtitleGuid,
    );
    final response = await _playerService.playVideo(
      PlayPlayRequest(
        mediaGuid: request.mediaGuid,
        videoGuid: request.videoGuid,
        videoEncoder: request.videoEncoder,
        resolution: videoStream.resolutionType,
        bitrate: videoStream.bps,
        startTimestamp: startPositionMs ~/ 1000,
        audioEncoder: request.audioEncoder,
        audioGuid: request.audioGuid,
        subtitleGuid: request.subtitleGuid,
        channels: request.channels,
        forcedSdr: request.forcedSdr,
      ),
    );
    final playUri = absolutePlayUrl(baseUrl, response.playLink);
    return HlsPlayLinkResult(
      playUri: playUri,
      playLinkRaw: response.playLink,
      effectiveStartMs: startPositionMs,
    );
  }

  String buildDisplaySubhead(
    ItemResponse item, {
    required int episodeNumber,
  }) {
    final season = item.parentTitle;
    final episodeLabel = episodeNumber > 0 ? '第 $episodeNumber 集' : '';
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
    String? playInfoAudioGuid,
  }) {
    if (requestedAudioGuid != null) {
      return audioStreams
          .where((stream) => stream.guid == requestedAudioGuid)
          .firstOrNull;
    }
    // Restore the audio track the backend echoed via play-info first, then
    // fall back to the default-flagged track and finally the first available.
    final echoedAudioStream =
        (playInfoAudioGuid != null && playInfoAudioGuid.isNotEmpty)
            ? audioStreams
                .where((stream) => stream.guid == playInfoAudioGuid)
                .firstOrNull
            : null;
    return echoedAudioStream ??
        audioStreams.where((stream) => stream.isDefault == 1).firstOrNull ??
        audioStreams.firstOrNull;
  }

  SubtitleStream? _selectSubtitleStream({
    required List<SubtitleStream> subtitleStreams,
    required String? requestedSubtitleGuid,
    String? playInfoSubtitleGuid,
  }) {
    if (requestedSubtitleGuid != null) {
      return subtitleStreams
          .where((stream) => stream.guid == requestedSubtitleGuid)
          .firstOrNull;
    }
    // Echo the subtitle track returned by play-info so resume restores the
    // exact subtitle the backend negotiated, instead of guessing by default.
    final echoedSubtitleStream =
        (playInfoSubtitleGuid != null && playInfoSubtitleGuid.isNotEmpty)
            ? subtitleStreams
                .where((stream) => stream.guid == playInfoSubtitleGuid)
                .firstOrNull
            : null;
    return echoedSubtitleStream ??
        subtitleStreams.where((stream) => stream.isDefault == 1).firstOrNull;
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
