import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_proxy.dart';
import 'package:fly_narwhal/data/models/cloud_storage_type.dart';
import 'package:fly_narwhal/data/models/player_models.dart';
import 'package:fly_narwhal/providers/quark_cdn_range_providers.dart';
import 'package:fly_narwhal/ui/features/player/controllers/playback_source_controller.dart';
import 'package:fly_narwhal/ui/features/player/controllers/player_session_coordinator.dart';
import 'package:fly_narwhal/ui/features/player/models/playback_source_spec.dart';

import '../../../tool/support/cdn_proxy_http_fixture.dart';

const _nas = 'https://nas.example/media';
const _cloud = 'https://cloud.example/movie.mp4';
const _limit = Duration(seconds: 5);

void main() {
  test(
      'NAS, CDN and NAS selections keep headers, records and probe ownership correct',
      () async {
    final origin = await CdnHttpFixture.start(length: 16);
    addTearDown(origin.close);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final factory = container.read(quarkCdnRangeServiceFactoryProvider);
    var proxies = 0;
    final controller = PlaybackSourceController(createProxy: ({onError}) {
      proxies++;
      return factory(onError: onError);
    });
    addTearDown(controller.close);
    final ordinary = await _prepare(controller);
    expect(ordinary.playUri, _nas);
    expect(ordinary.playerHeaders, {'Authorization': 'nas-only'});
    final context = _context(url: origin.uri.toString());
    final source = await _prepare(controller, context: context);
    expect(source.playUri, startsWith('http://127.0.0.1:'));
    expect(source.playUri, isNot(origin.uri.toString()));
    expect(source.playerHeaders, isEmpty);
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    final order = <String>[];
    for (final consumer in ['main', 'probe']) {
      await openPlaybackSource(
        source: source,
        configureSsl: (uri) async {
          expect(uri.toString(), source.playUri);
          order.add('$consumer:ssl');
        },
        open: () async {
          order.add('$consumer:open');
          final response =
              await (await client.getUrl(Uri.parse(source.playUri))).close();
          final bytes = await response.expand((part) => part).toList();
          expect(bytes, List.generate(16, fixtureByteAt));
        },
      );
    }
    expect(order, ['main:ssl', 'main:open', 'probe:ssl', 'probe:open']);
    expect(proxies, 1);
    expect(context.playLink, 'cloud-session');
    expect(context.playRecordLink, 'cloud-record');
    final restored = await _prepare(controller);
    expect(restored.playUri, _nas);
    expect(restored.playerHeaders, ordinary.playerHeaders);
    expect(source.isCurrent, isFalse);
  });

  test('HLS, other providers and missing selections retain the upstream route',
      () async {
    final controller = PlaybackSourceController(
        createProxy: ({onError}) => throw StateError('Unexpected proxy'));
    addTearDown(controller.close);
    for (final context in [
      _context(hls: true),
      _context(url: 'https://cloud.example/movie.m3u8'),
      _context(type: CloudStorageType.baiduPan),
      _context(qualities: []),
      const PlayingInfoCache(),
    ]) {
      final source = await _prepare(controller, context: context);
      expect(source.playUri, _nas);
      expect(source.playerHeaders, {'Authorization': 'nas-only'});
    }
    await expectLater(_prepare(controller, context: _context(url: '')),
        throwsA(isA<PlaybackSourceRejected>()));
    expect((await _prepare(controller)).isCurrent, isTrue);
  });

  test('Disabling the CDN range switch keeps the NAS link and skips the proxy',
      () async {
    final controller = PlaybackSourceController(
        createProxy: ({onError}) => throw StateError('Unexpected proxy'));
    addTearDown(controller.close);
    final source = await _prepare(controller,
        context: _context(url: 'https://cloud.example/movie.mp4'),
        preferCdnRange: false);
    expect(source.playUri, _nas);
    expect(source.playerHeaders, {'Authorization': 'nas-only'});
  });

  test(
      'A quality switch cancels pending metadata and keeps its captured selection',
      () async {
    final proxy = _PendingProxy();
    final controller =
        PlaybackSourceController(createProxy: ({onError}) => proxy);
    addTearDown(controller.close);
    final qualities = [DirectLinkQuality(resolution: 'Original', url: _cloud)];
    final cookies = ['ticket=old'];
    final opening = _prepare(controller,
        context: _context(qualities: qualities), headers: {'Cookie': cookies});
    final cancelled =
        expectLater(opening, throwsA(isA<PlaybackSourceSuperseded>()));
    qualities[0] = DirectLinkQuality(
        resolution: '1080p', url: 'https://cloud.example/new');
    cookies.add('ticket=new');
    await proxy.opened.future;
    expect(proxy.uri.toString(), _cloud);
    expect(proxy.headers, {'cookie': 'ticket=old'});
    final replacement = await _prepare(controller);
    await cancelled;
    expect(proxy.closed, isTrue);
    expect(replacement.isCurrent, isTrue);
    proxy.result.completeError(const HttpException('Late cancelled response'));
  });

  for (final phase in ['ssl', 'media']) {
    test('Leaving playback during $phase prevents obsolete completion',
        () async {
      final controller =
          PlaybackSourceController(createProxy: ({onError}) => _PendingProxy());
      addTearDown(controller.close);
      final source = await _prepare(controller);
      final entered = Completer<void>();
      final pending = Completer<void>();
      var opens = 0;
      var updates = 0;
      Future<void> pause() {
        entered.complete();
        return pending.future;
      }

      final opening = () async {
        await openPlaybackSource(
          source: source,
          configureSsl: (_) async {
            if (phase == 'ssl') await pause();
          },
          open: () async {
            opens++;
            if (phase == 'media') await pause();
          },
        );
        updates++;
      }();
      final cancelled =
          expectLater(opening, throwsA(isA<PlaybackSourceSuperseded>()));
      await entered.future;
      if (phase == 'ssl') {
        await controller.close().timeout(_limit);
      } else {
        expect((await _prepare(controller)).isCurrent, isTrue);
      }
      await cancelled;
      pending.completeError(StateError('Late media operation'));
      expect(opens, phase == 'ssl' ? 0 : 1);
      expect(updates, 0);
    });
  }

  test('A real metadata failure stays an error and allows manual NAS recovery',
      () async {
    final origin = await CdnHttpFixture.start(
        length: 16,
        handle: (request, _) async {
          request.response.statusCode = HttpStatus.forbidden;
          request.response.contentLength = 0;
          await request.response.close();
          return true;
        });
    addTearDown(origin.close);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final factory = container.read(quarkCdnRangeServiceFactoryProvider);
    final controller = PlaybackSourceController(createProxy: factory);
    addTearDown(controller.close);
    await expectLater(
        _prepare(controller, context: _context(url: origin.uri.toString())),
        throwsA(isA<CdnRangeFailure>()));
    expect(controller.active, isNull);
    expect((await _prepare(controller)).playUri, _nas);
  });

  test(
      'Source failure interrupts pending progress without invalidating the next source',
      () async {
    final proxy = _PendingProxy()
      ..result.complete(Uri.parse('http://127.0.0.1/media'));
    void Function(Object)? failSource;
    final controller = PlaybackSourceController(createProxy: ({onError}) {
      failSource = onError;
      return proxy;
    });
    addTearDown(controller.close);
    final source = await _prepare(controller, context: _context());
    final progress = Completer<void>();
    const failure = CdnRangeFailure('CDN resource changed');
    final rejected = expectLater(
        source.guard(() => progress.future), throwsA(same(failure)));
    failSource!(failure);
    await rejected;
    expect(proxy.closed, isTrue);
    final replacement = await _prepare(controller);
    failSource!(failure);
    expect(replacement.isCurrent, isTrue);
    progress.completeError(StateError('Late progress lookup'));
  });

  test(
      'Original, transcoded and STRM qualities retain upstream subtitle classification',
      () {
    final original =
        DirectLinkQuality(resolution: 'Original', bitrate: 24, url: _cloud);
    for (final (resolution, bitrate, strm, expected) in [
      ('Original', 24, false, false),
      ('1080p', 8, false, true),
      ('1080p', 8, true, false),
    ]) {
      expect(
          PlayerSessionCoordinator.isDirectLinkTranscodePlayback(
            directLinkQualities: [
              original,
              DirectLinkQuality(
                  resolution: resolution,
                  bitrate: bitrate,
                  url: 'https://cloud.example/refreshed')
            ],
            directLinkQualityIndex: 1,
            cloudStorageType:
                (strm ? CloudStorageType.strm : CloudStorageType.quarkPan)
                    .value,
            isStrm: strm,
          ),
          expected);
    }
  });
}

