import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart' as dio;

import '../../domain/update/entities/update_models.dart';
import '../../domain/update/repositories/cancellation_token.dart';
import 'download_url_resolver.dart';
import 'update_disk_space_probe.dart';
import 'update_file_store.dart';

/// Stable download failure categories consumed by application workflows.
enum UpdateDownloadFailureType {
  networkUnavailable,
  requestTimeout,
  httpStatus,
  redirectRejected,
  insufficientDiskSpace,
  permissionDenied,
  sizeMismatch,
  digestMissing,
  digestInvalid,
  hashMismatch,
  recordCorrupted,
  pathRejected,
  cancelled,
  unknown,
}

final class UpdateDownloadException implements Exception {
  const UpdateDownloadException({
    required this.type,
    required this.userMessageKey,
    required this.technicalDetail,
    required this.isRetryable,
    this.cause,
  });

  final UpdateDownloadFailureType type;
  final String userMessageKey;
  final String technicalDetail;
  final bool isRetryable;
  final Object? cause;

  /// Compatibility text for callers not yet migrated to message keys.
  String get message => userMessageKey;

  @override
  String toString() => 'UpdateDownloadException(${type.name})';
}

final class UpdateDownloadProgress {
  const UpdateDownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
  });

  final int receivedBytes;
  final int totalBytes;
}

final class UpdateDownloadRequest {
  const UpdateDownloadRequest({
    required this.candidate,
    required this.proxySnapshot,
    required this.cancellationToken,
  });

  final UpdateCandidate candidate;
  final UpdateProxySnapshot proxySnapshot;
  final CancellationToken cancellationToken;
}

final class VerifiedUpdateDownload {
  const VerifiedUpdateDownload({
    required this.file,
    required this.sha256,
    required this.sizeInBytes,
  });

  final File file;
  final String sha256;
  final int sizeInBytes;
}

/// Downloads packages with controlled redirects, fallback, and atomic commit.
abstract interface class UpdateDownloaderContract {
  Future<VerifiedUpdateDownload> downloadVerified(
    UpdateDownloadRequest request, {
    required void Function(UpdateDownloadProgress progress) onProgress,
  });
}

/// Downloads packages with controlled redirects, fallback, and atomic commit.
final class UpdateDownloader implements UpdateDownloaderContract {
  UpdateDownloader({
    required dio.Dio dio,
    required UpdateFileStore fileStore,
    required Object sha256Verifier,
    required DownloadUrlResolver downloadUrlResolver,
    UpdateDiskSpaceProbe diskSpaceProbe = const IoUpdateDiskSpaceProbe(),
    Future<void> Function()? beforeCommitBarrier,
    Future<void> Function()? afterCommitBarrier,
    this.maximumRedirects = 5,
  })  : _dioClient = dio,
        _fileStore = fileStore,
        _downloadUrlResolver = downloadUrlResolver,
        _diskSpaceProbe = diskSpaceProbe,
        _beforeCommitBarrier = beforeCommitBarrier,
        _afterCommitBarrier = afterCommitBarrier;

  final dio.Dio _dioClient;
  final UpdateFileStore _fileStore;
  final DownloadUrlResolver _downloadUrlResolver;
  final UpdateDiskSpaceProbe _diskSpaceProbe;
  final Future<void> Function()? _beforeCommitBarrier;
  final Future<void> Function()? _afterCommitBarrier;
  final int maximumRedirects;

