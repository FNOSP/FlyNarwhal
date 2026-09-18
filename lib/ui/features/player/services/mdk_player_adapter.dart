import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:fvp/mdk.dart' as mdk;

import '../../../../core/utils/log/app_talker.dart';

/// Decoded video size, mirroring the fields the player screens read from
/// media_kit's `VideoParams`.
///
/// [dw]/[dh] are the pixel-aspect-corrected display size (what the picture
/// actually looks like); [w]/[h] are the raw decoded size. Window auto-ratio
/// logic prefers the display size.
class VideoSize {
  const VideoSize({
    required this.w,
    required this.h,
    required this.dw,
    required this.dh,
  });

  final int w;
  final int h;
  final int dw;
  final int dh;
}

/// Thin adapter over the fvp/mdk backend player that presents the subset of
/// the media_kit API this app relies on.
///
/// mdk is an imperative, callback-driven player: playback position is a plain
/// getter rather than an event stream, and there is no texture widget. This
/// class closes those two gaps so the player screens keep consuming
/// `Stream<Duration>` / `Stream<bool>` / `Stream<VideoSize>` values and a
/// single view widget.
class MdkPlayerAdapter {
  MdkPlayerAdapter({bool lowLatency = false}) {
    _player = mdk.Player();
    if (lowLatency) {
      _player.setBufferRange(min: 0);
    }
    // fvp 0.38 exposes player notifications as broadcast streams instead of
    // single callback slots; keep the subscriptions to cancel them on dispose.
    _playerSubscriptions.addAll([
      _player.onStateChanged.listen(
        (event) => _handleStateChanged(event.oldValue, event.newValue),
      ),
      _player.onMediaStatus.listen(
        (event) => _handleMediaStatus(event.oldValue, event.newValue),
      ),
      _player.onEvent.listen(_handleEvent),
    ]);
  }

  /// How often the synthesized position/buffer streams are refreshed. mdk only
  /// exposes `position` as a getter, so it has to be polled.
  static const Duration _tickInterval = Duration(milliseconds: 200);

  late final mdk.Player _player;
  Timer? _ticker;
  final List<StreamSubscription<dynamic>> _playerSubscriptions = [];

  final _positionController = StreamController<Duration>.broadcast();
  final _bufferController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();
  final _playingController = StreamController<bool>.broadcast();
  final _bufferingController = StreamController<bool>.broadcast();
  final _completedController = StreamController<bool>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _videoSizeController = StreamController<VideoSize>.broadcast();
  final _trackListController = StreamController<void>.broadcast();

  int _lastPositionMs = 0;
  bool _disposed = false;
  bool _hasLoadedMedia = false;
  bool _subtitlesRendered = true;

  /// True while [open] is in flight. Switching media stops the previous
  /// playback, and mdk delivers that as a `stopped` state event; without this
  /// guard the stop of the OLD media is misread as the NEW session finishing,
  /// popping the playback-end overlay in the middle of a quality switch.
  bool _openingMedia = false;

  /// True between an explicit [stop] call and the resulting `stopped` event,
  /// so an app-initiated stop is not reported as playback completion.
  bool _stopRequested = false;

  /// How close to the end the position must be for a `stopped` event to count
  /// as real playback completion.
  static const int _completedProximityMs = 1500;

  /// Playback position stream, synthesized from the 200ms ticker plus explicit
  /// emits on seek and after opening media.
  Stream<Duration> get position => _positionController.stream;

  /// Buffer-ahead position stream: the end of the buffered range, matching what
  /// media_kit reported.
  Stream<Duration> get buffer => _bufferController.stream;

  Stream<Duration> get duration => _durationController.stream;
  Stream<bool> get playing => _playingController.stream;
  Stream<bool> get buffering => _bufferingController.stream;
  Stream<bool> get completed => _completedController.stream;
  Stream<String> get error => _errorController.stream;
  Stream<VideoSize> get videoParams => _videoSizeController.stream;

