import 'dart:io' show Platform;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:window_manager/window_manager.dart' hide WindowCaption, DragToMoveArea;

const double kWindowTitleBarHeight = 48.0;

class WindowCaption extends StatefulWidget {
  final Widget? title;
  final Color? backgroundColor;
  final Brightness? brightness;

  const WindowCaption({
    super.key,
    this.title,
    this.backgroundColor,
    this.brightness,
  });

  @override
  State<WindowCaption> createState() => _WindowCaptionState();
}

class _WindowCaptionState extends State<WindowCaption> with WindowListener {
  @override
  void initState() {
    windowManager.addListener(this);
    super.initState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.brightness == Brightness.dark;
    final backgroundColor = widget.backgroundColor ??
        (isDark ? const Color(0xff1C1C1C) : Colors.transparent);

    return Container(
      height: kWindowTitleBarHeight,
      color: backgroundColor,
      child: Row(
        children: [
          Expanded(
            child: DragToMoveArea(
              child: Container(
                height: double.infinity,
                padding: const EdgeInsets.only(left: 16),
                alignment: Alignment.centerLeft,
                child: DefaultTextStyle(
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black.withValues(alpha: 0.8956),
                    fontSize: 14,
                  ),
                  child: widget.title ?? const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          if (_shouldShowWindowButtons()) ...[
            WindowCaptionButton.minimize(
              brightness: widget.brightness,
              onPressed: () async {
                final isMinimized = await windowManager.isMinimized();
                if (isMinimized) {
                  windowManager.restore();
                } else {
                  windowManager.minimize();
                }
              },
            ),
            FutureBuilder<bool>(
              future: windowManager.isMaximized(),
              builder: (context, snapshot) {
                if (snapshot.data == true) {
                  return WindowCaptionButton.unmaximize(
                    brightness: widget.brightness,
                    onPressed: () => windowManager.unmaximize(),
                  );
                }
                return WindowCaptionButton.maximize(
                  brightness: widget.brightness,
                  onPressed: () => windowManager.maximize(),
                );
              },
            ),
            WindowCaptionButton.close(
              brightness: widget.brightness,
              onPressed: () => windowManager.close(),
            ),
          ],
        ],
      ),
    );
  }

  bool _shouldShowWindowButtons() {
    if (kIsWeb) return false;
    if (!Platform.isWindows && !Platform.isLinux) return false;
    return true;
  }

  @override
  void onWindowMaximize() => setState(() {});

  @override
  void onWindowUnmaximize() => setState(() {});
}

class DragToMoveArea extends StatelessWidget {
  final Widget child;

  const DragToMoveArea({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) {
        if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
          windowManager.startDragging();
        }
      },
      onDoubleTap: () async {
        if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
          final isMaximized = await windowManager.isMaximized();
          if (isMaximized) {
            windowManager.unmaximize();
          } else {
            windowManager.maximize();
          }
        }
      },
      child: child,
    );
  }
}

class WindowCaptionButton extends StatefulWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final Brightness? brightness;

  const WindowCaptionButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.brightness,
  });

  factory WindowCaptionButton.minimize({
    Key? key,
    VoidCallback? onPressed,
    Brightness? brightness,
  }) {
    return WindowCaptionButton(
      key: key,
      onPressed: onPressed,
      brightness: brightness,
      icon: _MinimizeIcon(brightness: brightness),
    );
  }

  factory WindowCaptionButton.maximize({
    Key? key,
    VoidCallback? onPressed,
    Brightness? brightness,
  }) {
    return WindowCaptionButton(
      key: key,
      onPressed: onPressed,
      brightness: brightness,
      icon: _MaximizeIcon(brightness: brightness),
    );
  }

  factory WindowCaptionButton.unmaximize({
    Key? key,
    VoidCallback? onPressed,
    Brightness? brightness,
  }) {
    return WindowCaptionButton(
      key: key,
      onPressed: onPressed,
      brightness: brightness,
      icon: _UnmaximizeIcon(brightness: brightness),
    );
  }

  factory WindowCaptionButton.close({
    Key? key,
    VoidCallback? onPressed,
    Brightness? brightness,
  }) {
    return WindowCaptionButton(
      key: key,
      onPressed: onPressed,
      brightness: brightness,
      icon: _CloseIcon(brightness: brightness),
    );
  }

  @override
  State<WindowCaptionButton> createState() => _WindowCaptionButtonState();
}

