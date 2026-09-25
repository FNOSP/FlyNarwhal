import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_proxy.dart';
import 'package:fly_narwhal/ui/features/player/controllers/playback_source_controller.dart';
import 'package:fly_narwhal/ui/features/player/models/playback_source_spec.dart';
import 'package:fly_narwhal/data/models/player_models.dart';
import 'package:fly_narwhal/ui/features/player/services/quark_playback_policy.dart';

const _cdn = PlaybackSourceSpec(
  playUri: 'https://cdn.example/video.mp4',
  transport: PlaybackTransport.quarkCdnRange,
);
const _standard = PlaybackSourceSpec(playUri: 'https://nas.example/video.mp4');

void main() {
  test(
      'Given pending metadata, when replaced, then cancellation precedes the transition queue',
      () async {
    final pending = Completer<Uri>();
    final proxy = _Proxy(pending: pending, cancelPending: true);
    final controller =
        PlaybackSourceController(createProxy: ({onError}) => proxy);
    final first = _prepare(controller, _cdn);
    final firstResult =
        expectLater(first, throwsA(isA<PlaybackSourceSuperseded>()));
    await proxy.opened.future;

    final replacement = _prepare(controller, _standard);
    expect(proxy.closeCalls, greaterThan(0));
    final current = await replacement;
    await firstResult;
    expect(current.isCurrent, isTrue);
    expect(current.playUri, _standard.playUri);
    await controller.close();
  });

  test(
      'Given a pending source, when closed repeatedly, then old work cannot become active',
      () async {
    final proxy = _Proxy(pending: Completer<Uri>(), cancelPending: true);
    final controller =
        PlaybackSourceController(createProxy: ({onError}) => proxy);
    final first = _prepare(controller, _cdn);
    final result = expectLater(first, throwsA(isA<PlaybackSourceSuperseded>()));
    await proxy.opened.future;
    await Future.wait([controller.close(), controller.close()]);
    await result;
    expect(controller.active, isNull);
    final replacement = await _prepare(controller, _standard);
    expect(replacement.isCurrent, isTrue);
    await controller.close();
  });

  test(
      'Given a late old proxy error, when another source is active, then the new source is untouched',
      () async {
    void Function(Object)? emitError;
    final controller = PlaybackSourceController(
      createProxy: ({onError}) {
        emitError = onError;
        return _Proxy();
      },
    );
    final old = await _prepare(controller, _cdn);
    final current = await _prepare(controller, _standard);
    emitError!(StateError('late'));
    expect(old.isCurrent, isFalse);
    expect(current.isCurrent, isTrue);
    expect(identical(controller.active, current), isTrue);
    await controller.close();
  });

  test(
      'Given a terminal failure after preparing playback, when another source is queued, then cleanup is isolated from the replacement',
      () async {
    void Function(Object)? emitError;
    final closed = Completer<void>();
    final proxy = _Proxy(firstClose: closed.future);
    var releases = 0;
    final controller = PlaybackSourceController(
      createProxy: ({onError}) {
        emitError = onError;
        return proxy;
      },
      releaseConsumers: () async {
        releases++;
      },
    );
    final old = await _prepare(controller, _cdn);
    final terminal = StateError('terminal');
    emitError!(terminal);
    emitError!(StateError('duplicate'));
    expect(proxy.closeCalls, 1);
    expect(controller.active, isNull);
    expect(() => old.ensureCurrent(), throwsA(same(terminal)));
    final replacement = _prepare(controller, _standard);
    closed.complete();
    final current = await replacement;
    expect(releases, 3);
    expect(current.isCurrent, isTrue);
    expect(identical(controller.active, current), isTrue);
    emitError!(StateError('late'));
    expect(current.isCurrent, isTrue);
    await controller.close();
  });

  test(
      'Given close fails before a pending prepare finishes, when cleanup joins the queue, then its error is observed and consumers still release',
      () async {
    final pending = Completer<Uri>();
    final closed = Completer<void>();
    final proxy = _Proxy(pending: pending, firstClose: closed.future);
    var releases = 0;
    final controller = PlaybackSourceController(
      createProxy: ({onError}) => proxy,
      releaseConsumers: () async {
        releases++;
      },
    );
    final opening = _prepare(controller, _cdn);
    final openResult =
        expectLater(opening, throwsA(isA<PlaybackSourceSuperseded>()));
    await proxy.opened.future;
    final closing = controller.close();
    final closeResult = expectLater(closing, throwsStateError);
    closed.completeError(StateError('close failed early'));
    // Allow the early rejection to arrive before the serialized close can run.
    await Future<void>.delayed(Duration.zero);
    pending.complete(Uri.parse('http://127.0.0.1:1234/old/media'));
    await openResult;
    await closeResult;
    expect(releases, 2);
    expect(controller.active, isNull);
    expect((await _prepare(controller, _standard)).isCurrent, isTrue);
    await controller.close();
  });

  test(
      'Given terminal failure and failing cleanup, when releasing resources internally, then background cleanup errors are handled',
      () async {
    void Function(Object)? emitError;
    var releases = 0;
    final released = Completer<void>();
    final controller = PlaybackSourceController(
      createProxy: ({onError}) {
        emitError = onError;
        return _Proxy(failClose: true);
      },
      releaseConsumers: () async {
        if (++releases == 2) released.complete();
      },
    );
    await _prepare(controller, _cdn);
    emitError!(StateError('terminal'));
    await released.future;
    // Join cleanup without inheriting its already-observed error.
    final current = await _prepare(controller, _standard);
    expect(current.isCurrent, isTrue);
    await controller.close();
  });
  test(
      'Given provider headers, when callers mutate them during opening, then the proxy sees an immutable snapshot and loopback gets no credentials',
      () async {
    final pending = Completer<Uri>();
    final proxy = _Proxy(pending: pending);
    final controller =
        PlaybackSourceController(createProxy: ({onError}) => proxy);
    final cookie = ['ticket=one'];
    final upstream = <String, dynamic>{
      'Cookie': cookie,
      'Range': 'bytes=secret-',
      'Host': 'nas.example'
    };
    final opening = controller.prepare(
      playUri: _cdn.playUri,
      directLinkContext: _direct(),
      upstreamHeaders: upstream,
      playerHeaders: {'Authorization': 'nas-secret'},
    );
    cookie.add('ticket=two');
    upstream['Referer'] = 'https://changed.example/';
    await proxy.opened.future;
    pending.complete(Uri.parse('http://127.0.0.1:1234/source/media'));
    final source = await opening;
    expect(proxy.headers, {'cookie': 'ticket=one'});
    expect(source.playerHeaders, isEmpty);
    expect(
        () => source.playerHeaders['Cookie'] = 'bad', throwsUnsupportedError);
    await controller.close();
  });

  test(
      'Given a route snapshot, when mutable quality metadata changes while queued, then opening and records retain the original selection',
      () async {
    final pending = Completer<Uri>();
    final proxy = _Proxy(pending: pending);
    final controller =
        PlaybackSourceController(createProxy: ({onError}) => proxy);
    final qualities = [
      DirectLinkQuality(resolution: 'Original', url: _cdn.playUri)
    ];
    final context = _direct(qualities: qualities);
    final opening = controller.prepare(
      playUri: _standard.playUri,
      directLinkContext: context,
      playerHeaders: {'Authorization': 'nas-only'},
      upstreamHeaders: const {},
    );
    qualities[0] = DirectLinkQuality(
        resolution: 'Changed', url: 'https://changed.example/other.mp4');
    await proxy.opened.future;
    pending.complete(Uri.parse('http://127.0.0.1:1234/source/media'));
    final source = await opening;
    expect(proxy.uri.toString(), _cdn.playUri);
    expect(source.playerHeaders, isEmpty);
    expect(context.playLink, 'original-session');
    expect(context.playRecordLink, 'original-record');
    expect(context.directLinkQualities.single.url,
        'https://changed.example/other.mp4');
    await controller.close();
  });

  test(
      'Given an invalid selected CDN URL, when prepared, then a real source error reaches upstream recovery without opening a proxy',
      () async {
    var creations = 0;
    var fallbacks = 0;
    final controller = PlaybackSourceController(createProxy: ({onError}) {
      creations++;
      return _Proxy();
    });
    try {
      await controller.prepare(
        playUri: _standard.playUri,
        directLinkContext: _direct(
            qualities: [DirectLinkQuality(resolution: 'Original', url: '')]),
        playerHeaders: const {},
        upstreamHeaders: const {},
      );
      fail('invalid selected URL succeeded');
    } on PlaybackSourceSuperseded {
      fail('real validation failure became cancellation');
    } on PlaybackSourceRejected {
      fallbacks++;
    }
    expect(creations, 0);
    expect(fallbacks, 1);
    expect((await _prepare(controller, _standard)).isCurrent, isTrue);
    await controller.close();
  });

  test(
      'Given a metadata request that never resolves, when it emits a real terminal failure, then cleanup starts and the opening flow receives the original cause',
      () async {
    void Function(Object)? emitError;
    final proxy = _Proxy(pending: Completer<Uri>());
    final controller = PlaybackSourceController(createProxy: ({onError}) {
      emitError = onError;
      return proxy;
    });
    final opening = _prepare(controller, _cdn);
    final terminal = StateError('HTTP 403');
    final result = expectLater(opening, throwsA(same(terminal)));
    await proxy.opened.future;
    emitError!(terminal);
    await result;
    expect(proxy.closeCalls, 1);
    expect(controller.active, isNull);
    final replacement = await _prepare(controller, _standard);
    expect(replacement.isCurrent, isTrue);
    // The abandoned metadata Future remains observed.
    proxy.pending!.completeError(StateError('late transport failure'));
    await controller.close();
  });

  test(
      'Given pending startup verification, when the proxy fails, then the original failure interrupts verification and duplicate failures are ignored',
      () async {
    void Function(Object)? emitError;
    final proxy = _Proxy();
    final controller = PlaybackSourceController(createProxy: ({onError}) {
      emitError = onError;
      return proxy;
    });
    final source = await _prepare(controller, _cdn);
    final pending = Completer<void>();
    final terminal = StateError('body failed');
    final waiting = source.guard(() => pending.future);
    final result = expectLater(waiting, throwsA(same(terminal)));
    emitError!(terminal);
    emitError!(StateError('duplicate'));
    await result;
    expect(() => source.ensureCurrent(), throwsA(same(terminal)));
    expect(proxy.closeCalls, 1);
    final replacement = await _prepare(controller, _standard);
    expect(
        () => source.ensureCurrent(), throwsA(isA<PlaybackSourceSuperseded>()));
    expect(replacement.isCurrent, isTrue);
    pending.completeError(StateError('late decoder failure'));
    await controller.close();
  });

  for (final stage in ['media open', 'subtitle wait', 'resume seek']) {
    test(
        'Given pending $stage, when the user changes source, then the guarded operation cancels without awaiting or leaking its late error',
        () async {
      final controller =
          PlaybackSourceController(createProxy: ({onError}) => _Proxy());
      final source = await _prepare(controller, _standard);
      final entered = Completer<void>();
      final pending = Completer<void>();
      var staleUpdates = 0;
      final waiting = () async {
        await source.guard(() {
          entered.complete();
          return pending.future;
        });
        staleUpdates++;
      }();
      final result =
          expectLater(waiting, throwsA(isA<PlaybackSourceSuperseded>()));
      await entered.future;
      final replacement = await _prepare(controller, _standard);
      await result;
      expect(staleUpdates, 0);
      expect(replacement.isCurrent, isTrue);
      pending.completeError(StateError('late $stage failure'));
      await controller.close();
    });
  }

  test(
      'Given an obsolete consumer, when its pending action errors, then the late error is classified as cancellation',
      () async {
    final controller =
        PlaybackSourceController(createProxy: ({onError}) => _Proxy());
    final source = await _prepare(controller, _standard);
    final pending = Completer<void>();
    var current = true;
    final waiting =
        source.guard(() => pending.future, isConsumerCurrent: () => current);
    final result =
        expectLater(waiting, throwsA(isA<PlaybackSourceSuperseded>()));
    current = false;
    pending.completeError(StateError('old probe failure'));
    await result;
    expect(source.isCurrent, isTrue);
    await controller.close();
  });
}

