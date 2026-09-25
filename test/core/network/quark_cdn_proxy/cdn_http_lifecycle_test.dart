import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_http_range_source.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_proxy_errors.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_range_source.dart';

final _uri = Uri.parse('https://provider.example/media?signature=secret');
const _deadline = Duration(seconds: 3);

void main() {
  late _Adapter adapter;
  late CdnHttpRangeSource source;
  setUp(() {
    adapter = _Adapter();
    source = CdnHttpRangeSource(adapter: adapter);
  });
  tearDown(() => source.close());

  Future<CdnRangeResponse> open(
          {CancelToken? token, String? ifRangeEtag}) async =>
      (await source.open(
              uri: _uri,
              headers: const {},
              start: 2,
              end: 5,
              cancelToken: token ?? CancelToken(),
              ifRangeEtag: ifRangeEtag))
          .getOrThrow();

  test(
      'Given defaults, then only the whole HTTP attempt has a 48 hour deadline',
      () {
    expect(source.requestTimeout, const Duration(hours: 48));
    expect(source.dio.options.connectTimeout, isNull);
    expect(source.dio.options.receiveTimeout, isNull);
    expect(source.dio.options.sendTimeout, isNull);
  });

  for (final weak in [false, true]) {
    test(
        'Given a ${weak ? 'weak' : 'strong'} entity tag, then parsed identity preserves strength',
        () async {
      adapter.respond = (_, __) async => _body(headers: {
            'ETag': ['${weak ? 'W/' : ''}"file-v1"'],
            'Last-Modified': ['Sun, 06 Nov 1994 08:49:37 GMT'],
          });
      final response = await open();
      expect(response.entityTag,
          CdnEntityTag(opaqueValue: 'file-v1', isWeak: weak));
      expect(response.entityTag!.strongValue, weak ? null : '"file-v1"');
      expect(response.lastModified, DateTime.utc(1994, 11, 6, 8, 49, 37));
      await response.stream.drain<void>();
      expect(source.activeAttemptCount, 0);
    });
  }

  test(
      'Given a strong conditional range, then only its owned If-Range reaches HTTP',
      () async {
    final response = await open(ifRangeEtag: '"file-v1"');
    expect(adapter.options!.headers['if-range'], '"file-v1"');
    expect(adapter.options!.followRedirects, isTrue);
    await response.stream.drain<void>();
  });

  for (final invalid in [
    'W/"weak"',
    'missing-quotes',
    '"two", "tags"',
    '"line\nbreak"'
  ]) {
    test('Given invalid If-Range $invalid, then fails before starting HTTP',
        () async {
      await expectLater(
          open(ifRangeEtag: invalid),
          throwsA(isA<CdnRequestFailure>()
              .having((e) => e.kind, 'kind', CdnRequestFailureKind.protocol)));
      expect(adapter.options, isNull);
    });
  }

  for (final invalidHeader in [
    {
      'ETag': ['unquoted']
    },
    {
      'ETag': ['"a"', '"b"']
    },
    {
      'Last-Modified': ['not-a-date']
    },
  ]) {
    test(
        'Given malformed identity metadata $invalidHeader, then rejects the media response',
        () async {
      adapter.respond = (_, __) async => _body(headers: invalidHeader);
      await expectLater(
          open(),
          throwsA(isA<CdnRequestFailure>()
              .having((e) => e.kind, 'kind', CdnRequestFailureKind.protocol)));
      expect(source.activeAttemptCount, 0);
    });
  }

  test(
      'Given an HTTP error page with invalid validators, then reports HTTP status without parsing identity',
      () async {
    adapter.respond =
        (_, __) async => ResponseBody.fromString('secret error', 403, headers: {
              'ETag': ['not-a-validator'],
              'Last-Modified': ['bad-date']
            });
    await expectLater(
        open(),
        throwsA(isA<CdnRequestFailure>()
            .having((e) => e.kind, 'kind', CdnRequestFailureKind.httpStatus)
            .having((e) => e.statusCode, 'status', 403)));
    expect(source.activeAttemptCount, 0);
  });

  for (final status in [200, 201, 204, 302, 304]) {
    test(
        'Given non-error HTTP $status without partial content, then it is a protocol failure rather than a retryable HTTP error',
        () async {
      adapter.respond = (_, __) async => ResponseBody.fromBytes([], status);
      await expectLater(
          open(),
          throwsA(isA<CdnRequestFailure>()
              .having((e) => e.kind, 'kind', CdnRequestFailureKind.protocol)
              .having((e) => e.phase, 'phase', CdnRequestFailurePhase.headers)
              .having((e) => e.statusCode, 'status', status)));
      expect(source.activeAttemptCount, 0);
    });
  }

  test(
      'Given absent identity headers, then leaves compatibility policy to the session',
      () async {
    final response = await open();
    expect(response.entityTag, isNull);
    expect(response.lastModified, isNull);
    await response.stream.drain<void>();
  });

  test(
      'Given headers never arrive, when the total deadline expires, then cancels the attempt once',
      () async {
    source.close();
    source = CdnHttpRangeSource(
        adapter: adapter, requestTimeout: const Duration(milliseconds: 40));
    final cancelled = Completer<void>();
    adapter.respond = (_, cancellation) {
      cancellation!.then((_) => cancelled.complete());
      return Completer<ResponseBody>().future;
    };
    await expectLater(
        open(),
        throwsA(isA<CdnRequestFailure>()
            .having((e) => e.phase, 'phase', CdnRequestFailurePhase.request)
            .having((e) => e.isTimeout, 'timeout', isTrue)));
    await cancelled.future.timeout(_deadline);
    expect(source.activeAttemptCount, 0);
    expect(adapter.calls, 1);
  });

  test(
      'Given progress throughout a body, when its original deadline expires, then progress does not restart the deadline',
      () async {
    source.close();
    source = CdnHttpRangeSource(
        adapter: adapter, requestTimeout: const Duration(milliseconds: 120));
    final stopped = Completer<void>();
    final body = StreamController<Uint8List>(onCancel: stopped.complete);
    adapter.respond = (_, __) async => _body(stream: body.stream);
    final response = await open();
    final received = <int>[];
    final failed = Completer<CdnRequestFailure>();
    response.stream.listen((bytes) => received.addAll(bytes),
        onError: (Object e) => failed.complete(e as CdnRequestFailure));
    final ticker = Timer.periodic(const Duration(milliseconds: 20), (_) {
      body.add(Uint8List.fromList([2]));
    });
    try {
      final failure = await failed.future.timeout(_deadline);
      expect(failure.phase, CdnRequestFailurePhase.body);
      expect(failure.isTimeout, isTrue);
      expect(received, isNotEmpty);
      await stopped.future.timeout(_deadline);
      expect(source.activeAttemptCount, 0);
    } finally {
      ticker.cancel();
      await body.close();
    }
  });

  test(
      'Given a paused consumer, then pause and resume propagate to the raw adapter body',
      () async {
    final paused = Completer<void>();
    final resumed = Completer<void>();
    final body = StreamController<Uint8List>(
        onPause: paused.complete, onResume: resumed.complete);
    adapter.respond = (_, __) async => _body(stream: body.stream);
    final response = await open();
    final received = <int>[];
    final subscription =
        response.stream.listen((bytes) => received.addAll(bytes));
    subscription.pause();
    await paused.future.timeout(_deadline);
    body.add(Uint8List.fromList([2, 3]));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(received, isEmpty);
    expect(source.activeAttemptCount, 1);
    subscription.resume();
    await resumed.future.timeout(_deadline);
    await Future<void>.delayed(Duration.zero);
    expect(received, [2, 3]);
    await subscription.cancel();
    await body.close();
    expect(source.activeAttemptCount, 0);
  });

  test(
      'Given an unlistened body, when its deadline expires, then releases the origin and preserves a typed late-listen failure',
      () async {
    source.close();
    source = CdnHttpRangeSource(
        adapter: adapter, requestTimeout: const Duration(milliseconds: 40));
    final stopped = Completer<void>();
    final body = StreamController<Uint8List>(onCancel: stopped.complete);
    adapter.respond = (_, __) async => _body(stream: body.stream);
    final response = await open();
    await stopped.future.timeout(_deadline);
    expect(source.activeAttemptCount, 0);
    await expectLater(
        response.stream,
        emitsInOrder([
          emitsError(isA<CdnRequestFailure>()
              .having((e) => e.isTimeout, 'timeout', isTrue)),
          emitsDone,
        ]));
    await body.close();
  });

  test(
      'Given cancellation followed by late headers, then disposes the late body and observes late errors',
      () async {
    final pending = Completer<ResponseBody>();
    final entered = Completer<void>();
    adapter.respond = (_, __) {
      entered.complete();
      return pending.future;
    };
    final token = CancelToken();
    final result = open(token: token);
    final rejected = expectLater(
        result,
        throwsA(isA<CdnRequestFailure>()
            .having((e) => e.kind, 'kind', CdnRequestFailureKind.cancelled)));
    await entered.future;
    token.cancel();
    await rejected;
    final cancelledBody = Completer<void>();
    final body = StreamController<Uint8List>(onCancel: cancelledBody.complete);
    pending.complete(_body(stream: body.stream));
    await cancelledBody.future.timeout(_deadline);
    body.addError(StateError('late signed URL secret'));
    await body.close();
    expect(source.activeAttemptCount, 0);
  });

  test('Given an adapter error after cancellation, then no late error escapes',
      () async {
    final pending = Completer<ResponseBody>();
    final entered = Completer<void>();
    adapter.respond = (_, __) {
      entered.complete();
      return pending.future;
    };
    final token = CancelToken();
    final rejected = expectLater(
        open(token: token),
        throwsA(isA<CdnRequestFailure>()
            .having((e) => e.kind, 'kind', CdnRequestFailureKind.cancelled)));
    await entered.future;
    token.cancel();
    await rejected;
    pending.completeError(StateError('late signed URL secret'));
    await Future<void>.delayed(Duration.zero);
    expect(source.activeAttemptCount, 0);
  });

  test(
      'Given cancellation and a timeout cause race, then explicit cancellation wins',
      () async {
    final token = CancelToken();
    adapter.respond = (_, __) async {
      token.cancel();
      throw TimeoutException('secret request URL');
    };
    await expectLater(
        open(token: token),
        throwsA(isA<CdnRequestFailure>()
            .having((e) => e.kind, 'kind', CdnRequestFailureKind.cancelled)
            .having((e) => e.isTimeout, 'timeout', isFalse)));
  });

  test(
      'Given a response cleanup hook, then cancellation calls both the hook and raw subscription cleanup',
      () async {
    var hookCalls = 0;
    final cancelled = Completer<void>();
    final body = StreamController<Uint8List>(onCancel: cancelled.complete);
    adapter.respond = (_, __) async => ResponseBody(body.stream, 206,
        headers: {
          'content-range': ['bytes 2-5/9']
        },
        onClose: () => hookCalls++);
    final token = CancelToken();
    final response = await open(token: token);
    final expectation = expectLater(
        response.stream,
        emitsInOrder([
          emitsError(isA<CdnRequestFailure>()),
          emitsDone,
        ]));
    token.cancel();
    await expectation;
    await cancelled.future.timeout(_deadline);
    expect(hookCalls, 1);
    await body.close();
  });

  test(
      'Given a paused body, when the whole source closes twice, then cleanup does not wait for resume',
      () async {
    final cancelled = Completer<void>();
    final body = StreamController<Uint8List>(onCancel: cancelled.complete);
    adapter.respond = (_, __) async => _body(stream: body.stream);
    final response = await open();
    final errors = <Object>[];
    final subscription = response.stream.listen((_) {}, onError: errors.add);
    subscription.pause();
    source.close();
    source.close();
    await cancelled.future.timeout(_deadline);
    expect(source.activeAttemptCount, 0);
    subscription.resume();
    await Future<void>.delayed(Duration.zero);
    expect(errors, hasLength(1));
    expect((errors.single as CdnRequestFailure).kind,
        CdnRequestFailureKind.cancelled);
    await subscription.cancel();
    await body.close();
  });

  test(
      'Given body failure with private details, then emits only sanitized typed facts',
      () async {
    final body = StreamController<Uint8List>();
    adapter.respond = (_, __) async => _body(stream: body.stream);
    final response = await open();
    final rejected = expectLater(
        response.stream,
        emitsInOrder([
          emitsError(isA<CdnRequestFailure>()
              .having((e) => e.phase, 'phase', CdnRequestFailurePhase.body)
              .having((e) => e.message, 'message', isNot(contains('secret')))),
          emitsDone,
        ]));
    body.addError(StateError('secret signed URL'));
    await rejected;
    await body.close();
    expect(source.activeAttemptCount, 0);
  });
}

ResponseBody _body(
        {Stream<Uint8List>? stream,
        Map<String, List<String>> headers = const {}}) =>
    ResponseBody(stream ?? Stream.value(Uint8List.fromList([2, 3, 4, 5])), 206,
        headers: {
          'content-range': ['bytes 2-5/9'],
          'content-length': ['4'],
          ...headers
        });

class _Adapter implements HttpClientAdapter {
  RequestOptions? options;
  int calls = 0;
  Future<ResponseBody> Function(RequestOptions, Future<void>?) respond =
      (_, __) async => _body();
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    this.options = options;
    calls++;
    return respond(options, cancelFuture);
  }

  @override
  void close({bool force = false}) {}
}
