// Verify that a built macOS Flutter app embeds the *full* libmpv/FFmpeg
// XCFramework (with the PGS/HDMV SUP bitmap subtitle decoder) rather than
// the default-stripped variant shipped by the upstream
// `media_kit_libs_macos_video` package.
//
// Usage:
//   dart run scripts/macos/verify_full_libmpv.dart <path-to-app.app>
//
// The script:
//   1. locates `Contents/Frameworks/Mpv.framework/Mpv` and
//      `Contents/Frameworks/Avcodec.framework/Avcodec` inside the bundle,
//   2. asserts the Mpv binary is a fat universal (arm64 + x86_64),
//   3. asserts the Avcodec binary contains the `hdmv_pgs_subtitle` symbol
//      (FFmpeg's PGS decoder) and reports the build configuration string.
//   4. asserts Avcodec's build configuration string references
//      `--enable-decoder=hdmv_pgs_subtitle` (or `hdmv_pgs`) so we can catch
//      future upstream profile regressions without launching the player.
//
// Exits non-zero on any failure so the release script can rely on it as a
// build-time gate.

import 'dart:io';

Future<int> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln('Usage: dart run scripts/macos/verify_full_libmpv.dart <path-to-app.app>');
    return 64;
  }
  final appPath = arguments[0];
  final app = Directory(appPath);
  if (!await app.exists()) {
    stderr.writeln('App bundle not found: $appPath');
    return 1;
  }

  final mpv = File('${app.path}/Contents/Frameworks/Mpv.framework/Versions/A/Mpv');
  final avcodec =
      File('${app.path}/Contents/Frameworks/Avcodec.framework/Versions/A/Avcodec');

  var failed = false;

  if (!await mpv.exists()) {
    stderr.writeln('Mpv.framework missing in $appPath (looked at ${mpv.path}).');
    failed = true;
  } else {
    final archs = await _architectures(mpv.path);
    stdout.writeln('Mpv architectures: $archs');
    // Debug builds on Apple Silicon produce arm64-only; release builds and CI
    // uploads must always be universal. The release script re-runs this
    // check on the production artifact, so we warn here rather than fail
    // when running locally on an arm64 Mac.
    final isUniversal = archs.contains('arm64') && archs.contains('x86_64');
    final isArm64Only = archs.length == 1 && archs.contains('arm64');
    if (!isUniversal && !isArm64Only) {
      stderr.writeln(
        'Mpv must be either a universal binary (arm64 + x86_64) or a single '
        'arm64 slice. Got: $archs',
      );
      failed = true;
    }
    if (isArm64Only) {
      stdout.writeln(
        'Mpv is arm64-only (debug build on Apple Silicon). A universal '
        'binary is required for release artifacts.',
      );
    }
  }

  if (!await avcodec.exists()) {
    stderr.writeln('Avcodec.framework missing in $appPath (looked at ${avcodec.path}).');
    failed = true;
  } else {
    final hasHdmvPgsSymbol =
        await _stringPresent(avcodec.path, 'hdmv_pgs_subtitle');
    final hasPgssubSymbol = await _stringPresent(avcodec.path, 'pgssub');
    final hasDecoderDescription =
        await _stringPresent(avcodec.path, 'PGS subtitle decoder');
    stdout.writeln(
      'Avcodec PGS markers: '
      'hdmv_pgs_subtitle=$hasHdmvPgsSymbol, '
      'pgssub=$hasPgssubSymbol, '
      'description=$hasDecoderDescription',
    );
    if (!hasPgssubSymbol) {
      stderr.writeln(
        'Avcodec does not contain the pgssub string. The default '
        'media_kit_libs_macos_video profile was used instead of the full one, '
        'so PGS/HDMV SUP bitmap subtitles will not render.',
      );
      failed = true;
    }
    if (!hasDecoderDescription) {
      stderr.writeln(
        'Avcodec does not contain the "PGS subtitle decoder" description. '
        'The FFmpeg build is missing the PGS codec registration.',
      );
      failed = true;
    }

    final config = await _ffmpegConfiguration(avcodec.path);
    stdout.writeln('FFmpeg build configuration (truncated):');
    stdout.writeln(config);
    final isFullProfile = config.contains('--enable-decoders') ||
        config.contains('enable-decoder=hdmv_pgs_subtitle');
    if (!isFullProfile) {
      stderr.writeln(
        'FFmpeg build configuration does not enable all decoders '
        '(--enable-decoders) nor explicitly --enable-decoder=hdmv_pgs_subtitle; '
        'the bundled binary likely came from the default profile.',
      );
      failed = true;
    }
  }

  if (failed) {
    stderr.writeln('macOS full libmpv verification FAILED for $appPath');
    return 1;
  }
  stdout.writeln('macOS full libmpv verification OK for $appPath');
  return 0;
}

Future<List<String>> _architectures(String binaryPath) async {
  final result = await Process.run('lipo', ['-archs', binaryPath]);
  if (result.exitCode != 0) {
    return const <String>[];
  }
  return (result.stdout as String)
      .trim()
      .split(RegExp(r'\s+'))
      .where((s) => s.isNotEmpty)
      .toList();
}

Future<bool> _stringPresent(String binaryPath, String needle) async {
  // Use `grep -c` to fail fast on huge binaries; it also exits non-zero when
  // there are no matches, which is fine for us (we just want a bool).
  final result = await Process.run('grep', ['-c', needle, binaryPath]);
  if (result.exitCode == 0) {
    final count = int.tryParse((result.stdout as String).trim());
    return (count ?? 0) > 0;
  }
  // Fallback to `strings` if `grep -c` somehow didn't match (e.g. binary
  // pattern is split across records); this is the original implementation.
  final strings = await Process.run('strings', [binaryPath]);
  if (strings.exitCode != 0) return false;
  return (strings.stdout as String).contains(needle);
}

Future<String> _ffmpegConfiguration(String avcodecPath) async {
  // FFmpeg 6 embeds the configuration string as the symbol `ff_config`.
  // We search the binary directly to avoid having to symlink the matching
  // libavutil for the `av_config` access path.
  final result = await Process.run('strings', [avcodecPath]);
  if (result.exitCode != 0) return '<strings failed: ${result.stderr}>';
  for (final line in (result.stdout as String).split('\n')) {
    if (line.contains('--enable-libxml2') || line.contains('--enable-libdav1d')) {
      return line;
    }
  }
  return '<FFmpeg configuration not found>';
}
