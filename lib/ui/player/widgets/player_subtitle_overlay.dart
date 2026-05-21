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

    final screenHeight = MediaQuery.sizeOf(context).height;
    final bottomPadding =
        (screenHeight * settings.verticalPosition).clamp(40.0, screenHeight * 0.5);
    final fontSize = settings.fontSize * settings.fontScale;

    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding),
          child: Text(
            lines.join('\n'),
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
