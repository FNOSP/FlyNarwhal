import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'hls_playlist_resolver.dart';
import 'hls_webvtt_parser.dart';
import 'models/hls_subtitle_cue.dart';

/// Fetches HLS WebVTT segments and exposes the currently visible subtitles.
class HlsSubtitleRepository {
  static const Duration _minimumFetchInterval = Duration(seconds: 2);
  static const int _prefetchWindowMs = 30000;
  static const int _seekThresholdMs = 3000;

  final String subtitlePlaylistUrl;
  final HlsPlaylistResolver _resolver;
  final HlsWebVttParser _parser = const HlsWebVttParser();

  final ValueNotifier<List<String>> visibleTexts = ValueNotifier(const []);

  final List<HlsSubtitleSegment> _segments = <HlsSubtitleSegment>[];
  final List<HlsSubtitleCue> _cues = <HlsSubtitleCue>[];
  final Set<int> _fetchedSegmentIndices = <int>{};

  bool _disposed = false;
  bool _initialized = false;
  int _lastObservedPositionMs = -1;
  int _lastFetchCheckEpochMs = 0;
  Future<void>? _pendingFetch;

  HlsSubtitleRepository({
    required Dio dio,
    required Map<String, String> headers,
    required this.subtitlePlaylistUrl,
  }) : _resolver = HlsPlaylistResolver(dio: dio, headers: headers);

  Future<void> initialize({int startPositionMs = 0}) async {
    if (_disposed || _initialized) {
      return;
    }
    final playlistContent = await _resolver.fetchContent(subtitlePlaylistUrl);
    _segments
      ..clear()
      ..addAll(_parseSegments(playlistContent));
    _initialized = true;
    await _fetchSegmentsAround(startPositionMs);
    _updateVisibleTexts(startPositionMs);
  }

  void onPlaybackPosition(int positionMs) {
    if (_disposed || !_initialized) {
      return;
    }

    final isSeek = _lastObservedPositionMs >= 0 &&
        (positionMs - _lastObservedPositionMs).abs() > _seekThresholdMs;
    _lastObservedPositionMs = positionMs;
    _updateVisibleTexts(positionMs);

    if (_shouldFetch(positionMs, force: isSeek)) {
      _pendingFetch ??= _fetchSegmentsAround(positionMs)
          .whenComplete(() => _pendingFetch = null);
    }
  }

  void dispose() {
    _disposed = true;
    visibleTexts.dispose();
  }

