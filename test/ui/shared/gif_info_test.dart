import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:fly_narwhal/ui/shared/gif_info.dart';

void main() {
  test('parses the bundled kowtow GIF single-play duration', () {
    final bytes = File('assets/images/donation_kowtow.gif').readAsBytesSync();
    final duration = gifSinglePlayDuration(bytes);
    // 88 frames at ~80–90ms: one pass is ≈7.3s.
    expect(duration, greaterThan(const Duration(seconds: 6)));
    expect(duration, lessThan(const Duration(seconds: 9)));
  });

  test('parses the bundled sticker GIF single-play duration', () {
    final bytes =
        File('assets/images/donation_thanks_sticker.gif').readAsBytesSync();
    final duration = gifSinglePlayDuration(bytes);
    // 7 frames at 50ms.
    expect(duration, greaterThan(const Duration(milliseconds: 300)));
    expect(duration, lessThan(const Duration(milliseconds: 500)));
  });

  test('non-GIF bytes yield Duration.zero', () {
    expect(gifSinglePlayDuration(Uint8List.fromList([1, 2, 3, 4])),
        Duration.zero);
    expect(gifSinglePlayDuration(Uint8List(0)), Duration.zero);
  });
}
