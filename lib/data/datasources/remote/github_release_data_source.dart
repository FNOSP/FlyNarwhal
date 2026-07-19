import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';

import '../../../domain/update/entities/update_models.dart';
import '../../../domain/update/repositories/cancellation_token.dart';
import '../../../domain/update/repositories/update_repository_error.dart';

/// Stable warning categories emitted while tolerantly mapping GitHub payloads.
enum GitHubReleaseWarningCode {
  invalidRelease,
  invalidAssetsStructure,
  invalidAsset,
}

/// Non-sensitive structured warning from tolerant payload mapping.
final class GitHubReleaseWarning {
  const GitHubReleaseWarning({
    required this.code,
    required this.itemIndex,
    required this.technicalDetails,
  });

  final GitHubReleaseWarningCode code;
  final int itemIndex;
  final String technicalDetails;
}

typedef GitHubReleaseWarningSink = void Function(GitHubReleaseWarning warning);
typedef UpdateRetryDelay = Future<void> Function(Duration duration);
typedef UpdateRetryJitter = Duration Function();

/// Contract separating repository coordination from GitHub HTTP mapping.
abstract interface class GitHubReleaseDataSourceContract {
  Future<List<UpdateRelease>> fetchReleases({
    required int page,
    required int pageSize,
    required CancellationToken cancellationToken,
  });
}

/// Fetches and validates GitHub Release payloads from the official API.
final class GitHubReleaseDataSource implements GitHubReleaseDataSourceContract {
  GitHubReleaseDataSource({
    required Dio dio,
    required String userAgent,
    GitHubReleaseWarningSink? warningSink,
    UpdateRetryDelay? retryDelay,
    UpdateRetryJitter? retryJitter,
    DateTime Function()? currentTime,
  })  : _dio = dio,
        _userAgent = _normalizeUserAgent(userAgent),
        _warningSink = warningSink ?? _ignoreWarning,
        _retryDelay = retryDelay ?? Future<void>.delayed,
        _retryJitter = retryJitter ?? _defaultJitter,
        _currentTime = currentTime ?? DateTime.now;

  static const int maximumRetryCount = 3;
  static const Duration maximumRetryAfter = Duration(seconds: 60);
  static const List<Duration> _retryBackoff = <Duration>[
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];
  static final Uri releasesEndpoint = Uri.https(
    'api.github.com',
    '/repos/FNOSP/FlyNarwhal/releases',
  );

  final Dio _dio;
  final String _userAgent;
  final GitHubReleaseWarningSink _warningSink;
  final UpdateRetryDelay _retryDelay;
  final UpdateRetryJitter _retryJitter;
  final DateTime Function() _currentTime;

  @override
  Future<List<UpdateRelease>> fetchReleases({
    required int page,
    required int pageSize,
    required CancellationToken cancellationToken,
  }) async {
    if (page < 1 || pageSize < 1) {
      throw const UpdateRepositoryException(
        code: UpdateRepositoryErrorCode.domainMapping,
        technicalDetails: 'Page and page size must be positive.',
        retryable: false,
      );
    }

    for (var attempt = 0; attempt <= maximumRetryCount; attempt++) {
      _throwIfCancelled(cancellationToken);
      try {
        final response = await _dio.get<Object?>(
          releasesEndpoint.toString(),
          queryParameters: <String, Object>{
            'per_page': pageSize,
            'page': page,
          },
          options: Options(
            responseType: ResponseType.json,
            headers: <String, String>{
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2022-11-28',
              'User-Agent': _userAgent,
            },
          ),
        );
        return _parseRoot(response.data);
      } on UpdateOperationCancelledException {
        throw _cancelledFailure();
      } on DioException catch (error) {
        final failure = _mapDioException(error);
        if (!failure.retryable || attempt == maximumRetryCount) {
          throw failure;
        }
        final retryAfter = _parseRetryAfter(error.response?.headers);
        await _waitBeforeRetry(
          retryAfter ?? _retryBackoff[attempt] + _retryJitter(),
          cancellationToken,
        );
      } on FormatException catch (error) {
        throw UpdateRepositoryException(
          code: UpdateRepositoryErrorCode.invalidJson,
          technicalDetails: error.message,
          retryable: false,
        );
      }
    }

    throw const UpdateRepositoryException(
      code: UpdateRepositoryErrorCode.network,
      technicalDetails: 'Retry loop exhausted unexpectedly.',
      retryable: true,
    );
  }

