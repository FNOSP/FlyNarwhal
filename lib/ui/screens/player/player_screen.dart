import 'dart:async';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart' hide DragToMoveArea;
import '../../../core/network/api_result.dart';
import '../../../data/models/episode_list_response.dart';
import '../../../data/models/media_request_models.dart';
import '../../../data/models/player_models.dart';
import '../../../data/models/movie_detail_models.dart';
import '../../../core/utils/log/app_talker.dart';
import '../../../providers/file_providers.dart';
import '../../../providers/providers.dart';
import '../../player/hls_subtitle_repository.dart';
import '../../player/desktop_pseudo_fullscreen_controller.dart';
import '../../player/pip_window_mode_controller.dart';
import '../../player/player_manager.dart';
import '../../player/media_p_view_model.dart';
import '../../player/player_overlay_controller.dart';
import '../../player/player_session_coordinator.dart';
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
import '../../player/widgets/subtitle_search_dialog.dart';
import '../../widgets/nas/add_nas_subtitle_dialog.dart';
import '../../widgets/toast.dart';
import '../../widgets/window_caption.dart';

enum _PlaybackIndicatorType { play, pause }

class PlayerScreen extends ConsumerStatefulWidget {
  final String guid;
  final String? mediaGuid;
  final String? audioGuid;
  final String? subtitleGuid;
  final int? initialPositionMs;

