import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/core/network/api_result.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_proxy_constants.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_proxy_errors.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_range_policy.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_range_session.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_range_source.dart';

const _chunk = CdnProxyDefaults.chunkSize;
const _tag = CdnEntityTag(opaqueValue: 'version-one');
final _modified = DateTime.utc(2026, 9, 1, 12);
final _uri = Uri.parse('https://cdn.example.test/movie.mp4?signature=private');

void main() {
  group('CdnRangeSession initialization', () {
    test(
        'Given a resource, when initialized twice, then probes only byte zero once',
        () async {
      final source = _ControlledSource(12345);
      final session = _session(source);
      addTearDown(session.close);
      await _initialize(session, source);
      await session.initialize();
      expect(source.requests, hasLength(1));
      expect(source.requests.single.uri, _uri);
      expect(source.requests.single.headers, {'cookie': 'provider=value'});
      expect(source.requests.single.ifRangeEtag, isNull);
      expect(session.totalLength, 12345);
      expect(session.contentType, 'video/mp4');
      _expectReleased(session, source);
    });

    test('Given an empty resource, when probed, then owns no body or buffer',
        () async {
      final source = _ControlledSource(0);
      final session = _session(source);
      addTearDown(session.close);
      await _initialize(session, source);
      expect(session.totalLength, 0);
      _expectReleased(session, source);
    });

    for (final failure in [_http(504), _transportTimeout]) {
      test(
          'Given a failed metadata probe (${failure.kind.name}), when initialized, then does not retry',
          () async {
        final source = _ControlledSource(10);
        final errors = <Object>[];
        final session = _session(source, errors: errors);
        addTearDown(session.close);
        final result =
            expectLater(session.initialize(), throwsA(isA<CdnRangeFailure>()));
        (await source.requestAt(0)).reject(failure);
        await result;
        expect(source.requests, hasLength(1));
        expect(errors, hasLength(1));
        _expectReleased(session, source);
      });
    }

    test(
        'Given pending metadata, when closed twice, then cancels without a source failure',
        () async {
      final source = _ControlledSource(10);
      final errors = <Object>[];
      final session = _session(source, errors: errors);
      final initialized =
          expectLater(session.initialize(), throwsA(isA<CdnRangeCancelled>()));
      final request = await source.requestAt(0);
      final close = session.close();
      expect(identical(close, session.close()), isTrue);
      await close.timeout(const Duration(seconds: 5));
      await initialized;
      expect(request.token.isCancelled, isTrue);
      expect(source.closeCount, 1);
      expect(errors, isEmpty);
      _expectReleased(session, source);
    });
  });

  group('CdnRangeSession ordered streaming', () {
    for (final length in [100, 3 * _chunk]) {
      test(
          'Given $length bytes, when a prefix arrives, then streams before the chunk is complete',
          () async {
        final source = _ControlledSource(length);
        final session = _session(source);
        addTearDown(session.close);
        await _initialize(session, source);
        final capture =
            _Capture(session.read(CdnByteRange(start: 0, end: length - 1)));
        addTearDown(capture.cancel);
        final first = await source.requestAt(1);
        await _barrier();
        expect(source.requests, hasLength(2),
            reason: 'No expansion before first response headers');
        first.respondMetadata();
        first.body.add(_bytes(0, 17));
        await capture.waitForBytes(17);
        _expectBytes(capture.bytes, 0, 17);
        expect(first.ended, isFalse);
        expect(capture.completed, isFalse);
        await capture.cancel();
        _expectReleased(session, source);
      });
    }

    test(
        'Given a complete single body without EOF, when read, then withholds only the final byte',
        () async {
      final source = _ControlledSource(10);
      final session = _session(source);
      addTearDown(session.close);
      await _initialize(session, source);
      final capture =
          _Capture(session.read(const CdnByteRange(start: 2, end: 5)));
      final request = await source.requestAt(1);
      request.respondMetadata();
      request.body.add(_bytes(2, 4));
      await capture.waitForBytes(3);
      await _barrier();
      _expectBytes(capture.bytes, 2, 3);
      expect(capture.completed, isFalse);
      unawaited(request.body.close());
      await capture.done;
      expect(capture.errors, isEmpty);
      _expectBytes(capture.bytes, 2, 4);
      _expectReleased(session, source);
    });

    test(
        'Given out-of-order completed chunks, when the first streams, then later bytes remain ordered',
        () async {
      final source = _ControlledSource(3 * _chunk);
      final session = _session(source);
      addTearDown(session.close);
      await _initialize(session, source);
      final capture = _Capture(
          session.read(const CdnByteRange(start: 0, end: 3 * _chunk - 1)));
      final first = await source.requestAt(1);
      first.respondMetadata();
      final second = await source.requestAt(2);
      second.respondMetadata();
      final third = await source.requestAt(3);
      third.respond();
      second.finishBody();
      await third.bodyEnded.future;
      await second.bodyEnded.future;
      await _barrier();
      expect(capture.bytes, isEmpty);
      expect(session.budget.occupiedSlots, 3);
      first.body.add(_bytes(0, 1024));
      await capture.waitForBytes(1024);
      _expectBytes(capture.bytes, 0, 1024);
      first.finishBody(start: 1024);
      await capture.done;
      expect(capture.errors, isEmpty);
      _expectBytes(capture.bytes, 0, 3 * _chunk);
      expect(capture.bytes.every((bytes) => bytes.length <= 64 * 1024), isTrue);
      expect(session.budget.peakOccupiedSlots, 3);
      _expectReleased(session, source);
    });

    test(
        'Given a nonzero read and a short remainder, when consumed, then follows OpenList boundaries',
        () async {
      const start = 173;
      const length = 2 * _chunk + 37;
      final source = _ControlledSource(start + length + 100);
      final session = _session(source);
      addTearDown(session.close);
      await _initialize(session, source);
      source.onOpen = (request) => request.respond();
      final bytes = await session
          .read(const CdnByteRange(start: start, end: start + length - 1))
          .toList();
      expect(
          source.requests
              .skip(1)
              .map((request) => (request.start, request.end)),
          [
            (start, start + _chunk ~/ 2 - 1),
            (start + _chunk ~/ 2, start + _chunk + 36),
            (start + _chunk + 37, start + length - 1),
          ]);
      _expectBytes(bytes, start, length);
      _expectReleased(session, source);
    });

    test(
        'Given more than three chunks, when buffers roll, then retained output bytes never mutate',
        () async {
      final source = _ControlledSource(5 * _chunk + 7);
      final session = _session(source);
      addTearDown(session.close);
      await _initialize(session, source);
      source.onOpen = (request) => request.respond();
      final bytes = await session
          .read(CdnByteRange(start: 0, end: source.totalLength - 1))
          .toList();
      _expectBytes(bytes, 0, source.totalLength);
      expect(bytes.every((bytes) => bytes.length <= 64 * 1024), isTrue);
      expect(source.requests, hasLength(7));
      expect(source.peakActive, lessThanOrEqualTo(3));
      expect(session.budget.peakOccupiedSlots, lessThanOrEqualTo(3));
      _expectReleased(session, source);
    });

    test(
        'Given a paused consumer, when prefetch completes, then memory stays at three slots and cancellation releases them',
        () async {
      final source = _ControlledSource(8 * _chunk);
      final session = _session(source);
      addTearDown(session.close);
      await _initialize(session, source);
      final paused = Completer<void>();
      late final StreamSubscription<Uint8List> subscription;
      subscription = session
          .read(CdnByteRange(start: 0, end: source.totalLength - 1))
          .listen((_) {
        subscription.pause();
        if (!paused.isCompleted) paused.complete();
      });
      final first = await source.requestAt(1);
      first.respondMetadata();
      final second = await source.requestAt(2);
      second.respondMetadata();
      final third = await source.requestAt(3);
      first.finishBody();
      await paused.future;
      second.finishBody();
      third.respond();
      await second.bodyEnded.future;
      await third.bodyEnded.future;
      await _barrier();
      expect(source.requests, hasLength(4));
      expect(session.budget.occupiedSlots, 3);
      expect(session.allocatedBufferBytes, lessThanOrEqualTo(3 * _chunk));
      expect(session.bufferedBytes, lessThanOrEqualTo(3 * _chunk));
      await subscription.cancel().timeout(const Duration(seconds: 5));
      _expectReleased(session, source);
    });
  });

  group('CdnRangeSession retry policy', () {
    for (final failure in [
      _http(504),
      _transportTimeout,
      const SocketException('reset')
    ]) {
      test(
          'Given a single-range ${failure.runtimeType} failure, when failed, then never retries or resumes',
          () async {
        final source = _ControlledSource(10);
        final errors = <Object>[];
        final session = _session(source, errors: errors);
        addTearDown(session.close);
        await _initialize(session, source);
        final result = expectLater(
            session.read(const CdnByteRange(start: 2, end: 5)).toList(),
            throwsA(isA<CdnRangeFailure>()));
        final request = await source.requestAt(1);
        if (failure is CdnRequestFailure) {
          request.reject(failure);
        } else {
          request.respondMetadata();
          request.body.add(_bytes(2, 2));
          request.body.addError(failure);
        }
        await result;
        expect(source.requests, hasLength(2));
        expect(errors, isEmpty);
        _expectReleased(session, source);
      });
    }

    test(
        'Given multiple partial body failures, when retried, then requests only accepted-prefix suffixes',
        () async {
      final source = _ControlledSource(2 * _chunk);
      final errors = <Object>[];
      final session = _session(source, errors: errors);
      addTearDown(session.close);
      await _initialize(session, source);
      source.onOpen = (request) {
        if (request.start >= _chunk) {
          request.respond();
        }
      };
      final capture = _Capture(
          session.read(const CdnByteRange(start: 0, end: 2 * _chunk - 1)));
      var request = await source
          .requestWhere((request) => request.start == 0 && request.end > 0);
      request.respondMetadata();
      request.body.add(_bytes(0, 7));
      request.body.addError(const SocketException('private signed URL'));
      request = await source.requestWhere((request) => request.start == 7);
      expect(request.end, _chunk - 1);
      request.respondMetadata();
      request.body.add(_bytes(7, 11));
      unawaited(request.body.close());
      request = await source.requestWhere((request) => request.start == 18);
      expect(request.end, _chunk - 1);
      request.respond();
      await capture.done;
      expect(capture.errors, isEmpty);
      _expectBytes(capture.bytes, 0, 2 * _chunk);
      expect(
          source.requests
              .where((request) => request.end == _chunk - 1)
              .map((request) => request.start),
          [0, 7, 18]);
      expect(errors, isEmpty);
      expect(session.budget.peakOccupiedSlots, lessThanOrEqualTo(3));
      _expectReleased(session, source);
    });

    test(
        'Given body errors after accepted bytes, when the fourth attempt fails, then stops and frees sibling tasks',
        () async {
      final source = _ControlledSource(3 * _chunk);
      final errors = <Object>[];
      final session = _session(source, errors: errors);
      addTearDown(session.close);
      await _initialize(session, source);
      source.onOpen = (request) {
        if (request.start >= _chunk) {
          request.respondMetadata();
        }
      };
      final result = expectLater(
          session
              .read(const CdnByteRange(start: 0, end: 3 * _chunk - 1))
              .toList(),
          throwsA(isA<CdnRangeFailure>()));
      for (var attempt = 0; attempt < 4; attempt++) {
        final request = await source.requestWhere(
            (request) => request.start == attempt && request.end == _chunk - 1);
        request.respondMetadata();
        request.body.add(_bytes(attempt, 1));
        request.body.addError(const SocketException('reset'));
      }
      await result;
      expect(source.requests.where((request) => request.end == _chunk - 1),
          hasLength(4));
      expect(errors, isEmpty);
      _expectReleased(session, source);
    });
    for (final status in [429, 502, 503, 504]) {
      test(
          'Given first-chunk HTTP $status, when it persists, then makes exactly four attempts',
          () async {
        final source = _ControlledSource(2 * _chunk);
        final errors = <Object>[];
        var delays = 0;
        final session = _session(source, errors: errors, retryJitter: () {
          delays++;
          return Duration.zero;
        });
        addTearDown(session.close);
        await _initialize(session, source);
        final result = expectLater(
            session
                .read(const CdnByteRange(start: 0, end: 2 * _chunk - 1))
                .toList(),
            throwsA(isA<CdnRangeFailure>()));
        for (var attempt = 1; attempt <= 4; attempt++) {
          (await source.requestAt(attempt)).reject(_http(status));
        }
        await result;
        expect(source.requests, hasLength(5));
        expect(delays, 3);
        expect(errors, isEmpty);
        _expectReleased(session, source);
      });
    }

    for (final status in [400, 401, 403, 404, 408, 416, 500]) {
      test(
          'Given first-chunk HTTP $status, when rejected, then fails without retry',
          () async {
        final source = _ControlledSource(2 * _chunk);
        final session = _session(source);
        addTearDown(session.close);
        await _initialize(session, source);
        final result = expectLater(
            session
                .read(const CdnByteRange(start: 0, end: 2 * _chunk - 1))
                .toList(),
            throwsA(isA<CdnRangeFailure>()));
        (await source.requestAt(1)).reject(_http(status));
        await result;
        expect(source.requests, hasLength(2));
        _expectReleased(session, source);
      });
    }

    test(
        'Given first-chunk HTTP and body errors, when mixed, then shares one finite retry budget',
        () async {
      final source = _ControlledSource(2 * _chunk);
      final session = _session(source);
      addTearDown(session.close);
      await _initialize(session, source);
      source.onOpen = (request) {
        if (request.start >= _chunk) {
          request.respondMetadata();
        }
      };
      final result = expectLater(
          session
              .read(const CdnByteRange(start: 0, end: 2 * _chunk - 1))
              .toList(),
          throwsA(isA<CdnRangeFailure>()));
      (await source.requestAt(1)).reject(_http(503));
      var request = await source.requestAt(2);
      request.respondMetadata();
      request.body.add(_bytes(0, 7));
      request.body.addError(const SocketException('reset'));
      request = await source.requestWhere((request) => request.start == 7);
      request.reject(_http(504));
      request = await source.requestWhere((request) => request.start == 7,
          occurrence: 2);
      request.respondMetadata();
      request.body.add(_bytes(7, 1));
      request.body.addError(const SocketException('reset'));
      await result;
      expect(source.requests.where((request) => request.end == _chunk - 1),
          hasLength(4));
      _expectReleased(session, source);
    });

    test(
        'Given a multi-chunk header timeout, when failed, then does not enter body retries',
        () async {
      final source = _ControlledSource(2 * _chunk);
      final session = _session(source);
      addTearDown(session.close);
      await _initialize(session, source);
      final result = expectLater(
          session
              .read(const CdnByteRange(start: 0, end: 2 * _chunk - 1))
              .toList(),
          throwsA(isA<CdnRangeFailure>()));
      (await source.requestAt(1)).reject(_transportTimeout);
      await result;
      expect(source.requests, hasLength(2));
      _expectReleased(session, source);
    });

    for (final status in [401, 403, 404, 408, 429, 500, 502, 503, 504]) {
      test(
          'Given later-chunk HTTP $status, when repeated beyond four failures, then retains an executor and recovers',
          () async {
        final source = _ControlledSource(2 * _chunk);
        final errors = <Object>[];
        final session = _session(source, errors: errors);
        addTearDown(session.close);
        await _initialize(session, source);
        final result = session
            .read(const CdnByteRange(start: 0, end: 2 * _chunk - 1))
            .toList();
        (await source.requestAt(1)).respond();
        for (var attempt = 0; attempt < 7; attempt++) {
          final request = await source.requestWhere(
              (request) => request.start == _chunk,
              occurrence: attempt + 1);
          request.reject(_http(status));
        }
        final retry = await source
            .requestWhere((request) => request.start == _chunk, occurrence: 8);
        retry.respond();
        _expectBytes(await result, 0, 2 * _chunk);
        expect(errors, isEmpty);
        expect(session.budget.peakOccupiedSlots, lessThanOrEqualTo(3));
        _expectReleased(session, source);
      });
    }

    test(
        'Given later-chunk HTTP 416, when rejected, then cancels only its read',
        () async {
      final source = _ControlledSource(2 * _chunk);
      final errors = <Object>[];
      final session = _session(source, errors: errors);
      addTearDown(session.close);
      await _initialize(session, source);
      final result = expectLater(
          session
              .read(const CdnByteRange(start: 0, end: 2 * _chunk - 1))
              .toList(),
          throwsA(isA<CdnRangeFailure>()));
      (await source.requestAt(1)).respondMetadata();
      (await source.requestAt(2)).reject(_http(416));
      await result;
      expect(source.requests, hasLength(3));
      expect(errors, isEmpty);
      _expectReleased(session, source);
    });

    test(
        'Given all expected bytes followed by an error, when failed, then does not request an empty suffix or deliver the tail',
        () async {
      final source = _ControlledSource(2 * _chunk);
      final session = _session(source);
      addTearDown(session.close);
      await _initialize(session, source);
      final capture = _Capture(
          session.read(const CdnByteRange(start: 0, end: 2 * _chunk - 1)));
      final request = await source.requestAt(1);
      request.respondMetadata();
      request.body.add(_bytes(0, _chunk));
      request.body.addError(const SocketException('EOF missing'));
      await capture.done;
      expect(capture.errors, hasLength(1));
      expect(capture.byteCount, lessThan(_chunk));
      expect(source.requests.where((request) => request.end == _chunk - 1),
          hasLength(1));
      expect(source.requests.every((request) => request.start <= request.end),
          isTrue);
      _expectReleased(session, source);
    });
  });

  group('CdnRangeSession retry edges', () {
    test(
        'Given a prefetched prefix that has not been delivered, when its body fails, then resumes after accepted bytes',
        () async {
      final source = _ControlledSource(2 * _chunk);
      final session = _session(source);
      addTearDown(session.close);
      await _initialize(session, source);
      final capture = _Capture(
          session.read(const CdnByteRange(start: 0, end: 2 * _chunk - 1)));
      final first = await source.requestAt(1);
      first.respondMetadata();
      final second = await source.requestAt(2);
      second.respondMetadata();
      second.body.add(_bytes(_chunk, 17));
      second.body.addError(const SocketException('reset'));
      final suffix =
          await source.requestWhere((request) => request.start == _chunk + 17);
      expect(suffix.end, 2 * _chunk - 1);
      expect(capture.bytes, isEmpty);
      expect(session.budget.occupiedSlots, 2);
      suffix.respond();
      first.finishBody();
      await capture.done;
      expect(capture.errors, isEmpty);
      _expectBytes(capture.bytes, 0, 2 * _chunk);
      _expectReleased(session, source);
    });

    test(
        'Given a typed body deadline, when retried, then resumes its prefix despite header timeout being terminal',
        () async {
      final source = _ControlledSource(2 * _chunk);
      final session = _session(source);
      addTearDown(session.close);
      await _initialize(session, source);
      source.onOpen = (request) {
        if (request.start >= _chunk) {
          request.respond();
        }
      };
      final result = session
          .read(const CdnByteRange(start: 0, end: 2 * _chunk - 1))
          .toList();
      final first = await source.requestAt(1);
      first.respondMetadata();
      first.body.add(_bytes(0, 7));
      first.body.addError(const CdnRequestFailure(
        message: 'Deadline exceeded',
        displayMessage: 'Deadline exceeded',
        isTimeout: true,
        kind: CdnRequestFailureKind.transport,
        phase: CdnRequestFailurePhase.body,
      ));
      final retry = await source.requestWhere((request) => request.start == 7);
      retry.respond();
      _expectBytes(await result, 0, 2 * _chunk);
      _expectReleased(session, source);
    });

    test(
        'Given four empty EOFs, when the body retry budget is exhausted, then sends no bytes and cancels siblings',
        () async {
      final source = _ControlledSource(2 * _chunk);
      final session = _session(source);
      addTearDown(session.close);
      await _initialize(session, source);
      final capture = _Capture(
          session.read(const CdnByteRange(start: 0, end: 2 * _chunk - 1)));
      for (var attempt = 1; attempt <= 4; attempt++) {
        final request = await source.requestWhere(
            (request) => request.end == _chunk - 1,
            occurrence: attempt);
        request.respond(bytes: Uint8List(0));
      }
      await capture.done;
      expect(capture.errors, hasLength(1));
      expect(capture.bytes, isEmpty);
      expect(source.requests.where((request) => request.end == _chunk - 1),
          hasLength(4));
      _expectReleased(session, source);
    });

    test(
        'Given an overlong chunk body, when validated, then rejects rather than retrying or emitting that event',
        () async {
      final source = _ControlledSource(2 * _chunk);
      final session = _session(source);
      addTearDown(session.close);
      await _initialize(session, source);
      final capture = _Capture(
          session.read(const CdnByteRange(start: 0, end: 2 * _chunk - 1)));
      (await source.requestAt(1)).respond(bytes: _bytes(0, _chunk + 1));
      await capture.done;
      expect(capture.errors, hasLength(1));
      expect(capture.bytes, isEmpty);
      expect(source.requests.where((request) => request.end == _chunk - 1),
          hasLength(1));
      _expectReleased(session, source);
    });

    test(
        'Given a later task with spent body retries, when HTTP retirement requeues it, then its new worker gets a fresh finite budget',
        () async {
      final source = _ControlledSource(2 * _chunk);
      final session = _session(source);
      addTearDown(session.close);
      await _initialize(session, source);
      final capture = _Capture(
          session.read(const CdnByteRange(start: 0, end: 2 * _chunk - 1)));
      final first = await source.requestAt(1);
      first.respondMetadata();
      for (var accepted = 0; accepted < 2; accepted++) {
        final request = await source
            .requestWhere((request) => request.start == _chunk + accepted);
        request.respondMetadata();
        request.body.add(_bytes(_chunk + accepted, 1));
        request.body.addError(const SocketException('reset'));
      }
      first.finishBody();
      await capture.waitForBytes(_chunk);
      await _barrier();
      (await source.requestWhere((request) => request.start == _chunk + 2))
          .reject(_http(403));
      var resumed = await source.requestWhere(
          (request) => request.start == _chunk + 2,
          occurrence: 2);
      for (var accepted = 2; accepted < 5; accepted++) {
        resumed.respondMetadata();
        resumed.body.add(_bytes(_chunk + accepted, 1));
        resumed.body.addError(const SocketException('reset'));
        resumed = await source
            .requestWhere((request) => request.start == _chunk + accepted + 1);
      }
      resumed.respond();
      await capture.done;
      expect(capture.errors, isEmpty);
      _expectBytes(capture.bytes, 0, 2 * _chunk);
      expect(source.requests.where((request) => request.start >= _chunk),
          hasLength(7));
      _expectReleased(session, source);
    });

    test(
        'Given two chunks and a held first body, when the resumed second gets HTTP 403, then retires to one worker before retrying',
        () async {
      const total = 11 * 1024 * 1024;
      const firstSize = 5 * 1024 * 1024;
      const prefix = 19;
      final source = _ControlledSource(total);
      final session = _session(source);
      addTearDown(session.close);
      await _initialize(session, source);
      final capture =
          _Capture(session.read(const CdnByteRange(start: 0, end: total - 1)));
      final first = await source.requestAt(1);
      expect((first.start, first.end), (0, firstSize - 1));
      first.respondMetadata();
      final second = await source.requestAt(2);
      expect((second.start, second.end), (firstSize, total - 1));
      second.respondMetadata();
      second.body.add(_bytes(firstSize, prefix));
      second.body.addError(const SocketException('reset after a valid prefix'));
      final suffix = await source.requestAt(3);
      expect((suffix.start, suffix.end), (firstSize + prefix, total - 1));
      suffix.reject(_http(403));
      await suffix.token.whenCancel;
      await _barrier();
      expect(source.requests, hasLength(4),
          reason:
              'After 2-to-1 retirement, the held first body owns the only executor');
      expect(session.activeDownloadCount, 1);
      expect(session.budget.occupiedSlots, 2);
      expect(capture.bytes, isEmpty);
      expect(first.ended, isFalse);

      first.finishBody();
      for (var occurrence = 2; occurrence <= 7; occurrence++) {
        final retry = await source.requestWhere(
            (request) => request.start == firstSize + prefix,
            occurrence: occurrence);
        retry.reject(_http(403));
      }
      final recovered = await source.requestWhere(
          (request) => request.start == firstSize + prefix,
          occurrence: 8);
      recovered.respond();
      await capture.done;
      expect(capture.errors, isEmpty);
      _expectBytes(capture.bytes, 0, total);
      expect(source.requests.where((request) => request.start == firstSize),
          hasLength(1),
          reason: 'The accepted prefix must not be downloaded again');
      expect(session.budget.peakOccupiedSlots, 2);
      _expectReleased(session, source);
    });
    test(
        'Given the reader is waiting on a later chunk, when HTTP errors repeat, then immediate retries do not request jitter',
        () async {
      final source = _ControlledSource(2 * _chunk);
      var jitterCalls = 0;
      final session = _session(source, retryJitter: () {
        jitterCalls++;
        return Duration.zero;
      });
      addTearDown(session.close);
      await _initialize(session, source);
      final capture = _Capture(
          session.read(const CdnByteRange(start: 0, end: 2 * _chunk - 1)));
      (await source.requestAt(1)).respond();
      await capture.waitForBytes(_chunk);
      await _barrier();
      for (var attempt = 1; attempt <= 6; attempt++) {
        (await source.requestWhere((request) => request.start == _chunk,
                occurrence: attempt))
            .reject(_http(403));
      }
      (await source.requestWhere((request) => request.start == _chunk,
              occurrence: 7))
          .respond();
      await capture.done;
      expect(capture.errors, isEmpty);
      expect(jitterCalls, 0);
      _expectBytes(capture.bytes, 0, 2 * _chunk);
      _expectReleased(session, source);
    });
  });
  group('CdnRangeSession identity and isolation', () {
    test(
        'Given a strong probe ETag, when downloading and resuming, then conditions requests on the same resource',
        () async {
      final source = _ControlledSource(2 * _chunk);
      final session = _session(source);
      addTearDown(session.close);
      await _initialize(session, source,
          entityTag: _tag, lastModified: _modified);
      source.onOpen = (request) {
        if (request.start >= _chunk) {
          request.respond(entityTag: _tag, lastModified: _modified);
        }
      };
      final result = session
          .read(const CdnByteRange(start: 0, end: 2 * _chunk - 1))
          .toList();
      var request = await source.requestAt(1);
      expect(request.ifRangeEtag, '"version-one"');
      request.respondMetadata(entityTag: _tag, lastModified: _modified);
      request.body.add(_bytes(0, 7));
      request.body.addError(const SocketException('reset'));
      request = await source.requestWhere((request) => request.start == 7);
      expect(request.ifRangeEtag, '"version-one"');
      request.respond(entityTag: _tag, lastModified: _modified);
      _expectBytes(await result, 0, 2 * _chunk);
      expect(
          source.requests
              .skip(1)
              .every((request) => request.ifRangeEtag == '"version-one"'),
          isTrue);
      _expectReleased(session, source);
    });

    test(
        'Given a missing probe tag, when first media headers supply it, then pins before expanding',
        () async {
      final source = _ControlledSource(2 * _chunk);
      final session = _session(source);
      addTearDown(session.close);
      await _initialize(session, source);
      final capture = _Capture(
          session.read(const CdnByteRange(start: 0, end: 2 * _chunk - 1)));
      final first = await source.requestAt(1);
      expect(first.ifRangeEtag, isNull);
      first.respondMetadata(entityTag: _tag);
      final second = await source.requestAt(2);
      expect(second.ifRangeEtag, '"version-one"');
      second.respond(entityTag: _tag);
      first.finishBody();
      await capture.done;
      expect(capture.errors, isEmpty);
      _expectBytes(capture.bytes, 0, 2 * _chunk);
    });

    test(
        'Given only a weak tag and a date, when read, then checks identity without sending If-Range',
        () async {
      const weakTag = CdnEntityTag(opaqueValue: 'weak-one', isWeak: true);
      final source = _ControlledSource(10);
      final session = _session(source);
      addTearDown(session.close);
      await _initialize(session, source,
          entityTag: weakTag, lastModified: _modified);
      final result =
          session.read(const CdnByteRange(start: 2, end: 5)).toList();
      final request = await source.requestAt(1);
      expect(request.ifRangeEtag, isNull);
      request.respond(entityTag: weakTag, lastModified: _modified.toLocal());
      _expectBytes(await result, 2, 4);
      _expectReleased(session, source);
    });

    final changes = <String, void Function(_PendingRequest)>{
      'changed strong tag': (request) => request.respond(
          entityTag: const CdnEntityTag(opaqueValue: 'version-two'),
          lastModified: _modified),
      'missing pinned tag': (request) =>
          request.respond(lastModified: _modified),
      'weakened tag': (request) => request.respond(
          entityTag:
              const CdnEntityTag(opaqueValue: 'version-one', isWeak: true),
          lastModified: _modified),
      'changed date': (request) => request.respond(
          entityTag: _tag,
          lastModified: _modified.add(const Duration(seconds: 1))),
      'missing pinned date': (request) => request.respond(entityTag: _tag),
      'changed total length': (request) => request.respond(
          totalLength: 11, entityTag: _tag, lastModified: _modified),
    };
    for (final entry in changes.entries) {
      test(
          'Given ${entry.key}, when received, then invalidates all readers exactly once',
          () async {
        final source = _ControlledSource(10);
        final errors = <Object>[];
        final session = _session(source, errors: errors);
        addTearDown(session.close);
        await _initialize(session, source,
            entityTag: _tag, lastModified: _modified);
        final first =
            _Capture(session.read(const CdnByteRange(start: 0, end: 3)));
        final other =
            _Capture(session.read(const CdnByteRange(start: 5, end: 8)));
        final requests = [await source.requestAt(1), await source.requestAt(2)];
        entry.value(requests[0]);
        await first.done;
        await other.done;
        expect(first.errors, hasLength(1));
        expect(other.errors, hasLength(1));
        expect(errors, [isA<CdnResourceChanged>()]);
        expect(requests.every((request) => request.token.isCancelled), isTrue);
        await expectLater(
            session.read(const CdnByteRange(start: 0, end: 1)).toList(),
            throwsA(isA<CdnResourceChanged>()));
        _expectReleased(session, source);
      });
    }

    for (final failure in [_http(404), _protocolFailure, _transportTimeout]) {
      test(
          'Given one ${failure.kind.name} failure, when another read is active, then keeps that read and the source usable',
          () async {
        final source = _ControlledSource(20);
        final errors = <Object>[];
        final session = _session(source, errors: errors);
        addTearDown(session.close);
        await _initialize(session, source);
        final failed = expectLater(
            session.read(const CdnByteRange(start: 0, end: 3)).toList(),
            throwsA(isA<CdnRangeFailure>()));
        final healthy =
            session.read(const CdnByteRange(start: 5, end: 8)).toList();
        final rejected = await source
            .requestWhere((request) => request.start == 0 && request.end == 3);
        final active =
            await source.requestWhere((request) => request.start == 5);
        active.respondMetadata();
        rejected.reject(failure);
        await failed;
        expect(active.token.isCancelled, isFalse);
        active.finishBody();
        _expectBytes(await healthy, 5, 4);
        final next =
            session.read(const CdnByteRange(start: 10, end: 12)).toList();
        (await source.requestWhere((request) => request.start == 10)).respond();
        _expectBytes(await next, 10, 3);
        expect(errors, isEmpty);
        expect(source.closeCount, 0);
        _expectReleased(session, source);
      });
    }

    for (final mime in [
      'application/vnd.apple.mpegurl',
      'application/x-mpegurl',
      'audio/mpegurl',
      'audio/x-mpegurl'
    ]) {
      test(
          'Given $mime and valid bytes, when read, then MIME does not reroute the proxy',
          () async {
        final source = _ControlledSource(10);
        final session = _session(source);
        addTearDown(session.close);
        final initialized = session.initialize();
        (await source.requestAt(0)).respond(contentType: mime);
        await initialized;
        expect(session.contentType, mime);
        final result =
            session.read(const CdnByteRange(start: 2, end: 5)).toList();
        (await source.requestAt(1)).respond(contentType: mime);
        _expectBytes(await result, 2, 4);
      });
    }
  });
  group('CdnRangeSession shared budget and cancellation', () {
    test('Given two sessions, when both read, then share the three-slot window',
        () async {
      final budget = CdnRangeBudget();
      final firstSource = _ControlledSource(3 * _chunk + 7);
      final secondSource = _ControlledSource(3 * _chunk + 9);
      final first = _session(firstSource, budget: budget);
      final second = _session(secondSource, budget: budget);
      addTearDown(first.close);
      addTearDown(second.close);
      await _initialize(first, firstSource);
      await _initialize(second, secondSource);
      firstSource.onOpen = (request) => request.respond();
      secondSource.onOpen = (request) => request.respond();
      final results = await Future.wait([
        first
            .read(CdnByteRange(start: 0, end: firstSource.totalLength - 1))
            .toList(),
        second
            .read(CdnByteRange(start: 0, end: secondSource.totalLength - 1))
            .toList(),
      ]);
      _expectBytes(results[0], 0, firstSource.totalLength);
      _expectBytes(results[1], 0, secondSource.totalLength);
      expect(budget.peakOccupiedSlots, lessThanOrEqualTo(3));
      _expectReleased(first, firstSource);
      _expectReleased(second, secondSource);
    });

    for (final closeSession in [false, true]) {
      test(
          'Given a day-long retry delay, when ${closeSession ? 'closed' : 'unsubscribed'}, then cancels immediately',
          () async {
        final source = _ControlledSource(2 * _chunk);
        final errors = <Object>[];
        final retrying = Completer<void>();
        final session = _session(source, errors: errors, retryJitter: () {
          if (!retrying.isCompleted) retrying.complete();
          return const Duration(days: 1);
        });
        addTearDown(session.close);
        await _initialize(session, source);
        final capture = _Capture(
            session.read(const CdnByteRange(start: 0, end: 2 * _chunk - 1)));
        (await source.requestAt(1)).reject(_http(503));
        await retrying.future;
        expect(session.budget.occupiedSlots, 1);
        if (closeSession) {
          await session.close().timeout(const Duration(seconds: 5));
          await capture.done;
          expect(capture.errors, everyElement(isA<CdnRangeCancelled>()));
        } else {
          await capture.cancel().timeout(const Duration(seconds: 5));
          expect(capture.errors, isEmpty);
        }
        expect(source.requests, hasLength(2));
        expect(errors, isEmpty);
        _expectReleased(session, source);
      });
    }

    test(
        'Given active bodies and a waiting new-source probe, when old source closes, then the new source reuses every slot',
        () async {
      final budget = CdnRangeBudget();
      final oldSource = _ControlledSource(3 * _chunk);
      final newSource = _ControlledSource(20);
      final oldSession = _session(oldSource, budget: budget);
      final newSession = _session(newSource, budget: budget);
      addTearDown(oldSession.close);
      addTearDown(newSession.close);
      await _initialize(oldSession, oldSource);
      final old = _Capture(
          oldSession.read(const CdnByteRange(start: 0, end: 3 * _chunk - 1)));
      (await oldSource.requestAt(1)).respondMetadata();
      (await oldSource.requestAt(2)).respondMetadata();
      await oldSource.requestAt(3);
      final initialized = newSession.initialize();
      await _barrier();
      expect(newSource.requests, isEmpty);
      expect(budget.occupiedSlots, 3);
      final closing = oldSession.close();
      expect(identical(closing, oldSession.close()), isTrue);
      await closing.timeout(const Duration(seconds: 5));
      await old.done;
      expect(old.errors, everyElement(isA<CdnRangeCancelled>()));
      (await newSource.requestAt(0)).respond();
      await initialized;
      final result =
          newSession.read(const CdnByteRange(start: 2, end: 5)).toList();
      (await newSource.requestAt(1)).respond();
      _expectBytes(await result, 2, 4);
      expect(oldSource.closeCount, 1);
      _expectReleased(oldSession, oldSource);
      _expectReleased(newSession, newSource);
    });

    test(
        'Given invalid intervals, when listened, then rejects without allocating or requesting',
        () async {
      final source = _ControlledSource(10);
      final session = _session(source);
      addTearDown(session.close);
      await _initialize(session, source);
      for (final range in [
        const CdnByteRange(start: -1, end: 1),
        const CdnByteRange(start: 2, end: 1),
        const CdnByteRange(start: 10, end: 10),
      ]) {
        await expectLater(session.read(range).toList(),
            throwsA(isA<CdnRangeNotSatisfiable>()));
      }
      expect(source.requests, hasLength(1));
      _expectReleased(session, source);
    });
  });
}