  List<UpdateRelease> _parseRoot(Object? payload) {
    if (payload is! List<dynamic>) {
      throw const UpdateRepositoryException(
        code: UpdateRepositoryErrorCode.invalidJson,
        technicalDetails: 'GitHub releases response root is not an array.',
        retryable: false,
      );
    }

    final releases = <UpdateRelease>[];
    for (var releaseIndex = 0; releaseIndex < payload.length; releaseIndex++) {
      final rawRelease = payload[releaseIndex];
      if (rawRelease is! Map<String, dynamic>) {
        _warn(
          GitHubReleaseWarningCode.invalidRelease,
          releaseIndex,
          'Release item is not an object.',
        );
        continue;
      }
      final release = _parseRelease(rawRelease, releaseIndex);
      if (release != null && !release.isDraft) {
        releases.add(release);
      }
    }
    return List<UpdateRelease>.unmodifiable(releases);
  }

  UpdateRelease? _parseRelease(
    Map<String, dynamic> payload,
    int releaseIndex,
  ) {
    final htmlUrl = Uri.tryParse(payload['html_url'] as String? ?? '');
    final rawAssets = payload['assets'];
    final assets = <UpdateReleaseAsset>[];
    if (rawAssets is List<dynamic>) {
      for (var assetIndex = 0; assetIndex < rawAssets.length; assetIndex++) {
        final rawAsset = rawAssets[assetIndex];
        if (rawAsset is! Map<String, dynamic>) {
          _warn(
            GitHubReleaseWarningCode.invalidAsset,
            assetIndex,
            'Asset item in release $releaseIndex is not an object.',
          );
          continue;
        }
        final asset = _parseAsset(rawAsset, assetIndex);
        if (asset != null) assets.add(asset);
      }
    } else if (rawAssets != null) {
      _warn(
        GitHubReleaseWarningCode.invalidAssetsStructure,
        releaseIndex,
        'Release assets field is not an array.',
      );
    }

    if (htmlUrl == null) {
      _warn(
        GitHubReleaseWarningCode.invalidRelease,
        releaseIndex,
        'Release html_url is malformed.',
      );
      return null;
    }
    final validation = UpdateRelease.validate(
      tagName: payload['tag_name'] as String? ?? '',
      displayName: payload['name'] as String? ?? '',
      releaseNotes: payload['body'] as String? ?? '',
      htmlUrl: htmlUrl,
      isPrerelease: payload['prerelease'] as bool? ?? false,
      isDraft: payload['draft'] as bool? ?? false,
      assets: assets,
    );
    if (validation is UpdateModelValidationFailure<UpdateRelease>) {
      _warn(
        GitHubReleaseWarningCode.invalidRelease,
        releaseIndex,
        'Release failed typed URL validation.',
      );
      return null;
    }
    return (validation as UpdateModelValidationSuccess<UpdateRelease>).value;
  }

  UpdateReleaseAsset? _parseAsset(
    Map<String, dynamic> payload,
    int assetIndex,
  ) {
    final downloadUrl =
        Uri.tryParse(payload['browser_download_url'] as String? ?? '');
    final size = payload['size'];
    if (downloadUrl == null ||
        !_isOfficialReleaseAssetUrl(downloadUrl) ||
        size is! int) {
      _warn(
        GitHubReleaseWarningCode.invalidAsset,
        assetIndex,
        'Asset URL or size field is invalid.',
      );
      return null;
    }
    final validation = UpdateReleaseAsset.validate(
      name: payload['name'] as String? ?? '',
      officialDownloadUrl: downloadUrl,
      sizeInBytes: size,
      rawDigest: payload['digest'] as String?,
      contentType: payload['content_type'] as String?,
    );
    if (validation is UpdateModelValidationFailure<UpdateReleaseAsset>) {
      _warn(
        GitHubReleaseWarningCode.invalidAsset,
        assetIndex,
        'Asset failed typed URL or size validation.',
      );
      return null;
    }
    return (validation as UpdateModelValidationSuccess<UpdateReleaseAsset>)
        .value;
  }

