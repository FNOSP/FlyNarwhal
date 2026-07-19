import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as path;

abstract class TalkerAsyncDispatcher {
  Future<void> initialize();

  bool enqueueDesktopConsoleLine(String line);

  bool enqueueFileLine({
    required String directoryPath,
    required String fileName,
    required String line,
  });

  bool enqueueCleanOldLogs({
    required String directoryPath,
    required int retentionDays,
    required String filePrefix,
  });

  Future<void> dispose();
}

class IoTalkerAsyncDispatcher implements TalkerAsyncDispatcher {
  Future<void>? _initializeFuture;
  Completer<void>? _workerExitCompleter;
  Isolate? _workerIsolate;
  SendPort? _workerSendPort;
  StreamSubscription<dynamic>? _errorSubscription;
  StreamSubscription<dynamic>? _exitSubscription;

  @override
  Future<void> initialize() {
    if (!_isDesktopPlatform()) {
      return Future.value();
    }

    if (_workerSendPort != null) {
      return Future.value();
    }

    return _initializeFuture ??= _spawnWorker();
  }

  @override
  bool enqueueDesktopConsoleLine(String line) {
    return _sendMessage(
      <String, Object?>{
        'command': _WorkerCommand.console.name,
        'line': line,
      },
    );
  }

  @override
  bool enqueueFileLine({
    required String directoryPath,
    required String fileName,
    required String line,
  }) {
    return _sendMessage(
      <String, Object?>{
        'command': _WorkerCommand.file.name,
        'directoryPath': directoryPath,
        'fileName': fileName,
        'line': line,
      },
    );
  }

  @override
  bool enqueueCleanOldLogs({
    required String directoryPath,
    required int retentionDays,
    required String filePrefix,
  }) {
    return _sendMessage(
      <String, Object?>{
        'command': _WorkerCommand.clean.name,
        'directoryPath': directoryPath,
        'retentionDays': retentionDays,
        'filePrefix': filePrefix,
      },
    );
  }

  @override
  Future<void> dispose() async {
    final workerSendPort = _workerSendPort;
    final workerExitCompleter = _workerExitCompleter;
    _workerSendPort = null;
    _initializeFuture = null;
    _workerExitCompleter = null;

    if (workerSendPort != null) {
      workerSendPort.send(
        <String, Object?>{
          'command': _WorkerCommand.shutdown.name,
        },
      );
    }

    if (workerExitCompleter != null) {
      try {
        await workerExitCompleter.future.timeout(
          const Duration(milliseconds: 500),
        );
      } catch (_) {
        // Allow dispose to keep moving if the worker does not exit in time.
      }
    }

    await _errorSubscription?.cancel();
    await _exitSubscription?.cancel();
    _errorSubscription = null;
    _exitSubscription = null;
    _workerIsolate?.kill(priority: Isolate.immediate);
    _workerIsolate = null;
  }

  bool _sendMessage(Map<String, Object?> message) {
    if (!_isDesktopPlatform()) {
      return false;
    }

    final workerSendPort = _workerSendPort;
    if (workerSendPort == null) {
      return false;
    }

    try {
      workerSendPort.send(message);
      return true;
    } catch (_) {
      _workerSendPort = null;
      _initializeFuture = null;
      return false;
    }
  }

  Future<void> _spawnWorker() async {
    final readyPort = ReceivePort();
    final errorPort = ReceivePort();
    final exitPort = ReceivePort();

    try {
      _workerExitCompleter = Completer<void>();
      _workerIsolate = await Isolate.spawn<_WorkerBootstrapData>(
        _runTalkerWorker,
        _WorkerBootstrapData(readyPort.sendPort),
        errorsAreFatal: false,
        onError: errorPort.sendPort,
        onExit: exitPort.sendPort,
      );

      _errorSubscription = errorPort.listen((dynamic _) {
        _workerSendPort = null;
        _initializeFuture = null;
        if (!(_workerExitCompleter?.isCompleted ?? true)) {
          _workerExitCompleter?.complete();
        }
      });
      _exitSubscription = exitPort.listen((dynamic _) {
        _workerSendPort = null;
        _initializeFuture = null;
        if (!(_workerExitCompleter?.isCompleted ?? true)) {
          _workerExitCompleter?.complete();
        }
      });

      final workerSendPort =
          await readyPort.first.timeout(const Duration(seconds: 5)) as SendPort;
      _workerSendPort = workerSendPort;
    } finally {
      readyPort.close();
    }
  }
}

class _WorkerBootstrapData {
  const _WorkerBootstrapData(this.readyPort);

  final SendPort readyPort;
}

enum _WorkerCommand {
  console,
  file,
  clean,
  shutdown,
}

