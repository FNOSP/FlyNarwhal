import 'package:fluent_ui/fluent_ui.dart';

List<String> normalizePosterResolutions(List<String>? input) {
  if (input == null || input.isEmpty) {
    return [];
  }
  final seen = <String>{};
  final result = <String>[];
  for (final resolution in input) {
    if (resolution == 'Others') {
      continue;
    }
    if (seen.add(resolution)) {
      result.add(resolution);
    }
  }
  return result;
}

class PosterResolutionTags extends StatelessWidget {
  final List<String>? resolutions;
  final double scaleFactor;
  final double spacing;

  const PosterResolutionTags({
    super.key,
    required this.resolutions,
    this.scaleFactor = 1,
    this.spacing = 4,
  });

  @override
  Widget build(BuildContext context) {
    final displayResolutions = normalizePosterResolutions(resolutions);
    if (displayResolutions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: displayResolutions.map((resolution) {
        final lowerResolution = resolution.toLowerCase();
        final isK = lowerResolution.endsWith('k');
        final isP = lowerResolution.endsWith('p');
        final label = isK
            ? resolution.toUpperCase()
            : (isP
                ? resolution.substring(0, resolution.length - 1)
                : resolution);

        return Padding(
          padding: EdgeInsets.only(left: spacing * scaleFactor),
          child: Container(
            padding: EdgeInsets.fromLTRB(
              (isK ? 6 : 2) * scaleFactor,
              0.2 * scaleFactor,
              (isK ? 6 : 2) * scaleFactor,
              0.2 * scaleFactor,
            ),
            decoration: BoxDecoration(
              color: isK
                  ? Colors.white.withValues(alpha: 0.8)
                  : Colors.transparent,
              border: isK
                  ? null
                  : Border.all(
                      color: Colors.white.withValues(alpha: 0.6),
                      width: 2 * scaleFactor,
                    ),
              borderRadius: BorderRadius.circular(4 * scaleFactor),
            ),
            child: Transform.translate(
              offset: Offset(0, -0.6 * scaleFactor),
              child: Text(
                label,
                style: TextStyle(
                  color: isK
                      ? Colors.black.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.6),
                  fontSize: (isK ? 12 : 10) * scaleFactor,
                  fontWeight: isK ? FontWeight.w800 : FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
