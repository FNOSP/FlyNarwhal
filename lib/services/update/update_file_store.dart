import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../data/storage/update_download_record_store.dart';
import '../../domain/update/entities/update_download_record.dart';
import '../../domain/update/entities/update_models.dart';
import 'sha256_verifier.dart';
import 'update_path_safety.dart';

export 'update_path_safety.dart';

typedef CachedFileVerifier = Future<bool> Function({
  required File file,
  required String expectedDigest,
});

/// Stable diagnostics emitted while rejecting unsafe or invalid cache state.
enum UpdateFileStoreFailureReason {
  recordCorrupted,
  pathRejected,
  fileMissing,
  sizeMismatch,
  hashMismatch,
}

/// A non-sensitive diagnostic describing why cache recovery was rejected.
final class UpdateFileStoreDiagnostic {
  const UpdateFileStoreDiagnostic(this.reason, this.message);

  final UpdateFileStoreFailureReason reason;
  final String message;
}

/// Thrown when candidate metadata could generate an unsafe cache path.
final class UpdatePathException implements Exception {
  const UpdatePathException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Replaceable cache operations used to test cancellation and rename boundaries.
abstract interface class UpdateCacheFileSystem {
  Future<bool> fileExists(String filePath);

  Future<int> fileLength(String filePath);

  Future<void> deleteFile(String filePath);

  Future<File> renameFile(String sourcePath, String destinationPath);

  Future<bool> directoryExists(String directoryPath);

  Future<void> ensureDirectory(String directoryPath);

  Future<void> deleteDirectory(String directoryPath);

  IOSink openWrite(String filePath);

  Stream<FileSystemEntity> list(
    String directoryPath, {
    required bool recursive,
    required bool followLinks,
  });

  Future<String> resolvePath(String entityPath);
}

/// dart:io cache operations with no access outside caller-validated paths.
final class IoUpdateCacheFileSystem implements UpdateCacheFileSystem {
  const IoUpdateCacheFileSystem();

  @override
  Future<bool> fileExists(String filePath) => File(filePath).exists();

  @override
  Future<int> fileLength(String filePath) => File(filePath).length();

  @override
  Future<void> deleteFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<File> renameFile(String sourcePath, String destinationPath) {
    return File(sourcePath).rename(destinationPath);
  }

  @override
  Future<bool> directoryExists(String directoryPath) =>
      Directory(directoryPath).exists();

  @override
  Future<void> ensureDirectory(String directoryPath) =>
      Directory(directoryPath).create(recursive: true);

  @override
  Future<void> deleteDirectory(String directoryPath) async {
    final directory = Directory(directoryPath);
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  @override
  IOSink openWrite(String filePath) =>
      File(filePath).openWrite(mode: FileMode.writeOnly);

  @override
  Stream<FileSystemEntity> list(
    String directoryPath, {
    required bool recursive,
    required bool followLinks,
  }) {
    return Directory(directoryPath).list(
      recursive: recursive,
      followLinks: followLinks,
    );
  }

  @override
  Future<String> resolvePath(String entityPath) async {
    final entityType =
        await FileSystemEntity.type(entityPath, followLinks: true);
    if (entityType == FileSystemEntityType.notFound) {
      return File(entityPath).absolute.path;
    }
    return File(entityPath).resolveSymbolicLinks();
  }
}

/// Minimal cache lifecycle used by the update state machine.
abstract interface class UpdateFileStoreContract {
  Future<bool> hasValidCachedFile(UpdateCandidate candidate);

  Future<File> getFinalFile(UpdateCandidate candidate);

  Future<void> deletePartialFile(UpdateCandidate candidate);

  Future<void> clearCandidate(UpdateCandidate candidate);