const _transportTimeout = CdnRequestFailure(
  message: 'Request deadline exceeded',
  displayMessage: 'Request deadline exceeded',
  isTimeout: true,
  kind: CdnRequestFailureKind.transport,
  phase: CdnRequestFailurePhase.headers,
);
const _protocolFailure = CdnRequestFailure(
  message: 'Invalid range response',
  displayMessage: 'Invalid range response',
  kind: CdnRequestFailureKind.protocol,
  phase: CdnRequestFailurePhase.headers,
);
CdnRequestFailure _http(int status) => CdnRequestFailure(
      message: 'HTTP $status',
      displayMessage: 'HTTP $status',
      kind: CdnRequestFailureKind.httpStatus,
      phase: CdnRequestFailurePhase.headers,
      statusCode: status,
    );

CdnRangeSession _session(
  _ControlledSource source, {
  CdnRangeBudget? budget,
  List<Object>? errors,
  Duration Function()? retryJitter,
}) =>
    CdnRangeSession(
      source: source,
      uri: _uri,
      headers: const {'cookie': 'provider=value'},
      budget: budget ?? CdnRangeBudget(),
      onError: errors?.add,
      retryJitter: retryJitter ?? () => Duration.zero,
    );

Future<void> _initialize(
  CdnRangeSession session,
  _ControlledSource source, {
  CdnEntityTag? entityTag,
  DateTime? lastModified,
}) async {
  final initialized = session.initialize();
  final request = await source.requestAt(0);
  expect((request.start, request.end), (0, 0));
  request.respond(
      entityTag: entityTag,
      lastModified: lastModified,
      bytes: source.totalLength == 0 ? Uint8List(0) : null);
  await initialized;
}

