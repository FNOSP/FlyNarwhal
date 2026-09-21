import 'dart:async';
import 'dart:convert';

/// Opt-in only: ordinary builds keep the existing seek path without sampling.
const playbackSeekDiagnosticsEnabled =
    bool.fromEnvironment('FLYNARWHAL_SEEK_DIAGNOSTICS');

/// Read only the timing/cache properties needed to distinguish a cached seek,
/// a low-level seek, and decoder work. Never query URLs, headers or media names.
class PlaybackSeekDiagnostics {
  PlaybackSeekDiagnostics({
    required this.readProperty,
    required this.writeLog,
    required this.isCurrent,
    this.delay = Future<void>.delayed,
    this.maxSamples = 200,
  });

  final Future<String> Function(String name) readProperty;
  final void Function(String message) writeLog;
  final bool Function() isCurrent;
  final Future<void> Function(Duration duration) delay;
  final int maxSamples;
  static int _nextId = 0;

  /// Exposed for tests. The caller awaits only command submission, as before.
  Future<void>? observation;

  Future<void> seek({
    required int targetMilliseconds,
    required Future<void> Function() submit,
  }) async {
    if (!isCurrent()) return;
    final id = ++_nextId;
    final sampling = Stopwatch()..start();
    final before = await _snapshot(targetMilliseconds);
    // Property reads can outlive a source switch or a newer seek request.
    if (!isCurrent()) return;
    _emit({
      'id': id,
      'event': 'before',
      'targetMs': targetMilliseconds,
      'samplingMs': sampling.elapsedMilliseconds,
      ...before,
    });
    if (!isCurrent()) return;
    final elapsed = Stopwatch()..start();
    try {
      await submit();
    } catch (_) {
      _emit({'id': id, 'event': 'command_failed'});
      rethrow;
    }
    if (!isCurrent()) return;
    _emit({
      'id': id,
      'event': 'command_returned',
      'elapsedMs': elapsed.elapsedMilliseconds,
    });
    observation = _observe(id, targetMilliseconds, elapsed);
    unawaited(observation);
  }

  Future<void> _observe(int id, int target, Stopwatch elapsed) async {
    try {
      var sawSeeking = false;
      for (var sample = 0; sample < maxSamples; sample++) {
        if (!isCurrent()) return;
        final seeking = await _read('seeking');
        if (!isCurrent()) return;
        if (seeking == 'yes') sawSeeking = true;
        final position = _finiteNumber(await _read('time-pos'));
        if (!isCurrent()) return;
        // A command reply is not a rendered-frame/completion event. Wait for
        // the native seeking flag to clear and position to reach the target.
        final atTarget =
            position != null && (position * 1000 - target).abs() <= 500;
        if (seeking == 'no' && (sawSeeking || atTarget)) {
          _emit({
            'id': id,
            'event': 'native_seek_settled',
            'elapsedMs': elapsed.elapsedMilliseconds,
            'observedSeeking': sawSeeking,
            'pollIntervalMs': 50,
            ...await _snapshot(target),
          });
          if (!isCurrent()) return;
          // Reads after settling can be normal cache refill. Capture them
          // separately instead of attributing all post-seek traffic to a miss.
          await delay(const Duration(seconds: 1));
          if (isCurrent()) {
            _emit({
              'id': id,
              'event': 'after_one_second',
              ...await _snapshot(target),
            });
          }
          return;
        }
        if (sample % 5 == 4) {
          _emit({
            'id': id,
            'event': 'waiting',
            'elapsedMs': elapsed.elapsedMilliseconds,
            ...await _snapshot(target),
          });
        }
        if (!isCurrent()) return;
        await delay(const Duration(milliseconds: 50));
      }
      _emit({'id': id, 'event': 'observation_timeout'});
    } catch (_) {
      // Diagnostics must never become an unhandled playback error.
      _emit({'id': id, 'event': 'observation_unavailable'});
    }
  }

  Future<String> _read(String name) async {
    if (!isCurrent()) return '';
    try {
      return await readProperty(name)
          .timeout(const Duration(milliseconds: 500));
    } catch (_) {
      return '';
    }
  }

  Future<Map<String, Object?>> _snapshot(int target) async {
    const names = [
      'time-pos',
      'seeking',
      'paused-for-cache',
      'demuxer-cache-state',
      'hwdec-current',
      'hr-seek',
      'hr-seek-framedrop',
      'video-params',
      'cache-secs',
      'cache-on-disk',
    ];
    final values = await Future.wait(names.map(_read));
    return summarizeSeekProperties(Map.fromIterables(names, values), target);
  }

  void _emit(Map<String, Object?> event) {
    // An awaited property read must not publish data from a replacement source.
    if (!isCurrent()) return;
    try {
      writeLog(jsonEncode(event));
    } catch (_) {
      // A failed logger must not prevent or replace a seek.
    }
  }
}

Map<String, Object?> summarizeSeekProperties(
    Map<String, String> properties, int targetMilliseconds) {
  final cache = _object(properties['demuxer-cache-state']);
  final rawRanges = cache['seekable-ranges'];
  final ranges = <Map<String, num>>[];
  if (rawRanges is List) {
    for (final range in rawRanges) {
      if (range is! Map) continue;
      final start = _finiteNumber(range['start']);
      final end = _finiteNumber(range['end']);
      if (start != null && end != null && start <= end) {
        ranges.add({'start': start, 'end': end});
      }
    }
  }
  final seconds = targetMilliseconds / 1000;
  final video = _object(properties['video-params']);
  return {
    'positionSeconds': _finiteNumber(properties['time-pos']),
    'seeking': _flag(properties['seeking']),
    'pausedForCache': _flag(properties['paused-for-cache']),
    'targetInReportedRange': rawRanges is List
        ? ranges.any(
            (range) => seconds >= range['start']! && seconds <= range['end']!)
        : null,
    'ranges': ranges,
    for (final key in [
      'cache-end',
      'reader-pts',
      'cache-duration',
      'raw-input-rate',
      'fw-bytes',
      'total-bytes',
      'file-cache-bytes',
      'debug-low-level-seeks',
      'debug-byte-level-seeks',
    ])
      key: _finiteNumber(cache[key]),
    for (final key in ['underrun', 'idle', 'eof'])
      key: cache[key] is bool ? cache[key] : null,
    for (final key in ['w', 'h']) 'video-$key': _finiteNumber(video[key]),
    // These native options are short identifiers, not arbitrary media text.
    for (final key in ['hwdec-current', 'hr-seek', 'hr-seek-framedrop'])
      key: RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(properties[key] ?? '')
          ? properties[key]
          : null,
    'cache-secs': _finiteNumber(properties['cache-secs']),
    'cache-on-disk': _flag(properties['cache-on-disk']),
  };
}

Map<String, dynamic> _object(String? value) {
  try {
    final decoded = jsonDecode(value ?? '');
    return decoded is Map<String, dynamic> ? decoded : {};
  } catch (_) {
    return {};
  }
}

num? _finiteNumber(Object? value) {
  final number = value is num
      ? value
      : value is String
          ? num.tryParse(value)
          : null;
  return number != null && number.isFinite ? number : null;
}

bool? _flag(String? value) => switch (value) {
      'yes' => true,
      'no' => false,
      _ => null,
    };