  Future<void> clearForRedownload(UpdateCandidate candidate);
}

/// Owns safe update cache paths, lifecycle cleanup, and restart recovery.
final class UpdateFileStore implements UpdateFileStoreContract {
  UpdateFileStore({
    required Sha256Verifier sha256Verifier,
    UpdateDirectoryProvider? updatesDirectoryProvider,
    UpdateDownloadRecordStore? downloadRecordStore,
    UpdateCacheFileSystem cacheFileSystem = const IoUpdateCacheFileSystem(),
    CachedFileVerifier? cachedFileVerifier,
  })  : _updatesDirectoryProvider =
            updatesDirectoryProvider ?? _defaultUpdatesDirectory,
        _downloadRecordStore =
            downloadRecordStore ?? JsonUpdateDownloadRecordStore(),
        _cacheFileSystem = cacheFileSystem,
        _cachedFileVerifier = cachedFileVerifier ?? sha256Verifier.verifyFile;

  final UpdateDirectoryProvider _updatesDirectoryProvider;
  final UpdateDownloadRecordStore _downloadRecordStore;
  final UpdateCacheFileSystem _cacheFileSystem;
  final CachedFileVerifier _cachedFileVerifier;

  UpdateFileStoreDiagnostic? lastDiagnostic;

  @override
  Future<File> getFinalFile(UpdateCandidate candidate) async {
    _validateCandidate(candidate);
    final directory = await _getCandidateDirectory(candidate);
    final finalPath = path.join(directory.path, candidate.asset.name);
    final updatesDirectory = await _updatesDirectoryProvider();
    if (!UpdatePathSafety.isWithinRoot(
      rootPath: updatesDirectory.path,
      candidatePath: finalPath,
    )) {
      throw const UpdatePathException('Candidate path escaped update cache.');
    }
    return File(finalPath);
  }

  Future<File> getPartialFile(UpdateCandidate candidate) async {
    final finalFile = await getFinalFile(candidate);
    return File('${finalFile.path}.part');
  }

  Future<void> prepareForDownload(UpdateCandidate candidate) async {
    final updatesDirectory = await _updatesDirectoryProvider();
    await _cacheFileSystem.ensureDirectory(updatesDirectory.path);
    final candidateDirectory = await _getCandidateDirectory(candidate);
    await _removeOtherVersionDirectories(candidate.version.toString());
    if (await _cacheFileSystem.directoryExists(candidateDirectory.path)) {
      await _assertSafeExistingPath(candidateDirectory.path);
    } else {
      await _cacheFileSystem.ensureDirectory(candidateDirectory.path);
    }
    await deletePartialFile(candidate);
  }

  Future<IOSink> openPartialWrite(UpdateCandidate candidate) async {
    final partialFile = await getPartialFile(candidate);
    await _assertSafeTargetPath(partialFile.path);
    return _cacheFileSystem.openWrite(partialFile.path);
  }

  @override
  Future<void> deletePartialFile(UpdateCandidate candidate) async {
    await _deleteSafePath((await getPartialFile(candidate)).path);
  }

  @override
  Future<bool> hasValidCachedFile(UpdateCandidate candidate) async {
    final finalFile = await getFinalFile(candidate);
    UpdateDownloadRecord? record;
    try {
      record = await _downloadRecordStore.load();
    } on UpdateDownloadRecordException {
      await deleteCachedFile(candidate);
      return false;
    }
    final digest = candidate.asset.digest;
    final recordMatchesCandidate = record != null &&
        record.stage == UpdateDownloadStage.verified &&
        record.version == candidate.version.toString() &&
        record.assetName == candidate.asset.name &&
        record.officialDownloadUrl == candidate.asset.officialDownloadUrl &&
        record.expectedSize == candidate.asset.sizeInBytes &&
        record.expectedSha256.toLowerCase() == digest?.toLowerCase() &&
        path.equals(
          path.normalize(record.finalFilePath),
          path.normalize(finalFile.path),
        );
    if (!recordMatchesCandidate ||
        digest == null ||
        !await _validateFile(
          finalFile,
          expectedSize: candidate.asset.sizeInBytes,
          expectedDigest: digest,
        )) {
      await deleteCachedFile(candidate);
      await _downloadRecordStore.delete();
      return false;
    }
    return true;
  }

