import 'dart:async';
import 'package:dio/dio.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart' hide DragToMoveArea;
import '../../../data/models/base_response.dart';
import '../../../data/models/episode_list_response.dart';
import '../../../data/models/player_models.dart';
import '../../../data/models/movie_detail_models.dart';
import '../../../providers/providers.dart';
import '../../player/mp4_parser.dart';
import '../../player/player_service.dart';
import '../../player/widgets/episode_selection_flyout.dart';
import '../../player/widgets/video_player_progress_bar.dart';
import '../../player/widgets/speed_control_flyout.dart';
import '../../player/widgets/quality_control_flyout.dart';
import '../../player/widgets/volume_control.dart';
import '../../player/widgets/fullscreen_control.dart';
import '../../player/widgets/next_episode_preview_flyout.dart';
import '../../player/widgets/player_action_button.dart';
import '../../player/widgets/player_settings_menu.dart';
import '../../player/widgets/subtitle_control_flyout.dart';
import '../../widgets/toast.dart';
import '../../widgets/window_caption.dart';

enum _PlayerFlyoutType { speed, episode, quality, subtitle }

class PlayerScreen extends ConsumerStatefulWidget {
  final String guid;
  final String? mediaGuid;
  final String? audioGuid;
  final String? subtitleGuid;

