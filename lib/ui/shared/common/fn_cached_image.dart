import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/providers.dart';
import 'img_loading_progress_ring.dart';

/// 统一网络图片组件——所有页面通过此组件加载远程图片，共享同一个缓存管理器。
class FnCachedImage extends ConsumerWidget {
  final String posterPath;
  final BoxFit fit;
  final double? placeholderSize;
  final double? width;
  final Widget? errorWidget;
  final Widget? placeholder;
  final Duration fadeOutDuration;

  const FnCachedImage({
    super.key,
    required this.posterPath,
    this.fit = BoxFit.cover,
    this.placeholderSize,
    this.width,
    this.errorWidget,
    this.placeholder,
    this.fadeOutDuration = const Duration(milliseconds: 120),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesManagerProvider);
    final baseUrl = prefs.getBaseUrl();
    final token = prefs.getToken();
    final cookie = prefs.getCookie();
    final cacheManager = ref.watch(imageCacheManagerProvider);

    final resolvedPath = posterPath.trim();
    final imageUrl = baseUrl != null && resolvedPath.isNotEmpty
        ? _buildUrl(baseUrl, resolvedPath)
        : null;

    final httpHeaders = token != null || (cookie != null && cookie.isNotEmpty)
        ? {
            if (token != null) 'Authorization': token,
            if (cookie != null && cookie.isNotEmpty) 'Cookie': cookie,
          }
        : null;

    if (imageUrl == null) {
      return errorWidget ??
          const Center(child: Icon(FluentIcons.file_image));
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      httpHeaders: httpHeaders,
      cacheManager: cacheManager,
      fit: fit,
      fadeOutDuration: fadeOutDuration,
      errorWidget: (context, url, error) =>
          errorWidget ?? const Center(child: Icon(FluentIcons.error)),
      placeholder: (context, url) =>
          placeholder ??
          ImgLoadingProgressRing(
            size: placeholderSize ?? 32.0,
          ),
    );
  }

  String _buildUrl(String baseUrl, String path) {
    final lowerPath = path.toLowerCase();
    final normalizedBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    if (lowerPath.startsWith('http://') || lowerPath.startsWith('https://')) {
      return path;
    }
    final suffix = path.contains('?')
        ? ''
        : (width != null ? '?w=${width!.round()}' : '');
    if (path.startsWith('/v/api/v1/sys/img')) {
      return '$normalizedBaseUrl$path$suffix';
    }
    if (path.startsWith('v/api/v1/sys/img')) {
      return '$normalizedBaseUrl/$path$suffix';
    }
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '$normalizedBaseUrl/v/api/v1/sys/img$normalizedPath$suffix';
  }
}

/// 返回 backdrop 使用的 [CachedNetworkImageProvider]，供 [Image] 组件使用。
CachedNetworkImageProvider fnCachedImageProvider(
  WidgetRef ref,
  String posterPath, {
  double? width,
}) {
  final prefs = ref.read(preferencesManagerProvider);
  final baseUrl = prefs.getBaseUrl();
  final token = prefs.getToken();
  final cookie = prefs.getCookie();
  final cacheManager = ref.read(imageCacheManagerProvider);

  final resolvedPath = posterPath.trim();
  final lowerPath = resolvedPath.toLowerCase();
  final normalizedBaseUrl = baseUrl?.endsWith('/') == true
      ? baseUrl!.substring(0, baseUrl.length - 1)
      : baseUrl;
  final suffix = resolvedPath.contains('?')
      ? ''
      : (width != null ? '?w=${width.round()}' : '');
  String imageUrl;
  if (baseUrl != null && resolvedPath.isNotEmpty) {
    if (lowerPath.startsWith('http://') || lowerPath.startsWith('https://')) {
      imageUrl = resolvedPath;
    } else if (resolvedPath.startsWith('/v/api/v1/sys/img')) {
      imageUrl = '$normalizedBaseUrl$resolvedPath$suffix';
    } else if (resolvedPath.startsWith('v/api/v1/sys/img')) {
      imageUrl = '$normalizedBaseUrl/$resolvedPath$suffix';
    } else {
      final normalizedPath = resolvedPath.startsWith('/')
          ? resolvedPath
          : '/$resolvedPath';
      imageUrl = '$normalizedBaseUrl/v/api/v1/sys/img$normalizedPath$suffix';
    }
  } else {
    imageUrl = resolvedPath;
  }

  final httpHeaders = token != null || (cookie != null && cookie.isNotEmpty)
      ? <String, String>{
          if (token != null) 'Authorization': token,
          if (cookie != null && cookie.isNotEmpty) 'Cookie': cookie,
        }
      : null;

  return CachedNetworkImageProvider(
    imageUrl,
    headers: httpHeaders,
    cacheManager: cacheManager,
  );
}