  bool _shouldFetch(int positionMs, {required bool force}) {
    if (_segments.isEmpty || _disposed) {
      return false;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    if (force) {
      _lastFetchCheckEpochMs = now;
      return true;
    }
    if (now - _lastFetchCheckEpochMs < _minimumFetchInterval.inMilliseconds) {
      return false;
    }
    _lastFetchCheckEpochMs = now;

    final windowEndMs = positionMs + _prefetchWindowMs;
    return _segments.any((segment) =>
        segment.overlapsWindow(positionMs, windowEndMs) &&
        !_fetchedSegmentIndices.contains(segment.index));
  }

  Future<void> _fetchSegmentsAround(int positionMs) async {
    if (_disposed || !_initialized) {
      return;
    }
    final windowEndMs = positionMs + _prefetchWindowMs;
    final targets = _segments.where((segment) {
      return segment.overlapsWindow(positionMs, windowEndMs) &&
          !_fetchedSegmentIndices.contains(segment.index);
    }).toList();

    for (final segment in targets) {
      if (_disposed) {
        return;
      }
      try {
        _fetchedSegmentIndices.add(segment.index);
        final content = await _resolver.fetchContent(
            _resolver.resolveUrl(subtitlePlaylistUrl, segment.uri));
        final result = _parser.parse(content);
        final cues = result.cues
            .map((cue) => HlsSubtitleCue(
                  startTimeMs: _normalizeCueStartTimeMs(
                    cue.startTimeMs,
                    segment.startTimeMs,
                    result.timestampMapLocalMs,
                  ),
                  endTimeMs: _normalizeCueEndTimeMs(
                    cue.endTimeMs,
                    segment.startTimeMs,
                    result.timestampMapLocalMs,
                  ),
                  text: cue.text,
                ))
            .where((cue) => cue.endTimeMs > cue.startTimeMs)
            .toList();
        if (cues.isNotEmpty) {
          _mergeCues(cues);
          _updateVisibleTexts(_lastObservedPositionMs);
        }
      } catch (_) {
        _fetchedSegmentIndices.remove(segment.index);
      }
    }
  }

  int _normalizeCueStartTimeMs(
    int rawStartTimeMs,
    int segmentStartTimeMs,
    int timestampMapLocalMs,
  ) {
    if (rawStartTimeMs >= math.max(0, segmentStartTimeMs - 5000)) {
      return rawStartTimeMs;
    }
    return segmentStartTimeMs +
        math.max(0, rawStartTimeMs - timestampMapLocalMs);
  }

  int _normalizeCueEndTimeMs(
    int rawEndTimeMs,
    int segmentStartTimeMs,
    int timestampMapLocalMs,
  ) {
    if (rawEndTimeMs >= math.max(0, segmentStartTimeMs - 5000)) {
      return rawEndTimeMs;
    }
    return segmentStartTimeMs + math.max(0, rawEndTimeMs - timestampMapLocalMs);
  }

  void _mergeCues(List<HlsSubtitleCue> cues) {
    _cues.addAll(cues);
    _cues.sort((a, b) => a.startTimeMs.compareTo(b.startTimeMs));

    final deduplicated = <HlsSubtitleCue>[];
    for (final cue in _cues) {
      final duplicate = deduplicated.any((existing) =>
          existing.startTimeMs == cue.startTimeMs &&
          existing.endTimeMs == cue.endTimeMs &&
          existing.text == cue.text);
      if (!duplicate) {
        deduplicated.add(cue);
      }
    }
    _cues
      ..clear()
      ..addAll(deduplicated);
  }

  void _updateVisibleTexts(int positionMs) {
    if (positionMs < 0) {
      _setVisibleTexts(const []);
      return;
    }

    final texts = _findVisibleTexts(positionMs);
    _setVisibleTexts(texts);
  }

  List<String> _findVisibleTexts(int positionMs) {
    if (_cues.isEmpty) {
      return const [];
    }

    var low = 0;
    var high = _cues.length - 1;
    var index = -1;

    while (low <= high) {
      final mid = (low + high) >> 1;
      if (_cues[mid].startTimeMs <= positionMs) {
        index = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    if (index == -1) {
      return const [];
    }

    final result = <String>[];
    for (var i = index; i >= 0; i--) {
      final cue = _cues[i];
      if (!cue.isVisibleAt(positionMs)) {
        if (positionMs - cue.startTimeMs > 300000) {
          break;
        }
        continue;
      }
      if (!result.contains(cue.text)) {
        result.insert(0, cue.text);
      }
    }
    return result;
  }

  void _setVisibleTexts(List<String> next) {
    final current = visibleTexts.value;
    if (listEquals(current, next)) {
      return;
    }
    visibleTexts.value = List<String>.unmodifiable(next);
  }

  List<HlsSubtitleSegment> _parseSegments(String content) {
    final lines = content.split(RegExp(r'\r?\n'));
    final segments = <HlsSubtitleSegment>[];
    var currentDurationMs = 0;
    var currentStartTimeMs = 0;
    var currentIndex = 0;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.startsWith('#EXTINF:')) {
        final durationText = line.substring(8).split(',').first.trim();
        currentDurationMs =
            ((double.tryParse(durationText) ?? 0) * 1000).round();
        continue;
      }
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }
      final segment = HlsSubtitleSegment(
        index: currentIndex++,
        uri: line,
        durationMs: currentDurationMs,
        startTimeMs: currentStartTimeMs,
        endTimeMs: currentStartTimeMs + currentDurationMs,
      );
      segments.add(segment);
      currentStartTimeMs = segment.endTimeMs;
    }

    return segments;
  }
}
