import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import 'app_talker.dart';

typedef SaveLogFileLocationPicker = Future<FileSaveLocation?> Function({
  required String suggestedName,
  String? initialDirectory,
});

typedef RevealExportedLogFile = Future<void> Function(File file);

abstract class ErrorLogExporter {
  bool get isSupported;

  List<String> getAvailableLogDates();

  Future<void> exportErrorLogs(String date);
}

class LogExportException implements Exception {
  const LogExportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DesktopErrorLogExporter implements ErrorLogExporter {
  DesktopErrorLogExporter({
    Future<String?> Function()? logDirectoryResolver,
    SaveLogFileLocationPicker? saveLocationPicker,
    RevealExportedLogFile? revealExportedFile,
    DateTime Function()? nowProvider,
  })  : _logDirectoryResolver =
            logDirectoryResolver ?? AppTalker.resolveLogDirectoryPathForExport,
        _saveLocationPicker = saveLocationPicker ?? _defaultSaveLocationPicker,
        _revealExportedFile = revealExportedFile ?? _defaultRevealExportedFile,
        _nowProvider = nowProvider ?? DateTime.now;

  static const XTypeGroup _logTypeGroup = XTypeGroup(
    label: 'Log files',
    extensions: <String>['log'],
  );

  static final RegExp _entryHeaderPattern = RegExp(
    r'^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] \[[A-Z]+\s*\] ',
  );
  static final RegExp _errorLevelPattern = RegExp(
    r'^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] \[(ERROR|CRITICAL)\s*\] ',
    caseSensitive: false,
  );

  final Future<String?> Function() _logDirectoryResolver;
  final SaveLogFileLocationPicker _saveLocationPicker;
  final RevealExportedLogFile _revealExportedFile;
  final DateTime Function() _nowProvider;

  @override
  bool get isSupported {
    if (kIsWeb) {
      return false;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        return true;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  @override
  List<String> getAvailableLogDates() {
    final now = _nowProvider();
    return List<String>.generate(3, (index) {
      return _formatDate(now.subtract(Duration(days: index)));
    });
  }

  @override
  Future<void> exportErrorLogs(String date) async {
    if (!isSupported) {
      throw const LogExportException('当前平台暂不支持导出日志');
    }

    final directoryPath = await _logDirectoryResolver();
    if (directoryPath == null || directoryPath.isEmpty) {
      throw const LogExportException('未找到日志目录');
    }

    final sourceFile = File(path.join(directoryPath, 'FlyNarwhal-$date.log'));
    if (!await sourceFile.exists()) {
      throw LogExportException('日志文件不存在: ${path.basename(sourceFile.path)}');
    }

    final saveLocation = await _saveLocationPicker(
      suggestedName: 'FlyNarwhal-Error-$date.log',
      initialDirectory: path.dirname(sourceFile.path),
    );
    if (saveLocation == null) {
      return;
    }

    final exportedContent = await _buildExportContent(sourceFile);
    final targetFile = File(saveLocation.path);

    await targetFile.parent.create(recursive: true);
    await targetFile.writeAsString(exportedContent, flush: true);
    await _revealExportedFile(targetFile);
  }

  // Split persisted Talker output into multi-line entries before filtering.
  Future<String> _buildExportContent(File sourceFile) async {
    final content = await sourceFile.readAsString();
    final entries = _splitEntries(content);
    final selectedEntries = _selectErrorContextEntries(entries);
    return selectedEntries.join('\n');
  }

  List<String> _splitEntries(String content) {
    final entries = <String>[];
    var currentEntry = StringBuffer();

    for (final line in const LineSplitter().convert(content)) {
      if (_entryHeaderPattern.hasMatch(line)) {
        if (currentEntry.isNotEmpty) {
          entries.add(currentEntry.toString());
        }
        currentEntry = StringBuffer(line);
        continue;
      }

      if (currentEntry.isEmpty) {
        currentEntry.write(line);
      } else {
        currentEntry
          ..write('\n')
          ..write(line);
      }
    }

    if (currentEntry.isNotEmpty) {
      entries.add(currentEntry.toString());
    }

    return entries;
  }

  // Keep nearby context so exported logs remain useful for debugging.
  List<String> _selectErrorContextEntries(List<String> entries) {
    final selectedIndices = <int>{};

    for (var index = 0; index < entries.length; index++) {
      if (!_errorLevelPattern.hasMatch(entries[index])) {
        continue;
      }

      final start = (index - 50).clamp(0, entries.length);
      final end = (index + 50).clamp(0, entries.length - 1);
      for (var current = start; current <= end; current++) {
        selectedIndices.add(current);
      }
    }

    final sortedIndices = selectedIndices.toList()..sort();
    return sortedIndices.map((index) => entries[index]).toList();
  }

  static Future<FileSaveLocation?> _defaultSaveLocationPicker({
    required String suggestedName,
    String? initialDirectory,
  }) {
    return getSaveLocation(
      suggestedName: suggestedName,
      initialDirectory: initialDirectory,
      acceptedTypeGroups: const <XTypeGroup>[_logTypeGroup],
    );
  }

  static Future<void> _defaultRevealExportedFile(File file) async {
    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.windows:
          await Process.start(
            'explorer.exe',
            <String>['/select,', file.path],
            runInShell: true,
          );
          return;
        case TargetPlatform.macOS:
          await Process.start(
            'open',
            <String>['-R', file.path],
            runInShell: true,
          );
          return;
        case TargetPlatform.linux:
          await Process.start(
            'xdg-open',
            <String>[file.parent.path],
            runInShell: true,
          );
          return;
        case TargetPlatform.android:
        case TargetPlatform.iOS:
        case TargetPlatform.fuchsia:
          return;
      }
    } catch (_) {
      return;
    }
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
