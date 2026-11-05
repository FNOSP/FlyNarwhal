import 'dart:typed_data';

/// Duration of one full play of an animated GIF: the sum of its frame delays.
///
/// The NETSCAPE loop count is deliberately ignored — the celebration plays
/// each sticker exactly once and removes it when a single pass has elapsed,
/// even though the source GIFs loop forever. Returns [Duration.zero] when the
/// bytes are not a parseable animated GIF so callers can fall back.
Duration gifSinglePlayDuration(Uint8List bytes) {
  if (bytes.length < 13 || bytes[0] != 0x47 || bytes[1] != 0x49 || bytes[2] != 0x46) {
    return Duration.zero; // not "GIF"
  }
  final flags = bytes[10];
  var i = 13;
  if (flags & 0x80 != 0) {
    i += 3 * (2 << (flags & 0x07)); // global colour table
  }
  var frames = 0;
  var centiseconds = 0;
  while (i < bytes.length) {
    final block = bytes[i];
    if (block == 0x3B) break; // trailer
    if (block == 0x21) {
      // Extension introducer.
      final label = bytes[i + 1];
      var j = i + 2;
      final subBlocks = <Uint8List>[];
      while (j < bytes.length && bytes[j] != 0) {
        final n = bytes[j];
        subBlocks.add(bytes.sublist(j + 1, j + 1 + n));
        j += 1 + n;
      }
      if (label == 0xF9 && subBlocks.isNotEmpty && subBlocks.first.length >= 4) {
        // Graphic control extension: delay in centiseconds, little endian.
        final delay = subBlocks.first[1] | (subBlocks.first[2] << 8);
        // Browsers treat sub-10ms delays as 100ms; do the same.
        centiseconds += delay <= 1 ? 10 : delay;
      }
      i = j + 1;
      continue;
    }
    if (block == 0x2C) {
      // Image descriptor.
      frames++;
      i += 9;
      final localFlags = bytes[i];
      i += 1;
      if (localFlags & 0x80 != 0) {
        i += 3 * (2 << (localFlags & 0x07)); // local colour table
      }
      i += 1; // LZW minimum code size
      while (i < bytes.length && bytes[i] != 0) {
        i += 1 + bytes[i];
      }
      i += 1;
      continue;
    }
    i += 1;
  }
  if (frames == 0 || centiseconds == 0) return Duration.zero;
  return Duration(milliseconds: centiseconds * 10);
}
