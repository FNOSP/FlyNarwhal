import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// One cached release-page response with its conditional-request ETag.
final class GitHubReleaseCacheEntry {
  const GitHubReleaseCacheEntry({
    required this.etag,
    required this.payload,
    required this.fetchedAt,
  });

  final String etag;
  final String payload;
  final DateTime fetchedAt;
}

/// Stores ETag entries so repeated checks can resolve with HTTP 304,
/// which GitHub does not count against the unauthenticated rate limit.
abstract interface class GitHubReleaseResponseCache {
  Future<GitHubReleaseCacheEntry?> load(int page);

  Future<void> save(int page, GitHubReleaseCacheEntry entry);

  Future<void> remove(int page);
}

/// File-based cache inside the application support directory.
///
/// Cache misses and I/O errors surface as null or no-ops: the cache is a
/// pure optimization and must never fail an update check.
final class FileGitHubReleaseResponseCache
    implements GitHubReleaseResponseCache {
  const FileGitHubReleaseResponseCache();

  static const String _directoryName = 'update-check-cache';

  Future<Directory?> _directory() async {
    try {
      final support = await getApplicationSupportDirectory();
      final directory = Directory(path.join(support.path, _directoryName));
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return directory;
    } on Object {
      return null;
    }
  }

  File? _fileFor(Directory? directory, int page) {
    if (directory == null) return null;
    return File(path.join(directory.path, 'github-releases-page-$page.json'));
  }

  @override
  Future<GitHubReleaseCacheEntry?> load(int page) async {
    try {
      final file = _fileFor(await _directory(), page);
      if (file == null || !await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      final etag = decoded['etag'];
      final payload = decoded['payload'];
      if (etag is! String || etag.isEmpty || payload is! String) return null;
      final rawFetchedAt = decoded['fetchedAt'];
      final fetchedAt = rawFetchedAt is String
          ? DateTime.tryParse(rawFetchedAt)
          : null;
      return GitHubReleaseCacheEntry(
        etag: etag,
        payload: payload,
        // A missing timestamp marks the entry as expired-but-reusable.
        fetchedAt:
            fetchedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
    } on Object {
      return null;
    }
  }

  @override
  Future<void> save(int page, GitHubReleaseCacheEntry entry) async {
    try {
      final file = _fileFor(await _directory(), page);
      if (file == null) return;
      await file.writeAsString(jsonEncode(<String, String>{
        'etag': entry.etag,
        'payload': entry.payload,
        'fetchedAt': entry.fetchedAt.toUtc().toIso8601String(),
      }));
    } on Object {
      // Best-effort optimization; write failures are ignored.
    }
  }

  @override
  Future<void> remove(int page) async {
    try {
      final file = _fileFor(await _directory(), page);
      if (file == null || !await file.exists()) return;
      await file.delete();
    } on Object {
      // Best-effort cleanup; failures are ignored.
    }
  }
}