  UpdateRepositoryException _mapDioException(DioException error) {
    if (error.type == DioExceptionType.cancel) return _cancelledFailure();
    if (error.type == DioExceptionType.badCertificate) {
      return UpdateRepositoryException(
        code: UpdateRepositoryErrorCode.tls,
        technicalDetails: error.message ?? 'TLS certificate validation failed.',
        retryable: false,
      );
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return UpdateRepositoryException(
        code: UpdateRepositoryErrorCode.timeout,
        technicalDetails: error.message ?? 'GitHub API request timed out.',
        retryable: true,
      );
    }
    final statusCode = error.response?.statusCode;
    if (statusCode != null) {
      return UpdateRepositoryException(
        code: UpdateRepositoryErrorCode.http,
        technicalDetails: 'GitHub API returned HTTP $statusCode.',
        retryable: statusCode == 429 || statusCode >= 500,
        httpStatusCode: statusCode,
      );
    }
    return UpdateRepositoryException(
      code: UpdateRepositoryErrorCode.network,
      technicalDetails: error.message ?? 'GitHub API connection failed.',
      retryable: error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.unknown,
    );
  }

  Duration? _parseRetryAfter(Headers? headers) {
    final rawValue = headers?.value('retry-after')?.trim();
    if (rawValue == null || rawValue.isEmpty) return null;
    final seconds = int.tryParse(rawValue);
    if (seconds != null && seconds >= 0) {
      return _capRetryAfter(Duration(seconds: seconds));
    }
    try {
      final retryAt = HttpDate.parse(rawValue);
      final duration = retryAt.difference(_currentTime().toUtc());
      if (duration.isNegative) return Duration.zero;
      return _capRetryAfter(duration);
    } on FormatException {
      return null;
    }
  }

  Future<void> _waitBeforeRetry(
    Duration duration,
    CancellationToken cancellationToken,
  ) async {
    _throwIfCancelled(cancellationToken);
    await _retryDelay(duration);
    _throwIfCancelled(cancellationToken);
  }

  void _throwIfCancelled(CancellationToken cancellationToken) {
    if (cancellationToken.isCancelled) {
      throw _cancelledFailure();
    }
  }

  void _warn(
    GitHubReleaseWarningCode code,
    int itemIndex,
    String technicalDetails,
  ) {
    _warningSink(
      GitHubReleaseWarning(
        code: code,
        itemIndex: itemIndex,
        technicalDetails: technicalDetails,
      ),
    );
  }

  static Duration _capRetryAfter(Duration duration) {
    return duration > maximumRetryAfter ? maximumRetryAfter : duration;
  }

  static bool _isOfficialReleaseAssetUrl(Uri downloadUrl) {
    return downloadUrl.scheme == 'https' &&
        downloadUrl.host.toLowerCase() == 'github.com' &&
        RegExp(r'^/[^/]+/[^/]+/releases/download/[^/]+/[^/]+$')
            .hasMatch(downloadUrl.path);
  }

  static String _normalizeUserAgent(String value) {
    if (value.startsWith('FlyNarwhal/')) return value;
    return 'FlyNarwhal/$value';
  }

  static Duration _defaultJitter() {
    return Duration(milliseconds: Random.secure().nextInt(501));
  }

  static void _ignoreWarning(GitHubReleaseWarning warning) {}

  static UpdateRepositoryException _cancelledFailure() {
    return const UpdateRepositoryException(
      code: UpdateRepositoryErrorCode.cancelled,
      technicalDetails: 'GitHub API request was cancelled.',
      retryable: false,
    );
  }
}