  const PlayerScreen({
    super.key,
    required this.guid,
    this.mediaGuid,
    this.audioGuid,
    this.subtitleGuid,
    this.initialPositionMs,
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with TickerProviderStateMixin, WindowListener {
  static const int _controlFlyoutOffset = 15;
  static const double _trailingControlSpacing = 12;
  static const Duration _playbackIndicatorVisibleDuration =
      Duration(milliseconds: 200);
  static const Duration _playbackIndicatorExitDuration =
      Duration(milliseconds: 300);
  static const Duration _hlsSubtitleInitTimeout = Duration(seconds: 5);

  late final ToastManager _toastManager;
  Player? _player;
  VideoController? _videoController;
  bool _isInitialized = false;
  bool _isLoading = true;
  bool _isPlaying = false;
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
  StreamSubscription<bool>? _playingSubscription;
  Timer? _playRecordTimer;
  Timer? _playbackIndicatorTimer;
  late final AnimationController _playbackIndicatorExitController;
  int _lastRecordedPosition = 0;
  int _pendingInitialResumeMs = 0;
  bool _initialResumeApplied = false;
  bool _hasSetupProviderListeners = false;
  bool _suspendPlaybackTransitionFeedback = true;
  bool _isPlaybackIndicatorVisible = false;
  _PlaybackIndicatorType? _playbackIndicatorType;
  int _loadRequestToken = 0;
  int _hlsSessionToken = 0;
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
  Map<String, String> _iso6391Map = const {};
  Map<String, String> _iso6392Map = const {};
  bool _showSubtitleSearchDialog = false;
  bool _showAddNasSubtitleDialog = false;
  bool _isUploadingLocalSubtitle = false;
  final DesktopPseudoFullscreenController _fullscreenController =
      DesktopPseudoFullscreenController();
  final PipWindowModeController _pipController = PipWindowModeController();
  bool _isPipMode = false;
  bool _isPipHovered = false;
  bool _isPipTransitioning = false;
  Timer? _pipBoundsSaveTimer;
  AnimationController? _pipTransitionController;

  PlayerOverlayController get _overlayController =>
      ref.read(playerOverlayControllerProvider.notifier);

  PlayerSessionCoordinator get _sessionCoordinator =>
      ref.read(playerSessionCoordinatorProvider);

  @override
  void initState() {
    super.initState();
    if (_isDesktopPlatform()) {
      windowManager.addListener(this);
      unawaited(_syncFullscreenState());
    }
    _toastManager = ToastManager();
    _playbackIndicatorExitController = AnimationController(
      vsync: this,
      duration: _playbackIndicatorExitDuration,
    )..addStatusListener((status) {
        if (status != AnimationStatus.completed || !mounted) {
          return;
        }
        setState(() => _isPlaybackIndicatorVisible = false);
        _playbackIndicatorExitController.value = 0;
      });
    _pipTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _syncPlaybackTargetsFromWidget();
    unawaited(_ensureSubtitleLanguageMapsLoaded());
    _initializePlayer();
  }

  @override
  void didUpdateWidget(covariant PlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final routeArgsChanged = oldWidget.guid != widget.guid ||
        oldWidget.mediaGuid != widget.mediaGuid ||
        oldWidget.audioGuid != widget.audioGuid ||
        oldWidget.subtitleGuid != widget.subtitleGuid ||
        oldWidget.initialPositionMs != widget.initialPositionMs;
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
    _setupPlayerPlaybackListener();
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

  void _setupPlayerPlaybackListener() {
    _playingSubscription?.cancel();
    final player = _player;
    if (player == null) return;

    _isPlaying = player.state.playing;
    _playingSubscription = player.stream.playing.listen((isPlaying) {
      _handlePlaybackStateChanged(isPlaying);
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
          AppTalker.warning('Player', 'mediaP state error: $nextError');
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

    ref.listenManual<SubtitleSettings>(
      subtitleSettingsProvider,
      (previous, next) {
        if (!mounted) return;
        if (previous?.offsetSeconds == next.offsetSeconds) {
          return;
        }
        _syncSubtitleOffsetToHlsRepository(next);
      },
    );
  }

  Future<void> _ensureSubtitleLanguageMapsLoaded() async {
    if (_iso6391Map.isNotEmpty && _iso6392Map.isNotEmpty) {
      return;
    }
    try {
      final tagRepository = ref.read(iTagRepositoryProvider);
      final results = await Future.wait<ApiResult<Map<String, String>>>([
        tagRepository.getTag('iso6391'),
        tagRepository.getTag('iso6392'),
      ]);
      if (!mounted) return;
      setState(() {
        _iso6391Map = results[0].dataOrNull ?? const <String, String>{};
        _iso6392Map = results[1].dataOrNull ?? const <String, String>{};
      });
    } catch (error) {
      AppTalker.warning('Player', 'load subtitle language tags failed: $error');
    }
  }

  String _resolveCurrentFilePath() {
    return _playingInfoCache?.currentFileStream?.path ?? '';
  }

  Future<void> _refreshSubtitleStreams({String? targetTrimId}) async {
    final cache = _playingInfoCache;
    if (cache == null) return;

    final result = await _sessionCoordinator.refreshSubtitleStreams(
      cache: cache,
      selectedSubtitleGuid: _selectedSubtitleGuid,
      targetTrimId: targetTrimId,
    );
    _playingInfoCache = result.playingInfoCache;
    ref
        .read(playerViewModelProvider.notifier)
        .updatePlayingInfo(result.playingInfoCache);

    if (!mounted) return;
    setState(() {
      _streamInfo = result.streamInfo;
      _selectedSubtitleGuid = result.selectedSubtitle?.guid;
      _requestedSubtitleGuid = result.selectedSubtitle?.guid;
    });
  }

  Future<void> _openSubtitleSearchDialog() async {
    if (_showSubtitleSearchDialog) return;
    final currentFile = _playingInfoCache?.currentFileStream;
    if (currentFile == null || currentFile.guid.isEmpty) {
      _toastManager.showToast('当前文件信息缺失，无法搜索字幕', type: ToastType.info);
      return;
    }

    setState(() => _showSubtitleSearchDialog = true);
    try {
      await showDialog<void>(
        context: context,
        builder: (_) => SubtitleSearchDialog(
          mediaFileName: currentFile.fileName,
          initialTrimIds:
              (_playingInfoCache?.currentSubtitleStreamList ?? const [])
                  .map((subtitle) => subtitle.trimId)
                  .where((trimId) => trimId.isNotEmpty)
                  .toList(),
          onSearch: (language) {
            return ref.read(fileRepositoryProvider).searchSubtitles(
                  mediaGuid: currentFile.guid,
                  language: language,
                );
          },
          onDownload: (item) async {
            try {
              await ref.read(fileRepositoryProvider).downloadSubtitle(
                    mediaGuid: currentFile.guid,
                    trimId: item.trimId,
                  );
              await _refreshSubtitleStreams(targetTrimId: item.trimId);
              if (!mounted) return;
              _toastManager.showToast('字幕下载成功', type: ToastType.success);
            } catch (error) {
              if (mounted) {
                _toastManager.showToast('下载字幕失败: $error',
                    type: ToastType.failed);
              }
              rethrow;
            }
          },
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _showSubtitleSearchDialog = false);
      }
    }
  }

  Future<void> _openAddNasSubtitleDialog() async {
    if (_showAddNasSubtitleDialog) return;
    final mediaGuid = _playingInfoCache?.currentFileStream?.guid ?? '';
    if (mediaGuid.isEmpty) {
      _toastManager.showToast('当前文件信息缺失，无法添加 NAS 字幕', type: ToastType.info);
      return;
    }

    setState(() => _showAddNasSubtitleDialog = true);
    try {
      await showDialog<void>(
        context: context,
        builder: (_) => AddNasSubtitleDialog(
          title: '添加 NAS 字幕文件',
          currentPath: _resolveCurrentFilePath(),
          onConfirm: (paths) async {
            try {
              await ref
                  .read(fileRepositoryProvider)
                  .markSubtitle(mediaGuid, paths);
              await _refreshSubtitleStreams();
              if (!mounted) return;
              _toastManager.showToast('NAS 字幕添加成功', type: ToastType.success);
            } catch (error) {
              if (!mounted) return;
              _toastManager.showToast('添加 NAS 字幕失败: $error',
                  type: ToastType.failed);
            }
          },
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _showAddNasSubtitleDialog = false);
      }
    }
  }

  Future<void> _pickAndUploadLocalSubtitle() async {
    final currentFile = _playingInfoCache?.currentFileStream;
    if (_isUploadingLocalSubtitle) return;
    if (currentFile == null || currentFile.guid.isEmpty) {
      _toastManager.showToast('当前文件信息缺失，无法上传字幕', type: ToastType.info);
      return;
    }

    const subtitleTypeGroup = XTypeGroup(
      label: '字幕文件',
      extensions: ['ass', 'srt', 'vtt', 'sub', 'ssa'],
    );

    try {
      final file = await openFile(
        acceptedTypeGroups: [subtitleTypeGroup],
        confirmButtonText: '选择',
      );
      if (file == null) return;

      setState(() => _isUploadingLocalSubtitle = true);
      final bytes = await file.readAsBytes();
      await ref.read(fileRepositoryProvider).uploadSubtitle(
            guid: currentFile.guid,
            bytes: bytes,
            fileName: file.name,
          );
      await _refreshSubtitleStreams();
      if (!mounted) return;
      _toastManager.showToast('电脑字幕文件上传成功', type: ToastType.success);
    } catch (error) {
      if (mounted) {
        _toastManager.showToast('上传字幕失败: $error', type: ToastType.failed);
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingLocalSubtitle = false);
      }
    }
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
      AppTalker.warning('Player', 'quit media failed: $e');
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

    final headers = _sessionCoordinator.buildPlayerHeaders();
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

  PlayRecordRequest? _buildPlayRecordRequest({
    required int positionSeconds,
  }) {
    final cache = _playingInfoCache;
    final fileStream = cache?.currentFileStream;
    final videoStream = cache?.currentVideoStream;
    if (cache == null || fileStream == null || videoStream == null) {
      return null;
    }

    final quality = cache.currentQuality;
    return PlayRecordRequest(
      itemGuid: cache.itemGuid ?? _currentItemGuid,
      mediaGuid: fileStream.guid,
      videoGuid: videoStream.guid,
      audioGuid: cache.currentAudioStream?.guid ?? '',
      subtitleGuid: cache.currentSubtitleStream?.guid,
      resolution: quality?.resolution ?? videoStream.resolutionType,
      bitrate: quality?.bitrate ?? videoStream.bps,
      ts: positionSeconds,
      duration: videoStream.duration,
      playLink: cache.playLink,
    );
  }

  Future<void> _callPlayRecordAtCurrentPosition() async {
    final player = _player;
    if (player == null) return;
    final position = player.state.position.inMilliseconds;
    if (position < 0) return;
    final request = _buildPlayRecordRequest(positionSeconds: position ~/ 1000);
    if (request == null) return;

    try {
      await ref.read(playerServiceProvider).updatePlayRecord(request);
    } catch (e) {
      AppTalker.warning(
        'Player',
        'play record update during switch failed: $e',
      );
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

    final playUri = _sessionCoordinator.absolutePlayUrl(baseUrl, playLink);
    final dio = ref.read(dioClientProvider).dio;
    final prepared = await _sessionCoordinator.preparePlaySourceForMediaKit(
      playUri: playUri,
      currentSubtitleStream: cache.currentSubtitleStream,
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
      loadToken: _loadRequestToken,
    );
  }

  Future<void> _reopenPlaybackWithDirectLink({
    required int startPositionMs,
  }) async {
    final cache = _playingInfoCache;
    final videoStream = cache?.currentVideoStream;
    if (cache == null || videoStream == null) return;

    final directLink = await _sessionCoordinator.getDirectPlayLink(
      mediaGuid: videoStream.mediaGuid,
      startPositionMs: startPositionMs,
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
      AppTalker.warning('Player', 'handle quit success failed: $e');
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
              _sessionCoordinator.looksLikeM3u8(cache.playLink!)
          ? (await _sessionCoordinator.preparePlaySourceForMediaKit(
              playUri:
                  _sessionCoordinator.absolutePlayUrl(baseUrl, cache.playLink!),
              currentSubtitleStream: cache.currentSubtitleStream,
            ))
              .subtitlePlaylistUrl
          : null;
      final startPositionMs = _player?.state.position.inMilliseconds ?? 0;
      _prepareHlsSubtitleOverlayMode(
        subtitleStream: cache.currentSubtitleStream,
        subtitlePlaylistUrl: subtitlePlaylistUrl,
      );
      await _applyCurrentSubtitleTrack(cache.currentSubtitleStream);
      if (!mounted) {
        return;
      }
      _startHlsSubtitleSessionAsync(
        dio: dio,
        subtitleStream: cache.currentSubtitleStream,
        subtitlePlaylistUrl: subtitlePlaylistUrl,
        startPositionMs: startPositionMs,
        loadToken: _loadRequestToken,
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
          _selectedSubtitleGuid = cache.currentSubtitleStream?.guid;
        });
      }
    } catch (e) {
      AppTalker.warning(
        'Player',
        'handle reset subtitle success failed: $e',
      );
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
      AppTalker.warning('Player', 'apply external subtitle failed: $e');
      if (player == _player) {
        await player.setSubtitleTrack(SubtitleTrack.no());
      }
    }
  }

  void _disposeHlsSubtitleSession() {
    // Invalidate stale async subtitle startup work before clearing the session.
    _hlsSessionToken++;
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
      AppTalker.info(
        'Player',
        'hls subtitle overlay prepared: playlist=$subtitlePlaylistUrl',
      );
    } else {
      AppTalker.info('Player', 'hls subtitle overlay disabled');
    }
  }

  void _syncSubtitleOffsetToHlsRepository(SubtitleSettings settings) {
    _hlsSubtitleRepository?.updateSubtitleOffsetSeconds(settings.offsetSeconds);
  }

  void _startHlsSubtitleSessionAsync({
    required Dio dio,
    required SubtitleStream? subtitleStream,
    required String? subtitlePlaylistUrl,
    required int startPositionMs,
    int? loadToken,
  }) {
    if (!_useHlsSubtitleOverlay) {
      return;
    }
    final sessionToken = ++_hlsSessionToken;
    unawaited(_configureHlsSubtitleSession(
      dio: dio,
      subtitleStream: subtitleStream,
      subtitlePlaylistUrl: subtitlePlaylistUrl,
      startPositionMs: startPositionMs,
      sessionToken: sessionToken,
      loadToken: loadToken,
    ));
  }

  Future<void> _configureHlsSubtitleSession({
    required Dio dio,
    required SubtitleStream? subtitleStream,
    required String? subtitlePlaylistUrl,
    required int startPositionMs,
    required int sessionToken,
    int? loadToken,
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
      headers: _sessionCoordinator.buildPlayerHeaders(),
      subtitlePlaylistUrl: subtitlePlaylistUrl,
    );
    repository.updateSubtitleOffsetSeconds(
      ref.read(subtitleSettingsProvider).offsetSeconds,
    );
    try {
      // Keep subtitle startup best-effort so video recovery is never blocked.
      await repository
          .initialize(startPositionMs: startPositionMs)
          .timeout(_hlsSubtitleInitTimeout);
      final isStaleSession = !mounted ||
          _hlsSessionToken != sessionToken ||
          (loadToken != null && loadToken != _loadRequestToken);
      if (isStaleSession) {
        repository.dispose();
        return;
      }

      void listener() {
        if (_hlsSessionToken != sessionToken) {
          return;
        }
        _hlsSubtitleTexts.value = repository.visibleTexts.value;
      }

      repository.visibleTexts.addListener(listener);
      _hlsSubtitleRepository = repository;
      _hlsSubtitleTextsListener = listener;
      _hlsSubtitleTexts.value = repository.visibleTexts.value;
      _useHlsSubtitleOverlay = true;
      AppTalker.info(
        'Player',
        'hls subtitle overlay enabled: playlist=$subtitlePlaylistUrl',
      );
    } catch (e) {
      repository.dispose();
      AppTalker.warning(
        'Player',
        'hls subtitle overlay init failed: $e',
      );
      if (_hlsSessionToken == sessionToken) {
        _hlsSubtitleTexts.value = const [];
        _useHlsSubtitleOverlay = false;
      }
    }
  }

  Future<void> _loadAndPlayMedia() async {
    final requestToken = ++_loadRequestToken;
    try {
      _suspendPlaybackTransitionFeedback = true;
      _hidePlaybackIndicator();
      setState(() => _isLoading = true);

      final dio = ref.read(dioClientProvider).dio;
      final result = await _sessionCoordinator.loadSession(
        PlayerRouteTarget(
          guid: _currentItemGuid,
          mediaGuid: _currentMediaGuid,
          audioGuid: _requestedAudioGuid,
          subtitleGuid: _requestedSubtitleGuid,
        ),
      );
      if (!mounted || requestToken != _loadRequestToken) {
        return;
      }

      _playInfo = result.playInfo;
      _streamInfo = result.streamInfo;
      _playingInfoCache = result.playingInfoCache;
      _qualities = result.qualities;
      _currentQuality = result.currentQuality;
      final initialResumeMs =
          widget.initialPositionMs ?? (result.playInfo.ts * 1000);
      _resetInitialResumeState(initialResumeMs);
      ref
          .read(playerViewModelProvider.notifier)
          .updatePlayingInfo(result.playingInfoCache);
      _prepareHlsSubtitleOverlayMode(
        subtitleStream: result.playingInfoCache.currentSubtitleStream,
        subtitlePlaylistUrl: result.preparedPlaySource.subtitlePlaylistUrl,
      );

      await _openMediaWithResume(
        playUri: result.preparedPlaySource.playUri,
        startPositionMs:
            widget.initialPositionMs ?? result.effectiveStartPositionMs,
        currentSubtitleStream: result.playingInfoCache.currentSubtitleStream,
        isInitialPlayback: true,
      );
      if (!mounted || requestToken != _loadRequestToken) {
        return;
      }
      _startHlsSubtitleSessionAsync(
        dio: dio,
        subtitleStream: result.playingInfoCache.currentSubtitleStream,
        subtitlePlaylistUrl: result.preparedPlaySource.subtitlePlaylistUrl,
        startPositionMs:
            widget.initialPositionMs ?? result.effectiveStartPositionMs,
        loadToken: requestToken,
      );

      _volume = ref.read(playerSettingsManagerProvider).getVolume();
      await _player!.setVolume(_volume * 100);

      _speed = ref.read(playerSettingsManagerProvider).getSpeed();
      await _player!.setRate(_speed);

      setState(() {
        _isLoading = false;
        _isInitialized = true;
        _isPlaying = _player?.state.playing ?? false;
        _duration = result.playingInfoCache.currentVideoStream!.duration > 0
            ? result.playingInfoCache.currentVideoStream!.duration * 1000
            : result.playInfo.item.duration * 1000;
        _currentResolution = _currentQuality?.resolution ?? '';
        _currentBitrate = _currentQuality?.bitrate;
        _selectedAudioGuid = result.audioGuid;
        _selectedSubtitleGuid = result.subtitleGuid;
        _episodeList = result.episodeList;
        _currentEpisode = result.currentEpisode;
        _nextEpisode = result.nextEpisode;
      });

      await _ensureInitialResumeApplied();
      _startPlayRecordTimer();
      _suspendPlaybackTransitionFeedback = false;
    } catch (e, st) {
      AppTalker.error(
        'Player',
        error: e,
        stackTrace: st,
        message: 'Error loading media',
      );
      _toastManager.showToast(
        '加载失败: $e',
        type: ToastType.failed,
      );
      _suspendPlaybackTransitionFeedback = false;
    } finally {
      // Always clear the loading flag for the active request, covering the
      // early-return paths above where the request stays current but never
      // reached the success branch (e.g. a superseded or aborted load).
      if (mounted && requestToken == _loadRequestToken && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startPlayRecordTimer() {
    _playRecordTimer?.cancel();
    _playRecordTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!_isInitialized || _player == null) return;

      final position = _player!.state.position.inMilliseconds;
      if (position != _lastRecordedPosition && position > 0) {
        _lastRecordedPosition = position;
        final request =
            _buildPlayRecordRequest(positionSeconds: position ~/ 1000);
        if (request == null) return;
        try {
          final playerService = ref.read(playerServiceProvider);
          await playerService.updatePlayRecord(request);
        } catch (_) {
          // Ignore record errors
        }
      }
    });
  }

  void _showUi() {
    _overlayController.showUi(isPlaying: _isPlaying);
  }

  void _handlePlaybackStateChanged(bool isPlaying) {
    final wasPlaying = _isPlaying;
    if (mounted && wasPlaying != isPlaying) {
      setState(() => _isPlaying = isPlaying);
    } else {
      _isPlaying = isPlaying;
    }

    if (_suspendPlaybackTransitionFeedback || wasPlaying == isPlaying) {
      return;
    }

    if (!isPlaying) {
      _showPlaybackIndicator(_PlaybackIndicatorType.pause);
    } else {
      _showPlaybackIndicator(_PlaybackIndicatorType.play);
    }
    _showUi();
  }

  void _showPlaybackIndicator(_PlaybackIndicatorType type) {
    _playbackIndicatorTimer?.cancel();
    _playbackIndicatorExitController.stop();
    _playbackIndicatorExitController.value = 0;

    if (mounted) {
      setState(() {
        _playbackIndicatorType = type;
        _isPlaybackIndicatorVisible = true;
      });
    } else {
      _playbackIndicatorType = type;
      _isPlaybackIndicatorVisible = true;
    }

    _playbackIndicatorTimer = Timer(_playbackIndicatorVisibleDuration, () {
      if (!mounted || !_isPlaybackIndicatorVisible) return;
      _playbackIndicatorExitController.forward(from: 0);
    });
  }

  void _hidePlaybackIndicator() {
    _playbackIndicatorTimer?.cancel();
    _playbackIndicatorExitController.stop();
    _playbackIndicatorExitController.value = 0;
    _playbackIndicatorType = null;
    _isPlaybackIndicatorVisible = false;
  }

  void _handleFlyoutHoverStateChanged(PlayerFlyoutType type, bool hovered) {
    _overlayController.setFlyoutHovered(type, hovered);
  }

  void _handleNextEpisodeHoverStateChanged(bool hovered) {
    _handleFlyoutHoverStateChanged(PlayerFlyoutType.nextEpisode, hovered);
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
    try {
      final isFullscreen = await _fullscreenController.toggle();
      if (!mounted) {
        return;
      }

      setState(() => _isFullscreen = isFullscreen);
    } catch (error, stackTrace) {
      AppTalker.error(
        'Player',
        error: error,
        stackTrace: stackTrace,
        message: 'toggle fullscreen failed',
      );
      if (mounted) {
        _toastManager.showToast('切换全屏失败: $error', type: ToastType.failed);
      }
    }
  }

  Future<void> _enterPipMode() async {
    AppTalker.info('PiP', 'PiP requested from player screen');
    if (!_isDesktopPlatform()) {
      _showFeatureComingSoon('画中画');
      return;
    }

    final player = _player;
    if (player == null || !_isInitialized) {
      _toastManager.showToast('播放器尚未准备完成', type: ToastType.info);
      return;
    }

    try {
      _isPipTransitioning = true;
      _dismissTransientPlayerUiBeforeExit();

      // Persist playback progress before shrinking the window.
      await _callPlayRecordAtCurrentPosition();

      // Reuse the same window and the same player by switching the window into
      // a compact, borderless, always-on-top form.
      await _pipController.enter();
      if (!mounted) {
        return;
      }
      setState(() {
        _isPipMode = true;
        _isPipHovered = false;
      });
      _pipTransitionController?.forward(from: 0);
    } catch (error, stackTrace) {
      AppTalker.error(
        'Player',
        error: error,
        stackTrace: stackTrace,
        message: 'enter PiP failed',
      );
      // Roll back to the normal window form on any failure.
      try {
        await _pipController.exit();
      } catch (_) {}
      if (mounted) {
        setState(() => _isPipMode = false);
        _toastManager.showToast('进入画中画失败: $error', type: ToastType.failed);
      }
    } finally {
      _isPipTransitioning = false;
    }
  }

  Future<void> _exitPipMode() async {
    if (!_isPipMode || _isPipTransitioning) {
      return;
    }
    try {
      _isPipTransitioning = true;
      _pipBoundsSaveTimer?.cancel();
      await _pipController.persistCurrentBounds();
      await _pipController.exit();
      if (!mounted) {
        return;
      }
      setState(() {
        _isPipMode = false;
        _isPipHovered = false;
      });
      _pipTransitionController?.reverse(from: 1);
    } catch (error, stackTrace) {
      AppTalker.error(
        'Player',
        error: error,
        stackTrace: stackTrace,
        message: 'exit PiP failed',
      );
      if (mounted) {
        _toastManager.showToast('退出画中画失败: $error', type: ToastType.failed);
      }
    } finally {
      _isPipTransitioning = false;
    }
  }

  void _schedulePipBoundsSave() {
    if (!_isPipMode) {
      return;
    }
    _pipBoundsSaveTimer?.cancel();
    _pipBoundsSaveTimer = Timer(
      const Duration(milliseconds: 400),
      () => unawaited(_pipController.persistCurrentBounds()),
    );
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
      final isTargetDirectLink = _sessionCoordinator.supportsDirectLink(
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
        final playRequest = _sessionCoordinator.createPlayRequest(
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
      AppTalker.warning('Player', 'switch quality failed: $e');
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
      AppTalker.warning('Player', 'switch audio failed: $e');
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
      AppTalker.warning('Player', 'switch subtitle failed: $e');
      _toastManager.showToast('切换字幕失败: $e', type: ToastType.failed);
      if (mounted) {
        setState(() {
          _selectedSubtitleGuid = previousSubtitle?.guid;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleBack() async {
    await _leavePlayerRoute(() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    });
  }

  Future<void> _closeFromPip() async {
    await _exitPipMode();
    if (!mounted) return;
    await _handleBack();
  }

  // Dismiss transient overlays before leaving the player route.
  void _dismissTransientPlayerUiBeforeExit() {
    _playRecordTimer?.cancel();
    _playbackIndicatorTimer?.cancel();
    _hidePlaybackIndicator();
    Tooltip.dismissAllToolTips();
    _overlayController.dismissTransientUi();
  }

  Future<void> _leavePlayerRoute(VoidCallback onLeave) async {
    _dismissTransientPlayerUiBeforeExit();

    // Restore the host window before leaving the fullscreen player route.
    await _restoreWindowModeBeforeLeave();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      onLeave();
    });
  }

  @override
  void dispose() {
    if (_isDesktopPlatform()) {
      windowManager.removeListener(this);
      unawaited(_fullscreenController.exitForRouteLeave());
      // Ensure the window is restored to its normal form when leaving while in
      // PiP mode so the next route is not stuck in a tiny borderless window.
      if (_pipController.isPipMode) {
        unawaited(_pipController.exit());
      }
    }
    _pipBoundsSaveTimer?.cancel();
    _positionSubscription?.cancel();
    _playingSubscription?.cancel();
    _disposeHlsSubtitleSession();
    _playRecordTimer?.cancel();
    _playbackIndicatorTimer?.cancel();
    _playbackIndicatorExitController.dispose();
    _pipTransitionController?.dispose();
    _player?.dispose();
    _hlsSubtitleTexts.dispose();
    _toastManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtitleSettings = ref.watch(subtitleSettingsProvider);
    final overlayState = ref.watch(playerOverlayControllerProvider);
    final pipTransition = _pipTransitionController;
    final playerStack = Stack(
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onHover: (_) => _showUi(),
          child: GestureDetector(
            onTap: _togglePlayPause,
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
                settings: subtitleSettings,
              );
            },
          ),
        ),
        if (_isLoading) const Center(child: ProgressRing()),
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: _buildPlaybackIndicator(),
            ),
          ),
        ),
        if (_isInitialized && !_isPipMode)
          AnimatedOpacity(
            opacity: overlayState.isUiVisible ? 1.0 : 0.0,
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
                      _overlayController.setHovered(
                        PlayerHoverZone.bottomControls,
                        true,
                      );
                      _showUi();
                    },
                    onExit: (_) => _overlayController.setHovered(
                      PlayerHoverZone.bottomControls,
                      false,
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildProgressBar(),
                            const SizedBox(height: 12),
                            _buildControlButtons(
                              overlayState: overlayState,
                              subtitleSettings: subtitleSettings,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (_isInitialized && _isPipMode) _buildPipOverlay(),
        Positioned.fill(
          child: ToastHost(toastManager: _toastManager),
        ),
      ],
    );

    if (pipTransition == null) {
      return playerStack;
    }
    return AnimatedBuilder(
      animation: pipTransition,
      builder: (context, child) {
        final t = Curves.easeInOutCubic.transform(pipTransition.value);
        return Transform.scale(
          scale: 1.0 - t * 0.08,
          child: child,
        );
      },
      child: playerStack,
    );
  }

  Widget _buildPipDragLayer() {
    // DragToMoveArea lets the user drag the borderless PiP window by its body.
    return Positioned.fill(
      child: DragToMoveArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _togglePlayPause,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  Widget _buildPipOverlay() {
    return Positioned.fill(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isPipHovered = true),
        onExit: (_) => setState(() => _isPipHovered = false),
        child: Stack(
          children: [
            _buildPipDragLayer(),
            if (_isPipHovered) ...[
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.24),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.38),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: PlayerActionButton.icon(
                  key: const ValueKey('pip-close'),
                  iconData: FluentIcons.chrome_close,
                  tooltip: '关闭',
                  onPressed: () => unawaited(_closeFromPip()),
                  size: 28,
                  iconSize: 14,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              Positioned(
                left: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: PlayerActionButton.svg(
                    key: const ValueKey('pip-seek-backward'),
                    svgAssetPath: 'assets/images/back10s.svg',
                    tooltip: '快退 10 秒',
                    onPressed: () => _seekRelative(-10000),
                    size: 38,
                    iconSize: 24,
                    borderRadius: BorderRadius.circular(19),
                  ),
                ),
              ),
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: PlayerActionButton.svg(
                    key: const ValueKey('pip-seek-forward'),
                    svgAssetPath: 'assets/images/forward10s.svg',
                    tooltip: '快进 10 秒',
                    onPressed: () => _seekRelative(10000),
                    size: 38,
                    iconSize: 24,
                    borderRadius: BorderRadius.circular(19),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 44,
                child: _buildPipProgressBar(),
              ),
              Positioned(
                left: 8,
                bottom: 6,
                child: VolumeControl(
                  volume: _volume,
                  popupBottomOffset: 36,
                  onVolumeChange: _setVolume,
                ),
              ),
              Positioned(
                right: 10,
                bottom: 8,
                child: PlayerActionButton.lottie(
                  key: const ValueKey('pip-exit'),
                  lottieAssetPath: 'assets/lottie/quit_pip.json',
                  tooltip: '退出画中画',
                  onPressed: () => unawaited(_exitPipMode()),
                  size: 30,
                  iconSize: 22,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPipProgressBar() {
    return StreamBuilder<Duration>(
      stream: _player?.stream.position,
      builder: (context, snapshot) {
        _currentPosition = snapshot.data?.inMilliseconds ?? _currentPosition;
        return VideoPlayerProgressBar(
          currentPosition: _currentPosition,
          totalDuration: _duration,
          onSeek: _seekTo,
        );
      },
    );
  }

  Widget _buildProgressBar() {
    return StreamBuilder<Duration>(
      stream: _player?.stream.position,
      builder: (context, snapshot) {
        _currentPosition = snapshot.data?.inMilliseconds ?? _currentPosition;
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) =>
              _overlayController.setHovered(PlayerHoverZone.progressBar, true),
          onExit: (_) =>
              _overlayController.setHovered(PlayerHoverZone.progressBar, false),
          child: VideoPlayerProgressBar(
            currentPosition: _currentPosition,
            totalDuration: _duration,
            onSeek: _seekTo,
          ),
        );
      },
    );
  }

  Widget _buildControlButtons({
    required PlayerOverlayState overlayState,
    required SubtitleSettings subtitleSettings,
  }) {
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
          key: const ValueKey('player-play-pause'),
          svgAssetPath:
              _isPlaying ? 'assets/images/pause.svg' : 'assets/images/play.svg',
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
            isActiveControl:
                overlayState.activeFlyout == PlayerFlyoutType.nextEpisode,
            onClick: () => _openEpisode(_nextEpisode!),
            onHoverStateChanged: _handleNextEpisodeHoverStateChanged,
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
        // Keep the trailing control cluster visually consistent.
        SpeedControlFlyout(
          key: const ValueKey('player-speed-control'),
          defaultSpeed: _speed,
          yOffset: _controlFlyoutOffset,
          isActiveControl: overlayState.activeFlyout == PlayerFlyoutType.speed,
          onHoverStateChanged: (hovered) =>
              _handleFlyoutHoverStateChanged(PlayerFlyoutType.speed, hovered),
          onSpeedSelected: (speed) => _setSpeed(speed.value),
        ),
        const SizedBox(width: _trailingControlSpacing),
        if (_episodeList.isNotEmpty && _displaySubhead.isNotEmpty) ...[
          EpisodeSelectionFlyout(
            episodes: _episodeList,
            currentEpisodeGuid: _currentItemGuid,
            isAutoPlay: overlayState.isAutoPlayEnabled,
            yOffset: _controlFlyoutOffset,
            isActiveControl:
                overlayState.activeFlyout == PlayerFlyoutType.episode,
            onHoverStateChanged: (hovered) => _handleFlyoutHoverStateChanged(
                PlayerFlyoutType.episode, hovered),
            onEpisodeSelected: _openEpisode,
            onAutoPlayChanged: _overlayController.setAutoPlayEnabled,
          ),
          const SizedBox(width: _trailingControlSpacing),
        ],
        if (_qualities.isNotEmpty)
          QualityControlFlyout(
            qualities: _qualities,
            currentResolution: _currentResolution,
            currentBitrate: _currentBitrate,
            yOffset: _controlFlyoutOffset,
            isActiveControl:
                overlayState.activeFlyout == PlayerFlyoutType.quality,
            onHoverStateChanged: (hovered) => _handleFlyoutHoverStateChanged(
                PlayerFlyoutType.quality, hovered),
            onQualitySelected: _onQualitySelected,
          ),
        const SizedBox(width: _trailingControlSpacing),
        MouseRegion(
          onEnter: (_) => _overlayController.setHovered(
              PlayerHoverZone.danmakuControl, true),
          onExit: (_) => _overlayController.setHovered(
            PlayerHoverZone.danmakuControl,
            false,
          ),
          child: PlayerActionButton.svg(
            svgAssetPath: overlayState.isDanmakuVisible
                ? 'assets/images/danmu_open.svg'
                : 'assets/images/danmu_close.svg',
            onPressed: () {
              _overlayController.toggleDanmakuVisibility();
              _showFeatureComingSoon('弹幕');
            },
            tooltip: '弹幕',
            size: 30,
            iconSize: 20,
          ),
        ),
        const SizedBox(width: _trailingControlSpacing),
        MouseRegion(
          onEnter: (_) => _overlayController.setHovered(
            PlayerHoverZone.danmakuSettings,
            true,
          ),
          onExit: (_) => _overlayController.setHovered(
            PlayerHoverZone.danmakuSettings,
            false,
          ),
          child: PlayerActionButton.svg(
            svgAssetPath: 'assets/images/danmu_setting.svg',
            onPressed: () => _showFeatureComingSoon('弹幕设置'),
            tooltip: '弹幕设置',
            size: 30,
            iconSize: 20,
          ),
        ),
        const SizedBox(width: _trailingControlSpacing),
        SubtitleControlFlyout(
          subtitles: _playingInfoCache?.currentSubtitleStreamList ?? const [],
          selectedSubtitleGuid: _selectedSubtitleGuid,
          iso6391Map: _iso6391Map,
          iso6392Map: _iso6392Map,
          subtitleSettings: subtitleSettings,
          canAdjustSubtitle: _canAdjustSubtitle,
          yOffset: _controlFlyoutOffset,
          isActiveControl:
              overlayState.activeFlyout == PlayerFlyoutType.subtitle,
          onHoverStateChanged: (hovered) => _handleFlyoutHoverStateChanged(
              PlayerFlyoutType.subtitle, hovered),
          onSubtitleSettingsChanged: (settings) =>
              ref.read(subtitleSettingsProvider.notifier).state = settings,
          onSubtitleSelected: _onSubtitleSelected,
          onOpenSubtitleSearch: _openSubtitleSearchDialog,
          onOpenAddNasSubtitle: _openAddNasSubtitleDialog,
          onOpenAddLocalSubtitle: _pickAndUploadLocalSubtitle,
        ),
        const SizedBox(width: _trailingControlSpacing),
        PlayerSettingsMenu(
          playingInfoCache: _playingInfoCache,
          iso6391Map: _iso6391Map,
          currentPositionMillis: _currentPosition,
          totalDurationMillis: _duration,
          popupBottomOffset: _controlFlyoutOffset.toDouble(),
          onHoverStateChanged: (hovered) => _overlayController.setHovered(
            PlayerHoverZone.settingsMenu,
            hovered,
          ),
          onAudioSelected: _onAudioSelected,
          onWindowAspectRatioChanged: (_) {},
          onSkipConfigChanged: (_, __) {},
        ),
        const SizedBox(width: _trailingControlSpacing),
        VolumeControl(
          key: const ValueKey('player-volume-control'),
          volume: _volume,
          popupBottomOffset: _controlFlyoutOffset.toDouble(),
          onHoverStateChanged: (hovered) => _overlayController.setHovered(
            PlayerHoverZone.volumeControl,
            hovered,
          ),
          onVolumeChange: _setVolume,
        ),
        const SizedBox(width: _trailingControlSpacing),
        MouseRegion(
          onEnter: (_) =>
              _overlayController.setHovered(PlayerHoverZone.pipControl, true),
          onExit: (_) =>
              _overlayController.setHovered(PlayerHoverZone.pipControl, false),
          child: PlayerActionButton.lottie(
            key: const ValueKey('player-enter-pip'),
            lottieAssetPath: 'assets/lottie/to_pip.json',
            onPressed: () => unawaited(_enterPipMode()),
            tooltip: '画中画',
            size: 30,
            iconSize: 22,
          ),
        ),
        const SizedBox(width: _trailingControlSpacing),
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

  Widget _buildPlaybackIndicator() {
    if (!_isPlaybackIndicatorVisible || _playbackIndicatorType == null) {
      return const SizedBox.shrink();
    }

    final animation = CurvedAnimation(
      parent: _playbackIndicatorExitController,
      curve: Curves.easeOutCubic,
    );

    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0).animate(animation),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1, end: 1.18).animate(animation),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.5),
          ),
          alignment: Alignment.center,
          child: SvgPicture.asset(
            _playbackIndicatorType == _PlaybackIndicatorType.pause
                ? 'assets/images/pause.svg'
                : 'assets/images/play.svg',
            width: 34,
            height: 34,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
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

  Future<void> _syncFullscreenState() async {
    final isFullscreen = await _fullscreenController.syncState();
    if (!mounted || _isFullscreen == isFullscreen) {
      return;
    }

    setState(() => _isFullscreen = isFullscreen);
  }

  Future<void> _restoreWindowModeBeforeLeave() async {
    if (!_isDesktopPlatform()) {
      return;
    }

    final isFullscreen = await _fullscreenController.exitForRouteLeave();
    if (!mounted || _isFullscreen == isFullscreen) {
      return;
    }

    setState(() => _isFullscreen = isFullscreen);
  }

  bool _isDesktopPlatform() {
    return !kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
  }

  @override
  void onWindowEnterFullScreen() {
    if (!mounted) {
      return;
    }

    setState(() => _isFullscreen = true);
  }

  @override
  void onWindowLeaveFullScreen() {
    if (!mounted) {
      return;
    }

    setState(() => _isFullscreen = false);
  }

  @override
  void onWindowMoved() => _schedulePipBoundsSave();

  @override
  void onWindowResized() => _schedulePipBoundsSave();

  bool get _canAdjustSubtitle {
    return _useHlsSubtitleOverlay &&
        (_playingInfoCache?.currentSubtitleStream != null ||
            _hlsSubtitleTexts.value.isNotEmpty);
  }

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
    return _sessionCoordinator.buildDisplaySubhead(
      item,
      episodeNumber:
          _currentEpisode?.episodeNumber ?? _playInfo?.item.episodeNumber ?? 0,
    );
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