void _expectReleased(CdnRangeSession session, _ControlledSource source) {
  expect(session.budget.occupiedSlots, 0);
  expect(session.activeDownloadCount, 0);
  expect(session.allocatedBufferBytes, 0);
  expect(session.bufferedBytes, 0);
  expect(source.active, 0);
}

// An event-queue barrier drains deterministic fake work without timing sleeps.
Future<void> _barrier() => Future<void>(() {});
int _byteAt(int offset) => (offset * 17 + offset ~/ 251) & 0xff;
Uint8List _bytes(int start, int length) {
  final bytes = Uint8List(length);
  for (var index = 0; index < length; index++) {
    bytes[index] = _byteAt(start + index);
  }
  return bytes;
}

void _expectBytes(List<Uint8List> chunks, int start, int length) {
  var offset = start;
  for (final chunk in chunks) {
    for (final byte in chunk) {
      if (byte != _byteAt(offset)) fail('Unexpected byte at offset $offset');
      offset++;
    }
  }
  expect(offset, start + length);
}

class _Capture {
  _Capture(Stream<Uint8List> stream) {
    _subscription = stream.listen(
        (data) {
          bytes.add(data);
          byteCount += data.length;
          for (final waiter in _waiters.toList()) {
            if (byteCount >= waiter.$1) {
              _waiters.remove(waiter);
              waiter.$2.complete();
            }
          }
        },
        onError: errors.add,
        onDone: () {
          completed = true;
          _done.complete();
        });
  }
  final bytes = <Uint8List>[];
  final errors = <Object>[];
  final _done = Completer<void>();
  final _waiters = <(int, Completer<void>)>[];
  late final StreamSubscription<Uint8List> _subscription;
  int byteCount = 0;
  bool completed = false;
  Future<void> get done => _done.future.timeout(const Duration(seconds: 5));
  Future<void> cancel() => _subscription.cancel();
  Future<void> waitForBytes(int count) {
    if (byteCount >= count) return Future.value();
    final waiter = Completer<void>();
    _waiters.add((count, waiter));
    return waiter.future.timeout(const Duration(seconds: 5));
  }
}