class _WindowCaptionButtonState extends State<WindowCaptionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.brightness == Brightness.dark;
    final isClose = widget.icon is _CloseIcon;

    Color backgroundColor;
    if (_isHovered) {
      if (isClose) {
        backgroundColor = const Color(0xFFE81123);
      } else {
        backgroundColor = isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.05);
      }
    } else {
      backgroundColor = Colors.transparent;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: kWindowTitleBarHeight,
          color: backgroundColor,
          child: widget.icon,
        ),
      ),
    );
  }
}

class _MinimizeIcon extends StatelessWidget {
  final Brightness? brightness;
  const _MinimizeIcon({this.brightness});

  @override
  Widget build(BuildContext context) {
    final color = brightness == Brightness.dark ? Colors.white : Colors.black;
    return CustomPaint(
      size: const Size(16, 16),
      painter: _MinimizeIconPainter(color),
    );
  }
}

class _MaximizeIcon extends StatelessWidget {
  final Brightness? brightness;
  const _MaximizeIcon({this.brightness});

  @override
  Widget build(BuildContext context) {
    final color = brightness == Brightness.dark ? Colors.white : Colors.black;
    return CustomPaint(
      size: const Size(16, 16),
      painter: _MaximizeIconPainter(color),
    );
  }
}

class _UnmaximizeIcon extends StatelessWidget {
  final Brightness? brightness;
  const _UnmaximizeIcon({this.brightness});

  @override
  Widget build(BuildContext context) {
    final color = brightness == Brightness.dark ? Colors.white : Colors.black;
    return CustomPaint(
      size: const Size(16, 16),
      painter: _UnmaximizeIconPainter(color),
    );
  }
}

class _CloseIcon extends StatelessWidget {
  final Brightness? brightness;
  const _CloseIcon({this.brightness});

  @override
  Widget build(BuildContext context) {
    final isDark = brightness == Brightness.dark;
    final color = isDark ? Colors.white : Colors.black;
    return Icon(
      FluentIcons.chrome_close,
      size: 12,
      color: color,
    );
  }
}

