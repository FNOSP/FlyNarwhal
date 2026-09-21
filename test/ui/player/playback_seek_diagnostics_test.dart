import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/ui/features/player/services/playback_seek_diagnostics.dart';

void main() {
  test('reported cache gaps and tail are not classified as cached', () {
    final properties = {
      'demuxer-cache-state': jsonEncode({
        'cache-end': 90,
        'seekable-ranges': [
          {'start': 10, 'end': 30},
          {'start': 50, 'end': 70},
        ],
      }),
    };
    for (final target in [0, 40000, 80000]) {
      expect(
          summarizeSeekProperties(properties, target)['targetInReportedRange'],
          isFalse);
    }
    expect(summarizeSeekProperties(properties, 20000)['targetInReportedRange'],
        isTrue);
    expect(summarizeSeekProperties({}, 20000)['targetInReportedRange'], isNull);
  });

  test('malformed properties are tolerated and arbitrary text is never logged',
      () {
    final summary = summarizeSeekProperties({
      'time-pos': 'NaN',
      'video-params': '{invalid',
      'hwdec-current': 'https://signed.invalid/private?token=secret',
      'demuxer-cache-state': jsonEncode({
        'url': 'https://signed.invalid/private?token=secret',
        'seekable-ranges': [
          null,
          {'start': 20, 'end': 10}
        ],
      }),
    }, 15000);
    expect(summary['positionSeconds'], isNull);
    expect(summary['ranges'], isEmpty);
    expect(jsonEncode(summary), isNot(contains('secret')));
  });

  test('command return is separate from native seek completion and refill',
      () async {
    final logs = <Map<String, dynamic>>[];
    var submitted = false;
    var settled = false;
    var seeks = 0;
    final probe = PlaybackSeekDiagnostics(
      readProperty: (name) async => switch (name) {
        'seeking' => submitted && !settled ? 'yes' : 'no',
        'time-pos' => settled ? '8' : '5',
        _ => '',
      },
      writeLog: (message) => logs.add(jsonDecode(message)),
      isCurrent: () => true,
      delay: (_) async {
        settled = true;
      },
    );
    await probe.seek(
        targetMilliseconds: 8000,
        submit: () async {
          seeks++;
          submitted = true;
        });
    await probe.observation;
    expect(seeks, 1);
    expect(logs.map((row) => row['event']), [
      'before',
      'command_returned',
      'native_seek_settled',
      'after_one_second',
    ]);
    expect(logs[2]['observedSeeking'], isTrue);
  });

  test('unavailable diagnostics and failed logger do not suppress the seek',
      () async {
    var seeks = 0;
    final probe = PlaybackSeekDiagnostics(
      readProperty: (_) async => throw StateError('unavailable'),
      writeLog: (_) => throw StateError('logger failed'),
      isCurrent: () => true,
      maxSamples: 0,
    );
    await probe.seek(
        targetMilliseconds: 8000,
        submit: () async {
          seeks++;
        });
    await probe.observation;
    expect(seeks, 1);
  });

  test(
      'Given an obsolete request, when seek starts, then no properties or commands are requested',
      () async {
    final reads = <String>[];
    final logs = <String>[];
    var seeks = 0;
    final probe = PlaybackSeekDiagnostics(
      readProperty: (name) async {
        reads.add(name);
        return '';
      },
      writeLog: logs.add,
      isCurrent: () => false,
    );

    await probe.seek(
        targetMilliseconds: 8000,
        submit: () async {
          seeks++;
        });

    expect(reads, isEmpty);
    expect(logs, isEmpty);
    expect(seeks, 0);
    expect(probe.observation, isNull);
  });

  for (final sourceChanged in [true, false]) {
    test(
        'Given pending seek sampling, when ${sourceChanged ? 'the source changes' : 'a newer seek starts'}, then the obsolete command is never submitted',
        () async {
      var sourceGeneration = 0;
      var seekGeneration = 0;
      final samplingStarted = Completer<void>();
      final sample = Completer<String>();
      final oldLogs = <String>[];
      final submittedTargets = <int>[];
      final probe = PlaybackSeekDiagnostics(
        readProperty: (name) async {
          if (name == 'time-pos') {
            samplingStarted.complete();
            return sample.future;
          }
          return '';
        },
        writeLog: oldLogs.add,
        isCurrent: () => sourceGeneration == 0 && seekGeneration == 0,
      );
      final pendingSeek = probe.seek(
          targetMilliseconds: 8000,
          submit: () async => submittedTargets.add(8000));
      await samplingStarted.future;

      if (sourceChanged) {
        sourceGeneration++;
      } else {
        seekGeneration++;
        final replacement = PlaybackSeekDiagnostics(
          readProperty: (_) async => '',
          writeLog: (_) {},
          isCurrent: () => sourceGeneration == 0 && seekGeneration == 1,
          maxSamples: 0,
        );
        await replacement.seek(
            targetMilliseconds: 12000,
            submit: () async => submittedTargets.add(12000));
        await replacement.observation;
      }
      sample.complete('5');
      await pendingSeek;

      expect(submittedTargets, sourceChanged ? isEmpty : [12000]);
      expect(oldLogs, isEmpty);
      expect(probe.observation, isNull);
    });
  }

  test(
      'Given an in-flight seek command, when the source changes before its reply, then no observation starts',
      () async {
    var current = true;
    final commandStarted = Completer<void>();
    final command = Completer<void>();
    final events = <String>[];
    final probe = PlaybackSeekDiagnostics(
      readProperty: (_) async => '',
      writeLog: (message) => events.add(jsonDecode(message)['event'] as String),
      isCurrent: () => current,
    );
    final pendingSeek = probe.seek(
        targetMilliseconds: 8000,
        submit: () {
          commandStarted.complete();
          return command.future;
        });
    await commandStarted.future;

    current = false;
    command.complete();
    await pendingSeek;

    expect(events, ['before']);
    expect(probe.observation, isNull);
  });

  for (final pendingPositionRead in [3, 4]) {
    test(
        'Given a pending ${pendingPositionRead == 3 ? 'settled' : 'refill'} snapshot, when the source changes, then late values are not logged',
        () async {
      var current = true;
      var positionReads = 0;
      final samplingStarted = Completer<void>();
      final sample = Completer<String>();
      final events = <String>[];
      final probe = PlaybackSeekDiagnostics(
        readProperty: (name) async {
          if (name == 'time-pos') {
            if (++positionReads == pendingPositionRead) {
              samplingStarted.complete();
              return sample.future;
            }
            return '8';
          }
          return name == 'seeking' ? 'no' : '';
        },
        writeLog: (message) =>
            events.add(jsonDecode(message)['event'] as String),
        isCurrent: () => current,
        delay: (_) async {},
      );
      await probe.seek(targetMilliseconds: 8000, submit: () async {});
      await samplingStarted.future;

      current = false;
      sample.complete('15');
      await probe.observation;

      expect(events, [
        'before',
        'command_returned',
        if (pendingPositionRead == 4) 'native_seek_settled',
      ]);
    });
  }
  test('actual player command failure is propagated without retry', () async {
    var seeks = 0;
    final error = StateError('seek failed');
    final probe = PlaybackSeekDiagnostics(
      readProperty: (_) async => '',
      writeLog: (_) {},
      isCurrent: () => true,
    );
    await expectLater(
        probe.seek(
            targetMilliseconds: 8000,
            submit: () async {
              seeks++;
              throw error;
            }),
        throwsA(same(error)));
    expect(seeks, 1);
    expect(probe.observation, isNull);
  });
}