  /// Emits whenever the media's stream list changes (new media loaded), so
  /// callers can re-read [audioStreams]/[subtitleStreams].
  Stream<void> get trackListChanges => _trackListController.stream;

  int get positionMs => _disposed ? 0 : _player.position;

  /// Media duration. `mediaInfo` is only populated once media has loaded, so
  /// this reports 0 (matching media_kit's pre-load state) until then.
  int get durationMs {
    if (_disposed || !_hasLoadedMedia) return 0;
    return _player.mediaInfo.duration;
  }

  bool get isPlaying => !_disposed && _player.state == mdk.PlaybackState.playing;

  double get volume => _disposed ? 0 : _player.volume;
  bool get mute => !_disposed && _player.mute;
  double get playbackRate => _disposed ? 1 : _player.playbackRate;

  /// Raw mdk player, for properties and decoders this adapter does not wrap.
  mdk.Player get raw => _player;

  VideoSize? get videoSize => _readVideoSize();

  int? get activeSubtitleIndex {
    if (_disposed) return null;
    final track = _player.activeSubtitleTracks;
    if (track.isEmpty) return null;
    return _streamIndexOfOrdinal(subtitleStreams, track.first);
  }

  int? get activeAudioIndex {
    if (_disposed) return null;
    final track = _player.activeAudioTracks;
    if (track.isEmpty) return null;
    return _streamIndexOfOrdinal(audioStreams, track.first);
  }

  /// Converts a container stream index (what `StreamInfo.index` reports and
  /// what the rest of the app works in) to mdk's per-type track ordinal — the
  /// position of the stream within [streams], which is what `setActiveTracks`
  /// and `activeTracks` actually use. Returns -1 when not found.
  ///
  /// These two numbering schemes differ whenever a media has streams of more
  /// than one type: e.g. a file laid out as video=stream0, audio=stream1 has a
  /// single audio track whose container index is 1 but whose audio ordinal is
  /// 0. Feeding the container index (1) to `setActiveTracks` asks for a
  /// non-existent 2nd audio track; mdk deactivates the real track, ignores the
  /// invalid ordinal, and leaves the player with no active audio — silence.
  int _trackOrdinal(List<mdk.StreamInfo> streams, int streamIndex) {
    for (var i = 0; i < streams.length; i++) {
      if (streams[i].index == streamIndex) return i;
    }
    return -1;
  }

  /// Inverse of [_trackOrdinal]: converts an mdk per-type track ordinal back to
  /// the container stream index. Returns null when out of range.
  int? _streamIndexOfOrdinal(List<mdk.StreamInfo> streams, int ordinal) {
    if (ordinal < 0 || ordinal >= streams.length) return null;
    return streams[ordinal].index;
  }

  /// Audio stream list of the currently loaded media.
  List<mdk.AudioStreamInfo> get audioStreams => _loadedMediaInfo?.audio ?? const [];

  /// Subtitle stream list of the currently loaded media. Includes externally
  /// added tracks, which appear after the embedded ones.
  List<mdk.SubtitleStreamInfo> get subtitleStreams =>
      _loadedMediaInfo?.subtitle ?? const [];

  mdk.MediaInfo? get _loadedMediaInfo {
    if (_disposed || !_hasLoadedMedia) return null;
    return _player.mediaInfo;
  }

  /// Opens [uri], applying custom HTTP headers and an optional start position.
  ///
  /// Playback starts automatically, matching the previous player's `open()`
  /// behaviour (callers never issue a separate play call after opening). Use
  /// [pause] to hold on the first frame.
  ///
  /// When [preferHdrRenderPath] is set and the decoded stream turns out to be
  /// HDR, the player renders through a platform view instead of a Flutter
  /// texture. The Flutter texture path is 8-bit and caps output at SDR, so HDR
  /// sources can only reach the display through the platform view's
  /// EDR-enabled CAMetalLayer.
  ///
  /// Returns true when the media prepared successfully. On failure an error is
  /// emitted on [error] and this returns false.
  Future<bool> open({
    required String uri,
    Map<String, String>? httpHeaders,
    int startPositionMs = 0,
    bool preferHdrRenderPath = false,
  }) async {
    if (_disposed) return false;
    _openingMedia = true;
    try {
      return await _openInternal(
        uri: uri,
        httpHeaders: httpHeaders,
        startPositionMs: startPositionMs,
        preferHdrRenderPath: preferHdrRenderPath,
      );
    } finally {
      _openingMedia = false;
    }
  }

