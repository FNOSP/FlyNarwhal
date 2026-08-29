import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/log/app_talker.dart';
import '../../../../domain/entities/media_type.dart';

import '../../../../data/models/episode_list_response.dart';
import '../../../../data/models/movie_detail_models.dart';
import '../../../../data/models/player_models.dart';
import '../../../../data/storage/player_settings_store.dart';
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
  final String? userGuid;

  const PlayerRouteTarget({
    required this.guid,
    this.mediaGuid,
    this.audioGuid,
    this.subtitleGuid,
    this.userGuid,
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
    required PlayerSettingsManager playerSettingsManager,
    required Dio dio,
  })  : _playerService = playerService,
        _preferencesManager = preferencesManager,
        _playerSettingsManager = playerSettingsManager,
        _dio = dio;

  final PlayerService _playerService;
  final PreferencesManager _preferencesManager;
  final PlayerSettingsManager _playerSettingsManager;
  final Dio _dio;

  // Advanced playback settings (mirror the web player's 高级设置): force H.264
  // transcoding and force HDR→SDR tone mapping on the play request.
  bool forceH264 = false;
  bool forceSdrColor = false;

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
    final historyMs = playInfo.ts * 1000;

    // Cloud-storage (网盘) media with direct-link qualities takes a dedicated
    // session path mirroring the web player: the quality list is the CDN
    // direct-link list (原画/流畅 …) selected by index, and the play mode
    // (网盘直连播放 vs NAS 代理播放) is a persisted per-user choice.
    if (streamInfo.isCloudDirectMedia) {
      return _loadCloudSession(
        playInfo: playInfo,
        streamInfo: streamInfo,
        target: target,
        currentVideoStream: currentVideoStream,
        fileStream: fileStream,
        audioStreams: audioStreams,
        subtitleStreams: subtitleStreams,
        currentAudioStream: currentAudioStream,
        currentSubtitleStream: currentSubtitleStream,
        audioGuid: audioGuid,
        subtitleGuid: subtitleGuid,
        transcodeQualities: qualities,
        startPositionMs: historyMs,
        baseUrl: baseUrl,
      );
    }

    // Restore the previously saved quality using the KMP matching strategy:
    // exact match first, then resolution-only fallback, then original quality.
    final currentQuality = initializeQuality(
      qualities,
      userGuid: target.userGuid,
    );

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

  Future<PlayerSessionLoadResult> _loadCloudSession({
    required PlayInfoResponse playInfo,
    required StreamResponse streamInfo,
    required PlayerRouteTarget target,
    required VideoStream currentVideoStream,
    required FileInfo fileStream,
    required List<AudioStream> audioStreams,
    required List<SubtitleStream> subtitleStreams,
    required AudioStream? currentAudioStream,
    required SubtitleStream? currentSubtitleStream,
    required String audioGuid,
    required String? subtitleGuid,
    required List<QualityResponse> transcodeQualities,
    required int startPositionMs,
    required String baseUrl,
  }) async {
    final directQualities = streamInfo.directLinkQualities!;
    final cloudType = streamInfo.cloudStorageInfo?.cloudStorageType;
    final savedMode =
        _playerSettingsManager.getCloudPlayMode(cloudType, target.userGuid);
    final useDirectLink = savedMode != 'proxy' && !transcodeForced;

    if (useDirectLink) {
      return _loadCloudDirectSession(
        playInfo: playInfo,
        streamInfo: streamInfo,
        currentVideoStream: currentVideoStream,
        fileStream: fileStream,
        audioStreams: audioStreams,
        subtitleStreams: subtitleStreams,
        currentAudioStream: currentAudioStream,
        currentSubtitleStream: currentSubtitleStream,
        audioGuid: audioGuid,
        subtitleGuid: subtitleGuid,
        directQualities: directQualities,
        startPositionMs: startPositionMs,
        userGuid: target.userGuid,
      );
    }

    // NAS 代理播放: a regular transcode session (play/play + media/p), using
    // the server transcode quality list instead of the direct-link list.
    final currentQuality = initializeQuality(
      transcodeQualities,
      userGuid: target.userGuid,
    );
    // Spinning up a transcode for a huge cloud file (e.g. a 24 GB 4K remux)
    // can take well past the client's 10 s receive timeout; extend it for
    // this one negotiation.
    final previousReceiveTimeout = _dio.options.receiveTimeout;
    _dio.options.receiveTimeout = const Duration(seconds: 60);
    try {
      return await _loadCloudProxySession(
        playInfo: playInfo,
        streamInfo: streamInfo,
        currentVideoStream: currentVideoStream,
        fileStream: fileStream,
        audioStreams: audioStreams,
        subtitleStreams: subtitleStreams,
        currentAudioStream: currentAudioStream,
        currentSubtitleStream: currentSubtitleStream,
        audioGuid: audioGuid,
        subtitleGuid: subtitleGuid,
        transcodeQualities: transcodeQualities,
        currentQuality: currentQuality,
        directQualities: directQualities,
        startPositionMs: startPositionMs,
        baseUrl: baseUrl,
      );
    } catch (error) {
      // The NAS could not start a transcode session for this cloud file
      // (server-side failure or timeout). Mirror the web player: surface the
      // proxy error guard and let the user retry or switch to 网盘直连播放 —
      // never auto-fallback or rewrite the persisted play-mode preference.
      AppTalker.warning('Player', 'cloud proxy session failed: $error');
      return _cloudProxyFailureResult(
        playInfo: playInfo,
        streamInfo: streamInfo,
        currentVideoStream: currentVideoStream,
        fileStream: fileStream,
        audioStreams: audioStreams,
        subtitleStreams: subtitleStreams,
        currentAudioStream: currentAudioStream,
        currentSubtitleStream: currentSubtitleStream,
        audioGuid: audioGuid,
        subtitleGuid: subtitleGuid,
        transcodeQualities: transcodeQualities,
        currentQuality: currentQuality,
        directQualities: directQualities,
        startPositionMs: startPositionMs,
      );
    } finally {
      _dio.options.receiveTimeout = previousReceiveTimeout;
    }
  }

  Future<PlayerSessionLoadResult> _loadCloudDirectSession({
    required PlayInfoResponse playInfo,
    required StreamResponse streamInfo,
    required VideoStream currentVideoStream,
    required FileInfo fileStream,
    required List<AudioStream> audioStreams,
    required List<SubtitleStream> subtitleStreams,
    required AudioStream? currentAudioStream,
    required SubtitleStream? currentSubtitleStream,
    required String audioGuid,
    required String? subtitleGuid,
    required List<DirectLinkQuality> directQualities,
    required int startPositionMs,
    String? userGuid,
  }) async {
    final cloudStorageType = streamInfo.cloudStorageInfo?.cloudStorageType;
    final filtered = filterDirectLinkQualities(
      qualities: directQualities,
      cloudStorageType: cloudStorageType,
    );
    final visibleQualities = filtered.qualities.isNotEmpty
        ? filtered.qualities
        : directQualities;
    final visibleOriginalIndices = filtered.originalIndices.isNotEmpty
        ? filtered.originalIndices
        : List<int>.generate(directQualities.length, (i) => i);
    final visibleIndex = defaultDirectLinkQualityIndex(
      visibleQualities,
      savedResolution: _playerSettingsManager
          .getNetdiskQuality(userGuid: userGuid)
          ?.resolution,
    );
    final originalIndex = visibleOriginalIndices[visibleIndex];
    final currentQuality = visibleQualities[visibleIndex].toQualityResponse();
    final directLink = await getDirectPlayLink(
      mediaGuid: currentVideoStream.mediaGuid,
      startPositionMs: startPositionMs,
      directLinkQualityIndex: originalIndex,
      directLinkQualities: directQualities,
      cloudStorageType: cloudStorageType,
      directLinkAudioIndex: playInfo.directLinkAudioIndex,
    );
    final preparedPlaySource = await preparePlaySourceForMediaKit(
      playUri: directLink.playUri,
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
      currentQualities:
          visibleQualities.map((q) => q.toQualityResponse()).toList(),
      currentQuality: currentQuality,
      directLinkQualities: directQualities,
      directLinkQualityIndex: originalIndex,
      currentAudioStreamList: audioStreams,
      currentSubtitleStreamList: subtitleStreams,
      playLink: null,
      playRecordLink: ensureDirectPlayRecordLink(null),
      isUseDirectLink: true,
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
      qualities: playingInfoCache.currentQualities,
      currentQuality: currentQuality,
      episodeList: const [],
      currentEpisode: null,
      nextEpisode: null,
      audioGuid: audioGuid,
      subtitleGuid: subtitleGuid,
      preparedPlaySource: preparedPlaySource,
      effectiveStartPositionMs: directLink.effectiveStartMs,
    );
  }

  Future<PlayerSessionLoadResult> _loadCloudProxySession({
    required PlayInfoResponse playInfo,
    required StreamResponse streamInfo,
    required VideoStream currentVideoStream,
    required FileInfo fileStream,
    required List<AudioStream> audioStreams,
    required List<SubtitleStream> subtitleStreams,
    required AudioStream? currentAudioStream,
    required SubtitleStream? currentSubtitleStream,
    required String audioGuid,
    required String? subtitleGuid,
    required List<QualityResponse> transcodeQualities,
    required QualityResponse? currentQuality,
    required List<DirectLinkQuality> directQualities,
    required int startPositionMs,
    required String baseUrl,
  }) async {
    final resolved = await _resolvePlayLink(
      playInfo: playInfo,
      videoStream: currentVideoStream,
      fileStream: fileStream,
      audioGuid: audioGuid,
      subtitleGuid: subtitleGuid,
      currentQuality: currentQuality,
      qualities: transcodeQualities,
      startPositionMs: startPositionMs,
      baseUrl: baseUrl,
      forceTranscode: true,
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
      currentQualities: transcodeQualities,
      currentQuality: currentQuality,
      directLinkQualities: directQualities,
      directLinkQualityIndex: null,
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
      qualities: transcodeQualities,
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

  /// Proxy-mode result for a failed initial cloud proxy negotiation. The
  /// empty play URI makes the player's open/verify step fail so the proxy
  /// error guard is shown; the direct-link qualities stay attached so the
  /// guard can offer 网盘直连播放.
  PlayerSessionLoadResult _cloudProxyFailureResult({
    required PlayInfoResponse playInfo,
    required StreamResponse streamInfo,
    required VideoStream currentVideoStream,
    required FileInfo fileStream,
    required List<AudioStream> audioStreams,
    required List<SubtitleStream> subtitleStreams,
    required AudioStream? currentAudioStream,
    required SubtitleStream? currentSubtitleStream,
    required String audioGuid,
    required String? subtitleGuid,
    required List<QualityResponse> transcodeQualities,
    required QualityResponse? currentQuality,
    required List<DirectLinkQuality> directQualities,
    required int startPositionMs,
  }) {
    final playingInfoCache = PlayingInfoCache(
      itemGuid: playInfo.item.guid,
      parentGuid: playInfo.parentGuid,
      item: playInfo.item,
      currentFileStream: fileStream,
      currentVideoStream: currentVideoStream,
      currentAudioStream: currentAudioStream,
      currentSubtitleStream: currentSubtitleStream,
      currentQualities: transcodeQualities,
      currentQuality: currentQuality,
      directLinkQualities: directQualities,
      directLinkQualityIndex: null,
      currentAudioStreamList: audioStreams,
      currentSubtitleStreamList: subtitleStreams,
      playLink: null,
      playRecordLink: null,
      isUseDirectLink: false,
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
      qualities: transcodeQualities,
      currentQuality: currentQuality,
      episodeList: const [],
      currentEpisode: null,
      nextEpisode: null,
      audioGuid: audioGuid,
      subtitleGuid: subtitleGuid,
      preparedPlaySource: const PreparedPlaySource(
        playUri: '',
        useHlsSubtitleOverlay: false,
      ),
      effectiveStartPositionMs: startPositionMs,
    );
  }

  /// Default direct-link quality index, mirroring the web player: prefer the
  /// previously saved netdisk resolution; otherwise pick the second non-m3u8
  /// quality when more than one exists (直连原画不可用时默认选择「流畅」),
  /// falling back to the first one.
  static int defaultDirectLinkQualityIndex(
    List<DirectLinkQuality> qualities, {
    String? savedResolution,
  }) {
    if (qualities.isEmpty) return 0;
    final nonM3u8 =
        qualities.where((q) => !q.isM3u8 && q.resolution.isNotEmpty).toList();
    if (savedResolution != null && savedResolution.isNotEmpty) {
      final savedIndex = nonM3u8.indexWhere(
        (q) => q.resolution == savedResolution,
      );
      if (savedIndex >= 0) {
        return qualities.indexOf(nonM3u8[savedIndex]);
      }
    }
    final defaultNonM3u8Index = nonM3u8.length > 1 ? 1 : 0;
    return nonM3u8.isEmpty ? 0 : qualities.indexOf(nonM3u8[defaultNonM3u8Index]);
  }

  /// Filters the direct-link quality list by cloud provider, mirroring the web
  /// player's `Ape`: 123/Baidu hide m3u8 qualities; 115 and others keep them.
  /// Returns the visible qualities together with their original indices in the
  /// unfiltered list so callers can map back to the stored list.
  static ({List<DirectLinkQuality> qualities, List<int> originalIndices})
      filterDirectLinkQualities({
    required List<DirectLinkQuality> qualities,
    required int? cloudStorageType,
  }) {
    final visible = <DirectLinkQuality>[];
    final originalIndices = <int>[];
    for (var i = 0; i < qualities.length; i++) {
      final q = qualities[i];
      // OneTwoThreePan (5) and BaiduPan (1) filter out m3u8 entries.
      if (q.isM3u8 &&
          (cloudStorageType == 1 || cloudStorageType == 5)) {
        continue;
      }
      visible.add(q);
      originalIndices.add(i);
    }
    return (qualities: visible, originalIndices: originalIndices);
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

    final nextSelectedSubtitle = subtitleStreams
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
    QualityResponse? quality,
    int startTimestamp = 0,
  }) {
    // Web logic: force h264 when the toggle is on or the source uses the
    // HEVC "rext" profile; forced_sdr only applies to non-SDR sources.
    final isSdrSource = videoStream.colorRangeType.toLowerCase() == 'sdr';
    final useH264 = forceH264 || videoStream.profile.toLowerCase() == 'rext';
    return PlayPlayRequest(
      mediaGuid: fileStream.guid,
      videoGuid: videoStream.guid,
      videoEncoder: useH264 ? 'h264' : videoStream.codecName,
      resolution: quality?.resolution ?? videoStream.resolutionType,
      bitrate: quality?.bitrate ?? videoStream.bps,
      startTimestamp: startTimestamp,
      audioEncoder: 'aac',
      audioGuid: audioGuid,
      subtitleGuid: subtitleGuid ?? '',
      channels: 2,
      forcedSdr: !isSdrSource && forceSdrColor ? 1 : 0,
    );
  }

  /// Whether the current force settings require a server transcode session.
  /// While either toggle is on the direct link must be skipped; once both
  /// are off a previously direct-link session can be restored.
  bool get transcodeForced => forceH264 || forceSdrColor;

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

  QualityResponse? initializeQuality(
    List<QualityResponse> qualities, {
    String? userGuid,
  }) {
    if (qualities.isEmpty) {
      return null;
    }

    final savedQuality = _playerSettingsManager.getQuality(userGuid: userGuid);
    QualityResponse? result;
    if (savedQuality != null) {
      result = qualities
          .where(
            (quality) =>
                quality.resolution == savedQuality.resolution &&
                (savedQuality.bitrate == null ||
                    quality.bitrate == savedQuality.bitrate),
          )
          .firstOrNull;
      if (result == null) {
        // Keep the selected resolution when the exact bitrate is unavailable.
        final sameResolution = qualities
            .where((quality) => quality.resolution == savedQuality.resolution)
            .toList()
          ..sort((left, right) => right.bitrate.compareTo(left.bitrate));
        result = sameResolution.firstOrNull;
      }
    }
    return result ?? qualities.firstOrNull;
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
    int? directLinkQualityIndex,
    List<DirectLinkQuality>? directLinkQualities,
    int? cloudStorageType,
    int? directLinkAudioIndex,
  }) async {
    final baseUrl = _preferencesManager.getBaseUrl() ?? '';
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    // When a specific direct-link quality is selected, mirror the web
    // player's provider-specific URL shape.
    if (directLinkQualities != null &&
        directLinkQualityIndex != null &&
        directLinkQualityIndex >= 0 &&
        directLinkQualityIndex < directLinkQualities.length) {
      final quality = directLinkQualities[directLinkQualityIndex];

      // Aliyun Pan (2) and 123 Pan (5): play the raw CDN URL directly.
      if (cloudStorageType == 2 || cloudStorageType == 5) {
        return DirectPlayLinkResult(
          playUri: quality.url,
          playLinkRaw: quality.url,
          effectiveStartMs: startPositionMs,
        );
      }

      // STRM (9001): the NAS already resolved the .strm content into a
      // playable URL when serving /stream, so play it directly (mirrors the
      // web player, which never routes STRM through the media/range proxy).
      if (cloudStorageType == CloudStorageInfo.strmCloudStorageType) {
        return DirectPlayLinkResult(
          playUri: quality.url,
          playLinkRaw: quality.url,
          effectiveStartMs: startPositionMs,
        );
      }

      // 115 Pan (3): m3u8 qualities are proxied through /wp/m3u8 with the
      // selected audio track appended; non-m3u8 uses the raw CDN URL.
      if (cloudStorageType == 3) {
        if (quality.isM3u8) {
          final proxiedUrl = _buildOneOneFiveM3u8Url(
            qualityUrl: quality.url,
            directLinkAudioIndex: directLinkAudioIndex,
            base: base,
          );
          return DirectPlayLinkResult(
            playUri: proxiedUrl,
            playLinkRaw: proxiedUrl,
            effectiveStartMs: startPositionMs,
          );
        }
        return DirectPlayLinkResult(
          playUri: quality.url,
          playLinkRaw: quality.url,
          effectiveStartMs: startPositionMs,
        );
      }
    }

    // Baidu Pan (1), Quark Pan (4) and fallbacks: use the NAS proxy with the
    // quality index so the server selects the matching CDN link.
    final controlPlayLink = '/v/api/v1/media/range/$mediaGuid';
    final qualityQuery = directLinkQualityIndex != null
        ? '?direct_link_quality_index=$directLinkQualityIndex'
        : '';
    final fullUrl = '$base$controlPlayLink$qualityQuery';
    // mpv (media_kit) cannot open the backend's "?range=bytes=offset-"
    // query-style direct link; it does not translate the query into a real
    // HTTP Range request, so the stream fails to open. The backend, however,
    // honours the standard HTTP Range header (verified: probing the base URL
    // returns 206 Partial Content). So always hand mpv the plain base URL and
    // let it resume by time via the mpv "start" property + on-demand Range
    // requests, instead of embedding the byte offset in the query string.
    // The direct_link_quality_index query is different: the backend selects
    // the matching CDN link server-side and still serves standard ranges, so
    // it is safe to keep (mirrors the web player's URL shape).
    return DirectPlayLinkResult(
      playUri: fullUrl,
      playLinkRaw: controlPlayLink,
      effectiveStartMs: startPositionMs,
    );
  }

  /// Builds the /wp/m3u8 proxy URL for 115 Pan m3u8 qualities.
  /// Mirrors the web player's R2.getM3u8Url(): appends the selected
  /// audio_track to the original m3u8 URL and encodes it into originalUrl.
  String _buildOneOneFiveM3u8Url({
    required String qualityUrl,
    required int? directLinkAudioIndex,
    required String base,
  }) {
    final originalUri = Uri.parse(qualityUrl);
    final Map<String, String> queryParams = {};
    if (directLinkAudioIndex != null && directLinkAudioIndex >= 0) {
      queryParams['audio_track'] = directLinkAudioIndex.toString();
    }
    final proxiedUri = originalUri.replace(
      queryParameters: {
        ...originalUri.queryParameters,
        ...queryParams,
      },
    );
    final encoded = Uri.encodeComponent(proxiedUri.toString());
    return '$base/v/api/v1/wp/m3u8?originalUrl=$encoded';
  }

  /// Request an HLS transcode play link from the backend. Used as a fallback
  /// when direct-link playback fails (e.g. unsupported container format).
  Future<HlsPlayLinkResult> requestHlsPlayLink({
    required VideoStream videoStream,
    required FileInfo fileStream,
    required String audioGuid,
    required String? subtitleGuid,
    required int startPositionMs,
    QualityResponse? quality,
  }) async {
    final baseUrl = _preferencesManager.getBaseUrl() ?? '';
    final request = createPlayRequest(
      videoStream: videoStream,
      fileStream: fileStream,
      audioGuid: audioGuid,
      subtitleGuid: subtitleGuid,
      quality: quality,
      startTimestamp: startPositionMs ~/ 1000,
    );
    final response = await _playerService.playVideo(
      request,
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
    bool forceTranscode = false,
  }) async {
    // Mirrors the web player: forcing H.264/SDR requires a transcode session,
    // so the direct link must be skipped while either setting is on. Cloud
    // proxy sessions also always go through play/play (the plain direct link
    // without a quality index would stream the wrong CDN file).
    if (!forceTranscode &&
        !transcodeForced &&
        supportsDirectLink(videoStream, currentQuality, qualities)) {
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
        quality: currentQuality,
        startTimestamp: startPositionMs ~/ 1000,
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
    playerSettingsManager: ref.watch(playerSettingsManagerProvider),
    dio: ref.watch(dioClientProvider).dio,
  );
});
