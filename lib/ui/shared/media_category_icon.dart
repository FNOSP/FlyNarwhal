import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 媒体库分类（`category`：Movie/TV/Mix/IPTV/Others）对应的图标资源路径，
/// 与 fnOS Web 详情页/侧边栏的 category → 图标映射一致；未知或缺省值
/// 回退到「其他」图标（Web 侧 vD 的 default/Others 分支）。
String mediaCategoryIconAsset(String? category) {
  switch (category) {
    case 'Movie':
      return 'assets/images/movie.svg';
    case 'TV':
      return 'assets/images/tv.svg';
    case 'Mix':
      return 'assets/images/mix_media.svg';
    case 'IPTV':
      return 'assets/images/live_tv.svg';
    case 'Others':
    default:
      return 'assets/images/other_media.svg';
  }
}

/// 按媒体库分类渲染图标；[color] 为空时保留 SVG 自带颜色（通常为
/// currentColor 由主题继承）。
Widget buildMediaCategoryIcon({
  required String? category,
  double size = 16,
  Color? color,
}) {
  return SvgPicture.asset(
    mediaCategoryIconAsset(category),
    width: size,
    height: size,
    colorFilter:
        color == null ? null : ColorFilter.mode(color, BlendMode.srcIn),
  );
}