  @override
  Future<VerifiedUpdateDownload> downloadVerified(
    UpdateDownloadRequest request, {
    required void Function(UpdateDownloadProgress progress) onProgress,
  }) async {
    final candidate = request.candidate;
    final expectedDigest = _parseExpectedDigest(candidate.asset.digest);
    final officialRoute = DownloadRoute.official(
      _downloadUrlResolver.validateOfficialUrl(
        candidate.asset.officialDownloadUrl,
      ),
    );
    final initialRoute = _downloadUrlResolver.createRoute(
      officialUrl: officialRoute.officialUrl,
      proxySnapshot: request.proxySnapshot,
    );

    File? partialFile;
    var committed = false;
    try {
      request.cancellationToken.throwIfCancelled();
      if (await _fileStore.hasValidCachedFile(candidate)) {
        final cachedFile = await _fileStore.getFinalFile(candidate);
        return VerifiedUpdateDownload(
          file: cachedFile,
          sha256: expectedDigest,
          sizeInBytes: candidate.asset.sizeInBytes,
        );
      }
      await _fileStore.prepareForDownload(candidate);
      partialFile = await _fileStore.getPartialFile(candidate);
      final requiredSpace =
          calculateRequiredDownloadSpace(candidate.asset.sizeInBytes);
      final availableSpace =
          await _diskSpaceProbe.getAvailableBytes(partialFile.parent.path);
      if (availableSpace < requiredSpace) {
        throw _failure(
          UpdateDownloadFailureType.insufficientDiskSpace,
          'update.download.error.insufficientDiskSpace',
          'Required $requiredSpace bytes but only $availableSpace are available.',
          retryable: true,
        );
      }

      try {
        final result = await _downloadAttempt(
          request: request,
          route: initialRoute,
          partialFile: partialFile,
          expectedDigest: expectedDigest,
          onProgress: onProgress,
        );
        committed = true;
        return result;
      } on UpdateDownloadException catch (error) {
        await _fileStore.deletePartialFile(candidate);
        if (!initialRoute.isProxy || !_allowsOfficialFallback(error.type)) {
          rethrow;
        }
        request.cancellationToken.throwIfCancelled();

        // Proxy fallback always starts a fresh official transfer exactly once.
        try {
          final fallbackResult = await _downloadAttempt(
            request: request,
            route: officialRoute,
            partialFile: partialFile,
            expectedDigest: expectedDigest,
            onProgress: onProgress,
          );
          committed = true;
          return fallbackResult;
        } on Object {
          await _fileStore.deletePartialFile(candidate);
          rethrow;
        }
      }
    } on UpdateOperationCancelledException catch (error) {
      throw _failure(
        UpdateDownloadFailureType.cancelled,
        'update.download.error.cancelled',
        'Download was cancelled before commit.',
        retryable: false,
        cause: error,
      );
    } on DownloadUrlRejectedException catch (error) {
      throw _failure(
        UpdateDownloadFailureType.redirectRejected,
        'update.download.error.redirectRejected',
        error.message,
        retryable: false,
        cause: error,
      );
    } on UpdatePathException catch (error) {
      throw _failure(
        UpdateDownloadFailureType.pathRejected,
        'update.download.error.pathRejected',
        error.message,
        retryable: false,
        cause: error,
      );
    } on FileSystemException catch (error) {
      throw _mapFileSystemFailure(error);
    } on Object catch (error) {
      throw _failure(
        UpdateDownloadFailureType.unknown,
        'update.download.error.unknown',
        error.toString(),
        retryable: true,
        cause: error,
      );
    } finally {
      if (!committed && partialFile != null) {
        await _fileStore.deletePartialFile(candidate);
      }
    }
  }

  /// Compatibility adapter retained while M07 migrates controller state.
  Future<File> download(
    UpdateCandidate candidate, {
    required void Function(int receivedBytes, int totalBytes) onProgress,
    required bool isProxyEnabled,
    required String proxyUrl,
    dio.CancelToken? cancelToken,
  }) async {
    final cancellationSource = CancellationTokenSource();
    unawaited(cancelToken?.whenCancel.then((_) => cancellationSource.cancel()));
    final result = await downloadVerified(
      UpdateDownloadRequest(
        candidate: candidate,
        proxySnapshot: UpdateProxySnapshot(
          isEnabled: isProxyEnabled,
          baseUrl: proxyUrl,
        ),
        cancellationToken: cancellationSource,
      ),
      onProgress: (progress) {
        onProgress(progress.receivedBytes, progress.totalBytes);
      },
    );
    return result.file;
  }

