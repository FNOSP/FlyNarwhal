import 'dart:async';

import '../../../../core/network/quark_cdn_proxy/cdn_proxy.dart';
import '../../../../data/models/player_models.dart';
import '../models/playback_source_spec.dart';
import '../services/quark_playback_policy.dart';

export '../models/playback_source_spec.dart' show PlaybackSourceSuperseded;

typedef PlaybackProxyFactory = CdnProxy Function({
  void Function(Object error)? onError,
});

/// An effective media address shared by playback and its hardware probe.
class PlaybackSourceLease {
  final String playUri;
  final Map<String, String> playerHeaders;
  final _SourceLifetime _lifetime;

  PlaybackSourceLease._({
    required this.playUri,
    required Map<String, String> playerHeaders,
    required _SourceLifetime lifetime,
  })  : playerHeaders = Map.unmodifiable(playerHeaders),
        _lifetime = lifetime;

  int get generation => _lifetime.generation;
  bool get isCurrent => _lifetime.isCurrent;

  /// Failed sources preserve their original error. Only replacement, exit or an
  /// obsolete consumer is cancellation.
  void ensureCurrent({bool Function()? isConsumerCurrent}) =>
      _lifetime.ensureCurrent(isConsumerCurrent: isConsumerCurrent);

  /// Interrupt waiting when this source ends and observe late action errors.
  Future<T> guard<T>(FutureOr<T> Function() action,
          {bool Function()? isConsumerCurrent}) =>
      _lifetime.guard(action, isConsumerCurrent: isConsumerCurrent);
}

class _SourceLifetime {
  _SourceLifetime(this.generation, this._ownsGeneration);

  final int generation;
  final bool Function() _ownsGeneration;
  final _waiters = <Completer<void>>{};
  CdnProxy? proxy;
  PlaybackSourceLease? lease;
  Future<void>? _closing;
  Object? failure;
  StackTrace? failureStack;

  bool get isCurrent => _ownsGeneration() && failure == null;

  void ensureCurrent({bool Function()? isConsumerCurrent}) {
    if (!_ownsGeneration() ||
        (isConsumerCurrent != null && !isConsumerCurrent())) {
      throw const PlaybackSourceSuperseded();
    }
    if (failure case final error?) {
      Error.throwWithStackTrace(error, failureStack!);
    }
  }

  void cancel() {
    for (final waiter in _waiters) {
      waiter.complete();
    }
    _waiters.clear();
  }

  bool fail(Object error) {
    if (!isCurrent) return false;
    failure = error;
    failureStack = StackTrace.current;
    cancel();
    return true;
  }

  Future<void> closeProxy() =>
      _closing ??= Future<void>.sync(() => proxy?.close());

  Future<T> guard<T>(FutureOr<T> Function() action,
      {bool Function()? isConsumerCurrent}) async {
    void check() => ensureCurrent(isConsumerCurrent: isConsumerCurrent);
    check();
    final ended = Completer<void>();
    _waiters.add(ended);
    try {
      final result = await Future.any<T>([
        Future<T>.sync(action),
        ended.future.then<T>((_) {
          check();
          throw const PlaybackSourceSuperseded();
        }),
      ]);
      check();
      return result;
    } catch (_) {
      check();
      rethrow;
    } finally {
      // Completed actions must not accumulate waiters until source cleanup.
      _waiters.remove(ended);
    }
  }
}

/// Owns routing snapshots, proxy resources and serialized source transitions.
class PlaybackSourceController {
  PlaybackSourceController({
    required PlaybackProxyFactory createProxy,
    void Function()? onInvalidate,
    Future<void> Function()? releaseConsumers,
  })  : _createProxy = createProxy,
        _onInvalidate = onInvalidate,
        _releaseConsumers = releaseConsumers;

  final PlaybackProxyFactory _createProxy;
  final void Function()? _onInvalidate;
  final Future<void> Function()? _releaseConsumers;
  Future<void> _transitions = Future<void>.value();
  _SourceLifetime? _current;
  int _generation = 0;

  int get generation => _generation;
  PlaybackSourceLease? get active =>
      _current?.isCurrent == true ? _current?.lease : null;

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = _transitions.then((_) => operation());
    _transitions =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<void> _release(Future<void>? closing) async {
    try {
      await closing;
    } finally {
      await _releaseConsumers?.call();
    }
  }

  Future<PlaybackSourceLease> prepare({
    required String playUri,
    PlayingInfoCache? directLinkContext,
    required Map<String, String> playerHeaders,
    required Map<String, dynamic> upstreamHeaders,
  }) {
    // Freeze provider values before joining any asynchronous transition.
    final source = snapshotPlaybackSource(
        playUri: playUri, directLinkContext: directLinkContext);
    final capturedPlayerHeaders =
        Map<String, String>.unmodifiable(playerHeaders);
    final capturedUpstreamHeaders = Map<String, String>.unmodifiable(
      normalizeCdnRequestHeaders(upstreamHeaders),
    );
    final previous = _current;
    final generation = ++_generation;
    previous?.cancel();
    final lifetime =
        _SourceLifetime(generation, () => generation == _generation);
    _current = lifetime;
    _onInvalidate?.call();
    final closing = previous?.closeProxy();
    closing?.ignore();

    return _enqueue(() async {
      // Cleanup of an old source must not reject a valid new selection.
      await _release(closing)
          .then<void>((_) {}, onError: (Object _, StackTrace __) {});
      lifetime.ensureCurrent();
      if (source.sourceError case final message?) {
        throw PlaybackSourceRejected(message);
      }
      var effectiveUri = source.playUri;
      if (source.transport == PlaybackTransport.quarkCdnRange) {
        final proxy = _createProxy(onError: (error) {
          if (!lifetime.fail(error)) return;
          // Keep the original failure for active opening operations. During
          // playback, closing the HTTP connection lets mpv handle the failure.
          final closing = lifetime.closeProxy();
          closing.ignore();
          _enqueue(() => _release(closing)).ignore();
        });
        lifetime.proxy = proxy;
        try {
          effectiveUri = (await lifetime.guard(() => proxy.open(
                    uri: Uri.parse(source.playUri),
                    headers: capturedUpstreamHeaders,
                  )))
              .toString();
        } catch (_) {
          // Cleanup errors cannot hide the opening error or cancellation.
          await lifetime
              .closeProxy()
              .then<void>((_) {}, onError: (Object _, StackTrace __) {});
          lifetime.ensureCurrent();
          rethrow;
        }
      }
      lifetime.ensureCurrent();
      return lifetime.lease = PlaybackSourceLease._(
        playUri: effectiveUri,
        playerHeaders: source.transport == PlaybackTransport.quarkCdnRange
            ? const {}
            : capturedPlayerHeaders,
        lifetime: lifetime,
      );
    });
  }

  Future<void> close() {
    final previous = _current;
    ++_generation;
    _current = null;
    previous?.cancel();
    _onInvalidate?.call();
    final closing = previous?.closeProxy();
    closing?.ignore();
    return _enqueue(() => _release(closing));
  }
}

/// Configure TLS for the actual endpoint and open only while its lease and
/// consumer remain current. Playback options remain owned by the player.
Future<void> openPlaybackSource({
  required PlaybackSourceLease source,
  required Future<void> Function(Uri uri) configureSsl,
  required Future<void> Function() open,
  bool Function()? isConsumerCurrent,
}) async {
  await source.guard(() => configureSsl(Uri.parse(source.playUri)),
      isConsumerCurrent: isConsumerCurrent);
  await source.guard(open, isConsumerCurrent: isConsumerCurrent);
}
