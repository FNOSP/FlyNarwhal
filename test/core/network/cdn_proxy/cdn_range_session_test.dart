import 'package:fly_narwhal/core/network/cdn_proxy/cdn_range_session.dart';
import 'package:fly_narwhal/core/network/cdn_proxy/cdn_range_source.dart';
import 'package:fly_narwhal/core/network/cdn_proxy/cdn_proxy_errors.dart';
import 'package:fly_narwhal/core/network/cdn_proxy/cdn_proxy_constants.dart';
import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/core/network/api_result.dart';
import 'package:fly_narwhal/core/network/cdn_proxy/cdn_range_policy.dart';

const _chunk = CdnProxyDefaults.chunkSize;
final _uri = Uri.parse('https://cdn.example.test/movie.mp4?signature=private');

void main() {
  group('CdnRangeSession', () {
    test(
        'Given a stalled body, when idle deadline expires, then retries its whole range without delivering partial bytes',
        () async {
      final errors = <Object>[];
      final source = _ControlledSource(10);
      final session = _session(source, CdnRangeBudget(),
          errors: errors, idleTimeout: const Duration(milliseconds: 20));
      addTearDown(session.close);
      await _initialize(session, source);
      final result =
          session.read(const CdnByteRange(start: 2, end: 5)).toList();
      final request = await source.requestAt(1);
      request.respondMetadata();
      request.body.add(Uint8List.fromList([255, 255]));
      final retry = await source.requestAt(2);
      expect(request.ended, isTrue);
      expect(request.token.isCancelled, isTrue);
      expect(session.budget.occupiedSlots, 1);
      expect((retry.start, retry.end), (2, 5));
      expect(identical(retry.token, request.token), isFalse);
      retry.respond();
      _expectBytes(await result, 2, 4);
      expect(errors, isEmpty);
      expect(session.budget.occupiedSlots, 0);
    });

    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
    ]) {
      test(
          'Given ${type.name} after partial bytes, when the same range recovers, then emits only complete retry bytes',
          () async {
        final errors = <Object>[];
        final source = _ControlledSource(10);
        final budget = CdnRangeBudget();
        final session = _session(source, budget, errors: errors);
        addTearDown(session.close);
        await _initialize(session, source);
        final result =
            session.read(const CdnByteRange(start: 2, end: 5)).toList();
        final request = await source.requestAt(1);
        request.respondMetadata();
        request.body.add(Uint8List.fromList([255, 255]));
        request.body.addError(DioException(
          requestOptions: RequestOptions(path: _uri.toString()),
          type: type,
          message: 'private signed URL',
        ));
        final retry = await source.requestAt(2);
        expect((retry.start, retry.end), (2, 5));
        expect(request.ended, isTrue);
        expect(request.token.isCancelled, isTrue);
        expect(identical(retry.token, request.token), isFalse);
        retry.respond();
        _expectBytes(await result, 2, 4);
        expect(errors, isEmpty);
        expect(budget.peakOccupiedSlots, 1);
        expect(budget.occupiedSlots, 0);
      });
    }

    test(
        'Given twelve consecutive header timeouts, when a later attempt succeeds, then has no retry count limit or playback failure',
        () async {
      final source = _ControlledSource(10);
      final budget = CdnRangeBudget();
      final errors = <Object>[];
      final session = _session(source, budget, errors: errors);
      addTearDown(session.close);
      await _initialize(session, source);
      final result =
          session.read(const CdnByteRange(start: 2, end: 5)).toList();
      for (var attempt = 1; attempt <= 12; attempt++) {
        final request = await source.requestAt(attempt);
        expect((request.start, request.end), (2, 5));
        request.rejectTimeout();
      }
      final retry = await source.requestAt(13);
      expect(budget.occupiedSlots, 1);
      expect(source.requests.skip(1).take(12).every((request) => request.ended),
          isTrue);
      expect(source.requests.skip(1).map((request) => request.token).toSet(),
          hasLength(13));
      retry.respond();
      _expectBytes(await result, 2, 4);
      expect(errors, isEmpty);
      expect(source.peakActive, 1);
      expect(budget.peakOccupiedSlots, 1);
      expect(budget.occupiedSlots, 0);
    });

    test(
        'Given an initial probe times out repeatedly, when its next attempt succeeds, then initializes without notifying playback failure',
        () async {
      final source = _ControlledSource(10);
      final budget = CdnRangeBudget();
      final errors = <Object>[];
      final session = _session(source, budget, errors: errors);
      addTearDown(session.close);
      final initialized = session.initialize();
      for (var attempt = 0; attempt < 4; attempt++) {
        final request = await source.requestAt(attempt);
        expect((request.start, request.end), (0, 0));
        request.rejectTimeout();
      }
      (await source.requestAt(4)).respond();
      await initialized;
      expect(session.totalLength, 10);
      expect(errors, isEmpty);
      expect(source.peakActive, 1);
      expect(budget.occupiedSlots, 0);
    });

    for (final closeSession in [false, true]) {
      test(
          'Given a range waiting a day before retry, when ${closeSession ? 'session closes' : 'subscription cancels'}, then cancels immediately and releases its slot',
          () async {
        final source = _ControlledSource(10);
        final budget = CdnRangeBudget();
        final errors = <Object>[];
        final streamErrors = <Object>[];
        final finished = Completer<void>();
        final session = _session(source, budget,
            errors: errors, retryDelay: const Duration(days: 1));
        addTearDown(session.close);
        await _initialize(session, source);
        final subscription = session
            .read(const CdnByteRange(start: 2, end: 5))
            .listen((_) => fail('Timed-out range must not emit bytes'),
                onError: streamErrors.add, onDone: finished.complete);
        final request = await source.requestAt(1);
        request.rejectTimeout();
        await request.token.whenCancel;
        await _drainMicrotasks();
        expect(budget.occupiedSlots, 1);
        expect(request.ended, isTrue);
        expect(source.requests, hasLength(2));
        if (closeSession) {
          await session.close().timeout(const Duration(seconds: 1));
          await finished.future;
          expect(streamErrors, everyElement(isA<CdnRangeCancelled>()));
        } else {
          await subscription.cancel().timeout(const Duration(seconds: 1));
          expect(streamErrors, isEmpty);
        }
        expect(budget.occupiedSlots, 0);
        expect(source.requests, hasLength(2));
        expect(source.active, 0);
        expect(errors, isEmpty);
      });
    }

    test(
        'Given a probe waiting a day before retry, when closed, then aborts initialization immediately without a playback failure',
        () async {
      final source = _ControlledSource(10);
      final budget = CdnRangeBudget();
      final errors = <Object>[];
      final session = _session(source, budget,
          errors: errors, retryDelay: const Duration(days: 1));
      addTearDown(session.close);
      final initialized =
          expectLater(session.initialize(), throwsA(isA<CdnRangeCancelled>()));
      final request = await source.requestAt(0);
      request.rejectTimeout();
      await request.token.whenCancel;
      await _drainMicrotasks();
      expect(budget.occupiedSlots, 1);
      await session.close().timeout(const Duration(seconds: 1));
      await initialized;
      expect(source.requests, hasLength(1));
      expect(source.active, 0);
      expect(budget.occupiedSlots, 0);
      expect(errors, isEmpty);
    });

    test(
        'Given the first chunk times out while later chunks and another reader occupy the window, when retried, then preserves ordered delivery and the three-slot budget',
        () async {
      final source = _ControlledSource(3 * _chunk + 7);
      final budget = CdnRangeBudget();
      final errors = <Object>[];
      final session = _session(source, budget, errors: errors);
      addTearDown(session.close);
      await _initialize(session, source);
      final emitted = <Uint8List>[];
      final finished = Completer<void>();
      session.read(const CdnByteRange(start: 0, end: 3 * _chunk - 1)).listen(
          emitted.add,
          onError: finished.completeError,
          onDone: finished.complete);
      await source.requestAt(3);
      final other = session
          .read(const CdnByteRange(start: 3 * _chunk, end: 3 * _chunk + 6))
          .toList();
      source.requests[3].respond();
      source.requests[2].respond();
      await source.requests[3].bodyEnded.future;
      await source.requests[2].bodyEnded.future;
      source.requests[1].rejectTimeout();
      final retry = await source.requestAt(4);
      expect((retry.start, retry.end), (0, _chunk - 1));
      expect(emitted, isEmpty);
      expect(source.requests, hasLength(5));
      expect(budget.occupiedSlots, 3);
      retry.respond();
      (await source.requestAt(5)).respond();
      await finished.future;
      _expectBytes(emitted, 0, 3 * _chunk);
      _expectBytes(await other, 3 * _chunk, 7);
      expect(source.peakActive, 3);
      expect(budget.peakOccupiedSlots, 3);
      expect(budget.occupiedSlots, 0);
      expect(errors, isEmpty);
    });

    test('Given a CDN resource, when initialized, then probes exactly byte 0',
        () async {
      final source = _ControlledSource(12345);
      final budget = CdnRangeBudget();
      final session = _session(source, budget);
      addTearDown(session.close);

      await _initialize(session, source);
      expect(source.requests.single.uri, _uri);
      expect(source.requests.single.headers, {'cookie': 'provider=value'});
      expect(session.totalLength, 12345);
      expect(session.contentType, 'video/mp4');
      expect(budget.occupiedSlots, 0);
      await session.initialize();
      expect(source.requests, hasLength(1));
    });

    test('Given an empty CDN resource, when probed, then length is zero',
        () async {
      final source = _ControlledSource(0);
      final budget = CdnRangeBudget();
      final errors = <Object>[];
      final session = _session(source, budget, errors: errors);
      addTearDown(session.close);
      final initialized = session.initialize();
      final request = await source.requestAt(0);
      request.respond(bytes: Uint8List(0));

      await initialized;
      expect(session.totalLength, 0);
      expect(budget.occupiedSlots, 0);
      expect(request.ended, isTrue);
      expect(errors, isEmpty);
    });

    test(
        'Given a nonzero start and tail, when read, then bytes and ranges match exactly',
        () async {
      const start = 173;
      const length = 2 * _chunk + 37;
      final source = _ControlledSource(start + length + 100);
      final budget = CdnRangeBudget();
      final session = _session(source, budget);
      addTearDown(session.close);
      await _initialize(session, source);
      final result = session
          .read(const CdnByteRange(start: start, end: start + length - 1))
          .toList();

      await source.requestAt(3);
      expect(
          source.requests
              .skip(1)
              .map((request) => (request.start, request.end)),
          [
            (start, start + _chunk - 1),
            (start + _chunk, start + 2 * _chunk - 1),
            (start + 2 * _chunk, start + length - 1),
          ]);
      for (final request in source.requests.skip(1)) {
        request.respond();
      }
      final data = await result;
      expect(data.map((bytes) => bytes.length), [_chunk, _chunk, 37]);
      _expectBytes(data, start, length);
      expect(budget.occupiedSlots, 0);
      expect(source.peakActive, 3);
    });

    test(
        'Given three requests finish out of order, when read, then emits ordered bytes',
        () async {
      final source = _ControlledSource(2 * _chunk + 7);
      final budget = CdnRangeBudget();
      final session = _session(source, budget);
      addTearDown(session.close);
      await _initialize(session, source);
      final emitted = <Uint8List>[];
      final finished = Completer<void>();
      session.read(CdnByteRange(start: 0, end: source.totalLength - 1)).listen(
            emitted.add,
            onError: finished.completeError,
            onDone: finished.complete,
          );
      await source.requestAt(3);
      expect(source.active, 3);

      source.requests[3].respond();
      source.requests[2].respond();
      await source.requests[3].bodyEnded.future;
      await source.requests[2].bodyEnded.future;
      await _drainMicrotasks();
      expect(emitted, isEmpty);
      expect(budget.occupiedSlots, 3);
      source.requests[1].respond();

      await finished.future;
      _expectBytes(emitted, 0, source.totalLength);
      expect(budget.peakOccupiedSlots, 3);
      expect(budget.occupiedSlots, 0);
    });

    test(
        'Given more than three chunks, when consumed, then rolls the bounded window',
        () async {
      final source = _ControlledSource(5 * _chunk + 7);
      final budget = CdnRangeBudget();
      final session = _session(source, budget);
      addTearDown(session.close);
      await _initialize(session, source);
      final result = session
          .read(CdnByteRange(start: 0, end: source.totalLength - 1))
          .toList();
      await source.requestAt(3);
      expect(source.requests, hasLength(4));
      for (var index = 1; index <= 6; index++) {
        final request = await source.requestAt(index);
        expect(request.end - request.start + 1, lessThanOrEqualTo(_chunk));
        request.respond();
      }

      _expectBytes(await result, 0, source.totalLength);
      expect(source.requests, hasLength(7));
      expect(source.peakActive, 3);
      expect(budget.peakOccupiedSlots, 3);
      expect(budget.occupiedSlots, 0);
    });

    test(
        'Given two reads in one session, when both run, then shares three slots',
        () async {
      final source = _ControlledSource(6 * _chunk);
      final budget = CdnRangeBudget();
      final session = _session(source, budget);
      addTearDown(session.close);
      await _initialize(session, source);
      final first = session
          .read(const CdnByteRange(start: 0, end: 3 * _chunk - 1))
          .toList();
      final second = session
          .read(const CdnByteRange(start: 3 * _chunk, end: 6 * _chunk - 1))
          .toList();
      await source.requestAt(3);
      expect(source.requests, hasLength(4));
      expect(budget.occupiedSlots, 3);

      for (var index = 1; index <= 6; index++) {
        (await source.requestAt(index)).respond();
      }
      _expectBytes(await first, 0, 3 * _chunk);
      _expectBytes(await second, 3 * _chunk, 3 * _chunk);
      expect(source.peakActive, 3);
      expect(budget.peakOccupiedSlots, 3);
      expect(budget.occupiedSlots, 0);
    });

    test(
        'Given two sessions share a budget, when both read, then total concurrency stays three',
        () async {
      final log = _RequestLog();
      final firstSource = _ControlledSource(3 * _chunk + 7, log: log);
      final secondSource = _ControlledSource(3 * _chunk + 9, log: log);
      final budget = CdnRangeBudget();
      final firstSession = _session(firstSource, budget);
      final secondSession = _session(secondSource, budget);
      addTearDown(firstSession.close);
      addTearDown(secondSession.close);
      await _initialize(firstSession, firstSource);
      await _initialize(secondSession, secondSource);
      final first = firstSession
          .read(CdnByteRange(start: 0, end: firstSource.totalLength - 1))
          .toList();
      final second = secondSession
          .read(CdnByteRange(start: 0, end: secondSource.totalLength - 1))
          .toList();
      await log.requestAt(4);
      expect(log.requests, hasLength(5));
      expect(log.active, 3);
      for (var index = 2; index < 10; index++) {
        (await log.requestAt(index)).respond();
      }

      _expectBytes(await first, 0, firstSource.totalLength);
      _expectBytes(await second, 0, secondSource.totalLength);
      expect(log.peakActive, 3);
      expect(budget.peakOccupiedSlots, 3);
      expect(budget.occupiedSlots, 0);
    });

    test(
        'Given a busy old source, when replaced, then the probe and new reads reuse its budget',
        () async {
      final log = _RequestLog();
      final oldSource = _ControlledSource(3 * _chunk, log: log);
      final newSource = _ControlledSource(3 * _chunk, log: log);
      final budget = CdnRangeBudget();
      final errors = <Object>[];
      final oldSession = _session(oldSource, budget, errors: errors);
      final newSession = _session(newSource, budget, errors: errors);
      addTearDown(oldSession.close);
      addTearDown(newSession.close);
      await _initialize(oldSession, oldSource);
      final oldFinished = Completer<void>();
      oldSession.read(const CdnByteRange(start: 0, end: 3 * _chunk - 1)).listen(
            (_) {},
            onError: (Object error) => expect(error, isA<CdnRangeCancelled>()),
            onDone: oldFinished.complete,
          );
      await oldSource.requestAt(3);
      final initialized = newSession.initialize();
      await _drainMicrotasks();
      expect(newSource.requests, isEmpty);
      expect(budget.occupiedSlots, 3);

      await oldSession.close();
      await oldFinished.future;
      final probe = await newSource.requestAt(0);
      expect((probe.start, probe.end), (0, 0));
      probe.respond();
      await initialized;
      final result = newSession
          .read(const CdnByteRange(start: 0, end: 3 * _chunk - 1))
          .toList();
      await newSource.requestAt(3);
      expect(newSource.active, 3);
      for (final request in newSource.requests.skip(1)) {
        request.respond();
      }

      _expectBytes(await result, 0, 3 * _chunk);
      expect(log.peakActive, 3);
      expect(budget.peakOccupiedSlots, 3);
      expect(budget.occupiedSlots, 0);
      expect(errors, isEmpty);
    });

    test(
        'Given a paused consumer, when downloads complete, then holds at most three chunks',
        () async {
      final source = _ControlledSource(8 * _chunk);
      final budget = CdnRangeBudget();
      final session = _session(source, budget);
      addTearDown(session.close);
      await _initialize(session, source);
      final paused = Completer<void>();
      late final StreamSubscription<Uint8List> subscription;
      subscription = session
          .read(CdnByteRange(start: 0, end: source.totalLength - 1))
          .listen((_) {
        subscription.pause();
        paused.complete();
      });
      await source.requestAt(3);
      source.requests[1].respond();
      await paused.future;
      source.requests[2].respond();
      source.requests[3].respond();
      await source.requests[2].bodyEnded.future;
      await source.requests[3].bodyEnded.future;
      await _drainMicrotasks();

      expect(source.requests, hasLength(4));
      expect(source.active, 0);
      expect(budget.occupiedSlots, 3);
      await subscription.cancel();
      expect(budget.occupiedSlots, 0);
      expect(source.requests, hasLength(4));
    });

    test(
        'Given hanging headers and body, when subscription cancels, then aborts every request',
        () async {
      final source = _ControlledSource(4 * _chunk);
      final budget = CdnRangeBudget();
      final errors = <Object>[];
      final session = _session(source, budget, errors: errors);
      addTearDown(session.close);
      await _initialize(session, source);
      final streamErrors = <Object>[];
      final subscription = session
          .read(CdnByteRange(start: 0, end: source.totalLength - 1))
          .listen((_) {}, onError: streamErrors.add);
      await source.requestAt(3);
      source.requests[1].respondMetadata();
      await source.requests[1].bodyListening.future;

      await subscription.cancel();
      expect(
          source.requests.skip(1).every((request) => request.token.isCancelled),
          isTrue);
      expect(source.active, 0);
      expect(budget.occupiedSlots, 0);
      expect(streamErrors, isEmpty);
      expect(errors, isEmpty);
    });

    test(
        'Given active and queued reads, when close repeats, then finishes without playback failure',
        () async {
      final source = _ControlledSource(6 * _chunk);
      final budget = CdnRangeBudget();
      final errors = <Object>[];
      final session = _session(source, budget, errors: errors);
      await _initialize(session, source);
      final streamErrors = <Object>[];
      final done = <Future<void>>[];
      for (final start in [0, 3 * _chunk]) {
        final finished = Completer<void>();
        session
            .read(CdnByteRange(start: start, end: start + 3 * _chunk - 1))
            .listen((_) {},
                onError: streamErrors.add, onDone: finished.complete);
        done.add(finished.future);
      }
      await source.requestAt(3);
      source.requests[1].respondMetadata();
      await source.requests[1].bodyListening.future;

      final firstClose = session.close();
      final secondClose = session.close();
      expect(identical(firstClose, secondClose), isTrue);
      await firstClose;
      await Future.wait(done);
      expect(source.closeCount, 1);
      expect(source.requests, hasLength(4));
      expect(
          source.requests.skip(1).every((request) => request.token.isCancelled),
          isTrue);
      expect(source.active, 0);
      expect(budget.occupiedSlots, 0);
      expect(streamErrors.every((error) => error is CdnRangeCancelled), isTrue);
      expect(errors, isEmpty);
    });

    test(
        'Given an unfinished initial probe, when closed, then cancels without notifying failure',
        () async {
      final source = _ControlledSource(100);
      final budget = CdnRangeBudget();
      final errors = <Object>[];
      final session = _session(source, budget, errors: errors);
      final initializeResult =
          expectLater(session.initialize(), throwsA(isA<CdnRangeCancelled>()));
      final request = await source.requestAt(0);

      await session.close();
      await initializeResult;
      expect(request.token.isCancelled, isTrue);
      expect(budget.occupiedSlots, 0);
      expect(errors, isEmpty);
    });

    test(
        'Given direct playback and decoder probe share slots, when closed for standard playback, then releases both readers',
        () async {
      final source = _ControlledSource(3 * _chunk);
      final budget = CdnRangeBudget();
      final errors = <Object>[];
      final streamErrors = <Object>[];
      final session = _session(source, budget, errors: errors);
      addTearDown(session.close);
      await _initialize(session, source);
      final finished = <Future<void>>[];
      for (final range in [
        const CdnByteRange(start: 0, end: 2 * _chunk - 1),
        const CdnByteRange(start: 2 * _chunk, end: 2 * _chunk + 63),
      ]) {
        final done = Completer<void>();
        session
            .read(range)
            .listen((_) {}, onError: streamErrors.add, onDone: done.complete);
        finished.add(done.future);
      }
      await source.requestAt(3);
      expect(source.requests.skip(1).map((request) => request.start),
          [0, _chunk, 2 * _chunk]);
      source.requests[1].respondMetadata();
      source.requests[3].respondMetadata();
      await source.requests[1].bodyListening.future;
      await source.requests[3].bodyListening.future;
      expect(budget.occupiedSlots, 3);

      // Routing to the existing standard player happens outside this service.
      // Closing its old source must release playback and decoder-probe work.
      await session.close();
      await Future.wait(finished);

      expect(source.closeCount, 1);
      expect(source.active, 0);
      expect(budget.occupiedSlots, 0);
      expect(source.requests, hasLength(4));
      expect(
          source.requests.skip(1).every((request) => request.token.isCancelled),
          isTrue);
      expect(streamErrors.every((error) => error is CdnRangeCancelled), isTrue);
      expect(errors, isEmpty);
    });

    for (final mime in [
      'application/vnd.apple.mpegurl',
      'application/x-mpegurl',
      'audio/mpegurl',
      'audio/x-mpegurl',
    ]) {
      test(
          'Given $mime with valid byte responses, when read, then MIME alone does not reject or reroute',
          () async {
        final source = _ControlledSource(10);
        final budget = CdnRangeBudget();
        final errors = <Object>[];
        final session = _session(source, budget, errors: errors);
        addTearDown(session.close);
        final initialized = session.initialize();
        (await source.requestAt(0)).respond(contentType: mime);
        await initialized;
        expect(session.contentType, mime);

        final result =
            session.read(const CdnByteRange(start: 2, end: 5)).toList();
        (await source.requestAt(1)).respond(contentType: mime);

        _expectBytes(await result, 2, 4);
        expect(source.requests, hasLength(2));
        expect(budget.occupiedSlots, 0);
        expect(errors, isEmpty);
      });
    }

    final invalidResponses = <String, void Function(_PendingRequest)>{
      'data source rejection': (request) => request.reject(),
      'different total length': (request) => request.respond(totalLength: 11),
      'total below endpoint': (request) => request.respond(totalLength: 3),
      'truncated body': (request) => request.respond(bytes: Uint8List(3)),
      'oversized body': (request) => request.respond(bytes: Uint8List(5)),
      'upstream stream error': (request) {
        request.respondMetadata();
        request.body.addError(StateError('source stream failed'));
      },
    };
    for (final entry in invalidResponses.entries) {
      test(
          'Given ${entry.key}, when read, then rejects data and releases the budget',
          () async {
        final source = _ControlledSource(10);
        final budget = CdnRangeBudget();
        final errors = <Object>[];
        final session = _session(source, budget, errors: errors);
        addTearDown(session.close);
        await _initialize(session, source);
        final rejected = expectLater(
            session.read(const CdnByteRange(start: 0, end: 3)).toList(),
            throwsA(isA<CdnRangeFailure>()));
        entry.value(await source.requestAt(1));

        await rejected;
        expect(budget.occupiedSlots, 0);
        expect(errors, hasLength(1));
        expect(errors.single, isA<CdnRangeFailure>());
        expect(source.requests[1].token.isCancelled, isTrue);
      });
    }

    test(
        'Given one failed chunk and pending siblings, when reading, then cancels the group and frees every slot',
        () async {
      final source = _ControlledSource(3 * _chunk);
      final budget = CdnRangeBudget();
      final errors = <Object>[];
      final session = _session(source, budget, errors: errors);
      addTearDown(session.close);
      await _initialize(session, source);
      final rejected = expectLater(
        session
            .read(const CdnByteRange(start: 0, end: 3 * _chunk - 1))
            .toList(),
        throwsA(isA<CdnRangeFailure>()),
      );
      await source.requestAt(3);
      source.requests[1].respond(bytes: Uint8List(0));

      await rejected;
      expect(
          source.requests.skip(1).every((request) => request.token.isCancelled),
          isTrue);
      expect(source.active, 0);
      expect(budget.occupiedSlots, 0);
      expect(errors, hasLength(1));
    });

    test(
        'Given a rejected probe, when initialized, then fails before reading media',
        () async {
      final source = _ControlledSource(10);
      final budget = CdnRangeBudget();
      final errors = <Object>[];
      final session = _session(source, budget, errors: errors);
      addTearDown(session.close);
      final rejected =
          expectLater(session.initialize(), throwsA(isA<CdnRangeFailure>()));
      (await source.requestAt(0)).reject();

      await rejected;
      expect(source.requests, hasLength(1));
      expect(budget.occupiedSlots, 0);
      expect(errors, hasLength(1));
    });

    test(
        'Given several stream events, when valid bytes arrive, then validates actual length',
        () async {
      final source = _ControlledSource(10);
      final session = _session(source, CdnRangeBudget());
      addTearDown(session.close);
      await _initialize(session, source);
      final result =
          session.read(const CdnByteRange(start: 2, end: 5)).toList();
      final request = await source.requestAt(1);
      request.respondMetadata();
      request.body.add(_bytes(2, 1));
      request.body.add(_bytes(3, 2));
      request.body.add(_bytes(5, 1));
      unawaited(request.body.close());
      _expectBytes(await result, 2, 4);
    });

    test(
        'Given an out-of-bounds read, when listened, then rejects without an upstream request',
        () async {
      final source = _ControlledSource(10);
      final budget = CdnRangeBudget();
      final session = _session(source, budget);
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
      expect(budget.occupiedSlots, 0);
    });
  });
}

