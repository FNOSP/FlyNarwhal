import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/core/utils/log/error_log_exporter.dart';
import 'package:fly_narwhal/core/utils/log/talker_formatter.dart';
import 'package:fly_narwhal/core/utils/log/talker_log_types.dart';
import 'package:fly_narwhal/core/network/quark_cdn_proxy/cdn_range_diagnostics.dart';
import 'package:talker/talker.dart';

void main() {
  test(
      'Given a full diagnostic report, when exporting errors, then all chunk context survives',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final directory =
        await Directory.systemTemp.createTemp('cdn-diagnostic-export-');
    addTearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      await directory.delete(recursive: true);
    });
    final entries = <String>[];
    String? report;
    final diagnostics =
        CdnRangeDiagnostics(writeLog: (message, {required failure}) {
      if (failure) report = message;
      entries
          .add(AppTalkerMessageFormatter.formatFileMessage(AppTaggedTalkerLog(
        tag: 'CdnDiagnostic',
        message: message,
        level: failure ? LogLevel.error : LogLevel.info,
      )));
    });
    diagnostics.initialized(1000, const Duration(seconds: 20));
    for (var i = 0; i < 32; i++) {
      diagnostics.finish(
          diagnostics.begin(start: i, end: i, probe: false), 'success');
    }
    diagnostics.failed(occupiedSlots: 2, activeReaders: 1);
    expect(report!.length, greaterThan(1000));
    const date = '2026-09-20';
    await File('${directory.path}/FlyNarwhal-$date.log')
        .writeAsString(entries.join('\n'));
    final exported = File('${directory.path}/export.log');
    final exporter = DesktopErrorLogExporter(
      logDirectoryResolver: () async => directory.path,
      saveLocationPicker: ({required suggestedName, initialDirectory}) async =>
          FileSaveLocation(exported.path),
      revealExportedFile: (_) async {},
    );
    await exporter.exportErrorLogs(date);
    expect(await exported.readAsString(), contains(report));
  });

  test('Given long playback, when it fails, then keeps only 32 recent chunks',
      () {
    final logs = <String>[];
    final diagnostics =
        CdnRangeDiagnostics(writeLog: (message, {required failure}) {
      logs.add(message);
    });
    for (var index = 0; index < 100; index++) {
      final trace = diagnostics.begin(start: index, end: index, probe: false);
      trace.admitted();
      trace.headersReceived(100);
      trace.received(1);
      diagnostics.finish(trace, 'success');
    }
    expect(logs, isEmpty);
    diagnostics.failed(occupiedSlots: 2, activeReaders: 1);
    diagnostics.failed(occupiedSlots: 0, activeReaders: 0);
    final report = jsonDecode(logs.single) as Map<String, dynamic>;
    final chunks = report['recentChunks'] as List;
    expect(chunks, hasLength(32));
    expect(chunks.first['start'], 68);
    expect(chunks.last['start'], 99);
  });

  test(
      'Given nested Dio socket error, when recorded, then retains codes without credentials',
      () {
    final error = DioException(
      requestOptions: RequestOptions(
        path: 'https://private.example/video?signature=secret',
        headers: {'Cookie': 'secret'},
      ),
      type: DioExceptionType.connectionError,
      message: 'secret',
      error: const SocketException('secret', osError: OSError('secret', 10054)),
    );
    expect(describeCdnDiagnosticError(error), {
      'type': 'DioException',
      'dioType': 'connectionError',
      'causeType': 'SocketException',
      'osErrorCode': 10054,
    });
  });

  test(
      'Given a broken logger, when reporting, then it cannot interrupt playback',
      () {
    final diagnostics = CdnRangeDiagnostics(writeLog: (_, {required failure}) {
      throw StateError('disk unavailable');
    });
    expect(() => diagnostics.initialized(100, const Duration(seconds: 20)),
        returnsNormally);
    expect(() => diagnostics.failed(occupiedSlots: 1, activeReaders: 1),
        returnsNormally);
  });
}