  Future<bool> _openInternal({
    required String uri,
    Map<String, String>? httpHeaders,
    int startPositionMs = 0,
    bool preferHdrRenderPath = false,
  }) async {
    _hasLoadedMedia = false;
    _lastPositionMs = 0;
    _usingHdrRenderPath = false;
    _externalSubtitleLoaded = false;

    _player.setProperty('avio.headers', _encodeHeaders(httpHeaders));

    // Assign the media before probing for its video size. fvp resolves
    // `updateTexture` from a per-media size completer that is only completed by
    // this media's own `loading -> loaded` transition; with no media assigned
    // nothing ever completes it and the await never returns, which strands
    // `open()` — and with it the caller's loading flag — forever.
    //
    // `prepare()` is what drives that transition, so it runs before the probe:
    // the probe then finds the size already resolved rather than waiting on a
    // decode that would not start until prepare() ran.
    _player.media = uri;

    final result = await _player.prepare(position: startPositionMs);
    if (_disposed) return false;

    if (result < 0) {
      _errorController.add('media prepare failed (code $result)');
      return false;
    }

    // Drop any render target from the previous media now that the new
    // container is parsed and its size known.
    await _player.updateTexture(width: -1);

    if (preferHdrRenderPath && _isHdrStream()) {
      final switched = await _player.usePlatformView();
      if (switched) {
        _usingHdrRenderPath = true;
        hdrRenderPathActive.value = true;
        _hdrRenderPathController.add(true);
      }
    }
    if (!_usingHdrRenderPath) {
      await _player.updateTexture();
    }
    if (_disposed) return false;

    _hasLoadedMedia = true;
    // prepare() leaves the player paused on the first frame.
    _player.state = mdk.PlaybackState.playing;
    _emitPosition(startPositionMs);
    _emitDuration();
    _emitVideoSize();
    _trackListController.add(null);
    _startTicker();
    return true;
  }

  /// Whether HDR sources should be presented through the platform-view
  /// renderer. Set by the player screen from the platform/display capability.
  bool _hdrRenderPathEnabled = false;

  set hdrRenderPathEnabled(bool value) {
    _hdrRenderPathEnabled = value;
  }

  /// Whether the current media is being rendered through the platform view.
  /// While true the Flutter-side video widgets and subtitle overlay must not
  /// be used: the native layer composites above Flutter's own layers.
  bool get isUsingHdrRenderPath => _usingHdrRenderPath;

  bool _usingHdrRenderPath = false;

  /// Whether the current media is rendering through the platform view, as a
  /// listenable so the video widget can swap its renderer.
  final hdrRenderPathActive = ValueNotifier<bool>(false);

  /// Emits true when a session switches to the platform-view renderer, so the
  /// UI can swap the video widget and drop overlays it can no longer show.
  final _hdrRenderPathController = StreamController<bool>.broadcast();
  Stream<bool> get hdrRenderPathChanges => _hdrRenderPathController.stream;

  /// The player's native handle, used as the platform view's `player`
  /// creation parameter.
  int get nativeHandle => _player.nativeHandle;