  Future<VerifiedUpdateDownload> _downloadAttempt({
    required UpdateDownloadRequest request,
    required DownloadRoute route,
    required File partialFile,
    required String expectedDigest,
    required void Function(UpdateDownloadProgress progress) onProgress,
  }) async {
    final response = await _openResponse(route, request.cancellationToken);
    final contentLength = _parseContentLength(response.headers);
    if (contentLength != null &&
        contentLength != request.candidate.asset.sizeInBytes) {
      throw _failure(
        UpdateDownloadFailureType.sizeMismatch,
        'update.download.error.sizeMismatch',
        'Content-Length $contentLength differs from Asset size ${request.candidate.asset.sizeInBytes}.',
        retryable: true,
      );
    }

    final digestInput = StreamController<List<int>>(sync: true);
    final digestFuture = sha256.bind(digestInput.stream).single;
    final output = await _fileStore.openPartialWrite(request.candidate);
    var receivedBytes = 0;
    var outputClosed = false;
    try {
      await for (final chunk in response.data!.stream) {
        request.cancellationToken.throwIfCancelled();
        if (receivedBytes + chunk.length >
            request.candidate.asset.sizeInBytes) {
          throw _failure(
            UpdateDownloadFailureType.sizeMismatch,
            'update.download.error.sizeMismatch',
            'Response stream exceeded the expected Asset size.',
            retryable: true,
          );
        }
        output.add(chunk);
        digestInput.add(chunk);
        receivedBytes += chunk.length;
        onProgress(UpdateDownloadProgress(
          receivedBytes: receivedBytes,
          totalBytes: contentLength ?? request.candidate.asset.sizeInBytes,
        ));
      }
      await digestInput.close();
      if (receivedBytes != request.candidate.asset.sizeInBytes) {
        throw _failure(
          UpdateDownloadFailureType.sizeMismatch,
          'update.download.error.sizeMismatch',
          'Received $receivedBytes bytes instead of ${request.candidate.asset.sizeInBytes}.',
          retryable: true,
        );
      }
      final actualDigest = (await digestFuture).toString();
      if (actualDigest != expectedDigest) {
        throw _failure(
          UpdateDownloadFailureType.hashMismatch,
          'update.download.error.hashMismatch',
          'Computed SHA-256 does not match the release digest.',
          retryable: true,
        );
      }

      // Flush and close the partial before crossing the atomic commit barrier.
      await output.flush();
      await output.close();
      outputClosed = true;
      await _beforeCommitBarrier?.call();
      request.cancellationToken.throwIfCancelled();
      final committedFile =
          await _fileStore.commitPartialFile(request.candidate);
      await _afterCommitBarrier?.call();
      return VerifiedUpdateDownload(
        file: committedFile,
        sha256: actualDigest,
        sizeInBytes: receivedBytes,
      );
    } on UpdateOperationCancelledException catch (error) {
      throw _failure(
        UpdateDownloadFailureType.cancelled,
        'update.download.error.cancelled',
        'Download was cancelled before commit.',
        retryable: false,
        cause: error,
      );
    } on FileSystemException catch (error) {
      throw _mapFileSystemFailure(error);
    } finally {
      if (!digestInput.isClosed) {
        await digestInput.close();
      }
      if (!outputClosed) {
        await output.close();
      }
    }
  }

  Future<dio.Response<dio.ResponseBody>> _openResponse(
    DownloadRoute route,
    CancellationToken cancellationToken,
  ) async {
    var currentUrl = route.initialUrl;
    for (var redirectCount = 0;
        redirectCount <= maximumRedirects;
        redirectCount++) {
      cancellationToken.throwIfCancelled();
      final dioCancelToken = dio.CancelToken();
      void cancelRequest() => dioCancelToken.cancel('update cancelled');
      cancellationToken.addCancellationListener(cancelRequest);
      try {
        final response = await _dioClient.get<dio.ResponseBody>(
          currentUrl.toString(),
          cancelToken: dioCancelToken,
          options: dio.Options(
            responseType: dio.ResponseType.stream,
            followRedirects: false,
            validateStatus: (_) => true,
          ),
        );
        final statusCode = response.statusCode ?? 0;
        if (_isRedirect(statusCode)) {
          if (redirectCount == maximumRedirects) {
            throw _failure(
              UpdateDownloadFailureType.redirectRejected,
              'update.download.error.redirectRejected',
              'Redirect limit $maximumRedirects was exceeded.',
              retryable: true,
            );
          }
          final location = response.headers.value(HttpHeaders.locationHeader);
          if (location == null || location.isEmpty) {
            throw _failure(
              UpdateDownloadFailureType.redirectRejected,
              'update.download.error.redirectRejected',
              'Redirect response omitted Location.',
              retryable: true,
            );
          }
          final redirectUrl = currentUrl.resolve(location);
          currentUrl = _downloadUrlResolver.validateRedirect(
            redirectUrl: redirectUrl,
            route: route,
          );
          continue;
        }
        if (statusCode < 200 || statusCode >= 300 || response.data == null) {
          throw _failure(
            UpdateDownloadFailureType.httpStatus,
            'update.download.error.httpStatus',
            'Download returned HTTP $statusCode.',
            retryable: statusCode == 429 || statusCode >= 500,
          );
        }
        return response;
      } on dio.DioException catch (error) {
        throw _mapDioFailure(error);
      } on DownloadUrlRejectedException catch (error) {
        throw _failure(
          UpdateDownloadFailureType.redirectRejected,
          'update.download.error.redirectRejected',
          error.message,
          retryable: true,
          cause: error,
        );
      } finally {
        cancellationToken.removeCancellationListener(cancelRequest);
      }
    }
    throw StateError('Unreachable redirect loop state.');
  }