class _ControlledSource implements CdnRangeSource {
  _ControlledSource(this.totalLength);
  final int totalLength;
  final requests = <_PendingRequest>[];
  final _changed = <Completer<void>>[];
  void Function(_PendingRequest)? onOpen;
  int active = 0;
  int peakActive = 0;
  int closeCount = 0;

  @override
  Future<ApiResult<CdnRangeResponse>> open({
    required Uri uri,
    required Map<String, String> headers,
    required int start,
    required int end,
    required CancelToken cancelToken,
    String? ifRangeEtag,
  }) {
    final request = _PendingRequest(
        this, uri, Map.of(headers), start, end, cancelToken, ifRangeEtag);
    requests.add(request);
    active++;
    if (active > peakActive) peakActive = active;
    for (final waiter in _changed.toList()) {
      waiter.complete();
    }
    _changed.clear();
    onOpen?.call(request);
    return request.response.future;
  }

  Future<_PendingRequest> requestAt(int index) async {
    while (requests.length <= index) {
      final changed = Completer<void>();
      _changed.add(changed);
      await changed.future.timeout(const Duration(seconds: 5), onTimeout: () {
        throw TimeoutException(
            'Expected request #$index; got ${requests.map((request) => (
                  request.start,
                  request.end
                )).toList()}');
      });
    }
    return requests[index];
  }

  Future<_PendingRequest> requestWhere(bool Function(_PendingRequest) predicate,
      {int occurrence = 1}) async {
    while (true) {
      final matching = requests.where(predicate).toList();
      if (matching.length >= occurrence) return matching[occurrence - 1];
      final changed = Completer<void>();
      _changed.add(changed);
      await changed.future.timeout(const Duration(seconds: 5), onTimeout: () {
        throw TimeoutException(
            'Expected matching request $occurrence; got ${requests.map((request) => (
                  request.start,
                  request.end
                )).toList()}');
      });
    }
  }

  @override
  void close() {
    closeCount++;
    for (final request in requests) {
      if (!request.ended) request.token.cancel('Fake source closed');
    }
  }
}