Future<PlaybackSourceLease> _prepare(PlaybackSourceController controller,
        {PlayingInfoCache? context,
        Map<String, dynamic> headers = const {'Cookie': 'cloud-only'},
        bool preferCdnRange = true}) =>
    controller.prepare(
      playUri: _nas,
      directLinkContext: context,
      playerHeaders: const {'Authorization': 'nas-only'},
      upstreamHeaders: headers,
      preferCdnRange: preferCdnRange,
    );

PlayingInfoCache _context(
        {String url = _cloud,
        bool hls = false,
        CloudStorageType type = CloudStorageType.quarkPan,
        List<DirectLinkQuality>? qualities}) =>
    PlayingInfoCache(
      playLink: 'cloud-session',
      playRecordLink: 'cloud-record',
      isUseDirectLink: true,
      directLinkQualityIndex: 0,
      directLinkQualities: qualities ??
          [DirectLinkQuality(resolution: 'Original', url: url, isM3u8: hls)],
      streamInfo: StreamResponse(
          cloudStorageInfo: CloudStorageInfo(cloudStorageType: type.value)),
    );

class _PendingProxy implements CdnProxy {
  final opened = Completer<void>();
  final result = Completer<Uri>();
  Uri? uri;
  Map<String, String>? headers;
  bool closed = false;
  @override
  Future<Uri> open({required Uri uri, required Map<String, String> headers}) {
    this.uri = uri;
    this.headers = headers;
    opened.complete();
    return result.future;
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}