  String _parseExpectedDigest(String? digest) {
    if (digest == null || digest.trim().isEmpty) {
      throw _failure(
        UpdateDownloadFailureType.digestMissing,
        'update.download.error.digestMissing',
        'Release asset digest is missing.',
        retryable: true,
      );
    }
    final match =
        RegExp(r'^sha256:([a-fA-F0-9]{64})$').firstMatch(digest.trim());
    if (match == null) {
      throw _failure(
        UpdateDownloadFailureType.digestInvalid,
        'update.download.error.digestInvalid',
        'Release asset digest is not a valid SHA-256 value.',
        retryable: true,
      );
    }
    return match.group(1)!.toLowerCase();
  }

  int? _parseContentLength(dio.Headers headers) {
    final value = headers.value(HttpHeaders.contentLengthHeader);
    if (value == null) return null;
    final parsed = int.tryParse(value);
    return parsed != null && parsed >= 0 ? parsed : null;
  }

  bool _isRedirect(int statusCode) =>
      statusCode == 301 ||
      statusCode == 302 ||
      statusCode == 303 ||
      statusCode == 307 ||
      statusCode == 308;

  bool _allowsOfficialFallback(UpdateDownloadFailureType type) {
    return type == UpdateDownloadFailureType.networkUnavailable ||
        type == UpdateDownloadFailureType.requestTimeout ||
        type == UpdateDownloadFailureType.httpStatus ||
        type == UpdateDownloadFailureType.redirectRejected ||
        type == UpdateDownloadFailureType.sizeMismatch ||
        type == UpdateDownloadFailureType.hashMismatch;
  }

  UpdateDownloadException _mapDioFailure(dio.DioException error) {
    if (dio.CancelToken.isCancel(error)) {
      return _failure(
        UpdateDownloadFailureType.cancelled,
        'update.download.error.cancelled',
        'HTTP transfer was cancelled.',
        retryable: false,
        cause: error,
      );
    }
    if (error.type == dio.DioExceptionType.connectionTimeout ||
        error.type == dio.DioExceptionType.receiveTimeout ||
        error.type == dio.DioExceptionType.sendTimeout) {
      return _failure(
        UpdateDownloadFailureType.requestTimeout,
        'update.download.error.requestTimeout',
        error.message ?? 'HTTP transfer timed out.',
        retryable: true,
        cause: error,
      );
    }
    return _failure(
      UpdateDownloadFailureType.networkUnavailable,
      'update.download.error.networkUnavailable',
      error.message ?? 'HTTP transfer failed.',
      retryable: true,
      cause: error,
    );
  }

  UpdateDownloadException _mapFileSystemFailure(FileSystemException error) {
    final errorCode = error.osError?.errorCode;
    final permissionDenied = errorCode == 5 || errorCode == 13;
    final diskFull = errorCode == 28 || errorCode == 112;
    return _failure(
      diskFull
          ? UpdateDownloadFailureType.insufficientDiskSpace
          : permissionDenied
              ? UpdateDownloadFailureType.permissionDenied
              : UpdateDownloadFailureType.unknown,
      diskFull
          ? 'update.download.error.insufficientDiskSpace'
          : permissionDenied
              ? 'update.download.error.permissionDenied'
              : 'update.download.error.unknown',
      error.message,
      retryable: true,
      cause: error,
    );
  }

  UpdateDownloadException _failure(
    UpdateDownloadFailureType type,
    String userMessageKey,
    String technicalDetail, {
    required bool retryable,
    Object? cause,
  }) {
    return UpdateDownloadException(
      type: type,
      userMessageKey: userMessageKey,
      technicalDetail: technicalDetail,
      isRetryable: retryable,
      cause: cause,
    );
  }
}