  /// True when the decoded video carries an HDR transfer function.
  ///
  /// Reads the decoder's own colour space rather than the backend's
  /// `color_range_type`, so the decision reflects what is actually being
  /// decoded — a transcoded session may deliver SDR even for an HDR source.
  ///
  /// PQ and HLG are the two BT.2100 HDR transfer functions; scRGB (linear,
  /// values above 1.0) can carry the same extended range. All three must go
  /// through the platform-view renderer: the Flutter texture path is 8-bit and
  /// its Metal blit deadlocks on 10-bit HDR buffers, freezing playback after
  /// the first frame.
  bool _isHdrStream() {
    if (!_hdrRenderPathEnabled) return false;
    final videos = _player.mediaInfo.video;
    if (videos == null || videos.isEmpty) {
      return false;
    }
    final codec = videos.first.codec;
    final colorSpace = codec.colorSpace;
    final isHdr = colorSpace == mdk.ColorSpace.bt2100PQ ||
        colorSpace == mdk.ColorSpace.bt2100hlg ||
        colorSpace == mdk.ColorSpace.scrgb;
    return isHdr;
  }

  void play() {
    if (_disposed) return;
    _player.state = mdk.PlaybackState.playing;
    _startTicker();
  }

  void pause() {
    if (_disposed) return;
    _player.state = mdk.PlaybackState.paused;
    _stopTicker();
    _emitPosition(_player.position);
  }

  void stop() {
    if (_disposed) return;
    _stopRequested = true;
    _stopTicker();
    _player.state = mdk.PlaybackState.stopped;
    _emitPosition(0);
  }

  Future<void> seek(Duration target) async {
    if (_disposed) return;
    await _player.seek(position: target.inMilliseconds);
    if (_disposed) return;
    _emitPosition(target.inMilliseconds);
  }

  /// Whether mdk is in the middle of an internal seek.
  bool get isSeeking =>
      !_disposed && _player.mediaStatus.test(mdk.MediaStatus.seeking);

