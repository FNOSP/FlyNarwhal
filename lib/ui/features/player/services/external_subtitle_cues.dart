/// Timestamped subtitle cues parsed from external WebVTT or SubRip content,
/// used to drive the compositor overlay from the playback position. mdk's
/// own text renderer force-draws a background box on these tracks, so the
/// overlay draws them instead; mdk keeps decoding the file only to keep the
/// external track registered.
class ExternalSubtitleCue {
  const ExternalSubtitleCue({
    required this.startMs,
    required this.endMs,
    required this.lines,
  });

  final int startMs;
  final int endMs;
  final List<String> lines;
}

List<ExternalSubtitleCue>? parseExternalSubtitleCues(
  String content,
  String format,
) {
  final normalized = format.toLowerCase().trim();
  if (normalized == 'vtt' || normalized == 'webvtt') {
    return _parseVtt(content);
  }
  return _parseSrt(content);
}

int _timestampMs(String? hours, String minutes, String seconds, String ms) {
  final h = int.parse(hours ?? '0');
  return ((h * 60 + int.parse(minutes)) * 60 + int.parse(seconds)) * 1000 +
      int.parse(ms);
}

final RegExp _vttTiming = RegExp(
  r'(?:(\d{1,2}):)?(\d{1,2}):(\d{2})[.,](\d{1,3})\s*-->\s*'
  r'(?:(\d{1,2}):)?(\d{1,2}):(\d{2})[.,](\d{1,3})',
);

final RegExp _srtTiming = RegExp(
  r'(\d{1,2}):(\d{2}):(\d{2})[.,](\d{1,3})\s*-->\s*'
  r'(\d{1,2}):(\d{2}):(\d{2})[.,](\d{1,3})',
);

List<ExternalSubtitleCue>? _parseVtt(String vtt) {
  final lines = vtt.split(RegExp(r'\r\n|\r|\n'));
  var i = 0;
  while (i < lines.length && lines[i].trim().isEmpty) {
    i++;
  }
  if (i >= lines.length || !lines[i].trim().startsWith('WEBVTT')) return null;
  i++;
  // Skip the header block (up to the first blank line); it can carry
  // X-TIMESTAMP-MAP and other metadata.
  while (i < lines.length && lines[i].trim().isNotEmpty) {
    i++;
  }

  final cues = <ExternalSubtitleCue>[];
  while (i < lines.length) {
    if (lines[i].trim().isEmpty) {
      i++;
      continue;
    }
    final head = lines[i].trim();
    if (head.startsWith('NOTE') ||
        head.startsWith('STYLE') ||
        head.startsWith('REGION')) {
      i++;
      while (i < lines.length && lines[i].trim().isNotEmpty) {
        i++;
      }
      continue;
    }

    // An optional cue identifier line may precede the timestamp.
    var match = _vttTiming.firstMatch(lines[i]);
    if (match == null) {
      i++;
      if (i < lines.length) match = _vttTiming.firstMatch(lines[i]);
    }
    if (match == null) {
      i++;
      continue;
    }
    i++;

    final textLines = <String>[];
    while (i < lines.length && lines[i].trim().isNotEmpty) {
      final cleaned = _stripMarkup(lines[i]);
      if (cleaned.isNotEmpty) textLines.add(cleaned);
      i++;
    }
    if (textLines.isEmpty) continue;

    cues.add(ExternalSubtitleCue(
      startMs: _timestampMs(
          match.group(1), match.group(2)!, match.group(3)!, match.group(4)!),
      endMs: _timestampMs(
          match.group(5), match.group(6)!, match.group(7)!, match.group(8)!),
      lines: textLines,
    ));
  }

  return cues.isEmpty ? null : cues;
}

List<ExternalSubtitleCue>? _parseSrt(String srt) {
  final lines = srt.split(RegExp(r'\r\n|\r|\n'));
  final cues = <ExternalSubtitleCue>[];
  var i = 0;

  while (i < lines.length) {
    if (lines[i].trim().isEmpty) {
      i++;
      continue;
    }
    // An index line may precede the timestamp.
    var match = _srtTiming.firstMatch(lines[i]);
    if (match == null) {
      i++;
      if (i < lines.length) match = _srtTiming.firstMatch(lines[i]);
    }
    if (match == null) {
      i++;
      continue;
    }
    i++;

    final textLines = <String>[];
    while (i < lines.length && lines[i].trim().isNotEmpty) {
      final cleaned = _stripMarkup(lines[i]);
      if (cleaned.isNotEmpty) textLines.add(cleaned);
      i++;
    }
    if (textLines.isEmpty) continue;

    cues.add(ExternalSubtitleCue(
      startMs: _timestampMs(
          match.group(1), match.group(2)!, match.group(3)!, match.group(4)!),
      endMs: _timestampMs(
          match.group(5), match.group(6)!, match.group(7)!, match.group(8)!),
      lines: textLines,
    ));
  }

  return cues.isEmpty ? null : cues;
}

/// Drops WebVTT/SRT inline tags; the overlay renders plain text.
String _stripMarkup(String line) {
  var s = line;
  s = s.replaceAll(RegExp(r'<\d{1,2}:\d{2}:\d{2}[.,]\d{3}>'), '');
  s = s.replaceAll(RegExp(r'<v[^>]*>|</v>'), '');
  s = s.replaceAll(RegExp(r'<c(\.[^>]*)?>|</c>'), '');
  s = s.replaceAll(RegExp(r'<rt>.*?</rt>'), '');
  s = s.replaceAll(RegExp(r'<ruby>|</ruby>'), '');
  s = s.replaceAll(RegExp(r'<lang[^>]*>|</lang>'), '');
  s = s.replaceAll(RegExp(r'<[^>]+>'), '');
  return s.trim();
}