  Future<File> commitPartialFile(UpdateCandidate candidate) async {
    final partialFile = await getPartialFile(candidate);
    final finalFile = await getFinalFile(candidate);
    await _assertSafeExistingPath(partialFile.path);
    await _assertSafeTargetPath(finalFile.path);

    // Publish the record only after the same-directory rename succeeds.
    await _deleteSafePath(finalFile.path);
    final committedFile =
        await _cacheFileSystem.renameFile(partialFile.path, finalFile.path);
    final digest = candidate.asset.digest;
    if (digest == null) {
      await _deleteSafePath(committedFile.path);
      throw const UpdatePathException('Verified candidate digest is missing.');
    }
    try {
      await _downloadRecordStore.save(
        _createRecord(
          candidate: candidate,
          finalFile: committedFile,
          stage: UpdateDownloadStage.verified,
          automaticFailureCount: 0,
        ),
      );
    } on Object {
      await _deleteSafePath(committedFile.path);
      rethrow;
    }
    return committedFile;
  }

  Future<void> persistDownloadingRecord(UpdateCandidate candidate) async {
    final finalFile = await getFinalFile(candidate);
    await _downloadRecordStore.save(
      _createRecord(
        candidate: candidate,
        finalFile: finalFile,
        stage: UpdateDownloadStage.downloading,
        automaticFailureCount: 0,
      ),
    );
  }

  Future<void> persistFailureRecord(
    UpdateCandidate candidate, {
    required int automaticFailureCount,
    required String failureCode,
    required DateTime failedAt,
  }) async {
    final finalFile = await getFinalFile(candidate);
    await _downloadRecordStore.save(
      _createRecord(
        candidate: candidate,
        finalFile: finalFile,
        stage: UpdateDownloadStage.failed,
        automaticFailureCount: automaticFailureCount,
        lastFailureCode: failureCode,
        lastFailureAt: failedAt,
      ),
    );
  }

  Future<File?> recoverVerifiedFile() async {
    lastDiagnostic = null;
    UpdateDownloadRecord? record;
    try {
      record = await _downloadRecordStore.load();
    } on UpdateDownloadRecordException catch (error) {
      lastDiagnostic = UpdateFileStoreDiagnostic(
        UpdateFileStoreFailureReason.recordCorrupted,
        error.message,
      );
      await clearOrphanedPartialFiles();
      return null;
    }
    if (record == null) {
      await clearOrphanedPartialFiles();
      return null;
    }

    final safeFile = await _resolveTrustedRecordFile(record);
    if (safeFile == null) return null;
    if (record.stage != UpdateDownloadStage.verified) {
      await _clearRecordCache(record, safeFile);
      return null;
    }
    if (!await _validateFile(
      safeFile,
      expectedSize: record.expectedSize,
      expectedDigest: record.expectedSha256,
    )) {
      await _clearRecordCache(record, safeFile);
      return null;
    }
    await clearOrphanedPartialFiles();
    return safeFile;
  }

  Future<void> clearOrphanedPartialFiles() async {
    final updatesDirectory = await _updatesDirectoryProvider();
    if (!await _cacheFileSystem.directoryExists(updatesDirectory.path)) return;
    await _assertSafeExistingPath(updatesDirectory.path);
    await for (final entity in _cacheFileSystem.list(
      updatesDirectory.path,
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File && entity.path.endsWith('.part')) {
        await _deleteSafePath(entity.path);
      }
    }
  }

  Future<void> clearPartialFiles() => clearOrphanedPartialFiles();

  Future<void> deleteCachedFile(UpdateCandidate candidate) async {
    await _deleteSafePath((await getPartialFile(candidate)).path);
    await _deleteSafePath((await getFinalFile(candidate)).path);
  }

