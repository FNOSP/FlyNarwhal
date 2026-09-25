import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_proxy.dart';
import 'package:fly_narwhal/data/models/player_models.dart';
import 'package:fly_narwhal/ui/features/player/controllers/playback_source_controller.dart';
import 'package:fly_narwhal/ui/features/player/services/quark_playback_policy.dart';

const _cloudUri = 'https://cdn.example/video.mp4';
const _ordinaryUri = 'https://nas.example/video.mp4';
const _localUri = 'http://127.0.0.1:1234/source/media';

void main() {
  test(
      'Given main playback and a probe, when opening the prepared source, then TLS sees the same endpoint and only one proxy exists',
      () async {
    var creations = 0;
    final controller = PlaybackSourceController(createProxy: ({onError}) {
      creations++;
      return _Proxy();
    });
    addTearDown(controller.close);
    final source = await _prepare(controller, cdn: true);
    final operations = <String>[];

    for (final consumer in ['main', 'probe']) {
      await openPlaybackSource(
        source: source,
        configureSsl: (uri) async {
          operations.add('$consumer:ssl:$uri');
        },
        open: () async {
          operations.add('$consumer:open:${source.playUri}');
        },
      );
    }

    expect(creations, 1);
    expect(operations, [
      'main:ssl:$_localUri',
      'main:open:$_localUri',
      'probe:ssl:$_localUri',
      'probe:open:$_localUri',
    ]);
  });

  test(
      'Given ordinary-CDN-ordinary selections, when opening, then TLS and player headers follow each actual address',
      () async {
    final controller = PlaybackSourceController(
      createProxy: ({onError}) => _Proxy(),
    );
    addTearDown(controller.close);
    final sslUris = <String>[];
    final openedHeaders = <Map<String, String>>[];
    for (final cdn in [false, true, false]) {
      final source = await _prepare(controller, cdn: cdn);
      await openPlaybackSource(
        source: source,
        configureSsl: (uri) async => sslUris.add(uri.toString()),
        open: () async => openedHeaders.add(source.playerHeaders),
      );
    }
    expect(sslUris, [_ordinaryUri, _localUri, _ordinaryUri]);
    expect(openedHeaders, [
      {'Authorization': 'nas-only'},
      <String, String>{},
      {'Authorization': 'nas-only'},
    ]);
  });

  for (final cdn in [false, true]) {
    for (final lateError in [false, true]) {
      test(
          'Given pending TLS for ${cdn ? 'CDN' : 'ordinary'} playback, when closed, then ${lateError ? 'late errors are observed' : 'late completion cannot open media'}',
          () async {
        final controller = PlaybackSourceController(
          createProxy: ({onError}) => _Proxy(),
        );
        final source = await _prepare(controller, cdn: cdn);
        final entered = Completer<void>();
        final pending = Completer<void>();
        var opens = 0;
        final opening = openPlaybackSource(
          source: source,
          configureSsl: (_) {
            entered.complete();
            return pending.future;
          },
          open: () async {
            opens++;
          },
        );
        final result =
            expectLater(opening, throwsA(isA<PlaybackSourceSuperseded>()));
        await entered.future;
        await controller.close().timeout(const Duration(seconds: 5));
        await result;
        if (lateError) {
          pending.completeError(StateError('late TLS failure'));
        } else {
          pending.complete();
        }
        await Future<void>.delayed(Duration.zero);
        expect(opens, 0);
      });
    }
  }

  test(
      'Given pending media open, when replaced, then the obsolete operation cannot continue and its late error is observed',
      () async {
    final controller = PlaybackSourceController(
      createProxy: ({onError}) => _Proxy(),
    );
    addTearDown(controller.close);
    final source = await _prepare(controller, cdn: true);
    final entered = Completer<void>();
    final pending = Completer<void>();
    var postOpenUpdates = 0;
    final opening = () async {
      await openPlaybackSource(
        source: source,
        configureSsl: (_) async {},
        open: () {
          entered.complete();
          return pending.future;
        },
      );
      postOpenUpdates++;
    }();
    final result =
        expectLater(opening, throwsA(isA<PlaybackSourceSuperseded>()));
    await entered.future;
    final current = await _prepare(controller);
    await result;
    pending.completeError(StateError('late decoder failure'));
    expect(postOpenUpdates, 0);
    expect(current.isCurrent, isTrue);
  });

  test(
      'Given a probe superseded during TLS, when its source remains active, then the old probe cannot open',
      () async {
    final controller = PlaybackSourceController(
      createProxy: ({onError}) => _Proxy(),
    );
    addTearDown(controller.close);
    final source = await _prepare(controller, cdn: true);
    final entered = Completer<void>();
    final pending = Completer<void>();
    var consumerCurrent = true;
    final opening = openPlaybackSource(
      source: source,
      configureSsl: (_) {
        entered.complete();
        return pending.future;
      },
      isConsumerCurrent: () => consumerCurrent,
      open: () async {
        fail('obsolete probe opened');
      },
    );
    final result =
        expectLater(opening, throwsA(isA<PlaybackSourceSuperseded>()));
    await entered.future;
    consumerCurrent = false;
    pending.complete();
    await result;
    expect(source.isCurrent, isTrue);
  });

  test(
      'Given an already canceled source, when opening is requested, then TLS and media callbacks do not run',
      () async {
    final controller = PlaybackSourceController(
      createProxy: ({onError}) => _Proxy(),
    );
    final source = await _prepare(controller);
    await controller.close();
    await expectLater(
      openPlaybackSource(
        source: source,
        configureSsl: (_) async {
          fail('canceled TLS configured');
        },
        open: () async {
          fail('canceled media opened');
        },
      ),
      throwsA(isA<PlaybackSourceSuperseded>()),
    );
  });

  test(
      'Given an active TLS configuration failure, when opening, then the original error reaches the caller and media remains unopened',
      () async {
    final controller = PlaybackSourceController(
      createProxy: ({onError}) => _Proxy(),
    );
    addTearDown(controller.close);
    final source = await _prepare(controller);
    final failure = StateError('TLS configuration failed');
    await expectLater(
      openPlaybackSource(
        source: source,
        configureSsl: (_) async {
          throw failure;
        },
        open: () async {
          fail('media opened after TLS failure');
        },
      ),
      throwsA(same(failure)),
    );
  });

  test(
      'Given proxy failure while TLS is pending, when cleanup interrupts opening, then the original proxy cause wins and no media opens',
      () async {
    void Function(Object)? emitError;
    final proxy = _Proxy();
    final controller = PlaybackSourceController(createProxy: ({onError}) {
      emitError = onError;
      return proxy;
    });
    addTearDown(controller.close);
    final source = await _prepare(controller, cdn: true);
    final entered = Completer<void>();
    final pending = Completer<void>();
    final failure = StateError('upstream body failed');
    final opening = openPlaybackSource(
      source: source,
      configureSsl: (_) {
        entered.complete();
        return pending.future;
      },
      open: () async {
        fail('failed proxy opened');
      },
    );
    final result = expectLater(opening, throwsA(same(failure)));
    await entered.future;
    emitError!(failure);
    await result;
    expect(proxy.closeCalls, 1);
    expect(source.isCurrent, isFalse);
    pending.completeError(StateError('late TLS failure'));
  });
}

Future<PlaybackSourceLease> _prepare(PlaybackSourceController controller,
        {bool cdn = false}) =>
    controller.prepare(
      playUri: cdn ? _cloudUri : _ordinaryUri,
      directLinkContext: cdn
          ? PlayingInfoCache(
              isUseDirectLink: true,
              directLinkQualityIndex: 0,
              directLinkQualities: [
                DirectLinkQuality(resolution: 'Original', url: _cloudUri),
              ],
              streamInfo: StreamResponse(
                cloudStorageInfo:
                    CloudStorageInfo(cloudStorageType: quarkCloudStorageType),
              ),
            )
          : null,
      playerHeaders: const {'Authorization': 'nas-only'},
      upstreamHeaders: const {'Cookie': 'cloud-only'},
    );

class _Proxy implements CdnProxy {
  int closeCalls = 0;

  @override
  Future<Uri> open(
          {required Uri uri, required Map<String, String> headers}) async =>
      Uri.parse(_localUri);

  @override
  Future<void> close() async {
    closeCalls++;
  }
}