  const PlayerScreen({
    super.key,
    required this.guid,
    this.mediaGuid,
    this.audioGuid,
    this.subtitleGuid,
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  static const int _controlFlyoutOffset = 15;
  static const double _controlFlyoutSpacing = 12;

  late final ToastManager _toastManager;
  Player? _player;
  VideoController? _videoController;
  bool _isInitialized = false;
  bool _isLoading = true;
  bool _isUiVisible = true;
  bool _isFullscreen = false;
  bool _isSeeking = false;
  int _currentPosition = 0;
  int _duration = 0;
  double _volume = 1.0;
  double _speed = 1.0;
  List<QualityResponse> _qualities = [];
  QualityResponse? _currentQuality;
  String _currentResolution = '';
  int? _currentBitrate;
  PlayingInfoCache? _playingInfoCache;
  PlayInfoResponse? _playInfo;
  StreamResponse? _streamInfo;
  Timer? _hideUiTimer;
  Timer? _playRecordTimer;
  int _lastRecordedPosition = 0;
  int _pendingInitialResumeMs = 0;
  bool _initialResumeApplied = false;

  // Hover states
  bool _isProgressBarHovered = false;
  bool _isBottomControlAreaHovered = false;
  bool _isSpeedControlHovered = false;
  bool _isVolumeControlHovered = false;
  bool _isQualityControlHovered = false;
  bool _isSettingsMenuHovered = false;
  bool _isSubtitleControlHovered = false;
  bool _isEpisodeControlHovered = false;
  bool _isNextEpisodeHovered = false;
  bool _isDanmakuControlHovered = false;
  bool _isDanmakuSettingsHovered = false;
  bool _isPipControlHovered = false;
  _PlayerFlyoutType? _activeFlyout;
  bool _isDanmakuVisible = true;
  bool _isAutoPlayEnabled = true;
  String? _selectedAudioGuid;
  String? _selectedSubtitleGuid;
  List<EpisodeListResponse> _episodeList = [];
  EpisodeListResponse? _currentEpisode;
  EpisodeListResponse? _nextEpisode;

  @override
  void initState() {
    super.initState();
    _toastManager = ToastManager();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _player = Player();
    _videoController = VideoController(_player!);

    await _loadAndPlayMedia();
  }

  void _resetInitialResumeState(int positionMs) {
    _pendingInitialResumeMs = positionMs;
    _initialResumeApplied = positionMs <= 0;
  }

  Future<void> _openMediaWithResume({
    required String playUri,
    required int startPositionMs,
    bool isInitialPlayback = false,
  }) async {
    final player = _player;
    if (player == null) return;

    final headers = _buildPlayerHeaders();
    await player.open(
      Media(
        playUri,
        httpHeaders: headers.isEmpty ? null : headers,
      ),
    );

    if (isInitialPlayback) {
      _resetInitialResumeState(startPositionMs);
    }

    await _applyResumePosition(startPositionMs,
        isInitialPlayback: isInitialPlayback);
  }

  Future<void> _applyResumePosition(
    int startPositionMs, {
    bool isInitialPlayback = false,
  }) async {
    final player = _player;
    if (player == null || startPositionMs <= 0) {
      if (isInitialPlayback) {
        _pendingInitialResumeMs = 0;
        _initialResumeApplied = true;
      }
      return;
    }

    const attemptDelays = <Duration>[
      Duration(milliseconds: 300),
      Duration(milliseconds: 600),
      Duration(milliseconds: 900),
    ];
    final target = Duration(milliseconds: startPositionMs);

    for (final delay in attemptDelays) {
      await Future<void>.delayed(delay);
      await player.seek(target);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final currentPosition = player.state.position.inMilliseconds;
      final applied = currentPosition >= startPositionMs - 1500;
      if (applied) {
        if (isInitialPlayback) {
          _pendingInitialResumeMs = 0;
          _initialResumeApplied = true;
        }
        return;
      }
    }

    if (isInitialPlayback) {
      _pendingInitialResumeMs = startPositionMs;
      _initialResumeApplied = false;
    }
  }

  Future<void> _ensureInitialResumeApplied() async {
    if (_initialResumeApplied || _pendingInitialResumeMs <= 0) {
      return;
    }
    await _applyResumePosition(
      _pendingInitialResumeMs,
      isInitialPlayback: true,
    );
  }

  Map<String, String> _buildPlayerHeaders() {
    final prefs = ref.read(preferencesManagerProvider);
    final headers = <String, String>{};
    final cookie = prefs.getCookie();
    if (cookie != null && cookie.isNotEmpty) {
      headers['Cookie'] = cookie;
    }
    final token = prefs.getToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = token;
    }
    return headers;
  }

  String _absolutePlayUrl(String baseUrl, String playLink) {
    if (playLink.startsWith('http://') || playLink.startsWith('https://')) {
      return playLink;
    }
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final path = playLink.startsWith('/') ? playLink : '/$playLink';
    return '$base$path';
  }

  PlayPlayRequest _createPlayRequest({
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

  Future<
      ({
        String playUri,
        String? playLinkRaw,
        int effectiveStartMs,
        bool isDirectLink,
      })> _resolvePlayLink({
    required PlayInfoResponse playInfo,
    required VideoStream videoStream,
    required FileInfo fileStream,
    required String audioGuid,
    required String? subtitleGuid,
    required List<QualityResponse> qualities,
    required int startPositionMs,
    required String baseUrl,
    required PlayerService playerService,
    required Dio dio,
  }) async {
    final originalQuality = qualities.isNotEmpty ? qualities.first : null;
    final isOriginalQuality = _currentQuality != null &&
        originalQuality != null &&
        _currentQuality!.resolution == originalQuality.resolution &&
        _currentQuality!.bitrate == originalQuality.bitrate;

    final useDirectLink = videoStream.wrapper == 'MP4' && isOriginalQuality;

    if (useDirectLink) {
      final r = await _getDirectPlayLink(
        mediaGuid: videoStream.mediaGuid,
        startPositionMs: startPositionMs,
        baseUrl: baseUrl,
        dio: dio,
      );
      return (
        playUri: r.url,
        playLinkRaw: null,
        effectiveStartMs: r.effectiveStartMs,
        isDirectLink: true,
      );
    }

    try {
      final request = _createPlayRequest(
        videoStream: videoStream,
        fileStream: fileStream,
        audioGuid: audioGuid,
        subtitleGuid: subtitleGuid,
      );
      final resp = await playerService.playVideo(request);
      final raw = resp.playLink;
      final uri = _absolutePlayUrl(baseUrl, raw);
      return (
        playUri: uri,
        playLinkRaw: raw,
        effectiveStartMs: startPositionMs,
        isDirectLink: false,
      );
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('8192')) {
        final r = await _getDirectPlayLink(
          mediaGuid: playInfo.mediaGuid,
          startPositionMs: startPositionMs,
          baseUrl: baseUrl,
          dio: dio,
        );
        return (
          playUri: r.url,
          playLinkRaw: null,
          effectiveStartMs: r.effectiveStartMs,
          isDirectLink: false,
        );
      }
      rethrow;
    }
  }

  Future<({String url, int effectiveStartMs})> _getDirectPlayLink({
    required String mediaGuid,
    required int startPositionMs,
    required String baseUrl,
    required Dio dio,
  }) async {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final fullUrl = '$base/v/api/v1/media/range/$mediaGuid';
    final ts = startPositionMs / 1000.0;
    try {
      final parser = Mp4Parser(dio);
      final offset = await parser.getOffset(fullUrl, ts);
      if (offset > 0) {
        final uri = '$fullUrl?range=bytes=$offset-';
        return (url: uri, effectiveStartMs: 0);
      }
      return (url: fullUrl, effectiveStartMs: startPositionMs);
    } catch (e) {
      debugPrint('[Player] getDirectPlayLink fallback: $e');
      return (url: fullUrl, effectiveStartMs: startPositionMs);
    }
  }

  Future<void> _loadAndPlayMedia() async {
    try {
      setState(() => _isLoading = true);

      final playerService = ref.read(playerServiceProvider);
      final prefs = ref.read(preferencesManagerProvider);
      final dio = ref.read(dioClientProvider).dio;
      final baseUrl = prefs.getBaseUrl() ?? '';

      final playInfo = await playerService.getPlayInfo(
        widget.guid,
        mediaGuid: widget.mediaGuid,
      );
      _playInfo = playInfo;
      debugPrint(
        '[Player] playInfo: guid=${playInfo.guid}, mediaGuid=${playInfo.mediaGuid}, videoGuid=${playInfo.videoGuid}, type=${playInfo.item.type}',
      );

      final targetMediaGuid = playInfo.mediaGuid;
      debugPrint('[Player] targetMediaGuid: $targetMediaGuid');

      final streamInfo = await playerService.getStreamInfo(
        targetMediaGuid,
        ip: playerService.getIpHash(prefs.getToken() ?? ''),
      );
      _streamInfo = streamInfo;
      debugPrint(
        '[Player] streamInfo: videoStream=${streamInfo.videoStream?.mediaGuid}, audioStreams=${streamInfo.audioStreams?.length ?? 0}',
      );

      final currentVideoStream = streamInfo.videoStream;
      final fileStream = streamInfo.fileStream;
      if (currentVideoStream == null || fileStream == null) {
        throw Exception('Missing video_stream or file_stream');
      }

      final audioStreams = streamInfo.audioStreams ?? [];
      final subtitleStreams = streamInfo.subtitleStreams ?? [];

      AudioStream? currentAudioStream;
      SubtitleStream? currentSubtitleStream;

      if (widget.audioGuid != null) {
        currentAudioStream =
            audioStreams.where((s) => s.guid == widget.audioGuid).firstOrNull;
      } else {
        currentAudioStream =
            audioStreams.where((s) => s.isDefault == 1).firstOrNull ??
                audioStreams.firstOrNull;
      }
      if (widget.subtitleGuid != null) {
        currentSubtitleStream = subtitleStreams
            .where((s) => s.guid == widget.subtitleGuid)
            .firstOrNull;
      } else {
        currentSubtitleStream =
            subtitleStreams.where((s) => s.isDefault == 1).firstOrNull;
      }

      final audioGuid =
          widget.audioGuid ?? currentAudioStream?.guid ?? playInfo.audioGuid;
      final subtitleGuid = widget.subtitleGuid ?? currentSubtitleStream?.guid;
      final episodeList =
          playInfo.item.type == 'Episode' && playInfo.parentGuid.isNotEmpty
              ? await _fetchEpisodeList(playInfo.parentGuid)
              : const <EpisodeListResponse>[];
      final currentEpisode = episodeList
          .where((episode) => episode.guid == widget.guid)
          .firstOrNull;
      final currentEpisodeIndex =
          episodeList.indexWhere((episode) => episode.guid == widget.guid);
      final nextEpisode = currentEpisodeIndex >= 0 &&
              currentEpisodeIndex + 1 < episodeList.length
          ? episodeList[currentEpisodeIndex + 1]
          : null;

      final qualities = streamInfo.qualities ?? [];
      _qualities = qualities;
      _currentQuality = qualities.isNotEmpty ? qualities.first : null;

      final historyMs = playInfo.ts * 1000;
      _resetInitialResumeState(historyMs);
      final resolved = await _resolvePlayLink(
        playInfo: playInfo,
        videoStream: currentVideoStream,
        fileStream: fileStream,
        audioGuid: audioGuid,
        subtitleGuid: subtitleGuid,
        qualities: qualities,
        startPositionMs: historyMs,
        baseUrl: baseUrl,
        playerService: playerService,
        dio: dio,
      );

      if (!resolved.isDirectLink && resolved.playLinkRaw != null) {
        try {
          _qualities = await playerService.getQualities(resolved.playLinkRaw!);
          if (_qualities.isNotEmpty) {
            _currentQuality = _qualities.first;
          }
        } catch (_) {
          // Ignore quality list errors
        }
      }

      _playingInfoCache = PlayingInfoCache(
        itemGuid: widget.guid,
        parentGuid: playInfo.parentGuid,
        item: playInfo.item,
        currentVideoStream: currentVideoStream,
        currentAudioStream: currentAudioStream,
        currentSubtitleStream: currentSubtitleStream,
        currentAudioStreamList: audioStreams,
        currentSubtitleStreamList: subtitleStreams,
        playLink: resolved.playLinkRaw ?? resolved.playUri,
        isUseDirectLink: resolved.isDirectLink,
        playConfig: playInfo.playConfig,
        streamInfo: streamInfo,
        isEpisode: playInfo.item.type == 'Episode',
        subhead: _buildDisplaySubhead(playInfo.item),
      );

      await _openMediaWithResume(
        playUri: resolved.playUri,
        startPositionMs: resolved.effectiveStartMs,
        isInitialPlayback: true,
      );

      _volume = ref.read(playerSettingsManagerProvider).getVolume();
      await _player!.setVolume(_volume * 100);

      _speed = ref.read(playerSettingsManagerProvider).getSpeed();
      await _player!.setRate(_speed);

      setState(() {
        _isLoading = false;
        _isInitialized = true;
        _duration = currentVideoStream.duration > 0
            ? currentVideoStream.duration * 1000
            : playInfo.item.duration * 1000;
        _currentResolution = _currentQuality?.resolution ?? '';
        _currentBitrate = _currentQuality?.bitrate;
        _selectedAudioGuid = audioGuid;
        _selectedSubtitleGuid = subtitleGuid;
        _episodeList = episodeList;
        _currentEpisode = currentEpisode;
        _nextEpisode = nextEpisode;
      });

      await _ensureInitialResumeApplied();
      _startPlayRecordTimer();
    } catch (e) {
      debugPrint('[Player] Error loading media: $e');
      _toastManager.showToast(
        '加载失败: $e',
        type: ToastType.failed,
      );
      setState(() => _isLoading = false);
    }
  }

  void _startPlayRecordTimer() {
    _playRecordTimer?.cancel();
    _playRecordTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!_isInitialized || _player == null) return;

      final position = _player!.state.position.inMilliseconds;
      if (position != _lastRecordedPosition && position > 0) {
        _lastRecordedPosition = position;
        try {
          final playerService = ref.read(playerServiceProvider);
          await playerService.updatePlayRecord(
            guid: widget.guid,
            ts: position ~/ 1000,
            duration: _duration > 0 ? _duration ~/ 1000 : null,
          );
        } catch (_) {
          // Ignore record errors
        }
      }
    });
  }

  void _showUi() {
    setState(() => _isUiVisible = true);
    _hideUiTimer?.cancel();
    _hideUiTimer = Timer(const Duration(seconds: 3), () {
      if (!_isProgressBarHovered &&
          !_isBottomControlAreaHovered &&
          !_isSpeedControlHovered &&
          !_isVolumeControlHovered &&
          !_isQualityControlHovered &&
          !_isSubtitleControlHovered &&
          !_isEpisodeControlHovered &&
          !_isNextEpisodeHovered &&
          !_isDanmakuControlHovered &&
          !_isDanmakuSettingsHovered &&
          !_isPipControlHovered &&
          !_isSettingsMenuHovered &&
          mounted) {
        setState(() => _isUiVisible = false);
      }
    });
  }

  void _handleFlyoutHoverStateChanged(
      _PlayerFlyoutType type, bool hovered) {
    setState(() {
      switch (type) {
        case _PlayerFlyoutType.speed:
          _isSpeedControlHovered = hovered;
          break;
        case _PlayerFlyoutType.episode:
          _isEpisodeControlHovered = hovered;
          break;
        case _PlayerFlyoutType.quality:
          _isQualityControlHovered = hovered;
          break;
        case _PlayerFlyoutType.subtitle:
          _isSubtitleControlHovered = hovered;
          break;
      }

      if (hovered) {
        _activeFlyout = type;
      } else if (_activeFlyout == type) {
        _activeFlyout = null;
      }
    });
  }

  void _togglePlayPause() {
    if (_player == null) return;
    if (_player!.state.playing) {
      _player!.pause();
    } else {
      _player!.play();
    }
  }

  void _seekRelative(int milliseconds) {
    if (_player == null) return;
    final current = _player!.state.position.inMilliseconds;
    final target = (current + milliseconds).clamp(0, _duration);
    _player!.seek(Duration(milliseconds: target));
  }

  void _seekTo(double progress) {
    if (_player == null) return;
    final target = (progress * _duration).toInt();
    _player!.seek(Duration(milliseconds: target));
  }

  void _setVolume(double volume) {
    if (_player == null) return;
    setState(() => _volume = volume);
    _player!.setVolume(volume * 100);
    ref.read(playerSettingsManagerProvider).setVolume(volume);
  }

  void _setSpeed(double speed) {
    if (_player == null) return;
    _speed = speed;
    _player!.setRate(speed);
    ref.read(playerSettingsManagerProvider).setSpeed(speed);
  }

  Future<void> _toggleFullscreen() async {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      final isFullscreen = await windowManager.isFullScreen();
      await windowManager.setFullScreen(!isFullscreen);
    } else {
      // Windows/Linux pseudo fullscreen
      if (_isFullscreen) {
        await windowManager.unmaximize();
      } else {
        await windowManager.maximize();
      }
    }
    setState(() => _isFullscreen = !_isFullscreen);
  }

  Future<void> _onQualitySelected(QualityResponse quality) async {
    await _reloadPlayback(
      audioGuid:
          _selectedAudioGuid ?? widget.audioGuid ?? _playInfo?.audioGuid ?? '',
      subtitleGuid: _selectedSubtitleGuid ?? widget.subtitleGuid,
      quality: quality,
    );
  }

  Future<void> _onAudioSelected(AudioStream audio) async {
    await _reloadPlayback(
      audioGuid: audio.guid,
      subtitleGuid: _selectedSubtitleGuid ?? widget.subtitleGuid,
    );
  }

  Future<void> _onSubtitleSelected(String? subtitleGuid) async {
    await _reloadPlayback(
      audioGuid:
          _selectedAudioGuid ?? widget.audioGuid ?? _playInfo?.audioGuid ?? '',
      subtitleGuid: subtitleGuid,
    );
  }

  Future<void> _reloadPlayback({
    required String audioGuid,
    required String? subtitleGuid,
    QualityResponse? quality,
  }) async {
    final playInfo = _playInfo;
    final streamInfo = _streamInfo;
    final videoStream = streamInfo?.videoStream;
    final fileStream = streamInfo?.fileStream;
    if (playInfo == null ||
        streamInfo == null ||
        videoStream == null ||
        fileStream == null ||
        _player == null) {
      return;
    }

    try {
      setState(() => _isLoading = true);

      final prefs = ref.read(preferencesManagerProvider);
      final baseUrl = prefs.getBaseUrl() ?? '';
      final playerService = ref.read(playerServiceProvider);
      final dio = ref.read(dioClientProvider).dio;

      final audioStreams = streamInfo.audioStreams ?? [];
      final currentAudioStream =
          audioStreams.where((s) => s.guid == audioGuid).firstOrNull ??
              audioStreams.where((s) => s.isDefault == 1).firstOrNull ??
              audioStreams.firstOrNull;

      final subtitleStreams = streamInfo.subtitleStreams ?? [];
      final currentSubtitleStream = subtitleGuid != null
          ? subtitleStreams.where((s) => s.guid == subtitleGuid).firstOrNull
          : subtitleStreams.where((s) => s.isDefault == 1).firstOrNull;
      final effectiveSubtitleGuid = subtitleGuid ?? currentSubtitleStream?.guid;

      final currentPosition = _player!.state.position.inMilliseconds;
      if (quality != null) {
        _currentQuality = quality;
      }

      final qualities = streamInfo.qualities ?? [];
      final resolved = await _resolvePlayLink(
        playInfo: playInfo,
        videoStream: videoStream,
        fileStream: fileStream,
        audioGuid: currentAudioStream?.guid ?? audioGuid,
        subtitleGuid: effectiveSubtitleGuid,
        qualities: qualities,
        startPositionMs: currentPosition,
        baseUrl: baseUrl,
        playerService: playerService,
        dio: dio,
      );

      if (!resolved.isDirectLink && resolved.playLinkRaw != null) {
        try {
          _qualities = await playerService.getQualities(resolved.playLinkRaw!);
        } catch (_) {
          // Ignore quality list errors
        }
      }

      _playingInfoCache = _playingInfoCache?.copyWith(
        currentAudioStream: currentAudioStream,
        currentSubtitleStream: currentSubtitleStream,
        playLink: resolved.playLinkRaw ?? resolved.playUri,
        isUseDirectLink: resolved.isDirectLink,
        subhead: playInfo.item.type == 'Episode'
            ? _buildDisplaySubhead(playInfo.item)
            : '',
      );

      await _openMediaWithResume(
        playUri: resolved.playUri,
        startPositionMs: resolved.effectiveStartMs,
      );

      setState(() {
        _isLoading = false;
        _selectedAudioGuid = currentAudioStream?.guid ?? audioGuid;
        _selectedSubtitleGuid = effectiveSubtitleGuid;
        _currentResolution = _currentQuality?.resolution ?? '';
        _currentBitrate = _currentQuality?.bitrate;
      });
    } catch (e) {
      _toastManager.showToast('切换播放配置失败: $e', type: ToastType.failed);
      setState(() => _isLoading = false);
    }
  }

  void _handleBack() {
    _leavePlayerRoute(() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    });
  }

  // Dismiss transient overlays before leaving the player route.
  void _dismissTransientPlayerUiBeforeExit() {
    _playRecordTimer?.cancel();
    _hideUiTimer?.cancel();
    Tooltip.dismissAllToolTips();

    _isProgressBarHovered = false;
    _isBottomControlAreaHovered = false;
    _isSpeedControlHovered = false;
    _isVolumeControlHovered = false;
    _isQualityControlHovered = false;
    _isSettingsMenuHovered = false;
    _isSubtitleControlHovered = false;
    _isEpisodeControlHovered = false;
    _isNextEpisodeHovered = false;
    _isDanmakuControlHovered = false;
    _isDanmakuSettingsHovered = false;
    _isPipControlHovered = false;
    _activeFlyout = null;
  }

  void _leavePlayerRoute(VoidCallback onLeave) {
    _dismissTransientPlayerUiBeforeExit();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      onLeave();
    });
  }

  @override
  void dispose() {
    _playRecordTimer?.cancel();
    _hideUiTimer?.cancel();
    _player?.dispose();
    _toastManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MouseRegion(
          onHover: (_) => _showUi(),
          child: GestureDetector(
            onTap: () => _showUi(),
            child: Container(
              color: Colors.black,
              child: _isInitialized && _videoController != null
                  ? Video(
                      controller: _videoController!,
                      controls: NoVideoControls,
                    )
                  : const Center(child: ProgressRing()),
            ),
          ),
        ),
        if (_isLoading) const Center(child: ProgressRing()),
        if (_isInitialized)
          AnimatedOpacity(
            opacity: _isUiVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 112,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildTopBar(),
                ),
                Center(child: _buildCenterPlayButton()),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 168,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: MouseRegion(
                    onEnter: (_) {
                      setState(() => _isBottomControlAreaHovered = true);
                      _showUi();
                    },
                    onExit: (_) {
                      setState(() => _isBottomControlAreaHovered = false);
                    },
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildProgressBar(),
                            const SizedBox(height: 12),
                            _buildControlButtons(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Positioned.fill(
          child: ToastHost(toastManager: _toastManager),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    return StreamBuilder<Duration>(
      stream: _player?.stream.position,
      builder: (context, snapshot) {
        _currentPosition = snapshot.data?.inMilliseconds ?? _currentPosition;
        return MouseRegion(
          onEnter: (_) => setState(() => _isProgressBarHovered = true),
          onExit: (_) => setState(() => _isProgressBarHovered = false),
          child: VideoPlayerProgressBar(
            currentPosition: _currentPosition,
            totalDuration: _duration,
            onSeek: _seekTo,
          ),
        );
      },
    );
  }

  Widget _buildControlButtons() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        PlayerActionButton.svg(
          svgAssetPath: _player?.state.playing == true
              ? 'assets/images/pause.svg'
              : 'assets/images/play.svg',
          onPressed: _togglePlayPause,
          tooltip: '播放/暂停',
          size: 34,
          iconSize: 22,
        ),
        const SizedBox(width: 16),
        PlayerActionButton.svg(
          svgAssetPath: 'assets/images/back10s.svg',
          onPressed: () => _seekRelative(-10000),
          tooltip: '快退 10 秒',
          size: 30,
          iconSize: 20,
        ),
        const SizedBox(width: 16),
        PlayerActionButton.svg(
          svgAssetPath: 'assets/images/forward10s.svg',
          onPressed: () => _seekRelative(10000),
          tooltip: '快进 10 秒',
          size: 30,
          iconSize: 20,
        ),
        if (_nextEpisode != null) ...[
          const SizedBox(width: 12),
          NextEpisodePreviewFlyout(
            nextEpisode: _nextEpisode!,
            onClick: () => _openEpisode(_nextEpisode!),
            onHoverStateChanged: (hovered) =>
                setState(() => _isNextEpisodeHovered = hovered),
          ),
        ],
        const SizedBox(width: 16),
        Text(
          '${formatDurationToDateTime(_currentPosition)} / ${formatDurationToDateTime(_duration)}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        SpeedControlFlyout(
          defaultSpeed: _speed,
          yOffset: _controlFlyoutOffset,
          isActiveControl: _activeFlyout == _PlayerFlyoutType.speed,
          onHoverStateChanged: (hovered) =>
              _handleFlyoutHoverStateChanged(_PlayerFlyoutType.speed, hovered),
          onSpeedSelected: (speed) => _setSpeed(speed.value),
        ),
        const SizedBox(width: _controlFlyoutSpacing),
        if (_episodeList.isNotEmpty && _displaySubhead.isNotEmpty) ...[
          EpisodeSelectionFlyout(
            episodes: _episodeList,
            currentEpisodeGuid: widget.guid,
            isAutoPlay: _isAutoPlayEnabled,
            yOffset: _controlFlyoutOffset,
            isActiveControl: _activeFlyout == _PlayerFlyoutType.episode,
            onHoverStateChanged: (hovered) =>
                _handleFlyoutHoverStateChanged(_PlayerFlyoutType.episode, hovered),
            onEpisodeSelected: _openEpisode,
            onAutoPlayChanged: (value) =>
                setState(() => _isAutoPlayEnabled = value),
          ),
          const SizedBox(width: _controlFlyoutSpacing),
        ],
        if (_qualities.isNotEmpty)
          QualityControlFlyout(
            qualities: _qualities,
            currentResolution: _currentResolution,
            currentBitrate: _currentBitrate,
            yOffset: _controlFlyoutOffset,
            isActiveControl: _activeFlyout == _PlayerFlyoutType.quality,
            onHoverStateChanged: (hovered) =>
                _handleFlyoutHoverStateChanged(_PlayerFlyoutType.quality, hovered),
            onQualitySelected: _onQualitySelected,
          ),
        const SizedBox(width: _controlFlyoutSpacing),
        MouseRegion(
          onEnter: (_) => setState(() => _isDanmakuControlHovered = true),
          onExit: (_) => setState(() => _isDanmakuControlHovered = false),
          child: PlayerActionButton.svg(
            svgAssetPath: _isDanmakuVisible
                ? 'assets/images/danmu_open.svg'
                : 'assets/images/danmu_close.svg',
            onPressed: () {
              setState(() => _isDanmakuVisible = !_isDanmakuVisible);
              _showFeatureComingSoon('弹幕');
            },
            tooltip: '弹幕',
            size: 30,
            iconSize: 20,
          ),
        ),
        const SizedBox(width: 16),
        MouseRegion(
          onEnter: (_) => setState(() => _isDanmakuSettingsHovered = true),
          onExit: (_) => setState(() => _isDanmakuSettingsHovered = false),
          child: PlayerActionButton.svg(
            svgAssetPath: 'assets/images/danmu_setting.svg',
            onPressed: () => _showFeatureComingSoon('弹幕设置'),
            tooltip: '弹幕设置',
            size: 30,
            iconSize: 20,
          ),
        ),
        const SizedBox(width: _controlFlyoutSpacing),
        SubtitleControlFlyout(
          subtitles: _playingInfoCache?.currentSubtitleStreamList ?? const [],
          selectedSubtitleGuid: _selectedSubtitleGuid,
          yOffset: _controlFlyoutOffset,
          isActiveControl: _activeFlyout == _PlayerFlyoutType.subtitle,
          onHoverStateChanged: (hovered) =>
              _handleFlyoutHoverStateChanged(_PlayerFlyoutType.subtitle, hovered),
          onSubtitleSelected: _onSubtitleSelected,
        ),
        const SizedBox(width: _controlFlyoutSpacing),
        PlayerSettingsMenu(
          playingInfoCache: _playingInfoCache,
          currentPositionMillis: _currentPosition,
          totalDurationMillis: _duration,
          popupBottomOffset: _controlFlyoutOffset.toDouble(),
          onHoverStateChanged: (hovered) =>
              setState(() => _isSettingsMenuHovered = hovered),
          onAudioSelected: _onAudioSelected,
          onWindowAspectRatioChanged: (_) {},
          onSkipConfigChanged: (_, __) {},
        ),
        const SizedBox(width: _controlFlyoutSpacing),
        VolumeControl(
          volume: _volume,
          popupBottomOffset: _controlFlyoutOffset.toDouble(),
          onHoverStateChanged: (hovered) =>
              setState(() => _isVolumeControlHovered = hovered),
          onVolumeChange: _setVolume,
        ),
        const SizedBox(width: 16),
        MouseRegion(
          onEnter: (_) => setState(() => _isPipControlHovered = true),
          onExit: (_) => setState(() => _isPipControlHovered = false),
          child: PlayerActionButton.lottie(
            lottieAssetPath: 'assets/lottie/to_pip.json',
            onPressed: () => _showFeatureComingSoon('画中画'),
            tooltip: '画中画',
            size: 30,
            iconSize: 22,
          ),
        ),
        const SizedBox(width: 16),
        FullScreenControl(
          isFullScreen: _isFullscreen,
          onClick: _toggleFullscreen,
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    final leftInset = _isMacOS ? 72.0 : 0.0;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: SizedBox(
          height: 36,
          child: Stack(
            children: [
              Positioned.fill(
                child: DragToMoveArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        text: _buildTitleSpan(),
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (leftInset > 0) SizedBox(width: leftInset),
                    _buildBackButton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return PlayerActionButton.icon(
      iconData: FluentIcons.back,
      onPressed: _handleBack,
      tooltip: '返回',
      size: _isMacOS ? 30 : 34,
      iconSize: _isMacOS ? 15 : 18,
      borderRadius: BorderRadius.circular(_isMacOS ? 15 : 17),
    );
  }

  Widget _buildCenterPlayButton() {
    final isPlaying = _player?.state.playing == true;
    return GestureDetector(
      onTap: _togglePlayPause,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.5),
        ),
        alignment: Alignment.center,
        child: SvgPicture.asset(
          isPlaying ? 'assets/images/pause.svg' : 'assets/images/play.svg',
          width: 34,
          height: 34,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
      ),
    );
  }

  TextSpan _buildTitleSpan() {
    final baseFontSize = _isMacOS ? 16.0 : 20.0;
    final subhead = _displaySubhead;
    if (subhead.isEmpty) {
      return TextSpan(
        text: _displayTitle,
        style: TextStyle(
          color: Colors.white,
          fontSize: baseFontSize,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return TextSpan(
      children: [
        TextSpan(
          text: _displayTitle,
          style: TextStyle(
            color: Colors.white,
            fontSize: baseFontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        TextSpan(
          text: _isMacOS ? ' / ' : ' | ',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.84),
            fontSize: baseFontSize,
            fontWeight: FontWeight.w300,
          ),
        ),
        TextSpan(
          text: subhead,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.76),
            fontSize: _isMacOS ? 16 : 14,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  bool get _isMacOS => defaultTargetPlatform == TargetPlatform.macOS;

  String get _displayTitle {
    final item = _playInfo?.item ?? _playingInfoCache?.item;
    if (item == null) return '';
    if (item.type == 'Episode' && item.tvTitle.isNotEmpty) {
      return item.tvTitle;
    }
    return item.title;
  }

  String get _displaySubhead {
    final item = _playInfo?.item ?? _playingInfoCache?.item;
    if (item == null || item.type != 'Episode') {
      return '';
    }
    return _buildDisplaySubhead(item);
  }

  String _buildDisplaySubhead(ItemResponse item) {
    final season = item.parentTitle;
    final episodeNumber =
        _currentEpisode?.episodeNumber ?? _playInfo?.item.episodeNumber ?? 0;
    final episodeLabel = episodeNumber > 0 ? '第$episodeNumber集' : '';
    final episodeTitle = item.title;
    final parts = <String>[
      if (season.isNotEmpty) season,
      if (episodeLabel.isNotEmpty) episodeLabel,
      if (episodeTitle.isNotEmpty) episodeTitle,
    ];
    return parts.join(' · ');
  }

  Future<List<EpisodeListResponse>> _fetchEpisodeList(String guid) async {
    final response = await ref
        .read(dioClientProvider)
        .dio
        .get('/v/api/v1/episode/list/$guid');
    return _parseEpisodeList(response.data);
  }

  List<EpisodeListResponse> _parseEpisodeList(dynamic payload) {
    if (payload is List) {
      return payload
          .map((entry) =>
              EpisodeListResponse.fromJson(entry as Map<String, dynamic>))
          .toList();
    }
    if (payload is Map<String, dynamic>) {
      final baseResponse = FnBaseResponse<List<EpisodeListResponse>>.fromJson(
        payload,
        (json) => ((json as List<dynamic>?) ?? const <dynamic>[])
            .map((entry) =>
                EpisodeListResponse.fromJson(entry as Map<String, dynamic>))
            .toList(),
      );
      return baseResponse.data ?? const <EpisodeListResponse>[];
    }
    return const <EpisodeListResponse>[];
  }

  void _openEpisode(EpisodeListResponse episode) {
    if (episode.guid == widget.guid) {
      return;
    }
    _leavePlayerRoute(() => context.go('/player/${episode.guid}'));
  }

  void _showFeatureComingSoon(String feature) {
    _toastManager.showToast('$feature 暂未接入', type: ToastType.info);
  }
}