class _MinimizeIconPainter extends CustomPainter {
  final Color color;
  _MinimizeIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(3.49805, 8)
      ..cubicTo(3.42969, 8, 3.36458, 7.98698, 3.30273, 7.96094)
      ..cubicTo(3.24414, 7.9349, 3.19206, 7.89909, 3.14648, 7.85352)
      ..cubicTo(3.10091, 7.80794, 3.0651, 7.75586, 3.03906, 7.69727)
      ..cubicTo(3.01302, 7.63542, 3, 7.57031, 3, 7.50195)
      ..cubicTo(3, 7.43359, 3.01302, 7.37012, 3.03906, 7.31152)
      ..cubicTo(3.0651, 7.24967, 3.10091, 7.19596, 3.14648, 7.15039)
      ..cubicTo(3.19206, 7.10156, 3.24414, 7.06413, 3.30273, 7.03809)
      ..cubicTo(3.36458, 7.01204, 3.42969, 6.99902, 3.49805, 6.99902)
      ..lineTo(12.502, 6.99902)
      ..cubicTo(12.5703, 6.99902, 12.6338, 7.01204, 12.6924, 7.03809)
      ..cubicTo(12.7542, 7.06413, 12.8079, 7.10156, 12.8535, 7.15039)
      ..cubicTo(12.8991, 7.19596, 12.9349, 7.24967, 12.9609, 7.31152)
      ..cubicTo(12.987, 7.37012, 13, 7.43359, 13, 7.50195)
      ..cubicTo(13, 7.57031, 12.987, 7.63542, 12.9609, 7.69727)
      ..cubicTo(12.9349, 7.75586, 12.8991, 7.80794, 12.8535, 7.85352)
      ..cubicTo(12.8079, 7.89909, 12.7542, 7.9349, 12.6924, 7.96094)
      ..cubicTo(12.6338, 7.98698, 12.5703, 8, 12.502, 8)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MaximizeIconPainter extends CustomPainter {
  final Color color;
  _MaximizeIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(4.47461, 13)
      ..cubicTo(4.2793, 13, 4.09212, 12.9609, 3.91309, 12.8828)
      ..cubicTo(3.73405, 12.8014, 3.57617, 12.694, 3.43945, 12.5605)
      ..cubicTo(3.30599, 12.4238, 3.19857, 12.266, 3.11719, 12.0869)
      ..cubicTo(3.03906, 11.9079, 3, 11.7207, 3, 11.5254)
      ..lineTo(3, 4.47461)
      ..cubicTo(3, 4.2793, 3.03906, 4.09212, 3.11719, 3.91309)
      ..cubicTo(3.19857, 3.73405, 3.30599, 3.5778, 3.43945, 3.44434)
      ..cubicTo(3.57617, 3.30762, 3.73405, 3.2002, 3.91309, 3.12207)
      ..cubicTo(4.09212, 3.04069, 4.2793, 3, 4.47461, 3)
      ..lineTo(11.5254, 3)
      ..cubicTo(11.7207, 3, 11.9079, 3.04069, 12.0869, 3.12207)
      ..cubicTo(12.266, 3.2002, 12.4222, 3.30762, 12.5557, 3.44434)
      ..cubicTo(12.6924, 3.5778, 12.7998, 3.73405, 12.8779, 3.91309)
      ..cubicTo(12.9593, 4.09212, 13, 4.2793, 13, 4.47461)
      ..lineTo(13, 11.5254)
      ..cubicTo(13, 11.7207, 12.9593, 11.9079, 12.8779, 12.0869)
      ..cubicTo(12.7998, 12.266, 12.6924, 12.4238, 12.5557, 12.5605)
      ..cubicTo(12.4222, 12.694, 12.266, 12.8014, 12.0869, 12.8828)
      ..cubicTo(11.9079, 12.9609, 11.7207, 13, 11.5254, 13)
      ..lineTo(4.47461, 13)
      ..moveTo(11.501, 11.999)
      ..cubicTo(11.5693, 11.999, 11.6328, 11.986, 11.6914, 11.96)
      ..cubicTo(11.7533, 11.9339, 11.807, 11.8981, 11.8525, 11.8525)
      ..cubicTo(11.8981, 11.807, 11.9339, 11.7549, 11.96, 11.6963)
      ..cubicTo(11.986, 11.6344, 11.999, 11.5693, 11.999, 11.501)
      ..lineTo(11.999, 4.49902)
      ..cubicTo(11.999, 4.43066, 11.986, 4.36719, 11.96, 4.30859)
      ..cubicTo(11.9339, 4.24674, 11.8981, 4.19303, 11.8525, 4.14746)
      ..cubicTo(11.807, 4.10189, 11.7533, 4.06608, 11.6914, 4.04004)
      ..cubicTo(11.6328, 4.014, 11.5693, 4.00098, 11.501, 4.00098)
      ..lineTo(4.49902, 4.00098)
      ..cubicTo(4.43066, 4.00098, 4.36556, 4.014, 4.30371, 4.04004)
      ..cubicTo(4.24512, 4.06608, 4.19303, 4.10189, 4.14746, 4.14746)
      ..cubicTo(4.10189, 4.19303, 4.06608, 4.24674, 4.04004, 4.30859)
      ..cubicTo(4.014, 4.36719, 4.00098, 4.43066, 4.00098, 4.49902)
      ..lineTo(4.00098, 11.501)
      ..cubicTo(4.00098, 11.5693, 4.014, 11.6344, 4.04004, 11.6963)
      ..cubicTo(4.06608, 11.7549, 4.10189, 11.807, 4.14746, 11.8525)
      ..cubicTo(4.19303, 11.8981, 4.24512, 11.9339, 4.30371, 11.96)
      ..cubicTo(4.36556, 11.986, 4.43066, 11.999, 4.49902, 11.999)
      ..lineTo(11.501, 11.999)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _UnmaximizeIconPainter extends CustomPainter {
  final Color color;
  _UnmaximizeIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(11.999, 5.96387)
      ..cubicTo(11.999, 5.69368, 11.9453, 5.43978, 11.8379, 5.20215)
      ..cubicTo(11.7305, 4.96126, 11.584, 4.75293, 11.3984, 4.57715)
      ..cubicTo(11.2161, 4.39811, 11.0029, 4.25814, 10.7588, 4.15723)
      ..cubicTo(10.5179, 4.05306, 10.264, 4.00098, 9.99707, 4.00098)
      ..lineTo(5.08496, 4.00098)
      ..cubicTo(5.13704, 3.85124, 5.21029, 3.71452, 5.30469, 3.59082)
      ..cubicTo(5.39909, 3.46712, 5.50814, 3.36133, 5.63184, 3.27344)
      ..cubicTo(5.75553, 3.18555, 5.89062, 3.11882, 6.03711, 3.07324)
      ..cubicTo(6.18685, 3.02441, 6.34147, 3, 6.50098, 3)
      ..lineTo(9.99707, 3)
      ..cubicTo(10.4105, 3, 10.7995, 3.07975, 11.1641, 3.23926)
      ..cubicTo(11.5286, 3.39551, 11.846, 3.60872, 12.1162, 3.87891)
      ..cubicTo(12.3896, 4.14909, 12.6045, 4.46647, 12.7607, 4.83105)
      ..cubicTo(12.9202, 5.19564, 13, 5.58464, 13, 5.99805)
      ..lineTo(13, 9.49902)
      ..cubicTo(13, 9.65853, 12.9756, 9.81315, 12.9268, 9.96289)
      ..cubicTo(12.8812, 10.1094, 12.8145, 10.2445, 12.7266, 10.3682)
      ..cubicTo(12.6387, 10.4919, 12.5329, 10.6009, 12.4092, 10.6953)
      ..cubicTo(12.2855, 10.7897, 12.1488, 10.863, 11.999, 10.915)
      ..lineTo(11.999, 5.96387)
      ..moveTo(4.47461, 13)
      ..cubicTo(4.2793, 13, 4.09212, 12.9609, 3.91309, 12.8828)
      ..cubicTo(3.73405, 12.8014, 3.57617, 12.694, 3.43945, 12.5605)
      ..cubicTo(3.30599, 12.4238, 3.19857, 12.266, 3.11719, 12.0869)
      ..cubicTo(3.03906, 11.9079, 3, 11.7207, 3, 11.5254)
      ..lineTo(3, 6.47656)
      ..cubicTo(3, 6.27799, 3.03906, 6.09082, 3.11719, 5.91504)
      ..cubicTo(3.19857, 5.736, 3.30599, 5.57975, 3.43945, 5.44629)
      ..cubicTo(3.57617, 5.30957, 3.73242, 5.20215, 3.9082, 5.12402)
      ..cubicTo(4.08724, 5.04264, 4.27604, 5.00195, 4.47461, 5.00195)
      ..lineTo(9.52344, 5.00195)
      ..cubicTo(9.72201, 5.00195, 9.91081, 5.04264, 10.0898, 5.12402)
      ..cubicTo(10.2689, 5.20215, 10.4251, 5.30794, 10.5586, 5.44141)
      ..cubicTo(10.6921, 5.57487, 10.7979, 5.73112, 10.876, 5.91016)
      ..cubicTo(10.9574, 6.08919, 10.998, 6.27799, 10.998, 6.47656)
      ..lineTo(10.998, 11.5254)
      ..cubicTo(10.998, 11.724, 10.9574, 11.9128, 10.876, 12.0918)
      ..cubicTo(10.7979, 12.2676, 10.6904, 12.4238, 10.5537, 12.5605)
      ..cubicTo(10.4202, 12.694, 10.264, 12.8014, 10.085, 12.8828)
      ..cubicTo(9.90918, 12.9609, 9.72201, 13, 9.52344, 13)
      ..lineTo(4.47461, 13)
      ..moveTo(9.49902, 11.999)
      ..cubicTo(9.56738, 11.999, 9.63086, 11.986, 9.68945, 11.96)
      ..cubicTo(9.7513, 11.9339, 9.80501, 11.8981, 9.85059, 11.8525)
      ..cubicTo(9.89941, 11.807, 9.93685, 11.7549, 9.96289, 11.6963)
      ..cubicTo(9.98893, 11.6344, 10.002, 11.5693, 10.002, 11.501)
      ..lineTo(10.002, 6.50098)
      ..cubicTo(10.002, 6.43262, 9.98893, 6.36751, 9.96289, 6.30566)
      ..cubicTo(9.93685, 6.24382, 9.90104, 6.1901, 9.85547, 6.14453)
      ..cubicTo(9.8099, 6.09896, 9.75618, 6.06315, 9.69434, 6.03711)
      ..cubicTo(9.63249, 6.01107, 9.56738, 5.99805, 9.49902, 5.99805)
      ..lineTo(4.49902, 5.99805)
      ..cubicTo(4.43066, 5.99805, 4.36556, 6.01107, 4.30371, 6.03711)
      ..cubicTo(4.24512, 6.06315, 4.19303, 6.10059, 4.14746, 6.14941)
      ..cubicTo(4.10189, 6.19499, 4.06608, 6.2487, 4.04004, 6.31055)
      ..cubicTo(4.014, 6.36914, 4.00098, 6.43262, 4.00098, 6.50098)
      ..lineTo(4.00098, 11.501)
      ..cubicTo(4.00098, 11.5693, 4.014, 11.6344, 4.04004, 11.6963)
      ..cubicTo(4.06608, 11.7549, 4.10189, 11.807, 4.14746, 11.8525)
      ..cubicTo(4.19303, 11.8981, 4.24512, 11.9339, 4.30371, 11.96)
      ..cubicTo(4.36556, 11.986, 4.43066, 11.999, 4.49902, 11.999)
      ..lineTo(9.49902, 11.999)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
