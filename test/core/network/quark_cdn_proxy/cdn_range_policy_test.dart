import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_proxy_constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_range_policy.dart';

void main() {
  const chunk = CdnProxyDefaults.chunkSize;
  const maxInt = 0x7fffffffffffffff;

  group('resolveCdnRange', () {
    test('Given no Range, when resolved, then returns the whole resource', () {
      final result = resolveCdnRange(null, chunk + 1);
      expect(result.partial, isFalse);
      expectRange(result.range, 0, chunk);
    });

    test('Given an empty resource, when resolved, then only full GET succeeds',
        () {
      final result = resolveCdnRange(null, 0);
      expect(result.range, isNull);
      expect(result.partial, isFalse);
      for (final header in ['bytes=0-0', 'bytes=0-', 'bytes=-1']) {
        expect(
          () => resolveCdnRange(header, 0),
          throwsA(isA<CdnRangeNotSatisfiable>()),
        );
      }
    });

    final cases = <(String, int, int)>[
      ('bytes=0-0', 0, 0),
      ('bytes=23-67', 23, 67),
      ('bytes=99-99', 99, 99),
      ('bytes=23-200', 23, 99),
      ('bytes=23-', 23, 99),
      ('bytes=99-', 99, 99),
      ('bytes=-1', 99, 99),
      ('bytes=-33', 67, 99),
      ('bytes=-100', 0, 99),
      ('bytes=-101', 0, 99),
      (' BYTES=0001-0003 ', 1, 3),
      ('bytes=1-999999999999999999999999999999999999', 1, 99),
      ('bytes=-999999999999999999999999999999999999', 0, 99),
    ];
    for (final (header, start, end) in cases) {
      test('Given $header, when resolved, then returns the exact interval', () {
        final result = resolveCdnRange(header, 100);
        expect(result.partial, isTrue);
        expectRange(result.range, start, end);
      });
    }

    for (final header in [
      '',
      'bytes=',
      'bytes=-',
      'bytes=-0',
      'bytes=100-',
      'bytes=100-101',
      'bytes=4-3',
      'bytes=1-2,4-5',
      'bytes=1-2,',
      'bytes=1 - 2',
      'bytes=+1-2',
      'bytes=1--2',
      'bytes=1.0-2',
      'bytes=0x1-2',
      'items=1-2',
      'bytes=a-b',
      'bytes=999999999999999999999999999999999999-',
    ]) {
      test('Given invalid $header, when resolved, then rejects the range', () {
        expect(
          () => resolveCdnRange(header, 100),
          throwsA(isA<CdnRangeNotSatisfiable>()),
        );
      });
    }

    test('Given a negative length, when resolved, then rejects the input', () {
      expect(() => resolveCdnRange(null, -1), throwsArgumentError);
    });

    test('Given int-sized files, when resolved, then no endpoint wraps', () {
      expectRange(resolveCdnRange(null, maxInt).range, 0, maxInt - 1);
      expectRange(
        resolveCdnRange('bytes=${maxInt - 1}-$maxInt', maxInt).range,
        maxInt - 1,
        maxInt - 1,
      );
      expectRange(
          resolveCdnRange('bytes=-$maxInt', maxInt).range, 0, maxInt - 1);
      expect(resolveCdnRange(null, maxInt).range!.length, maxInt);
    });
  });

  group('splitCdnRange and cdnRangeConcurrency', () {
    final lengths = <int, List<int>>{
      1: [1],
      chunk - 1: [chunk - 1],
      chunk: [chunk],
      chunk ~/ 2: [chunk ~/ 2],
      chunk + 1: [chunk ~/ 2, chunk ~/ 2 + 1],
      2 * chunk - 1: [chunk - 1, chunk],
      2 * chunk: [chunk, chunk],
      2 * chunk + 1: [chunk ~/ 2, chunk ~/ 2 + 1, chunk],
      23 * 1024 * 1024: [5 * 1024 * 1024, 8 * 1024 * 1024, chunk],
      29 * 1024 * 1024: [9 * 1024 * 1024, chunk, chunk],
      3 * chunk - 1: [chunk - 1, chunk, chunk],
      3 * chunk: [chunk, chunk, chunk],
      3 * chunk + 1: [chunk ~/ 2, chunk ~/ 2 + 1, chunk, chunk],
    };
    for (final entry in lengths.entries) {
      for (final start in [0, 173, 5 * 1024 * 1024 * 1024]) {
        test(
          'Given ${entry.key} bytes at $start, when split, then covers exactly',
          () {
            final chunks = splitCdnRange(
              CdnByteRange(start: start, end: start + entry.key - 1),
            ).toList();
            expect(chunks.map((part) => part.length), entry.value);
            expect(chunks.first.start, start);
            expect(chunks.last.end, start + entry.key - 1);
            for (var index = 1; index < chunks.length; index++) {
              expect(chunks[index].start, chunks[index - 1].end + 1);
            }
            expect(
              cdnRangeConcurrency(entry.key),
              entry.value.length < 3 ? entry.value.length : 3,
            );
          },
        );
      }
    }

    test('Given zero bytes, when scheduling, then starts no requests', () {
      expect(cdnRangeConcurrency(0), 0);
    });

    test(
        'Given 25 or 15 MiB, when split, then the short first part precedes full parts',
        () {
      for (final mib in [25, 15]) {
        final chunks = splitCdnRange(
          CdnByteRange(start: 0, end: mib * 1024 * 1024 - 1),
        ).toList();
        expect(chunks.map((part) => part.length), [
          5 * 1024 * 1024,
          if (mib == 25) chunk,
          chunk,
        ]);
        expect(cdnRangeConcurrency(mib * 1024 * 1024), mib == 25 ? 3 : 2);
      }
    });

    test('Given int-sized intervals, when split lazily, then avoids overflow',
        () {
      final first = splitCdnRange(
        const CdnByteRange(start: 0, end: maxInt - 1),
      ).take(3).toList();
      expect(first.map((part) => part.length), [maxInt % chunk, chunk, chunk]);
      final tail = splitCdnRange(
        const CdnByteRange(start: maxInt - chunk, end: maxInt),
      ).toList();
      expect(tail.map((part) => part.length), [chunk ~/ 2, chunk ~/ 2 + 1]);
      expectRange(tail.last, maxInt - chunk ~/ 2, maxInt);
      expect(cdnRangeConcurrency(maxInt), 3);
      expect(cdnRangeConcurrency(maxInt, chunkSize: 1), 3);
      expect(cdnRangeConcurrency(maxInt, chunkSize: maxInt), 1);
    });

    test('Given a custom size, when split, then honors its bound and tail', () {
      final chunks = splitCdnRange(
        const CdnByteRange(start: 7, end: 13),
        chunkSize: 3,
      ).toList();
      expect(chunks.map((part) => part.length), [1, 3, 3]);
      expectRange(chunks.last, 11, 13);
      expect(cdnRangeConcurrency(7, chunkSize: 3), 3);
    });

    test('Given invalid limits, when scheduling, then rejects the inputs', () {
      expect(() => cdnRangeConcurrency(-1), throwsArgumentError);
      for (final size in [0, -1]) {
        expect(
          () => cdnRangeConcurrency(0, chunkSize: size),
          throwsArgumentError,
        );
        expect(
          () => splitCdnRange(
            const CdnByteRange(start: 0, end: 0),
            chunkSize: size,
          ).toList(),
          throwsArgumentError,
        );
      }
      for (final range in [
        const CdnByteRange(start: -1, end: 1),
        const CdnByteRange(start: 2, end: 1),
        const CdnByteRange(start: 0, end: maxInt),
      ]) {
        expect(() => splitCdnRange(range).toList(), throwsArgumentError);
        expect(() => range.length, throwsArgumentError);
      }
    });
  });
}

void expectRange(CdnByteRange? range, int start, int end) {
  expect(range, isNotNull);
  expect(range!.start, start);
  expect(range.end, end);
  expect(range.length, end - start + 1);
}
