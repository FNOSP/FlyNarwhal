import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../domain/update/entities/update_download_record.dart';

typedef UpdateDirectoryProvider = Future<Directory> Function();

/// Replaceable record persistence contract for deterministic tests.
abstract interface class UpdateDownloadRecordStore {
  Future<UpdateDownloadRecord?> load();

  Future<void> save(UpdateDownloadRecord record);

  Future<void> delete();
}

/// Minimal file operations required for durable record replacement.
abstract interface class UpdateRecordFileSystem {
  Future<bool> fileExists(String filePath);

  Future<String> readText(String filePath);

  Future<void> writeTextAndFlush(String filePath, String contents);

  Future<void> replaceFileAtomically({
    required String temporaryPath,
    required String destinationPath,
  });

  Future<void> deleteFile(String filePath);
}

/// dart:io implementation which flushes before same-directory replacement.
final class IoUpdateRecordFileSystem implements UpdateRecordFileSystem {
  const IoUpdateRecordFileSystem();

  @override
  Future<bool> fileExists(String filePath) => File(filePath).exists();

  @override
  Future<String> readText(String filePath) => File(filePath).readAsString();

  @override
  Future<void> writeTextAndFlush(String filePath, String contents) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);
    final sink = file.openWrite(mode: FileMode.writeOnly);
    try {
      sink.write(contents);
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  @override
  Future<void> replaceFileAtomically({
    required String temporaryPath,
    required String destinationPath,
  }) async {
    if (path.dirname(temporaryPath) != path.dirname(destinationPath)) {
      throw const FileSystemException(
        'Record replacement requires the same directory.',
      );
    }
    try {
      // POSIX rename replaces the destination atomically in one operation.
      await File(temporaryPath).rename(destinationPath);
      return;
    } on FileSystemException {
      if (!Platform.isWindows) rethrow;
    }

    final destination = File(destinationPath);
    if (!await destination.exists()) {
      await File(temporaryPath).rename(destinationPath);
      return;
    }
    final backupPath = '$destinationPath.backup';
    final backup = File(backupPath);
    if (await backup.exists()) {
      throw const FileSystemException(
        'A stale record replacement backup already exists.',
      );
    }

    // Windows dart:io cannot request replace-existing rename; retain and
    // restore the old record if the safe same-directory fallback fails.
    await destination.rename(backupPath);
    try {
      await File(temporaryPath).rename(destinationPath);
    } on Object {
      await backup.rename(destinationPath);
      rethrow;
    }
    await backup.delete();
  }

  @override
  Future<void> deleteFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}

/// Stores the typed download record outside SharedPreferences.
final class JsonUpdateDownloadRecordStore implements UpdateDownloadRecordStore {
  JsonUpdateDownloadRecordStore({
    UpdateDirectoryProvider? applicationSupportDirectoryProvider,
    UpdateDirectoryProvider? updatesCacheDirectoryProvider,
    UpdateRecordFileSystem fileSystem = const IoUpdateRecordFileSystem(),
  })  : _applicationSupportDirectoryProvider =
            applicationSupportDirectoryProvider ??
                getApplicationSupportDirectory,
        _updatesCacheDirectoryProvider =
            updatesCacheDirectoryProvider ?? _defaultUpdatesCacheDirectory,
        _fileSystem = fileSystem;

  static const String _recordFileName = 'download-record.json';
  static const String _temporaryRecordFileName = 'download-record.json.tmp';

  final UpdateDirectoryProvider _applicationSupportDirectoryProvider;
  final UpdateDirectoryProvider _updatesCacheDirectoryProvider;
  final UpdateRecordFileSystem _fileSystem;

  @override
  Future<UpdateDownloadRecord?> load() async {
    final recordPath = await _getRecordPath();
    if (!await _fileSystem.fileExists(recordPath)) return null;

    try {
      final decoded = jsonDecode(await _fileSystem.readText(recordPath));
      if (decoded is! Map<String, dynamic>) {
        throw const UpdateDownloadRecordException(
          UpdateDownloadRecordFailureReason.corrupted,
          'Update download record root must be an object.',
        );
      }
      return UpdateDownloadRecord.fromJson(decoded);
    } on UpdateDownloadRecordException {
      await delete();
      rethrow;
    } on Object {
      await delete();
      throw const UpdateDownloadRecordException(
        UpdateDownloadRecordFailureReason.corrupted,
        'Update download record JSON is corrupted.',
      );
    }
  }

  @override
  Future<void> save(UpdateDownloadRecord record) async {
    final recordPath = await _getRecordPath();
    final temporaryPath = await _getTemporaryRecordPath();
    try {
      await _fileSystem.writeTextAndFlush(
        temporaryPath,
        jsonEncode(record.toJson()),
      );
      await _fileSystem.replaceFileAtomically(
        temporaryPath: temporaryPath,
        destinationPath: recordPath,
      );
    } finally {
      await _fileSystem.deleteFile(temporaryPath);
    }
  }

  @override
  Future<void> delete() async {
    await _fileSystem.deleteFile(await _getRecordPath());
    await _fileSystem.deleteFile(await _getTemporaryRecordPath());
  }

  Future<Directory> getUpdatesCacheDirectory() {
    return _updatesCacheDirectoryProvider();
  }

  Future<bool> recordFileExists() async {
    return _fileSystem.fileExists(await _getRecordPath());
  }

  Future<bool> temporaryRecordFileExists() async {
    return _fileSystem.fileExists(await _getTemporaryRecordPath());
  }

  Future<void> writeRawJsonForTesting(Map<String, Object?> json) async {
    await writeRawTextForTesting(jsonEncode(json));
  }

  Future<void> writeRawTextForTesting(String value) async {
    await _fileSystem.writeTextAndFlush(await _getRecordPath(), value);
  }

  Future<String> _getRecordPath() async {
    final supportDirectory = await _applicationSupportDirectoryProvider();
    return path.join(
      supportDirectory.path,
      'updates',
      _recordFileName,
    );
  }

  Future<String> _getTemporaryRecordPath() async {
    final supportDirectory = await _applicationSupportDirectoryProvider();
    return path.join(
      supportDirectory.path,
      'updates',
      _temporaryRecordFileName,
    );
  }

  static Future<Directory> _defaultUpdatesCacheDirectory() async {
    final cacheDirectory = await getTemporaryDirectory();
    return Directory(path.join(cacheDirectory.path, 'updates'));
  }
}
