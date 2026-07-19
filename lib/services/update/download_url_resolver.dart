import '../../data/storage/update_settings_store.dart';

/// Immutable proxy configuration captured when a download starts.
final class UpdateProxySnapshot {
  const UpdateProxySnapshot({
    required this.isEnabled,
    required this.baseUrl,
  });

  final bool isEnabled;
  final String baseUrl;
}

/// Identifies the redirect policy used by one download attempt.
final class DownloadRoute {
  const DownloadRoute._({
    required this.initialUrl,
    required this.officialUrl,
    required this.isProxy,
    required this.allowedProxyHost,
  });

  factory DownloadRoute.official(Uri officialUrl) {
    return DownloadRoute._(
      initialUrl: officialUrl,
      officialUrl: officialUrl,
      isProxy: false,
      allowedProxyHost: null,
    );
  }

  factory DownloadRoute.proxy({
    required Uri initialUrl,
    required Uri officialUrl,
  }) {
    return DownloadRoute._(
      initialUrl: initialUrl,
      officialUrl: officialUrl,
      isProxy: true,
      allowedProxyHost: initialUrl.host.toLowerCase(),
    );
  }

  final Uri initialUrl;
  final Uri officialUrl;
  final bool isProxy;
  final String? allowedProxyHost;

  int? get allowedProxyPort => isProxy ? initialUrl.port : null;
}

final class DownloadUrlRejectedException implements FormatException {
  const DownloadUrlRejectedException(this.message, [this.source]);

  @override
  final String message;

  @override
  final dynamic source;

  @override
  int? get offset => null;

  @override
  String toString() => message;
}

/// Resolves download URLs and enforces initial and redirect trust boundaries.
final class DownloadUrlResolver {
  const DownloadUrlResolver();

  static const Set<String> officialRedirectHosts = <String>{
    'github.com',
    'objects.githubusercontent.com',
    'github-releases.githubusercontent.com',
    'release-assets.githubusercontent.com',
  };

  Uri validateOfficialUrl(Uri officialUrl) {
    final pathSegments = officialUrl.pathSegments;
    final hasExpectedPath = pathSegments.length >= 6 &&
        pathSegments[0] == 'FNOSP' &&
        pathSegments[1] == 'FlyNarwhal' &&
        pathSegments[2] == 'releases' &&
        pathSegments[3] == 'download' &&
        pathSegments[4].isNotEmpty &&
        pathSegments.sublist(5).every((segment) => segment.isNotEmpty);
    if (officialUrl.scheme != 'https' ||
        officialUrl.host.toLowerCase() != 'github.com' ||
        officialUrl.hasPort ||
        officialUrl.userInfo.isNotEmpty ||
        officialUrl.hasQuery ||
        officialUrl.hasFragment ||
        !hasExpectedPath) {
      throw DownloadUrlRejectedException(
        'Official update URL is outside the trusted GitHub release path.',
        officialUrl,
      );
    }
    return officialUrl;
  }

  DownloadRoute createRoute({
    required Uri officialUrl,
    required UpdateProxySnapshot proxySnapshot,
  }) {
    final trustedOfficialUrl = validateOfficialUrl(officialUrl);
    if (!proxySnapshot.isEnabled) {
      return DownloadRoute.official(trustedOfficialUrl);
    }
    final proxyUrl = _resolveProxyUrl(
      officialUrl: trustedOfficialUrl,
      proxyUrl: proxySnapshot.baseUrl,
    );
    return DownloadRoute.proxy(
      initialUrl: proxyUrl,
      officialUrl: trustedOfficialUrl,
    );
  }

  Uri resolve({
    required Uri originalUrl,
    required bool isProxyEnabled,
    required String proxyUrl,
  }) {
    return createRoute(
      officialUrl: originalUrl,
      proxySnapshot: UpdateProxySnapshot(
        isEnabled: isProxyEnabled,
        baseUrl: proxyUrl,
      ),
    ).initialUrl;
  }

  Uri validateRedirect({
    required Uri redirectUrl,
    required DownloadRoute route,
  }) {
    if (redirectUrl.scheme != 'https' ||
        redirectUrl.host.isEmpty ||
        redirectUrl.userInfo.isNotEmpty ||
        redirectUrl.hasFragment) {
      throw DownloadUrlRejectedException(
        'Download redirect must remain on HTTPS.',
        redirectUrl,
      );
    }
    final redirectHost = redirectUrl.host.toLowerCase();
    final hostAllowed = route.isProxy
        ? redirectHost == route.allowedProxyHost &&
            redirectUrl.port == route.allowedProxyPort
        : officialRedirectHosts.contains(redirectHost);
    if (!hostAllowed) {
      throw DownloadUrlRejectedException(
        'Download redirect host is outside the allowed route.',
        redirectUrl,
      );
    }
    return redirectUrl;
  }

  Uri _resolveProxyUrl({
    required Uri officialUrl,
    required String proxyUrl,
  }) {
    final normalizedProxyUrl = UpdateSettingsStore.normalizeProxyUrl(proxyUrl);
    if (normalizedProxyUrl == null) {
      throw const DownloadUrlRejectedException(
        'Proxy base must be a validated HTTPS URL.',
      );
    }
    return Uri.parse('$normalizedProxyUrl$officialUrl');
  }
}
