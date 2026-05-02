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
import '../../../data/models/episode_list_response.dart';
import '../../../data/models/player_models.dart';
import '../../../data/models/movie_detail_models.dart';
import '../../../providers/providers.dart';
import '../../player/mp4_parser.dart';
import '../../player/hls_playlist_resolver.dart';
import '../../player/hls_subtitle_repository.dart';
import '../../player/media_p_view_model.dart';
import '../../player/player_service.dart';
import '../../player/player_view_model.dart';
import '../../player/widgets/episode_selection_flyout.dart';
import '../../player/widgets/player_subtitle_overlay.dart';
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

class _PreparedPlaySource {
  final String playUri;
  final bool useHlsSubtitleOverlay;
  final String? subtitlePlaylistUrl;

  const _PreparedPlaySource({
    required this.playUri,
    required this.useHlsSubtitleOverlay,
    this.subtitlePlaylistUrl,
  });
}

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
  StreamSubscription<Duration>? _positionSubscription;
  Timer? _hideUiTimer;
  Timer? _playRecordTimer;
  int _lastRecordedPosition = 0;
  int _pendingInitialResumeMs = 0;
  bool _initialResumeApplied = false;
  bool _hasSetupProviderListeners = false;

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
  late String _currentItemGuid;
  String? _currentMediaGuid;
  String? _requestedAudioGuid;
  String? _requestedSubtitleGuid;
  String? _selectedAudioGuid;
  String? _selectedSubtitleGuid;
  List<EpisodeListResponse> _episodeList = [];
  EpisodeListResponse? _currentEpisode;
  EpisodeListResponse? _nextEpisode;
  HlsSubtitleRepository? _hlsSubtitleRepository;
  VoidCallback? _hlsSubtitleTextsListener;
  final ValueNotifier<List<String>> _hlsSubtitleTexts =
      ValueNotifier<List<String>>(const []);
  bool _useHlsSubtitleOverlay = false;

  @override
  void initState() {
    super.initState();
    _toastManager = ToastManager();
    _syncPlaybackTargetsFromWidget();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(covariant PlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final routeArgsChanged = oldWidget.guid != widget.guid ||
        oldWidget.mediaGuid != widget.mediaGuid ||
        oldWidget.audioGuid != widget.audioGuid ||
        oldWidget.subtitleGuid != widget.subtitleGuid;
    if (!routeArgsChanged) return;

    final shouldReload = widget.guid != _currentItemGuid ||
        widget.mediaGuid != _currentMediaGuid ||
        widget.audioGuid != _requestedAudioGuid ||
        widget.subtitleGuid != _requestedSubtitleGuid;
    if (!shouldReload) return;

    unawaited(_switchPlaybackTarget(
      guid: widget.guid,
      mediaGuid: widget.mediaGuid,
      audioGuid: widget.audioGuid,
      subtitleGuid: widget.subtitleGuid,
    ));
  }

  Future<void> _initializePlayer() async {
    _player = Player();
    _videoController = VideoController(_player!);
    _setupPlayerPositionListener();
    _setupProviderListeners();

    await _loadAndPlayMedia();
  }

  void _setupPlayerPositionListener() {
    _positionSubscription?.cancel();
    final player = _player;
    if (player == null) return;
    _positionSubscription = player.stream.position.listen((position) {
      _hlsSubtitleRepository?.onPlaybackPosition(position.inMilliseconds);
    });
  }

  void _setupProviderListeners() {
    if (_hasSetupProviderListeners) return;
    _hasSetupProviderListeners = true;

    ref.listenManual<MediaPState>(
      mediaPViewModelProvider,
      (previous, next) {
        if (!mounted) return;

        final previousError = previous?.error;
        final nextError = next.error;
        if (nextError != null &&
            nextError.isNotEmpty &&
            nextError != previousError) {
          debugPrint('[Player] mediaP state error: $nextError');
        }

        final previousQuitReqId = previous?.quitResponse?.reqId;
        final nextQuitResponse = next.quitResponse;
        if (nextQuitResponse != null &&
            nextQuitResponse.reqId != previousQuitReqId) {
          unawaited(_handleQuitSuccess(nextQuitResponse));
        }

        final previousResetQualityReqId = previous?.resetQualityResponse?.reqId;
        final nextResetQualityResponse = next.resetQualityResponse;
        if (nextResetQualityResponse != null &&
            nextResetQualityResponse.reqId != previousResetQualityReqId) {
          _handleResetQualitySuccess(nextResetQualityResponse);
        }

        final previousResetAudioReqId = previous?.resetAudioResponse?.reqId;
        final nextResetAudioResponse = next.resetAudioResponse;
        if (nextResetAudioResponse != null &&
            nextResetAudioResponse.reqId != previousResetAudioReqId) {
          _handleResetAudioSuccess(nextResetAudioResponse);
        }

        final previousResetSubtitleReqId =
            previous?.resetSubtitleResponse?.reqId;
        final nextResetSubtitleResponse = next.resetSubtitleResponse;
        if (nextResetSubtitleResponse != null &&
            nextResetSubtitleResponse.reqId != previousResetSubtitleReqId) {
          unawaited(_handleResetSubtitleSuccess(nextResetSubtitleResponse));
        }
      },
    );
  }

  void _syncPlaybackTargetsFromWidget() {
    _currentItemGuid = widget.guid;
    _currentMediaGuid = widget.mediaGuid;
    _requestedAudioGuid = widget.audioGuid;
    _requestedSubtitleGuid = widget.subtitleGuid;
  }

  void _resetPlaybackStateForTargetChange() {
    _disposeHlsSubtitleSession();
    _playRecordTimer?.cancel();
    _lastRecordedPosition = 0;
    _currentPosition = 0;
    _duration = 0;
    _pendingInitialResumeMs = 0;
    _initialResumeApplied = false;
    _selectedAudioGuid = null;
    _selectedSubtitleGuid = null;
    _qualities = [];
    _currentQuality = null;
    _currentResolution = '';
    _currentBitrate = null;
    _playInfo = null;
    _streamInfo = null;
    _playingInfoCache = null;
    _episodeList = [];
    _currentEpisode = null;
    _nextEpisode = null;
    _isNextEpisodeHovered = false;
  }

  Future<void> _quitCurrentPlaybackIfNeeded() async {
    final cache = _playingInfoCache;
    final playLink = cache?.playLink;
    if (cache == null ||
        cache.isUseDirectLink ||
        playLink == null ||
        playLink.isEmpty) {
      return;
    }

    try {
      await ref.read(mediaPViewModelProvider.notifier).quit(
            MediaPRequest(playLink: playLink),
            updateState: false,
          );
    } catch (e) {
      debugPrint('[Player] quit media failed: $e');
    }
  }

  Future<void> _switchPlaybackTarget({
    required String guid,
    String? mediaGuid,
    String? audioGuid,
    String? subtitleGuid,
  }) async {
    final isSameTarget = guid == _currentItemGuid &&
        mediaGuid == _currentMediaGuid &&
        audioGuid == _requestedAudioGuid &&
        subtitleGuid == _requestedSubtitleGuid;
    if (isSameTarget) return;

    await _quitCurrentPlaybackIfNeeded();
    if (!mounted) return;

    setState(() {
      _currentItemGuid = guid;
      _currentMediaGuid = mediaGuid;
      _requestedAudioGuid = audioGuid;
      _requestedSubtitleGuid = subtitleGuid;
      _resetPlaybackStateForTargetChange();
      _isLoading = true;
    });

    await _loadAndPlayMedia();
  }

  void _resetInitialResumeState(int positionMs) {
    _pendingInitialResumeMs = positionMs;
    _initialResumeApplied = positionMs <= 0;
  }

  Future<void> _openMediaWithResume({
    required String playUri,
    required int startPositionMs,
    required SubtitleStream? currentSubtitleStream,
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
    await _applyCurrentSubtitleTrack(currentSubtitleStream);

    if (isInitialPlayback) {
      _resetInitialResumeState(startPositionMs);
    }

    await _applyResumePosition(startPositionMs,
        isInitialPlayback: isInitialPlayback);
  }

  bool _supportsDirectLink(
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

  Future<void> _callPlayRecordAtCurrentPosition() async {
    final player = _player;
    if (player == null) return;
    final position = player.state.position.inMilliseconds;
    if (position < 0) return;

    try {
      await ref.read(playerServiceProvider).updatePlayRecord(
            guid: _currentItemGuid,
            ts: position ~/ 1000,
            duration: _duration > 0 ? _duration ~/ 1000 : null,
          );
    } catch (e) {
      debugPrint('[Player] play record update during switch failed: $e');
    }
  }

  Future<void> _reopenPlaybackFromPlayLink({
    required String playLink,
    required int startPositionMs,
  }) async {
    final prefs = ref.read(preferencesManagerProvider);
    final baseUrl = prefs.getBaseUrl() ?? '';
    final cache = _playingInfoCache;
    if (baseUrl.isEmpty || cache == null) return;

    final playUri = _absolutePlayUrl(baseUrl, playLink);
    final dio = ref.read(dioClientProvider).dio;
    final prepared = await _preparePlaySourceForMediaKit(
      playUri: playUri,
      currentSubtitleStream: cache.currentSubtitleStream,
      dio: dio,
    );
    _prepareHlsSubtitleOverlayMode(
      subtitleStream: cache.currentSubtitleStream,
      subtitlePlaylistUrl: prepared.subtitlePlaylistUrl,
    );
    await _openMediaWithResume(
      playUri: prepared.playUri,
      startPositionMs: startPositionMs,
      currentSubtitleStream: cache.currentSubtitleStream,
    );
    _startHlsSubtitleSessionAsync(
      dio: dio,
      subtitleStream: cache.currentSubtitleStream,
      subtitlePlaylistUrl: prepared.subtitlePlaylistUrl,
      startPositionMs: startPositionMs,
    );
  }

  Future<void> _reopenPlaybackWithDirectLink({
    required int startPositionMs,
  }) async {
    final cache = _playingInfoCache;
    final videoStream = cache?.currentVideoStream;
    if (cache == null || videoStream == null) return;

    final prefs = ref.read(preferencesManagerProvider);
    final baseUrl = prefs.getBaseUrl() ?? '';
    final dio = ref.read(dioClientProvider).dio;
    final directLink = await _getDirectPlayLink(
      mediaGuid: videoStream.mediaGuid,
      startPositionMs: startPositionMs,
      baseUrl: baseUrl,
      dio: dio,
    );
    _playingInfoCache = cache.copyWith(
      playLink: directLink.playLinkRaw,
      isUseDirectLink: true,
    );
    ref
        .read(playerViewModelProvider.notifier)
        .updatePlayingInfo(_playingInfoCache);
    _disposeHlsSubtitleSession();
    await _openMediaWithResume(
      playUri: directLink.playUri,
      startPositionMs: directLink.effectiveStartMs,
      currentSubtitleStream: _playingInfoCache?.currentSubtitleStream,
    );
  }

  Future<void> _handlePlayPlaySuccess(
    PlayPlayResponse response, {
    required int startPositionMs,
  }) async {
    final cache = _playingInfoCache;
    if (cache == null) return;

    _playingInfoCache = cache.copyWith(
      playLink: response.playLink,
      isUseDirectLink: false,
    );
    ref
        .read(playerViewModelProvider.notifier)
        .updatePlayingInfo(_playingInfoCache);
    await _reopenPlaybackFromPlayLink(
      playLink: response.playLink,
      startPositionMs: startPositionMs,
    );
  }

  Future<void> _handleQuitSuccess(
    MediaResetQualityResponse response,
  ) async {
    ref.read(mediaPViewModelProvider.notifier).clearQuitResponse();
    if (response.result != 'succ' || _player == null) {
      return;
    }

    try {
      final startPositionMs = _player!.state.position.inMilliseconds;
      await _reopenPlaybackWithDirectLink(startPositionMs: startPositionMs);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentQuality = _playingInfoCache?.currentQuality;
          _currentResolution = _currentQuality?.resolution ?? '';
          _currentBitrate = _currentQuality?.bitrate;
        });
      }
    } catch (e) {
      debugPrint('[Player] handle quit success failed: $e');
      if (mounted) {
        _toastManager.showToast('切换原画失败: $e', type: ToastType.failed);
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleResetQualitySuccess(MediaResetQualityResponse response) {
    ref.read(mediaPViewModelProvider.notifier).clearResetQualityResponse();
    if (response.result != 'succ' || !mounted) {
      return;
    }
    setState(() {
      _isLoading = false;
      _currentQuality = _playingInfoCache?.currentQuality;
      _currentResolution = _currentQuality?.resolution ?? '';
      _currentBitrate = _currentQuality?.bitrate;
    });
  }

  void _handleResetAudioSuccess(MediaResetQualityResponse response) {
    ref.read(mediaPViewModelProvider.notifier).clearResetAudioResponse();
    if (response.result != 'succ' || !mounted) {
      return;
    }
    setState(() {
      _isLoading = false;
      _selectedAudioGuid = _playingInfoCache?.currentAudioStream?.guid;
    });
  }

  Future<void> _handleResetSubtitleSuccess(
    MediaResetQualityResponse response,
  ) async {
    ref.read(mediaPViewModelProvider.notifier).clearResetSubtitleResponse();
    if (response.result != 'succ') {
      return;
    }

    final cache = _playingInfoCache;
    if (cache == null) return;
    try {
      final dio = ref.read(dioClientProvider).dio;
      final baseUrl = ref.read(preferencesManagerProvider).getBaseUrl() ?? '';
      final subtitlePlaylistUrl = cache.playLink != null &&
              baseUrl.isNotEmpty &&
              _looksLikeM3u8(cache.playLink!)
          ? (await _preparePlaySourceForMediaKit(
              playUri: _absolutePlayUrl(baseUrl, cache.playLink!),
              currentSubtitleStream: cache.currentSubtitleStream,
              dio: dio,
            ))
              .subtitlePlaylistUrl
          : null;
      final startPositionMs = _player?.state.position.inMilliseconds ?? 0;
      _prepareHlsSubtitleOverlayMode(
        subtitleStream: cache.currentSubtitleStream,
        subtitlePlaylistUrl: subtitlePlaylistUrl,
      );
      await _applyCurrentSubtitleTrack(cache.currentSubtitleStream);
      _startHlsSubtitleSessionAsync(
        dio: dio,
        subtitleStream: cache.currentSubtitleStream,
        subtitlePlaylistUrl: subtitlePlaylistUrl,
        startPositionMs: startPositionMs,
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
          _selectedSubtitleGuid = cache.currentSubtitleStream?.guid;
        });
      }
    } catch (e) {
      debugPrint('[Player] handle reset subtitle success failed: $e');
      if (mounted) {
        _toastManager.showToast('切换字幕失败: $e', type: ToastType.failed);
        setState(() => _isLoading = false);
      }
    }
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

  bool _isSupportedExternalSubtitle(SubtitleStream? subtitleStream) {
    if (subtitleStream == null || subtitleStream.isExternal != 1) {
      return false;
    }
    const supportedFormats = {'srt', 'ass', 'ssa', 'vtt'};
    return supportedFormats.contains(subtitleStream.format.toLowerCase());
  }

  Future<void> _applyCurrentSubtitleTrack(
    SubtitleStream? subtitleStream,
  ) async {
    final player = _player;
    if (player == null) return;

    if (subtitleStream == null) {
      await player.setSubtitleTrack(SubtitleTrack.no());
      return;
    }

    if (_useHlsSubtitleOverlay && subtitleStream.isExternal != 1) {
      await player.setSubtitleTrack(SubtitleTrack.no());
      return;
    }

    if (!_isSupportedExternalSubtitle(subtitleStream)) {
      return;
    }

    try {
      final content = await ref
          .read(playerServiceProvider)
          .downloadExternalSubtitle(subtitleStream.guid);
      if (!mounted || player != _player) {
        return;
      }

      final expectedSubtitleGuid =
          _requestedSubtitleGuid ?? _selectedSubtitleGuid;
      if (expectedSubtitleGuid != null &&
          expectedSubtitleGuid != subtitleStream.guid) {
        return;
      }

      await player.setSubtitleTrack(
        SubtitleTrack.data(
          content,
          title: subtitleStream.title.isNotEmpty ? subtitleStream.title : null,
          language: subtitleStream.language.isNotEmpty
              ? subtitleStream.language
              : null,
        ),
      );
    } catch (e) {
      debugPrint('[Player] apply external subtitle failed: $e');
      if (player == _player) {
        await player.setSubtitleTrack(SubtitleTrack.no());
      }
    }
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

  bool _looksLikeM3u8(String playUri) {
    final uri = Uri.tryParse(playUri);
    if (uri == null) {
      return playUri.contains('.m3u8');
    }
    return uri.path.toLowerCase().contains('.m3u8');
  }

  Future<_PreparedPlaySource> _preparePlaySourceForMediaKit({
    required String playUri,
    required SubtitleStream? currentSubtitleStream,
    required Dio dio,
  }) async {
    if (!_looksLikeM3u8(playUri) ||
        currentSubtitleStream == null ||
        currentSubtitleStream.isExternal == 1) {
      return _PreparedPlaySource(
        playUri: playUri,
        useHlsSubtitleOverlay: false,
      );
    }

    final resolver = HlsPlaylistResolver(
      dio: dio,
      headers: _buildPlayerHeaders(),
    );
    final result = await resolver.resolve(
      playUri,
      subtitleStream: currentSubtitleStream,
    );

    debugPrint(
      '[Player] hls resolve: original=${result.originalUrl}, '
      'play=${result.playUrl}, hasSubtitleMedia=${result.hasSubtitleMedia}, '
      'subtitlePlaylist=${result.subtitlePlaylistUrl}',
    );

    return _PreparedPlaySource(
      playUri: result.playUrl,
      useHlsSubtitleOverlay: result.subtitlePlaylistUrl != null,
      subtitlePlaylistUrl: result.subtitlePlaylistUrl,
    );
  }

  void _disposeHlsSubtitleSession() {
    final repository = _hlsSubtitleRepository;
    final listener = _hlsSubtitleTextsListener;
    if (repository != null && listener != null) {
      repository.visibleTexts.removeListener(listener);
    }
    repository?.dispose();
    _hlsSubtitleRepository = null;
    _hlsSubtitleTextsListener = null;
    _hlsSubtitleTexts.value = const [];
    _useHlsSubtitleOverlay = false;
  }

  void _prepareHlsSubtitleOverlayMode({
    required SubtitleStream? subtitleStream,
    required String? subtitlePlaylistUrl,
  }) {
    _disposeHlsSubtitleSession();
    final shouldUseOverlay = subtitleStream != null &&
        subtitleStream.isExternal != 1 &&
        subtitlePlaylistUrl != null &&
        subtitlePlaylistUrl.isNotEmpty;
    _useHlsSubtitleOverlay = shouldUseOverlay;
    if (shouldUseOverlay) {
      debugPrint(
        '[Player] hls subtitle overlay prepared: playlist=$subtitlePlaylistUrl',
      );
    } else {
      debugPrint('[Player] hls subtitle overlay disabled');
    }
  }

  void _startHlsSubtitleSessionAsync({
    required Dio dio,
    required SubtitleStream? subtitleStream,
    required String? subtitlePlaylistUrl,
    required int startPositionMs,
  }) {
    if (!_useHlsSubtitleOverlay) {
      return;
    }
    unawaited(_configureHlsSubtitleSession(
      dio: dio,
      subtitleStream: subtitleStream,
      subtitlePlaylistUrl: subtitlePlaylistUrl,
      startPositionMs: startPositionMs,
    ));
  }

  Future<void> _configureHlsSubtitleSession({
    required Dio dio,
    required SubtitleStream? subtitleStream,
    required String? subtitlePlaylistUrl,
    required int startPositionMs,
  }) async {
    if (subtitleStream == null ||
        subtitleStream.isExternal == 1 ||
        subtitlePlaylistUrl == null ||
        subtitlePlaylistUrl.isEmpty) {
      _disposeHlsSubtitleSession();
      return;
    }

    final repository = HlsSubtitleRepository(
      dio: dio,
      headers: _buildPlayerHeaders(),
      subtitlePlaylistUrl: subtitlePlaylistUrl,
    );
    void listener() {
      _hlsSubtitleTexts.value = repository.visibleTexts.value;
    }

    repository.visibleTexts.addListener(listener);
    _hlsSubtitleRepository = repository;
    _hlsSubtitleTextsListener = listener;
    _useHlsSubtitleOverlay = true;
    try {
      await repository.initialize(startPositionMs: startPositionMs);
      debugPrint(
        '[Player] hls subtitle overlay enabled: playlist=$subtitlePlaylistUrl',
      );
    } catch (e) {
      debugPrint('[Player] hls subtitle overlay init failed: $e');
      if (_hlsSubtitleRepository == repository) {
        _disposeHlsSubtitleSession();
      }
    }
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
        String playLinkRaw,
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
        playUri: r.playUri,
        playLinkRaw: r.playLinkRaw,
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
          playUri: r.playUri,
          playLinkRaw: r.playLinkRaw,
          effectiveStartMs: r.effectiveStartMs,
          isDirectLink: false,
        );
      }
      rethrow;
    }
  }

  Future<
      ({
        String playUri,
        String playLinkRaw,
        int effectiveStartMs,
      })> _getDirectPlayLink({
    required String mediaGuid,
    required int startPositionMs,
    required String baseUrl,
    required Dio dio,
  }) async {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final controlPlayLink = '/v/api/v1/media/range/$mediaGuid';
    final fullUrl = '$base$controlPlayLink';
    final ts = startPositionMs / 1000.0;
    try {
      final parser = Mp4Parser(dio);
      final offset = await parser.getOffset(fullUrl, ts);
      if (offset > 0) {
        final rangedPlayLink = '$controlPlayLink?range=bytes=$offset-';
        return (
          playUri: '$base$rangedPlayLink',
          playLinkRaw: rangedPlayLink,
          effectiveStartMs: 0,
        );
      }
      return (
        playUri: fullUrl,
        playLinkRaw: controlPlayLink,
        effectiveStartMs: startPositionMs,
      );
    } catch (e) {
      debugPrint('[Player] getDirectPlayLink fallback: $e');
      return (
        playUri: fullUrl,
        playLinkRaw: controlPlayLink,
        effectiveStartMs: startPositionMs,
      );
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
        _currentItemGuid,
        mediaGuid: _currentMediaGuid,
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

      if (_requestedAudioGuid != null) {
        currentAudioStream = audioStreams
            .where((s) => s.guid == _requestedAudioGuid)
            .firstOrNull;
      } else {
        currentAudioStream =
            audioStreams.where((s) => s.isDefault == 1).firstOrNull ??
                audioStreams.firstOrNull;
      }
      if (_requestedSubtitleGuid != null) {
        currentSubtitleStream = subtitleStreams
            .where((s) => s.guid == _requestedSubtitleGuid)
            .firstOrNull;
      } else {
        currentSubtitleStream =
            subtitleStreams.where((s) => s.isDefault == 1).firstOrNull;
      }

      final audioGuid =
          _requestedAudioGuid ?? currentAudioStream?.guid ?? playInfo.audioGuid;
      final subtitleGuid =
          _requestedSubtitleGuid ?? currentSubtitleStream?.guid;
      final episodeList =
          playInfo.item.type == 'Episode' && playInfo.parentGuid.isNotEmpty
              ? await _fetchEpisodeList(playInfo.parentGuid)
              : const <EpisodeListResponse>[];
      final currentEpisode = episodeList
          .where((episode) => episode.guid == _currentItemGuid)
          .firstOrNull;
      final currentEpisodeIndex =
          episodeList.indexWhere((episode) => episode.guid == _currentItemGuid);
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
      final preparedPlaySource = await _preparePlaySourceForMediaKit(
        playUri: resolved.playUri,
        currentSubtitleStream: currentSubtitleStream,
        dio: dio,
      );

      _playingInfoCache = PlayingInfoCache(
        itemGuid: _currentItemGuid,
        parentGuid: playInfo.parentGuid,
        item: playInfo.item,
        currentFileStream: fileStream,
        currentVideoStream: currentVideoStream,
        currentAudioStream: currentAudioStream,
        currentSubtitleStream: currentSubtitleStream,
        currentQualities: qualities,
        currentQuality: _currentQuality,
        currentAudioStreamList: audioStreams,
        currentSubtitleStreamList: subtitleStreams,
        playLink: resolved.playLinkRaw,
        isUseDirectLink: resolved.isDirectLink,
        playConfig: playInfo.playConfig,
        streamInfo: streamInfo,
        isEpisode: playInfo.item.type == 'Episode',
        subhead: _buildDisplaySubhead(playInfo.item),
      );
      ref
          .read(playerViewModelProvider.notifier)
          .updatePlayingInfo(_playingInfoCache);
      _prepareHlsSubtitleOverlayMode(
        subtitleStream: currentSubtitleStream,
        subtitlePlaylistUrl: preparedPlaySource.subtitlePlaylistUrl,
      );

      await _openMediaWithResume(
        playUri: preparedPlaySource.playUri,
        startPositionMs: resolved.effectiveStartMs,
        currentSubtitleStream: currentSubtitleStream,
        isInitialPlayback: true,
      );
      _startHlsSubtitleSessionAsync(
        dio: dio,
        subtitleStream: currentSubtitleStream,
        subtitlePlaylistUrl: preparedPlaySource.subtitlePlaylistUrl,
        startPositionMs: resolved.effectiveStartMs,
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
            guid: _currentItemGuid,
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

  void _handleFlyoutHoverStateChanged(_PlayerFlyoutType type, bool hovered) {
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
    await _switchQualityWithSessionFlow(quality);
  }

  Future<void> _onAudioSelected(AudioStream audio) async {
    await _switchAudioWithSessionFlow(audio);
  }

  Future<void> _onSubtitleSelected(String? subtitleGuid) async {
    final stream = _streamInfo?.subtitleStreams
        ?.where((item) => item.guid == subtitleGuid)
        .firstOrNull;
    await _switchSubtitleWithSessionFlow(stream);
  }

  Future<void> _switchQualityWithSessionFlow(QualityResponse quality) async {
    final cache = _playingInfoCache;
    final player = _player;
    if (cache == null || player == null) {
      return;
    }

    final videoStream = cache.currentVideoStream;
    final fileStream = cache.currentFileStream;
    final currentAudio = cache.currentAudioStream;
    if (videoStream == null || fileStream == null) return;

    try {
      setState(() => _isLoading = true);
      final currentPosition = player.state.position.inMilliseconds;
      final currentPlayLink = cache.playLink;
      final isTargetDirectLink = _supportsDirectLink(
        videoStream,
        quality,
        cache.currentQualities,
      );
      _playingInfoCache = cache.copyWith(
        currentQuality: quality,
        isUseDirectLink: isTargetDirectLink,
        playLink: isTargetDirectLink ? null : cache.playLink,
      );
      ref
          .read(playerViewModelProvider.notifier)
          .updatePlayingInfo(_playingInfoCache);

      if (isTargetDirectLink &&
          !cache.isUseDirectLink &&
          currentPlayLink != null) {
        await ref.read(mediaPViewModelProvider.notifier).quit(
              MediaPRequest(playLink: currentPlayLink),
            );
      } else if (!cache.isUseDirectLink && currentPlayLink != null) {
        await ref.read(mediaPViewModelProvider.notifier).resetQuality(
              MediaPRequest(
                playLink: currentPlayLink,
                quality: MediaPQuality(
                  resolution: quality.resolution,
                  bitrate: quality.bitrate,
                ),
                startTimestamp: currentPosition ~/ 1000,
                clearCache: true,
              ),
            );
      } else {
        final audioGuid = currentAudio?.guid ??
            _selectedAudioGuid ??
            _requestedAudioGuid ??
            _playInfo?.audioGuid ??
            '';
        final playRequest = _createPlayRequest(
          videoStream: videoStream,
          fileStream: fileStream,
          audioGuid: audioGuid,
          subtitleGuid: cache.currentSubtitleStream?.guid,
        );
        final playerService = ref.read(playerServiceProvider);
        final response = await playerService.playVideo(
          PlayPlayRequest(
            mediaGuid: playRequest.mediaGuid,
            videoGuid: playRequest.videoGuid,
            videoEncoder: playRequest.videoEncoder,
            resolution: quality.resolution,
            bitrate: quality.bitrate,
            startTimestamp: currentPosition ~/ 1000,
            audioEncoder: playRequest.audioEncoder,
            audioGuid: playRequest.audioGuid,
            subtitleGuid: playRequest.subtitleGuid,
            channels: playRequest.channels,
            forcedSdr: playRequest.forcedSdr,
          ),
        );
        await _handlePlayPlaySuccess(response,
            startPositionMs: currentPosition);
      }

      setState(() {
        _isLoading = false;
        _currentQuality = quality;
        _currentResolution = quality.resolution;
        _currentBitrate = quality.bitrate;
      });
    } catch (e) {
      debugPrint('[Player] switch quality failed: $e');
      _toastManager.showToast('切换画质失败: $e', type: ToastType.failed);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _switchAudioWithSessionFlow(AudioStream audio) async {
    final cache = _playingInfoCache;
    final currentPlayLink = cache?.playLink;
    final player = _player;
    if (cache == null || currentPlayLink == null || player == null) {
      return;
    }

    final previousAudio = cache.currentAudioStream;
    try {
      setState(() => _isLoading = true);
      _requestedAudioGuid = audio.guid;
      _playingInfoCache = cache.copyWith(currentAudioStream: audio);
      ref
          .read(playerViewModelProvider.notifier)
          .updatePlayingInfo(_playingInfoCache);
      await _callPlayRecordAtCurrentPosition();
      await ref.read(mediaPViewModelProvider.notifier).resetAudio(
            MediaPRequest(
              playLink: currentPlayLink,
              startTimestamp: player.state.position.inMilliseconds ~/ 1000,
              clearCache: true,
              audioEncoder: 'aac',
              channels: 2,
              audioIndex: audio.index,
            ),
          );
      if (mounted) {
        setState(() {
          _selectedAudioGuid = audio.guid;
          _isLoading = false;
        });
      }
    } catch (e) {
      _playingInfoCache = cache.copyWith(currentAudioStream: previousAudio);
      ref
          .read(playerViewModelProvider.notifier)
          .updatePlayingInfo(_playingInfoCache);
      debugPrint('[Player] switch audio failed: $e');
      _toastManager.showToast('切换音频失败: $e', type: ToastType.failed);
      if (mounted) {
        setState(() {
          _selectedAudioGuid = previousAudio?.guid;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _switchSubtitleWithSessionFlow(SubtitleStream? subtitle) async {
    final cache = _playingInfoCache;
    final currentPlayLink = cache?.playLink;
    final player = _player;
    if (cache == null || currentPlayLink == null || player == null) {
      return;
    }

    final previousSubtitle = cache.currentSubtitleStream;
    final subtitleIndex = subtitle == null
        ? null
        : subtitle.isExternal == 1
            ? -1
            : subtitle.index;

    try {
      setState(() => _isLoading = true);
      _requestedSubtitleGuid = subtitle?.guid;
      _playingInfoCache = cache.copyWith(
        previousSubtitle: previousSubtitle,
        currentSubtitleStream: subtitle,
      );
      ref
          .read(playerViewModelProvider.notifier)
          .updatePlayingInfo(_playingInfoCache);
      await _callPlayRecordAtCurrentPosition();
      await ref.read(mediaPViewModelProvider.notifier).resetSubtitle(
            MediaPRequest(
              playLink: currentPlayLink,
              subtitleIndex: subtitleIndex,
              startTimestamp: player.state.position.inMilliseconds ~/ 1000,
            ),
          );
      if (mounted) {
        setState(() {
          _selectedSubtitleGuid = subtitle?.guid;
          _isLoading = false;
        });
      }
    } catch (e) {
      _playingInfoCache = cache.copyWith(
        currentSubtitleStream: previousSubtitle,
        previousSubtitle: previousSubtitle,
      );
      ref
          .read(playerViewModelProvider.notifier)
          .updatePlayingInfo(_playingInfoCache);
      debugPrint('[Player] switch subtitle failed: $e');
      _toastManager.showToast('切换字幕失败: $e', type: ToastType.failed);
      if (mounted) {
        setState(() {
          _selectedSubtitleGuid = previousSubtitle?.guid;
          _isLoading = false;
        });
      }
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
    _positionSubscription?.cancel();
    _disposeHlsSubtitleSession();
    _playRecordTimer?.cancel();
    _hideUiTimer?.cancel();
    _player?.dispose();
    _hlsSubtitleTexts.dispose();
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
        Positioned.fill(
          child: ValueListenableBuilder<List<String>>(
            valueListenable: _hlsSubtitleTexts,
            builder: (context, lines, _) {
              return PlayerSubtitleOverlay(
                lines: lines,
                visible: _useHlsSubtitleOverlay,
              );
            },
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
    final prefs = ref.watch(preferencesManagerProvider);
    final baseUrl = prefs.getBaseUrl() ?? '';
    final token = prefs.getToken();
    final cookie = prefs.getCookie();
    final httpHeaders = token != null || (cookie != null && cookie.isNotEmpty)
        ? {
            if (token != null) 'Authorization': token,
            if (cookie != null && cookie.isNotEmpty) 'Cookie': cookie,
          }
        : null;
    final cacheManager = ref.watch(imageCacheManagerProvider);

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
            baseUrl: baseUrl,
            httpHeaders: httpHeaders,
            cacheManager: cacheManager,
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
            currentEpisodeGuid: _currentItemGuid,
            isAutoPlay: _isAutoPlayEnabled,
            yOffset: _controlFlyoutOffset,
            isActiveControl: _activeFlyout == _PlayerFlyoutType.episode,
            onHoverStateChanged: (hovered) => _handleFlyoutHoverStateChanged(
                _PlayerFlyoutType.episode, hovered),
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
            onHoverStateChanged: (hovered) => _handleFlyoutHoverStateChanged(
                _PlayerFlyoutType.quality, hovered),
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
          onHoverStateChanged: (hovered) => _handleFlyoutHoverStateChanged(
              _PlayerFlyoutType.subtitle, hovered),
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
    return ref.read(playerServiceProvider).getEpisodeList(guid);
  }

  void _openEpisode(EpisodeListResponse episode) {
    if (episode.guid == _currentItemGuid) {
      return;
    }
    unawaited(_switchPlaybackTarget(guid: episode.guid));
  }

  void _showFeatureComingSoon(String feature) {
    _toastManager.showToast('$feature 暂未接入', type: ToastType.info);
  }
}