class _PendingRequest {
  _PendingRequest(this.source, this.uri, this.headers, this.start, this.end,
      this.token, this.ifRangeEtag) {
    body = StreamController<Uint8List>(onCancel: () {
      _finish();
      if (!bodyEnded.isCompleted) bodyEnded.complete();
    });
    unawaited(token.whenCancel.then((_) {
      if (!response.isCompleted) {
        response.complete(const ResultFailure(CdnRequestFailure(
            message: 'Cancelled',
            displayMessage: 'Cancelled',
            kind: CdnRequestFailureKind.cancelled)));
      }
      _finish();
      if (!body.isClosed) unawaited(body.close());
    }));
  }
  final _ControlledSource source;
  final Uri uri;
  final Map<String, String> headers;
  final int start;
  final int end;
  final CancelToken token;
  final String? ifRangeEtag;
  final response = Completer<ApiResult<CdnRangeResponse>>();
  final bodyEnded = Completer<void>();
  late final StreamController<Uint8List> body;
  bool ended = false;

  void _finish() {
    if (ended) return;
    ended = true;
    source.active--;
  }

  void respondMetadata(
      {int? totalLength,
      String contentType = 'video/mp4',
      CdnEntityTag? entityTag,
      DateTime? lastModified}) {
    response.complete(Success(CdnRangeResponse(
      totalLength: totalLength ?? source.totalLength,
      contentType: contentType,
      stream: body.stream,
      entityTag: entityTag,
      lastModified: lastModified,
    )));
  }

  void reject(CdnRequestFailure failure) =>
      response.complete(ResultFailure(failure));
  void finishBody({int? start, Uint8List? bytes}) {
    final offset = start ?? this.start;
    body.add(bytes ?? _bytes(offset, end - offset + 1));
    unawaited(body.close());
  }

  void respond(
      {int? totalLength,
      String contentType = 'video/mp4',
      Uint8List? bytes,
      CdnEntityTag? entityTag,
      DateTime? lastModified}) {
    respondMetadata(
        totalLength: totalLength,
        contentType: contentType,
        entityTag: entityTag,
        lastModified: lastModified);
    finishBody(bytes: bytes);
  }
}
