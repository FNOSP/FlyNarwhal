import 'dart:ui' show lerpDouble;

import 'package:fluent_ui/fluent_ui.dart';
import '../../../data/models/player_models.dart';

class PlayerSubtitleOverlay extends StatelessWidget {
  final List<String> lines;
  final bool visible;
  final SubtitleSettings settings;

  const PlayerSubtitleOverlay({
    super.key,
    required this.lines,
    required this.visible,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible || lines.isEmpty) {
      return const SizedBox.shrink();
    }

    const minBottomPadding = 40.0;
    const topSafeInset = 40.0;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final joinedLines = lines.join('\n');
    final fontSize = settings.fontSize * settings.fontScale;
    final lineCount =
        joinedLines.split('\n').where((line) => line.isNotEmpty).length;
    final estimatedTextHeight =
        ((lineCount <= 0 ? 1 : lineCount) * fontSize * 1.35) + 16.0;
    final maxBottomPadding = (screenHeight - topSafeInset - estimatedTextHeight)
        .clamp(minBottomPadding, screenHeight - topSafeInset);
    final bottomPadding = lerpDouble(
          minBottomPadding,
          maxBottomPadding,
          settings.verticalPosition.clamp(0.0, 1.0),
        ) ??
        minBottomPadding;

    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding),
          child: Text(
            joinedLines,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fontSize,
              height: 1.35,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              shadows: const [
                Shadow(
                  color: Color(0xCC000000),
                  offset: Offset(0, 1),
                  blurRadius: 1,
                ),
                Shadow(
                  color: Color(0xAA000000),
                  offset: Offset(0, 2),
                  blurRadius: 4,
                ),
                Shadow(
                  color: Color(0x66000000),
                  offset: Offset(0, 4),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