Future<PlaybackSourceLease> _prepare(
        PlaybackSourceController controller, PlaybackSourceSpec source) =>
    controller.prepare(
        playUri: source.playUri,
        directLinkContext: source.transport == PlaybackTransport.quarkCdnRange
            ? _direct()
            : null,
        playerHeaders: const {},
        upstreamHeaders: const {});

PlayingInfoCache _direct({List<DirectLinkQuality>? qualities}) =>
    PlayingInfoCache(
      itemGuid: 'movie',
      playLink: 'original-session',
      playRecordLink: 'original-record',
      isUseDirectLink: true,
      directLinkQualityIndex: 0,
      directLinkQualities: qualities ??
          [DirectLinkQuality(resolution: 'Original', url: _cdn.playUri)],
      streamInfo: StreamResponse(
          cloudStorageInfo:
              CloudStorageInfo(cloudStorageType: quarkCloudStorageType)),
    );

class _Proxy implements CdnProxy {
  _Proxy(
      {this.pending,
      this.cancelPending = false,
      this.firstClose,
      this.failClose = false});
  final Completer<Uri>? pending;
  final bool cancelPending;
  final Future<void>? firstClose;
  final bool failClose;
  final opened = Completer<void>();
  Map<String, String>? headers;
  Uri? uri;
  int closeCalls = 0;

  @override
  Future<Uri> open(
      {required Uri uri, required Map<String, String> headers}) async {
    this.headers = headers;
    this.uri = uri;
    opened.complete();
    if (pending != null) return pending!.future;
    return Uri.parse('http://127.0.0.1:1234/source/media');
  }

  @override
  Future<void> close() {
    closeCalls++;
    if (cancelPending && pending != null && !pending!.isCompleted) {
      pending!.completeError(const CdnRangeCancelled());
    }
    if (failClose) return Future.error(StateError('cleanup failure'));
    return closeCalls == 1 && firstClose != null
        ? firstClose!
        : Future<void>.value();
  }
}
