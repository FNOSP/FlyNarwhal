import 'package:fluent_ui/fluent_ui.dart';

class PlayerSubtitleOverlay extends StatelessWidget {
  final List<String> lines;
  final bool visible;

  const PlayerSubtitleOverlay({
    super.key,
    required this.lines,
    required this.visible,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible || lines.isEmpty) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 84),
          child: Text(
            lines.join('\n'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              height: 1.35,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              shadows: [
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
