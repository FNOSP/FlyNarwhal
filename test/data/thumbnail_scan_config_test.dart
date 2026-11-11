import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/data/models/fly_narwhal/index.dart';

void main() {
  group('ThumbnailScanConfig.fromJson', () {
    test('full snapshot maps every field', () {
      final config = ThumbnailScanConfig.fromJson({
        'enabled': true,
        'cron': '0 0 3 * * ?',
        'dirs': ['/vol1/media', '/vol2/movies'],
        'cronValid': true,
        'nextRunTimeMs': 1762830000000,
        'scanState': 'RUNNING',
        'currentDir': '/vol1/media',
        'scannedFiles': 42,
        'lastRunTimeMs': 1762740000000,
        'lastFinishTimeMs': 1762740600000,
        'lastStatus': 'SUCCESS',
        'lastScannedCount': 120,
        'lastQueuedCount': 8,
        'lastError': null,
      });

      expect(config.enabled, isTrue);
      expect(config.cron, '0 0 3 * * ?');
      expect(config.dirs, ['/vol1/media', '/vol2/movies']);
      expect(config.cronValid, isTrue);
      expect(config.nextRunTime,
          DateTime.fromMillisecondsSinceEpoch(1762830000000));
      expect(config.scanState, ThumbnailScanState.running);
      expect(config.isBusy, isTrue);
      expect(config.currentDir, '/vol1/media');
      expect(config.scannedFiles, 42);
      expect(config.lastStatus, 'SUCCESS');
      expect(config.lastScannedCount, 120);
      expect(config.lastQueuedCount, 8);
      expect(config.lastError, isNull);
    });

    test('missing fields fall back to disabled/never/idle', () {
      final config = ThumbnailScanConfig.fromJson(const {});
      expect(config.enabled, isFalse);
      expect(config.cron, isEmpty);
      expect(config.dirs, isEmpty);
      expect(config.cronValid, isTrue, reason: 'an empty cron is not invalid');
      expect(config.scanState, ThumbnailScanState.idle);
      expect(config.isBusy, isFalse);
      expect(config.lastStatus, ThumbnailScanConfig.lastStatusNever);
      expect(config.nextRunTime, isNull);
    });

    test('unknown scan state reads as idle', () {
      expect(ThumbnailScanState.fromString('WHATEVER'),
          ThumbnailScanState.idle);
      expect(ThumbnailScanState.fromString('queued'),
          ThumbnailScanState.queued);
    });
  });

  test('toSaveJson carries exactly the three editable fields', () {
    final config = ThumbnailScanConfig.fromJson({
      'enabled': true,
      'cron': '0 0 3 * * ?',
      'dirs': ['/vol1/media'],
      'scanState': 'RUNNING',
      'lastStatus': 'SUCCESS',
    });
    expect(config.toSaveJson(), {
      'enabled': true,
      'cron': '0 0 3 * * ?',
      'dirs': ['/vol1/media'],
    });
  });

  group('CronPreviewResult.fromJson', () {
    test('valid preview lists ascending run times', () {
      final result = CronPreviewResult.fromJson({
        'valid': true,
        'nextRuns': [1000, 2000, 3000],
      });
      expect(result.valid, isTrue);
      expect(result.error, isNull);
      expect(result.nextRuns.length, 3);
      expect(result.nextRuns.first, DateTime.fromMillisecondsSinceEpoch(1000));
    });

    test('invalid preview carries the server reason', () {
      final result = CronPreviewResult.fromJson({
        'valid': false,
        'error': 'invalid cron expression: foo',
      });
      expect(result.valid, isFalse);
      expect(result.error, contains('invalid cron'));
      expect(result.nextRuns, isEmpty);
    });
  });
}