  @override
  Future<void> clearCandidate(UpdateCandidate candidate) async {
    final candidateDirectory = await _getCandidateDirectory(candidate);
    if (await _cacheFileSystem.directoryExists(candidateDirectory.path)) {
      await _assertSafeExistingPath(candidateDirectory.path);
      await _cacheFileSystem.deleteDirectory(candidateDirectory.path);
    }
    await _downloadRecordStore.delete();
  }

  Future<void> clearAfterSuccessfulInstallation(UpdateCandidate candidate) {
    return clearCandidate(candidate);
  }

  @override
  Future<void> clearForRedownload(UpdateCandidate candidate) {
    return clearCandidate(candidate);
  }

  Future<File?> _resolveTrustedRecordFile(UpdateDownloadRecord record) async {
    final updatesDirectory = await _updatesDirectoryProvider();
    final expectedPath = path.join(
      updatesDirectory.path,
      record.version,
      record.assetName,
    );
    final recordedPathMatches = Platform.isWindows
        ? path.Context(style: path.Style.windows).equals(
            path.Context(style: path.Style.windows)
                .normalize(record.finalFilePath),
            path.Context(style: path.Style.windows).normalize(expectedPath),
          )
        : path.equals(
            path.normalize(record.finalFilePath), path.normalize(expectedPath));
    if (!UpdatePathSafety.isSafeAssetName(record.assetName) ||
        !recordedPathMatches ||
        !UpdatePathSafety.isWithinRoot(
          rootPath: updatesDirectory.path,
          candidatePath: record.finalFilePath,
        )) {
      await _rejectPath();
      return null;
    }

    if (await _cacheFileSystem.fileExists(record.finalFilePath)) {
      final resolvedRoot =
          await _cacheFileSystem.resolvePath(updatesDirectory.path);
      final resolvedFile =
          await _cacheFileSystem.resolvePath(record.finalFilePath);
      if (!UpdatePathSafety.isWithinRoot(
        rootPath: resolvedRoot,
        candidatePath: resolvedFile,
      )) {
        await _rejectPath();
        return null;
      }
    }
    return File(record.finalFilePath);
  }

  Future<void> _rejectPath() async {
    lastDiagnostic = const UpdateFileStoreDiagnostic(
      UpdateFileStoreFailureReason.pathRejected,
      'Persisted update path was outside the cache root.',
    );
    await _downloadRecordStore.delete();
    await clearOrphanedPartialFiles();
  }

  Future<bool> _validateFile(
    File file, {
    required int expectedSize,
    required String expectedDigest,
  }) async {
    if (!await _cacheFileSystem.fileExists(file.path)) {
      lastDiagnostic = const UpdateFileStoreDiagnostic(
        UpdateFileStoreFailureReason.fileMissing,
        'Recorded update file does not exist.',
      );
      return false;
    }
    if (await _cacheFileSystem.fileLength(file.path) != expectedSize) {
      lastDiagnostic = const UpdateFileStoreDiagnostic(
        UpdateFileStoreFailureReason.sizeMismatch,
        'Recorded update file size did not match.',
      );
      return false;
    }
    if (!await _cachedFileVerifier(
      file: file,
      expectedDigest: expectedDigest,
    )) {
      lastDiagnostic = const UpdateFileStoreDiagnostic(
        UpdateFileStoreFailureReason.hashMismatch,
        'Recorded update file digest did not match.',
      );
      return false;
    }
    return true;
  }

  Future<void> _clearRecordCache(
    UpdateDownloadRecord record,
    File safeFile,
  ) async {
    await _deleteSafePath(safeFile.path);
    await _deleteSafePath('${safeFile.path}.part');
    await _downloadRecordStore.delete();
  }

