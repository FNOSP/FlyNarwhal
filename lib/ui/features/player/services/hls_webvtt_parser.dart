import '../models/hls_subtitle_cue.dart';

class HlsWebVttParseResult {
  final int timestampMapLocalMs;
  final List<HlsSubtitleCue> cues;

  const HlsWebVttParseResult({
    required this.timestampMapLocalMs,
    required this.cues,
  });
}

/// Parses WebVTT content used by HLS subtitle segments.
class HlsWebVttParser {
  const HlsWebVttParser();

  HlsWebVttParseResult parse(String content) {
    final lines = content.split(RegExp(r'\r?\n'));
    final cues = <HlsSubtitleCue>[];
    var index = 0;
    var timestampMapLocalMs = 0;

    while (index < lines.length) {
      final line = lines[index].trim();
      if (line.startsWith('X-TIMESTAMP-MAP=')) {
        timestampMapLocalMs = _parseTimestampMapLocalMs(line) ?? 0;
        index++;
        continue;
      }
      if (line.isEmpty ||
          line == 'WEBVTT' ||
          line.startsWith('NOTE') ||
          line.startsWith('STYLE') ||
          line.startsWith('REGION')) {
        index++;
        continue;
      }
      if (!line.contains('-->')) {
        index++;
        continue;
      }

      final times = line.split('-->');
      if (times.length != 2) {
        index++;
        continue;
      }

      final startTimeMs = _parseTimestamp(times[0].trim());
      final endTimeMs = _parseTimestamp(
        times[1].trim().split(RegExp(r'\s+')).first,
      );
      if (startTimeMs == null ||
          endTimeMs == null ||
          endTimeMs <= startTimeMs) {
        index++;
        continue;
      }

      final textLines = <String>[];
      index++;
      while (index < lines.length) {
        final textLine = lines[index].trimRight();
        if (textLine.trim().isEmpty) {
          break;
        }
        textLines.add(_stripCueTags(textLine));
        index++;
      }

      final text =
          textLines.where((line) => line.trim().isNotEmpty).join('\n').trim();
      if (text.isNotEmpty) {
        cues.add(HlsSubtitleCue(
          startTimeMs: startTimeMs,
          endTimeMs: endTimeMs,
          text: text,
        ));
      }
      index++;
    }

    return HlsWebVttParseResult(
      timestampMapLocalMs: timestampMapLocalMs,
      cues: cues,
    );
  }

  int? _parseTimestampMapLocalMs(String line) {
    final localMatch = RegExp(r'LOCAL:([^,\s]+)').firstMatch(line);
    final local = localMatch?.group(1);
    if (local == null || local.isEmpty) {
      return null;
    }
    return _parseTimestamp(local);
  }

  int? _parseTimestamp(String input) {
    final value = input.replaceAll(',', '.').trim();
    final parts = value.split(':');
    if (parts.length != 2 && parts.length != 3) {
      return null;
    }

    var hours = 0;
    var minutes = 0;
    double seconds = 0;

    if (parts.length == 3) {
      hours = int.tryParse(parts[0]) ?? 0;
      minutes = int.tryParse(parts[1]) ?? 0;
      seconds = double.tryParse(parts[2]) ?? 0;
    } else {
      minutes = int.tryParse(parts[0]) ?? 0;
      seconds = double.tryParse(parts[1]) ?? 0;
    }

    return ((hours * 3600 + minutes * 60) * 1000 + seconds * 1000).round();
  }

  String _stripCueTags(String line) {
    return line.replaceAll(RegExp(r'<[^>]+>'), '').trim();
  }
}
