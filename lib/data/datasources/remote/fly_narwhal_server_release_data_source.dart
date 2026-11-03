import 'package:dio/dio.dart';

import '../../../core/utils/log/app_talker.dart';

/// A single GitHub release asset for the FlyNarwhal server distribution jar.
final class FlyNarwhalServerAsset {
  const FlyNarwhalServerAsset({
    required this.name,
    required this.browserDownloadUrl,
    this.digest,
  });

  final String name;
  final String browserDownloadUrl;
  final String? digest;
}

/// A single GitHub release from the FlyNarwhal server repository.
final class FlyNarwhalServerRelease {
  const FlyNarwhalServerRelease({
    required this.tagName,
    required this.assets,
  });

  final String tagName;
  final List<FlyNarwhalServerAsset> assets;
}

/// Fetches tagged releases from the FlyNarwhal server repository on GitHub.
///
/// This is intentionally separate from [GitHubReleaseDataSource], which is
/// scoped to the desktop client repository, paginates, and applies the client's
/// strict typed validation. The server self-update flow needs a single tagged
/// release from `FNOSP/fly-narwhal-server` with its raw jar assets.
final class FlyNarwhalServerReleaseDataSource {
  FlyNarwhalServerReleaseDataSource({
    required Dio dio,
    required String userAgent,
    String apiBaseUrl = defaultApiBaseUrl,
  })  : _dio = dio,
        _userAgent = userAgent,
        _apiBaseUrl = apiBaseUrl;

  static const String defaultApiBaseUrl = 'https://api.github.com';

  final Dio _dio;
  final String _userAgent;
  final String _apiBaseUrl;

  Uri _endpoint(String path) =>
      Uri.parse('$_apiBaseUrl/repos/FNOSP/fly-narwhal-server/$path');

  Uri endpointForTag(String tagName) => _endpoint('releases/tags/$tagName');

  Uri get latestEndpoint => _endpoint('releases/latest');

  /// The most recent published release, with its `v`-prefixed tag name.
  ///
  /// `/releases/latest` excludes prereleases; a repository with no published
  /// release answers 404, which is reported as `null`.
  Future<FlyNarwhalServerRelease?> fetchLatest() async {
    AppTalker.info('FlyNarwhalServerUpdate', 'Fetching latest server release.');
    try {
      final response = await _dio.get<Object?>(
        latestEndpoint.toString(),
        options: _requestOptions(),
      );
      return _parseRelease(response.data);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        AppTalker.info(
          'FlyNarwhalServerUpdate',
          'No latest server release published.',
        );
        return null;
      }
      AppTalker.error(
        'FlyNarwhalServerUpdate',
        error: error,
        stackTrace: error.stackTrace,
        message: '获取服务端最新 release 失败',
      );
      rethrow;
    }
  }

  /// Returns the release for [tagName], or `null` when that tag has no release
  /// yet (HTTP 404). Other failures are rethrown.
  Future<FlyNarwhalServerRelease?> fetchByTag(String tagName) async {
    AppTalker.info(
      'FlyNarwhalServerUpdate',
      'Fetching server release for tag $tagName.',
    );
    try {
      final response = await _dio.get<Object?>(
        endpointForTag(tagName).toString(),
        options: _requestOptions(),
      );
      return _parseRelease(response.data);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        AppTalker.info(
          'FlyNarwhalServerUpdate',
          'No server release found for tag $tagName.',
        );
        return null;
      }
      AppTalker.error(
        'FlyNarwhalServerUpdate',
        error: error,
        stackTrace: error.stackTrace,
        message: '获取服务端 release 失败: $tagName',
      );
      rethrow;
    }
  }

  Options _requestOptions() => Options(
        responseType: ResponseType.json,
        headers: <String, String>{
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
          'User-Agent': _userAgent,
        },
      );

  FlyNarwhalServerRelease _parseRelease(Object? payload) {    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Server release response is not an object.');
    }
    final tagName = payload['tag_name'] as String? ?? '';
    final rawAssets = payload['assets'];
    final assets = <FlyNarwhalServerAsset>[];
    if (rawAssets is List<dynamic>) {
      for (final rawAsset in rawAssets) {
        if (rawAsset is! Map<String, dynamic>) continue;
        final name = rawAsset['name'] as String? ?? '';
        final downloadUrl =
            rawAsset['browser_download_url'] as String? ?? '';
        if (name.isEmpty || downloadUrl.isEmpty) continue;
        final rawDigest = rawAsset['digest'] as String?;
        assets.add(
          FlyNarwhalServerAsset(
            name: name,
            browserDownloadUrl: downloadUrl,
            digest: (rawDigest == null || rawDigest.isEmpty)
                ? null
                : rawDigest,
          ),
        );
      }
    }
    return FlyNarwhalServerRelease(tagName: tagName, assets: assets);
  }
}