  Future<void> _removeOtherVersionDirectories(String currentVersion) async {
    final updatesDirectory = await _updatesDirectoryProvider();
    if (!await _cacheFileSystem.directoryExists(updatesDirectory.path)) return;
    await for (final entity in _cacheFileSystem.list(
      updatesDirectory.path,
      recursive: false,
      followLinks: false,
    )) {
      if (entity is Directory && path.basename(entity.path) != currentVersion) {
        await _assertSafeExistingPath(entity.path);
        await _cacheFileSystem.deleteDirectory(entity.path);
      }
    }
  }

  Future<void> _assertSafeExistingPath(String entityPath) async {
    final updatesDirectory = await _updatesDirectoryProvider();
    final resolvedRoot =
        await _cacheFileSystem.resolvePath(updatesDirectory.path);
    final resolvedEntity = await _cacheFileSystem.resolvePath(entityPath);
    final samePath = Platform.isWindows
        ? path.Context(style: path.Style.windows).equals(
            path.Context(style: path.Style.windows).normalize(resolvedRoot),
            path.Context(style: path.Style.windows).normalize(resolvedEntity),
          )
        : path.equals(
            path.normalize(resolvedRoot), path.normalize(resolvedEntity));
    if (!samePath &&
        !UpdatePathSafety.isWithinRoot(
          rootPath: resolvedRoot,
          candidatePath: resolvedEntity,
        )) {
      throw const UpdatePathException(
        'Resolved update path escaped the cache root.',
      );
    }
  }

  Future<void> _assertSafeTargetPath(String entityPath) async {
    final updatesDirectory = await _updatesDirectoryProvider();
    if (!UpdatePathSafety.isWithinRoot(
      rootPath: updatesDirectory.path,
      candidatePath: entityPath,
    )) {
      throw const UpdatePathException('Update target escaped cache root.');
    }
    await _assertSafeExistingPath(path.dirname(entityPath));
    if (await _cacheFileSystem.fileExists(entityPath)) {
      await _assertSafeExistingPath(entityPath);
    }
  }

  Future<void> _deleteSafePath(String entityPath) async {
    if (!await _cacheFileSystem.fileExists(entityPath)) return;
    await _assertSafeExistingPath(entityPath);
    await _cacheFileSystem.deleteFile(entityPath);
  }

  Future<Directory> _getCandidateDirectory(UpdateCandidate candidate) async {
    _validateCandidate(candidate);
    final updatesDirectory = await _updatesDirectoryProvider();
    return Directory(path.join(
      updatesDirectory.path,
      candidate.version.toString(),
    ));
  }

  void _validateCandidate(UpdateCandidate candidate) {
    if (!UpdatePathSafety.isSafeAssetName(candidate.asset.name)) {
      throw const UpdatePathException('Unsafe update asset name.');
    }
  }

  UpdateDownloadRecord _createRecord({
    required UpdateCandidate candidate,
    required File finalFile,
    required UpdateDownloadStage stage,
    required int automaticFailureCount,
    String? lastFailureCode,
    DateTime? lastFailureAt,
  }) {
    final digest = candidate.asset.digest;
    if (digest == null) {
      throw const UpdatePathException('Candidate digest is missing.');
    }
    return UpdateDownloadRecord(
      schemaVersion: UpdateDownloadRecord.currentSchemaVersion,
      version: candidate.version.toString(),
      assetName: candidate.asset.name,
      officialDownloadUrl: candidate.asset.officialDownloadUrl,
      expectedSize: candidate.asset.sizeInBytes,
      expectedSha256: digest.toLowerCase(),
      finalFilePath: finalFile.path,
      stage: stage,
      automaticFailureCount: automaticFailureCount,
      lastFailureCode: lastFailureCode,
      lastFailureAt: lastFailureAt,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  static Future<Directory> _defaultUpdatesDirectory() async {
    final cacheDirectory = await getTemporaryDirectory();
    return Directory(path.join(cacheDirectory.path, 'updates'));
  }
}
