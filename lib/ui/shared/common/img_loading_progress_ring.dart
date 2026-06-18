import 'package:fluent_ui/fluent_ui.dart';

/// Centered small circular progress ring for image loading placeholders.
class ImgLoadingProgressRing extends StatelessWidget {
  final double size;

  const ImgLoadingProgressRing({
    super.key,
    this.size = 32.0,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: const ProgressRing(
          activeColor: Color(0x8BFFFFFF),
        ),
      ),
    );
  }
}