CdnRangeSession _session(_ControlledSource source, CdnRangeBudget budget,
        {List<Object>? errors,
        Duration retryDelay = Duration.zero,
        Duration idleTimeout = const Duration(seconds: 20)}) =>
    CdnRangeSession(
      source: source,
      uri: _uri,
      headers: const {'cookie': 'provider=value'},
      budget: budget,
      onError: errors?.add,
      retryDelay: retryDelay,
      idleTimeout: idleTimeout,
    );

Future<void> _initialize(
    CdnRangeSession session, _ControlledSource source) async {
  final initialized = session.initialize();
  final request = await source.requestAt(0);
  expect((request.start, request.end), (0, 0));
  request.respond();
  await initialized;
}

// All fake work uses microtasks. One event-queue barrier lets that work settle
// before asserting that no extra request was started; no timer delay is used.
Future<void> _drainMicrotasks() => Future<void>(() {});

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

class _RequestLog {
  final requests = <_PendingRequest>[];
  final _waiters = <(int, Completer<_PendingRequest>)>[];
  int active = 0;
  int peakActive = 0;

  void add(_PendingRequest request) {
    requests.add(request);
    active++;
    if (active > peakActive) peakActive = active;
    for (final waiter in _waiters.toList()) {
      if (requests.length > waiter.$1) {
        _waiters.remove(waiter);
        waiter.$2.complete(requests[waiter.$1]);
      }
    }
  }