void _runTalkerWorker(_WorkerBootstrapData bootstrap) {
  final receivePort = ReceivePort();
  bootstrap.readyPort.send(receivePort.sendPort);

  // Keep the worker loop isolated so desktop log I/O never blocks the UI isolate.
  unawaited(_runTalkerWorkerLoop(receivePort));
}

Future<void> _runTalkerWorkerLoop(ReceivePort receivePort) async {
  final sinks = <String, IOSink>{};
  var pendingFlushCount = 0;

  // Flush buffered log writes periodically to balance visibility and I/O pressure.
  final flushTimer = Timer.periodic(const Duration(seconds: 1), (_) {
    unawaited(_flushSinks(sinks));
  });

  try {
    await for (final dynamic rawMessage in receivePort) {
      if (rawMessage is! Map<Object?, Object?>) {
        continue;
      }

      try {
        final commandName = rawMessage['command'] as String?;
        if (commandName == null) {
          continue;
        }

        final command = _parseWorkerCommand(commandName);
        if (command == null) {
          continue;
        }

        switch (command) {
          case _WorkerCommand.console:
            final line = rawMessage['line'] as String?;
            if (line == null || line.isEmpty) {
              continue;
            }
            stdout.writeln(line);
            break;
          case _WorkerCommand.file:
            final directoryPath = rawMessage['directoryPath'] as String?;
            final fileName = rawMessage['fileName'] as String?;
            final line = rawMessage['line'] as String?;
            if (directoryPath == null || fileName == null || line == null) {
              continue;
            }

            final filePath = path.join(directoryPath, fileName);
            final sink = sinks.putIfAbsent(filePath, () {
              Directory(directoryPath).createSync(recursive: true);
              return File(filePath).openWrite(mode: FileMode.append);
            });
            sink.writeln(line);
            pendingFlushCount++;

            if (pendingFlushCount >= 20) {
              pendingFlushCount = 0;
              await _flushSinks(sinks);
            }
            break;
          case _WorkerCommand.clean:
            final directoryPath = rawMessage['directoryPath'] as String?;
            final retentionDays = rawMessage['retentionDays'] as int?;
            final filePrefix = rawMessage['filePrefix'] as String?;
            if (directoryPath == null ||
                retentionDays == null ||
                filePrefix == null) {
              continue;
            }
            _cleanOldLogs(
              directoryPath: directoryPath,
              retentionDays: retentionDays,
              filePrefix: filePrefix,
            );
            break;
          case _WorkerCommand.shutdown:
            await _flushSinks(sinks);
            await _closeSinks(sinks);
            receivePort.close();
            return;
        }
      } catch (_) {
        // Keep background logging best-effort and never crash the worker.
      }
    }
  } finally {
    flushTimer.cancel();
    await _flushSinks(sinks);
    await _closeSinks(sinks);
  }
}

Future<void> _flushSinks(Map<String, IOSink> sinks) async {
  for (final sink in sinks.values) {
    try {
      await sink.flush();
    } catch (_) {
      // Keep sink flush failures isolated from the caller.
    }
  }
}

Future<void> _closeSinks(Map<String, IOSink> sinks) async {
  for (final sink in sinks.values) {
    try {
      await sink.close();
    } catch (_) {
      // Keep sink close failures isolated from the caller.
    }
  }
  sinks.clear();
}

void _cleanOldLogs({
  required String directoryPath,
  required int retentionDays,
  required String filePrefix,
}) {
  final logDirectory = Directory(directoryPath);
  if (!logDirectory.existsSync()) {
    logDirectory.createSync(recursive: true);
    return;
  }

  final today = DateTime.now();

  // Clean only files that match the expected rolling naming convention.
  for (final entity in logDirectory.listSync()) {
    if (entity is! File) {
      continue;
    }

    final fileName = path.basename(entity.path);
    if (!fileName.startsWith(filePrefix) || !fileName.endsWith('.log')) {
      continue;
    }

    final datePart =
        fileName.substring(filePrefix.length, fileName.length - '.log'.length);
    final fileDate = DateTime.tryParse(datePart);
    if (fileDate == null) {
      continue;
    }

    if (today.difference(fileDate).inDays >= retentionDays) {
      entity.deleteSync();
    }
  }
}

_WorkerCommand? _parseWorkerCommand(String value) {
  for (final command in _WorkerCommand.values) {
    if (command.name == value) {
      return command;
    }
  }

  return null;
}

bool _isDesktopPlatform() {
  return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
}

TalkerAsyncDispatcher createPlatformTalkerAsyncDispatcher() =>
    IoTalkerAsyncDispatcher();
