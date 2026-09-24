import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_http_range_source.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_proxy_errors.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_range_source.dart';
import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/core/network/api_result.dart';
import 'package:fly_narwhal/providers/quark_cdn_range_providers.dart';

const _deadline = Duration(seconds: 4);
final _cdnUri = Uri.parse('https://cdn.invalid/video.mp4');

void main() {
  group('Quark CDN providers', () {
    test(
        'Given the default source factory, when invoked twice, then creates independent data sources',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final createSource = container.read(cdnRangeSourceFactoryProvider);

      final first = createSource();
      final second = createSource();
      addTearDown(first.close);
      addTearDown(second.close);

      expect(first, isA<CdnHttpRangeSource>());
      expect(second, isA<CdnHttpRangeSource>());
      expect(identical(first, second), isFalse);
    });

    test(
        'Given an overridden source factory, when services close, then each owns a separate source',
        () async {
      final sources = <_ControlledSource>[];
      final container = _createContainer(() {
        final source = _ControlledSource();
        sources.add(source);
        return source;
      });
      final createService = container.read(quarkCdnRangeServiceFactoryProvider);

      final first = createService();
      final second = createService();
      addTearDown(first.close);
      addTearDown(second.close);
      expect(sources, hasLength(2));

      await first.close();
      expect(sources.first.closeCount, 1);
      expect(sources.last.closeCount, 0);

      await second.close();
      await first.close();
      expect(sources.map((source) => source.closeCount), [1, 1]);
      expect(sources.every((source) => !source.started.isCompleted), isTrue);
    });

    test(
        'Given a source failure, when opening a service, then forwards its error callback and releases the source',
        () async {
      final source = _ControlledSource();
      final errors = <Object>[];
      final container = _createContainer(() => source);
      final service = container.read(quarkCdnRangeServiceFactoryProvider)(
        onError: errors.add,
      );
      addTearDown(service.close);
      source.response.complete(
        ResultFailure(FailureInfo.fromMessage('Simulated CDN failure')),
      );

      await expectLater(
        service.open(uri: _cdnUri, headers: const {}),
        throwsA(isA<Object>()),
      );
      await service.close();

      expect(errors, hasLength(1));
      expect(errors.single, isA<CdnRangeFailure>());
      expect(source.closeCount, 1);
    });

    test(
        'Given four services, when probing concurrently, then shares the default three-request quota',
        () async {
      final sources = <_ControlledSource>[];
      final container = _createContainer(() {
        final source = _ControlledSource();
        sources.add(source);
        return source;
      });
      final createService = container.read(quarkCdnRangeServiceFactoryProvider);
      final services = List.generate(4, (_) => createService());
      addTearDown(() async {
        await Future.wait(services.map((service) => service.close()));
      });

      final openings = services
          .map((service) => service.open(uri: _cdnUri, headers: const {}))
          .toList();
      await Future.wait(sources.take(3).map((source) => source.started.future))
          .timeout(_deadline);
      expect(sources.last.started.isCompleted, isFalse);

      // Finishing one probe must release its global slot to the fourth source.
      sources.first.succeed();
      await sources.last.started.future.timeout(_deadline);
      for (final source in sources.skip(1)) {
        source.succeed();
      }
      final uris = await Future.wait(openings).timeout(_deadline);

      expect(uris.map((uri) => uri.host).toSet(), {'127.0.0.1'});
      expect(uris.toSet(), hasLength(4));
      expect(sources.every((source) => source.openCount == 1), isTrue);
    });
  });
}

ProviderContainer _createContainer(CdnRangeSourceFactory createSource) {
  final container = ProviderContainer(overrides: [
    cdnRangeSourceFactoryProvider.overrideWithValue(createSource),
  ]);
  addTearDown(container.dispose);
  return container;
}

class _ControlledSource implements CdnRangeSource {
  final started = Completer<void>();
  final response = Completer<ApiResult<CdnRangeResponse>>();
  int closeCount = 0;
  int openCount = 0;

  void succeed() {
    response.complete(Success(CdnRangeResponse(
      totalLength: 16,
      contentType: 'video/mp4',
      stream: Stream.value(Uint8List.fromList([0])),
    )));
  }

  @override
  Future<ApiResult<CdnRangeResponse>> open({
    required Uri uri,
    required Map<String, String> headers,
    required int start,
    required int end,
    required CancelToken cancelToken,
    String? ifRangeEtag,
  }) {
    openCount++;
    if (!started.isCompleted) started.complete();
    return Future.any([
      response.future,
      cancelToken.whenCancel.then<ApiResult<CdnRangeResponse>>(
        (_) => ResultFailure(FailureInfo.fromMessage('Cancelled')),
      ),
    ]);
  }

  @override
  void close() {
    closeCount++;
  }
}