  /// Waits until an in-flight internal seek finishes.
  ///
  /// Issuing a new seek while mdk is still flushing a previous one (the
  /// `prepare()` resume seek, a track-change seek) can deadlock its pipeline:
  /// the reader stops delivering packets, the seek never completes and
  /// playback is frozen at the seek target forever. Callers that schedule a
  /// seek right after opening media must let the initial seek finish first.
  ///
  /// Returns true once mdk is idle, or false when [timeout] elapsed while a
  /// seek was still in flight (the caller decides whether to proceed).
  Future<bool> waitForSeekIdle({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final stopwatch = Stopwatch()..start();
    while (!_disposed &&
        _player.mediaStatus.test(mdk.MediaStatus.seeking) &&
        stopwatch.elapsed < timeout) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    final idle = !_disposed &&
        !_player.mediaStatus.test(mdk.MediaStatus.seeking);
    return idle;
  }

  /// Volume uses the app's UI scale (0-100) so existing call sites, including
  /// the macOS gain in `player_volume_helper.dart`, keep working unchanged.
  /// mdk expects a raw multiplier where 1.0 is the source level.
  void setVolume(double uiVolume) {
    if (_disposed) return;
    _player.volume = (uiVolume / 100.0).clamp(0.0, 1.0);
  }

  void setMute(bool value) {
    if (_disposed) return;
    _player.mute = value;
  }

  void setRate(double rate) {
    if (_disposed) return;
    _player.playbackRate = rate;
  }

  /// Selects an embedded audio track by its container stream index.
  ///
  /// Setting the already-active track is skipped: mdk still runs a full
  /// deactivate/reactivate cycle for it, which besides being wasted work can
  /// trip mdk's deactivate-path deadlock while the pipeline is still filling
  /// after a seek.
  void setAudioTrack(int streamIndex) {
    if (_disposed) return;
    final ordinal = _trackOrdinal(audioStreams, streamIndex);
    if (ordinal < 0) return;
    final active = _player.activeAudioTracks;
    if (active.length == 1 && active.first == ordinal) return;
    _player.activeAudioTracks = [ordinal];
  }

  /// Selects a subtitle track by its container stream index. Passing null turns
  /// subtitles off.
  void setSubtitleTrack(int? streamIndex) {
    if (_disposed) return;
    final active = _player.activeSubtitleTracks;
    if (streamIndex == null) {
      // Turning subtitles off must clear the render flag too, not just the
      // active track. `_applySubtitleVisibility()` below re-writes the
      // `subtitle` property from `_subtitlesRendered`, so leaving that flag
      // true would clear the track and then immediately switch the renderer
      // back on: the track list reads empty while the subtitle is still on
      // screen. mdk's renderer keys on the property, not on the track.
      _subtitlesRendered = false;
      // Same rationale as setAudioTrack: skip the no-op deactivate cycle.
      if (active.isNotEmpty) {
        _player.activeSubtitleTracks = const [];
      }
    } else {
      final ordinal = _trackOrdinal(subtitleStreams, streamIndex);
      if (ordinal < 0) {
        _applySubtitleVisibility();
        return;
      }
      if (active.length == 1 && active.first == ordinal) {
        _applySubtitleVisibility();
        return;
      }
      // Keep the render flag in step with the selection: a track that was
      // switched off earlier must render again once the user picks one.
      _subtitlesRendered = true;
      _player.activeSubtitleTracks = [ordinal];
    }
    _applySubtitleVisibility();
  }

  /// Loads an external subtitle from decoded text content.
  ///
  /// mdk takes a URL/path for external subtitles rather than raw text, so the
  /// content is written to [subtitleCacheDirectory] and loaded from there.
  /// Returns the new track's index, or null when it could not be added.
  ///
  /// The file name encodes [title]/[language] so the track can be matched back
  /// to the server-side subtitle stream, since mdk exposes no other metadata
  /// for externally added tracks.
  Future<int?> addExternalSubtitle(
    String content, {
    required Directory subtitleCacheDirectory,
    String? title,
    String? language,
    String? format,
  }) async {
    if (_disposed) return null;
    final extension = _normalizeSubtitleFormat(format);
    final fileName = _externalSubtitleFileName(
      title: title,
      language: language,
      extension: extension,
    );
    final file = File('${subtitleCacheDirectory.path}/$fileName');
    await file.parent.create(recursive: true);
    await file.writeAsString(content, flush: true);
    if (_disposed) return null;

    // Replacing an external track: mdk keeps the previous one until it is
    // cleared explicitly.
    _player.setMedia('', mdk.MediaType.subtitle);

    final before = subtitleStreams.length;
    _player.setMedia(file.path, mdk.MediaType.subtitle);
    final streams = subtitleStreams;
    if (streams.length <= before) return null;

    final index = streams.last.index;
    _externalSubtitleTitles[index] = _externalSubtitleLabel(
      title: title,
      language: language,
      extension: extension,
    );
    final ordinal = _trackOrdinal(subtitleStreams, index);
    if (ordinal >= 0) {
      _player.activeSubtitleTracks = [ordinal];
    }
    _externalSubtitleLoaded = true;
    // Loading the file must not change whether subtitles are rendered: this
    // can run while the user has subtitles switched off (the off path still
    // applies settings), and forcing the property back on would silently undo
    // that choice.
    return index;
  }

  /// Drops the externally loaded subtitle track.
  ///
  /// mdk keeps an external track active until it is cleared, so switching back
  /// to an embedded track requires this first. Skipped when no external track
  /// is loaded: `setMedia('', subtitle)` still runs a deactivate cycle inside
  /// mdk for nothing, which can trip its deactivate-path deadlock.
  void removeExternalSubtitle() {
    if (_disposed) return;
    if (!_externalSubtitleLoaded) return;
    _externalSubtitleLoaded = false;
    _player.setMedia('', mdk.MediaType.subtitle);
    _externalSubtitleTitles.clear();
  }

  /// Whether an external subtitle file is currently loaded into the player.
  bool _externalSubtitleLoaded = false;

  /// Turns subtitle rendering off without discarding the selected track.
  void hideSubtitles() {
    if (_disposed) return;
    _subtitlesRendered = false;
    _applySubtitleVisibility();
  }

  void showSubtitles() {
    if (_disposed) return;
    _subtitlesRendered = true;
    _applySubtitleVisibility();
  }

  void _applySubtitleVisibility() {
    _player.setProperty('subtitle', _subtitlesRendered ? '1' : '0');
  }

  /// The name under which an externally added subtitle track is labelled,
  /// matching what the track resolvers compare against.
  String externalSubtitleLabelAt(int index) =>
      _externalSubtitleTitles[index] ?? '';

  final _externalSubtitleTitles = <int, String>{};

  void setProperty(String name, String value) {
    if (_disposed) return;
    _player.setProperty(name, value);
  }

  String? getProperty(String name) => _disposed ? null : _player.getProperty(name);

  void setBufferRange({int min = -1, int max = -1, bool drop = false}) {
    if (_disposed) return;
    _player.setBufferRange(min: min, max: max, drop: drop);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _stopTicker();
    for (final subscription in _playerSubscriptions) {
      await subscription.cancel();
    }
    _playerSubscriptions.clear();
    _player.dispose();
    await _positionController.close();
    await _bufferController.close();
    await _durationController.close();
    await _playingController.close();
    await _bufferingController.close();
    await _completedController.close();
    await _errorController.close();
    await _videoSizeController.close();
    await _trackListController.close();
    await _hdrRenderPathController.close();
    hdrRenderPathActive.dispose();
  }

  void _handleStateChanged(mdk.PlaybackState oldState, mdk.PlaybackState newState) {
    if (_disposed) return;
    _playingController.add(newState == mdk.PlaybackState.playing);
    if (newState == mdk.PlaybackState.stopped) {
      _stopTicker();
      _emitPosition(_player.position);
      final stopRequested = _stopRequested;
      _stopRequested = false;
      // A `stopped` event alone does not mean the media finished: switching
      // media stops the previous playback (delivered asynchronously, possibly
      // after the new open() completed), and an explicit stop() is not a
      // completion either. Only report completion when the position actually
      // reached the end.
      final nearEnd = _isPositionNearEnd();
      if (!_openingMedia && !stopRequested && nearEnd) {
        _completedController.add(true);
      }
    }
  }

  /// Whether the current position is at (or within [_completedProximityMs] of)
  /// the media's end. Live streams have no end, and an unknown duration cannot
  /// prove completion.
  bool _isPositionNearEnd() {
    if (_player.isLive) return false;
    if (!_hasLoadedMedia) return false;
    final duration = _player.mediaInfo.duration;
    if (duration <= 0) return false;
    return _player.position >= duration - _completedProximityMs;
  }

  void _handleMediaStatus(mdk.MediaStatus oldStatus, mdk.MediaStatus newStatus) {
    if (_disposed) return;

    final wasBuffering = oldStatus.test(mdk.MediaStatus.buffering);
    final isBuffering = newStatus.test(mdk.MediaStatus.buffering);
    if (wasBuffering != isBuffering) {
      _bufferingController.add(isBuffering);
    }

    final wasLoaded = oldStatus.test(mdk.MediaStatus.loaded);
    final isLoaded = newStatus.test(mdk.MediaStatus.loaded);
    if (!wasLoaded && isLoaded) {
      _emitDuration();
      _emitVideoSize();
      _trackListController.add(null);
    }

    final wasEnd = oldStatus.test(mdk.MediaStatus.end);
    final isEnd = newStatus.test(mdk.MediaStatus.end);
    if (!wasEnd && isEnd) {
      _stopTicker();
      _emitPosition(_player.position);
      // Ignore an end delivered for the previous media while a new one is
      // being opened (quality switch): it is not this session's completion.
      if (!_openingMedia) {
        _completedController.add(true);
      }
    }
  }

  void _handleEvent(mdk.MediaEvent event) {
    if (_disposed) return;
    if (event.category == 'decoder.video' ||
        (event.category == 'video' && event.detail == 'size')) {
      _emitVideoSize();
      _trackListController.add(null);
      return;
    }
    // The `error` field is not an error flag: mdk uses it as a numeric payload
    // (buffering progress, thread ids, frame timestamps). Only the categories
    // below indicate a real failure.
    if (_isErrorCategory(event.category)) {
      final detail = event.detail.isEmpty ? event.category : event.detail;
      AppTalker.warning('Player', 'mdk error event: $detail');
      _errorController.add(detail);
      return;
    }
    AppTalker.info('Player', 'mdk event: ${event.category} - ${event.detail}');
  }

  static bool _isErrorCategory(String category) {
    return category.contains('error') || category.contains('invalid');
  }

  void _startTicker() {
    _ticker ??= Timer.periodic(_tickInterval, (_) => _tick());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _tick() {
    if (_disposed || !_hasLoadedMedia) return;
    final current = _player.position;
    if (current != _lastPositionMs) {
      _emitPosition(current);
      final buffered = _player.buffered();
      _bufferController.add(Duration(milliseconds: current + buffered));
    }
  }

  void _emitPosition(int milliseconds) {
    if (milliseconds < 0) return;
    _lastPositionMs = milliseconds;
    if (!_positionController.isClosed) {
      _positionController.add(Duration(milliseconds: milliseconds));
    }
  }

  void _emitDuration() {
    final duration = durationMs;
    if (duration <= 0) return;
    if (!_durationController.isClosed) {
      _durationController.add(Duration(milliseconds: duration));
    }
  }

  void _emitVideoSize() {
    final size = _readVideoSize();
    if (size == null) return;
    if (!_videoSizeController.isClosed) {
      _videoSizeController.add(size);
    }
  }

  VideoSize? _readVideoSize() {
    final info = _loadedMediaInfo;
    if (info == null) return null;
    final streams = info.video;
    if (streams == null || streams.isEmpty) return null;
    final stream = streams.first;
    final codec = stream.codec;
    if (codec.width <= 0 || codec.height <= 0) return null;

    // mdk reports the raw frame size plus a pixel aspect ratio; the display
    // size corrects for anamorphic sources. A 90/270 degree rotation swaps
    // the axes.
    final rawWidth = codec.width;
    final rawHeight = (codec.height / codec.par).round();
    if (stream.rotation % 180 == 90) {
      return VideoSize(
        w: rawHeight,
        h: rawWidth,
        dw: rawHeight,
        dh: rawWidth,
      );
    }
    return VideoSize(w: rawWidth, h: rawHeight, dw: rawWidth, dh: rawHeight);
  }

  static String _encodeHeaders(Map<String, String>? headers) {
    if (headers == null || headers.isEmpty) return '';
    final buffer = StringBuffer();
    headers.forEach((key, value) {
      buffer.write('$key: $value\r\n');
    });
    return buffer.toString();
  }

  static String _externalSubtitleFileName({
    String? title,
    String? language,
    required String extension,
  }) {
    final stem = (title == null || title.isEmpty) ? 'subtitle' : title;
    final languagePart =
        (language == null || language.isEmpty) ? '' : '_$language';
    final safeStem = stem.replaceAll(RegExp(r'[^\w\-.]'), '_');
    return 'fvp_sub_$safeStem$languagePart.$extension';
  }

  static String _externalSubtitleLabel({
    String? title,
    String? language,
    required String extension,
  }) {
    final stem = (title == null || title.isEmpty) ? 'subtitle' : title;
    final languageSuffix =
        (language == null || language.isEmpty) ? '' : '.$language';
    return '$stem$languageSuffix.$extension';
  }

  static String _normalizeSubtitleFormat(String? format) {
    if (format == null || format.isEmpty) return 'srt';
    final normalized = format.toLowerCase().trim();
    return switch (normalized) {
      'subrip' => 'srt',
      'ass' || 'ssa' => 'ass',
      'vtt' || 'webvtt' => 'vtt',
      'pgs' || 'sup' => 'sup',
      _ => normalized,
    };
  }

  @visibleForTesting
  static String debugNormalizeSubtitleFormat(String? format) =>
      _normalizeSubtitleFormat(format);

  @visibleForTesting
  static String debugSubtitleFileName({
    String? title,
    String? language,
    required String extension,
  }) =>
      _externalSubtitleFileName(
        title: title,
        language: language,
        extension: extension,
      );
}
