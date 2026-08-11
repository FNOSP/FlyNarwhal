import 'package:flutter/widgets.dart';

import '../../../domain/entities/media_type.dart';

/// 无封面时按媒体类型返回占位图资源路径，与 Web 端实现保持一致：
/// Directory/Season 显示文件夹，LiveChannel 显示直播图标，
/// 其余类型（电影/电视/视频/剧集）显示通用的"无封面"胶卷图标。
String mediaPlaceholderAsset(MediaType? type) {
  switch (type) {
    case MediaType.directory:
    case MediaType.season:
      return 'assets/images/directory_no_cover.png';
    case MediaType.liveChannel:
      return 'assets/images/live_channel_no_cover.png';
    case MediaType.movie:
    case MediaType.tv:
    case MediaType.video:
    case MediaType.episode:
    case null:
      return 'assets/images/video_no_cover.png';
  }
}

/// 媒体封面缺省占位图。
///
/// 未指定 [size] 时按容器较短边的 [widthFactor] 等比缩放（对齐 Web 端比例）；
/// 紧凑场景（列表小图、flyout 缩略图）建议显式传入 [size]。
class MediaPosterPlaceholder extends StatelessWidget {
  final MediaType? type;
  final double? size;
  final double widthFactor;

  const MediaPosterPlaceholder({
    super.key,
    this.type,
    this.size,
    this.widthFactor = 0.45,
  });

  @override
  Widget build(BuildContext context) {
    final assetPath = mediaPlaceholderAsset(type);
    final fixedSize = size;
    if (fixedSize != null) {
      return Image.asset(
        assetPath,
        width: fixedSize,
        height: fixedSize,
        fit: BoxFit.contain,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final finiteWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 48.0;
        final finiteHeight =
            constraints.maxHeight.isFinite ? constraints.maxHeight : 48.0;
        final width =
            (finiteWidth < finiteHeight ? finiteWidth : finiteHeight) *
                widthFactor;
        return Image.asset(
          assetPath,
          width: width,
          height: width,
          fit: BoxFit.contain,
        );
      },
    );
  }
}
