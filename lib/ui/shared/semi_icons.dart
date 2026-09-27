import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Icons taken 1:1 from the web client (Semi Design icon set), so the
/// desktop toolbar buttons render pixel-identical to the web UI.
class SemiIcons {
  const SemiIcons._();

  static const String _assetDir = 'assets/icons/semi';

  static SvgPicture chevronDown({double size = 16, Color? color}) =>
      _icon('chevron_down', size, color);

  static SvgPicture caretUp({double size = 12, Color? color}) =>
      _icon('caret_up', size, color);

  static SvgPicture caretDown({double size = 12, Color? color}) =>
      _icon('caret_down', size, color);

  static SvgPicture desktop({double size = 20, Color? color}) =>
      _icon('desktop', size, color);

  static SvgPicture grid({double size = 20, Color? color}) =>
      _icon('grid', size, color);

  static SvgPicture sslCertificate({double size = 20, Color? color}) =>
      _icon('ssl_certificate', size, color);

  static SvgPicture removeFromContinue({double size = 16, Color? color}) =>
      _icon('remove_from_continue', size, color);

  static SvgPicture resumePlay({double size = 16, Color? color}) =>
      _icon('resume_play', size, color);

  static SvgPicture restartPlay({double size = 16, Color? color}) =>
      _icon('restart_play', size, color);

  static SvgPicture deleteVideo({double size = 16, Color? color}) =>
      _icon('delete_video', size, color);

  static SvgPicture _icon(String name, double size, Color? color) {
    return SvgPicture.asset(
      '$_assetDir/$name.svg',
      width: size,
      height: size,
      colorFilter:
          color == null ? null : ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
