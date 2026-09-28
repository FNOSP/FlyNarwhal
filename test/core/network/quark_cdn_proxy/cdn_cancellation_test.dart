import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_cancellation.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_proxy_errors.dart';

void main() {
  group('CdnCancellation', () {
    test(
        'Given removable listeners, when cancelled repeatedly, then only registered callbacks run once',
        () {
      final cancellation = CdnCancellation();
      var removedCalls = 0;
      var retainedCalls = 0;
      final remove = cancellation.onCancel(() => removedCalls++);
      final removeRetained = cancellation.onCancel(() => retainedCalls++);
      expect(cancellation.listenerCount, 2);

      remove();
      remove();
      expect(cancellation.listenerCount, 1);
      cancellation.cancel();
      cancellation.cancel();
      removeRetained();
      removeRetained();

      expect(cancellation.isCancelled, isTrue);
      expect(removedCalls, 0);
      expect(retainedCalls, 1);
      expect(cancellation.listenerCount, 0);

      var lateCalls = 0;
      final removeLate = cancellation.onCancel(() => lateCalls++);
      expect(lateCalls, 1);
      expect(cancellation.listenerCount, 0);
      removeLate();
      removeLate();
      cancellation.cancel();
      expect(lateCalls, 1);
    });

    test(
        'Given repeated successful operations, when each wait completes, then cancellation listeners do not accumulate',
        () async {
      final cancellation = CdnCancellation();
      for (var index = 0; index < 1000; index++) {
        expect(await cancellation.wait(Future<int>.value(index)), index);
        expect(cancellation.listenerCount, 0, reason: 'iteration $index');
      }
      expect(cancellation.isCancelled, isFalse);
      cancellation.cancel();
      expect(cancellation.listenerCount, 0);
    });

    test(
        'Given repeated failed operations, when each wait fails, then preserves the error and releases its listener',
        () async {
      final cancellation = CdnCancellation();
      final failure = StateError('operation failed');
      for (var index = 0; index < 1000; index++) {
        await expectLater(
          cancellation.wait(Future<int>.error(failure)),
          throwsA(same(failure)),
        );
        expect(cancellation.listenerCount, 0, reason: 'iteration $index');
      }
      expect(cancellation.isCancelled, isFalse);
    });

    test(
        'Given multiple pending waits, when cancelled twice, then all wake and late successes retain no listeners',
        () async {
      final cancellation = CdnCancellation();
      final operations = List.generate(32, (_) => Completer<int>());
      final checks = operations
          .map((operation) => expectLater(
                cancellation.wait(operation.future),
                throwsA(isA<CdnRangeCancelled>()),
              ))
          .toList();
      expect(cancellation.listenerCount, operations.length);

      cancellation.cancel();
      cancellation.cancel();
      await Future.wait(checks);
      expect(cancellation.listenerCount, 0);

      for (var index = 0; index < operations.length; index++) {
        operations[index].complete(index);
      }
      await _flushMicrotasks();
      expect(cancellation.listenerCount, 0);
    });

    test(
        'Given an already cancelled signal, when waiting on a later failing operation, then its late error is observed',
        () async {
      final cancellation = CdnCancellation()..cancel();
      final operation = Completer<int>();
      await expectLater(
        cancellation.wait(operation.future),
        throwsA(isA<CdnRangeCancelled>()),
      );
      expect(cancellation.listenerCount, 0);

      // Do not attach a test-side listener to the original operation: wait must
      // retain its error handler even though cancellation was already known.
      operation
          .completeError(StateError('late error after prior cancellation'));
      await _flushMicrotasks();
      expect(cancellation.listenerCount, 0);
    });

    test(
        'Given a pending wait, when cancelled before its operation fails, then the late error does not escape',
        () async {
      final cancellation = CdnCancellation();
      final operation = Completer<int>();
      final check = expectLater(
        cancellation.wait(operation.future),
        throwsA(isA<CdnRangeCancelled>()),
      );
      expect(cancellation.listenerCount, 1);
      cancellation.cancel();
      await check;
      expect(cancellation.listenerCount, 0);

      operation
          .completeError(StateError('late error after active cancellation'));
      await _flushMicrotasks();
      expect(cancellation.listenerCount, 0);
    });

    test(
        'Given synchronous completion, when wait returns normally, then no listener survives registration',
        () async {
      final cancellation = CdnCancellation();
      expect(await cancellation.wait(SynchronousFuture<int>(42)), 42);
      expect(cancellation.listenerCount, 0);
      expect(cancellation.isCancelled, isFalse);
    });

    test(
        'Given same-turn success and cancellation, when the await resumes, then cancellation wins',
        () async {
      for (final synchronous in [false, true]) {
        final cancellation = CdnCancellation();
        final operation = Completer<int>();
        final future =
            synchronous ? SynchronousFuture<int>(42) : operation.future;
        final check = expectLater(
          cancellation.wait(future),
          throwsA(isA<CdnRangeCancelled>()),
          reason: 'synchronous completion: $synchronous',
        );
        if (!synchronous) {
          operation.complete(42);
        }
        cancellation.cancel();
        await check;
        expect(cancellation.listenerCount, 0);
      }
    });
  });
}

Future<void> _flushMicrotasks() async {
  // Allow late operation handlers and their chained futures to settle without
  // sleeping or intercepting uncaught errors from the Flutter test zone.
  for (var index = 0; index < 3; index++) {
    await Future<void>.microtask(() {});
  }
}
