import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/core/network/cdn_proxy/cdn_proxy.dart';
import 'package:fly_narwhal/ui/features/player/controllers/playback_source_controller.dart';
import 'package:fly_narwhal/ui/features/player/models/playback_source_spec.dart';

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
    final errors = <Object>[];
    final controller = PlaybackSourceController(
      createProxy: ({onError}) {
        emitError = onError;
        return _Proxy();
      },
      onError: errors.add,
    );
    final old = await _prepare(controller, _cdn);
    final current = await _prepare(controller, _standard);
    emitError!(StateError('late'));
    expect(old.isCurrent, isFalse);
    expect(current.isCurrent, isTrue);
    expect(identical(controller.active, current), isTrue);
    expect(errors, isEmpty);
    await controller.close();
  });

  test(
      'Given an error callback that starts a replacement, when the proxy fails, then cleanup cannot cancel the replacement',
      () async {
    void Function(Object)? emitError;
    late PlaybackSourceController controller;
    Future<PlaybackSourceLease>? replacement;
    var errors = 0;
    controller = PlaybackSourceController(
      createProxy: ({onError}) {
        emitError = onError;
        return _Proxy();
      },
      onError: (_) {
        errors++;
        replacement = _prepare(controller, _standard);
      },
    );
    final old = await _prepare(controller, _cdn);
    emitError!(StateError('terminal'));
    emitError!(StateError('duplicate'));
    final current = await replacement!;
    expect(errors, 1);
    expect(old.isCurrent, isFalse);
    expect(current.isCurrent, isTrue);
    expect(identical(controller.active, current), isTrue);
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
      'Given terminal failure and failing cleanup, when notifying UI, then background cleanup errors are handled',
      () async {
    void Function(Object)? emitError;
    var errors = 0;
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
      onError: (_) {
        errors++;
      },
    );
    await _prepare(controller, _cdn);
    emitError!(StateError('terminal'));
    await released.future;
    // Join cleanup without inheriting its already-observed error.
    final current = await _prepare(controller, _standard);
    expect(errors, 1);
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
      source: _cdn,
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
      'Given a rejected cloud source, when prepared, then no proxy opens and manual retry remains possible',
      () async {
    var creations = 0;
    final controller = PlaybackSourceController(createProxy: ({onError}) {
      creations++;
      return _Proxy();
    });
    await expectLater(
        _prepare(controller,
            const PlaybackSourceSpec(playUri: '', sourceError: '手动切换 NAS')),
        throwsA(isA<PlaybackSourceRejected>()
            .having((e) => e.message, 'message', contains('NAS'))));
    expect(creations, 0);
    expect((await _prepare(controller, _standard)).isCurrent, isTrue);
    await controller.close();
  });

  test(
      'Given main playback and a probe, when opening their shared source, then both configure the same actual URI without another proxy',
      () async {
    var creations = 0;
    final controller = PlaybackSourceController(createProxy: ({onError}) {
      creations++;
      return _Proxy();
    });
    final source = await _prepare(controller, _cdn);
    final operations = <String>[];
    for (final consumer in ['main', 'probe']) {
      await openPlaybackSource(
        source: source,
        configureSsl: (uri) async {
          operations.add('$consumer:ssl:$uri');
        },
        setProperty: (name, value) async {
          operations.add('$consumer:$name=$value');
        },
        open: () async {
          operations.add('$consumer:open');
        },
      );
    }
    expect(creations, 1);
    expect(operations, [
      'main:ssl:http://127.0.0.1:1234/source/media',
      'main:network-timeout=0',
      'main:open',
      'probe:ssl:http://127.0.0.1:1234/source/media',
      'probe:network-timeout=0',
      'probe:open',
    ]);
    await controller.close();
    await expectLater(
        openPlaybackSource(
            source: source,
            configureSsl: (_) async {},
            open: () async {
              fail('obsolete source opened');
            }),
        throwsA(isA<PlaybackSourceSuperseded>()));
  });

  for (final cancelDuringSsl in [true, false]) {
    test(
        'Given ${cancelDuringSsl ? 'SSL configuration' : 'timeout configuration'} is pending, when the source closes, then neither player may open the old URI',
        () async {
      final controller =
          PlaybackSourceController(createProxy: ({onError}) => _Proxy());
      final source = await _prepare(controller, _standard);
      final entered = Completer<void>();
      final resume = Completer<void>();
      var opened = false;
      final opening = openPlaybackSource(
        source: source,
        configureSsl: (_) async {
          if (cancelDuringSsl) {
            entered.complete();
            await resume.future;
          }
        },
        setProperty: (_, __) async {
          if (!cancelDuringSsl) {
            entered.complete();
            await resume.future;
          }
        },
        open: () async {
          opened = true;
        },
      );
      final result =
          expectLater(opening, throwsA(isA<PlaybackSourceSuperseded>()));
      await entered.future;
      await controller.close();
      resume.complete();
      await result;
      expect(opened, isFalse);
    });
  }

  test(
      'Given a probe is superseded while TLS awaits, when the source itself is still active, then the probe cannot open',
      () async {
    final controller =
        PlaybackSourceController(createProxy: ({onError}) => _Proxy());
    final source = await _prepare(controller, _cdn);
    final entered = Completer<void>();
    final resume = Completer<void>();
    var current = true;
    final opening = openPlaybackSource(
      source: source,
      configureSsl: (_) async {
        entered.complete();
        await resume.future;
      },
      isConsumerCurrent: () => current,
      open: () async {
        fail('obsolete probe opened');
      },
    );
    final result =
        expectLater(opening, throwsA(isA<PlaybackSourceSuperseded>()));
    await entered.future;
    current = false;
    resume.complete();
    await result;
    expect(source.isCurrent, isTrue);
    await controller.close();
  });

  test(
      'Given standard-CDN-standard transitions, when source policies are applied, then timeouts and startup rules restore',
      () async {
    final controller =
        PlaybackSourceController(createProxy: ({onError}) => _Proxy());
    final timeouts = <String>[];
    for (final spec in [_standard, _cdn, _standard]) {
      final source = await _prepare(controller, spec);
      await openPlaybackSource(
          source: source,
          configureSsl: (_) async {},
          setProperty: (_, value) async {
            timeouts.add(value);
          },
          open: () async {});
      final recovering = spec.transport == PlaybackTransport.quarkCdnRange;
      expect(source.policy.waitForRecovery, recovering);
      expect(
          source.policy.shouldAbortStalledStart(
              elapsed: const Duration(seconds: 8),
              mediaDuration: const Duration(minutes: 1),
              hasVideo: false,
              buffered: Duration.zero),
          !recovering);
    }
    expect(timeouts, ['5', '0', '5']);
    await controller.close();
  });
}

Future<PlaybackSourceLease> _prepare(
        PlaybackSourceController controller, PlaybackSourceSpec source) =>
    controller.prepare(
        source: source, playerHeaders: const {}, upstreamHeaders: const {});

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
  int closeCalls = 0;

  @override
  Future<Uri> open(
      {required Uri uri, required Map<String, String> headers}) async {
    this.headers = headers;
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