  Future<_PendingRequest> requestAt(int index) {
    if (requests.length > index) return Future.value(requests[index]);
    final waiter = Completer<_PendingRequest>();
    _waiters.add((index, waiter));
    return waiter.future;
  }
}

class _ControlledSource extends _RequestLog implements CdnRangeSource {
  _ControlledSource(this.totalLength, {this.log});
  final int totalLength;
  final _RequestLog? log;
  int closeCount = 0;

  @override
  Future<ApiResult<CdnRangeResponse>> open(
      {required Uri uri,
      required Map<String, String> headers,
      required int start,
      required int end,
      required CancelToken cancelToken}) {
    final request =
        _PendingRequest(this, uri, Map.of(headers), start, end, cancelToken);
    add(request);
    log?.add(request);
    return request.response.future;
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
  _PendingRequest(
      this.source, this.uri, this.headers, this.start, this.end, this.token) {
    body = StreamController<Uint8List>(
      onListen: bodyListening.complete,
      onCancel: () {
        _finish();
        if (!bodyEnded.isCompleted) bodyEnded.complete();
      },
    );
    unawaited(token.whenCancel.then((_) {
      if (!response.isCompleted) {
        response.complete(ResultFailure(FailureInfo.fromMessage('Cancelled')));
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
  final response = Completer<ApiResult<CdnRangeResponse>>();
  final bodyListening = Completer<void>();
  final bodyEnded = Completer<void>();
  late final StreamController<Uint8List> body;
  bool ended = false;

  void _finish() {
    if (ended) return;
    ended = true;
    source.active--;
    final log = source.log;
    if (log != null) log.active--;
  }

  void respondMetadata({int? totalLength, String contentType = 'video/mp4'}) {
    response.complete(Success(CdnRangeResponse(
        totalLength: totalLength ?? source.totalLength,
        contentType: contentType,
        stream: body.stream)));
  }

  void reject() {
    response
        .complete(ResultFailure(FailureInfo.fromMessage('CDN 返回的资源范围或大小不一致')));
  }

  void rejectTimeout() {
    response.complete(const ResultFailure(CdnRequestFailure(
      message: 'Response receive timeout',
      displayMessage: 'Response receive timeout',
      isTimeout: true,
    )));
  }

  void respond(
      {int? totalLength, String contentType = 'video/mp4', Uint8List? bytes}) {
    respondMetadata(totalLength: totalLength, contentType: contentType);
    body.add(bytes ?? _bytes(start, end - start + 1));
    unawaited(body.close());
  }
}
