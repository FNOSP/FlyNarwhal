import 'dart:async';

import '../../../../core/network/cdn_proxy/cdn_proxy.dart';
import '../models/playback_source_spec.dart';
import '../services/playback_network_policy.dart';

typedef PlaybackProxyFactory = CdnProxy Function({
  void Function(Object error)? onError,
});

/// An immutable player endpoint tied to one source generation. The main player
/// and its probe share this lease; neither owns or recreates the underlying proxy.
class PlaybackSourceLease {
  final String playUri;
  final PlaybackTransport transport;
  final Map<String, String> playerHeaders;
  final int generation;
  final bool Function() _isCurrent;

  PlaybackSourceLease._({
    required this.playUri,
    required this.transport,
    required Map<String, String> playerHeaders,
    required this.generation,
    required bool Function() isCurrent,
  })  : playerHeaders = Map.unmodifiable(playerHeaders),
        _isCurrent = isCurrent;

  bool get isCurrent => _isCurrent();
  PlaybackOpenPolicy get policy => PlaybackOpenPolicy.forTransport(transport);

  void ensureCurrent() {
    if (!isCurrent) throw const PlaybackSourceSuperseded();
  }
}

/// Owns source transitions independently of widgets, media_kit and UI errors.
/// Cancellation starts immediately, even while the serialized prepare is waiting
/// for proxy metadata or a retry. A failed transition never poisons the queue.
class PlaybackSourceController {
  PlaybackSourceController({
    required PlaybackProxyFactory createProxy,
    void Function()? onInvalidate,
    Future<void> Function()? releaseConsumers,
    void Function(Object error)? onError,
  })  : _createProxy = createProxy,
        _onInvalidate = onInvalidate,
        _releaseConsumers = releaseConsumers,
        _onError = onError;

  final PlaybackProxyFactory _createProxy;
  final void Function()? _onInvalidate;
  final Future<void> Function()? _releaseConsumers;
  final void Function(Object error)? _onError;
  Future<void> _transitions = Future<void>.value();
  CdnProxy? _proxy;
  PlaybackSourceLease? _active;
  int _generation = 0;

  int get generation => _generation;
  PlaybackSourceLease? get active => _active;

  int _invalidate() {
    final generation = ++_generation;
    _onInvalidate?.call();
    return generation;
  }

  void _ensureCurrent(int generation) {
    if (generation != _generation) throw const PlaybackSourceSuperseded();
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = _transitions.then((_) => operation());
    _transitions =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<void> _release() async {
    final proxy = _proxy;
    _proxy = null;
    _active = null;
    // Close the source before joining consumers whose open/read can be blocked.
    try {
      await proxy?.close();
    } finally {
      await _releaseConsumers?.call();
    }
  }

  Future<PlaybackSourceLease> prepare({
    required PlaybackSourceSpec source,
    required Map<String, String> playerHeaders,
    required Map<String, dynamic> upstreamHeaders,
  }) {
    final generation = _invalidate();
    final closing = _proxy?.close();
    // The queue can still be blocked when close fails; observe it immediately.
    closing?.ignore();
    final capturedPlayerHeaders =
        Map<String, String>.unmodifiable(playerHeaders);
    final capturedUpstreamHeaders = Map<String, String>.unmodifiable(
      normalizeCdnRequestHeaders(upstreamHeaders),
    );
    return _enqueue(() async {
      try {
        await closing;
      } finally {
        await _release();
      }
      _ensureCurrent(generation);
      if (source.sourceError case final message?) {
        throw PlaybackSourceRejected(message);
      }
      var effectiveUri = source.playUri;
      if (source.transport == PlaybackTransport.quarkCdnRange) {
        final proxy = _createProxy(onError: (error) {
          if (generation != _generation) return;
          // Invalidate and queue cleanup before notifying user code, which may
          // synchronously prepare a replacement source. Observe cleanup errors.
          close().ignore();
          _onError?.call(error);
        });
        _proxy = proxy;
        try {
          effectiveUri = (await proxy.open(
            uri: Uri.parse(source.playUri),
            headers: capturedUpstreamHeaders,
          ))
              .toString();
          _ensureCurrent(generation);
        } catch (_) {
          await proxy.close();
          if (identical(_proxy, proxy)) _proxy = null;
          _ensureCurrent(generation);
          rethrow;
        }
      }
      _ensureCurrent(generation);
      return _active = PlaybackSourceLease._(
        playUri: effectiveUri,
        transport: source.transport,
        playerHeaders: source.transport == PlaybackTransport.quarkCdnRange
            ? const {}
            : capturedPlayerHeaders,
        generation: generation,
        isCurrent: () => generation == _generation,
      );
    });
  }

  Future<void> close() {
    _invalidate();
    final closing = _proxy?.close();
    // The queue can still be blocked when close fails; observe it immediately.
    closing?.ignore();
    return _enqueue(() async {
      try {
        await closing;
      } finally {
        await _release();
      }
    });
  }
}

/// Shared by main playback and hardware probing. TLS always sees the actual
/// player endpoint (loopback for CDN), with validity checked after each await.
Future<void> openPlaybackSource({
  required PlaybackSourceLease source,
  required Future<void> Function(Uri uri) configureSsl,
  required Future<void> Function() open,
  Future<void> Function(String name, String value)? setProperty,
  bool Function()? isConsumerCurrent,
}) async {
  void ensureCurrent() {
    source.ensureCurrent();
    if (isConsumerCurrent != null && !isConsumerCurrent()) {
      throw const PlaybackSourceSuperseded();
    }
  }

  ensureCurrent();
  await configureSsl(Uri.parse(source.playUri));
  ensureCurrent();
  await openWithPlaybackNetworkPolicy(
    transport: source.transport,
    setProperty: setProperty,
    open: () {
      ensureCurrent();
      return open();
    },
  );
  ensureCurrent();
}
