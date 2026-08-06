// Fetch a full libmpv (with PGS/HDMV SUP bitmap subtitle support) and its
// runtime dependency closure from the Ubuntu 24.04 (Noble) apt pool, and
// extract the .so files into a scratch directory layout that the existing
// `scripts/linux/bundle_full_libmpv.dart` script can recursively scan.
//
// The default media_kit Linux package dlopens the system `libmpv.so.2`, which
// on most distributions (and on a clean build host without `mpv libmpv-dev`
// installed) lacks the PGS decoder. This script is the "no system libmpv"
// fallback for `flutter run` / `flutter build linux` in any build type.
//
// Pinning strategy
// ----------------
// All package versions and SHA256s are pinned in the `_kPackages` table below
// against the Noble pool. To bump (e.g. for a future Ubuntu SRU release),
// re-run the discovery snippet in THIRD_PARTY_LIBMPV.md and edit the const
// map. The download path only resolves to that exact pool layout so the
// SHA256 verification is meaningful.
//
// Architecture handling
// ----------------------
// amd64 packages live under `http://archive.ubuntu.com/ubuntu/pool/...`, while
// arm64 lives under `http://ports.ubuntu.com/ubuntu-ports/pool/...`. The
// script picks the correct base URL automatically based on the `<arch>` arg.
//
// Usage
// -----
//   dart run scripts/linux/fetch_full_libmpv.dart <scratch-dir> <arch>
//     <arch> ∈ {x86_64, aarch64}
//
// On success, the scratch directory contains:
//   <scratch>/.cache/         downloaded .deb files (reused on next run)
//   <scratch>/root/           extracted files (the layout the bundler scans)
//   <scratch>/root/usr/lib/<arch>-linux-gnu/libmpv.so.2   (the deliverable)

import 'dart:async';
import 'dart:io';

class _Package {
  const _Package({
    required this.poolPath,
    required this.sha256,
  });

  /// Relative path under the architecture-specific pool root, e.g.
  /// `pool/universe/m/mpv/libmpv2_0.37.0-1ubuntu4_amd64.deb`.
  final String poolPath;

  /// SHA256 of the .deb file as published in the apt Packages index.
  final String sha256;
}

const _kPackages = <String, _Package>{
  // mpv + FFmpeg closure
  'libmpv2': _Package(
    poolPath: 'pool/universe/m/mpv/libmpv2_0.37.0-1ubuntu4_amd64.deb',
    sha256: '12ea9d67e291a90cea5b7497f3f9d196643bf2e85ad17cb683e9c7ad18981c00',
  ),
  'libavcodec60': _Package(
    poolPath: 'pool/universe/f/ffmpeg/libavcodec60_6.1.1-3ubuntu5_amd64.deb',
    sha256: '970d92c1697f762235af439d72df8c6cb492be45050a1a00bbe0d0842a137f93',
  ),
  'libavformat60': _Package(
    poolPath: 'pool/universe/f/ffmpeg/libavformat60_6.1.1-3ubuntu5_amd64.deb',
    sha256: '3a855488d50b4ebe04425e5f690e00ebd65d70e60f85c9765d5823a2f82b4969',
  ),
  'libavfilter9': _Package(
    poolPath: 'pool/universe/f/ffmpeg/libavfilter9_6.1.1-3ubuntu5_amd64.deb',
    sha256: '083b800aaf4fd1de817fb8dc12995e6a277c3500159c4a0fa21d36a76b6208ea',
  ),
  'libavutil58': _Package(
    poolPath: 'pool/universe/f/ffmpeg/libavutil58_6.1.1-3ubuntu5_amd64.deb',
    sha256: 'e57f8cc358f4b1b2af721ca6242723dc12290df543a142811ce7747e2d5b30cc',
  ),
  'libswscale7': _Package(
    poolPath: 'pool/universe/f/ffmpeg/libswscale7_6.1.1-3ubuntu5_amd64.deb',
    sha256: '2c17ae58b35112aace5179d7deea51faa20e82e04847b257f339376b11744e22',
  ),
  'libswresample4': _Package(
    poolPath: 'pool/universe/f/ffmpeg/libswresample4_6.1.1-3ubuntu5_amd64.deb',
    sha256: 'd55afe23e07b02b2def1647181a727dfad996001f72b5172da8a99691c3fa208',
  ),
  // libass + font shaping
  'libass9': _Package(
    poolPath: 'pool/universe/liba/libass/libass9_0.17.1-2build1_amd64.deb',
    sha256: 'a3dd7b4e6fa05d0d6607739b3c1f60a305f2fb78d9f6e8b8e38d10d0b4fc4052',
  ),
  'libfreetype6': _Package(
    poolPath: 'pool/main/f/freetype/libfreetype6_2.13.2+dfsg-1build3_amd64.deb',
    sha256: '321dda934f62fa8af08529a8c4c34b0ec040f172c0a945dce10b8be6f1014917',
  ),
  'libfribidi0': _Package(
    poolPath: 'pool/main/f/fribidi/libfribidi0_1.0.13-3build1_amd64.deb',
    sha256: '6cd50259d39ce0dfafee2632c6268538e6a02590e77161a133e9683af346dd1d',
  ),
  'libharfbuzz0b': _Package(
    poolPath: 'pool/main/h/harfbuzz/libharfbuzz0b_8.3.0-2build2_amd64.deb',
    sha256: 'd6f7eea2244f98aa0463a056680d4629476bf624767ede301560e24add686b5c',
  ),
  'libxml2': _Package(
    poolPath: 'pool/main/libx/libxml2/libxml2_2.9.14+dfsg-1.3ubuntu3_amd64.deb',
    sha256: '8c4efd7abe155df3cf0f9b64d659f2d866215785f8e8c44234fbb341d58cc967',
  ),
  // libplacebo + Vulkan loader + helpers
  'libplacebo338': _Package(
    poolPath: 'pool/universe/libp/libplacebo/libplacebo338_6.338.2-2build1_amd64.deb',
    sha256: '9c173df229673887df3cce7d4a26de15f7477a62cd1391f9a88c346018ecad1f',
  ),
  'libshaderc1': _Package(
    poolPath: 'pool/universe/s/shaderc/libshaderc1_2023.8-1build1_amd64.deb',
    sha256: 'ebd699ab3feaf00676a7da0644dd74290f60cd1b34057256db90f60e126655b1',
  ),
  'libvulkan1': _Package(
    poolPath: 'pool/main/v/vulkan-loader/libvulkan1_1.3.275.0-1build1_amd64.deb',
    sha256: 'ccf4fe8f4461442f27ea2494c7ae650b60bd396fec2688b0c44a27d66a222f74',
  ),
  'libudfread0': _Package(
    poolPath: 'pool/universe/libu/libudfread/libudfread0_1.1.2-1build1_amd64.deb',
    sha256: '9340c4bdb5954ed98a81eb7979c25187d0c4d95b633cac29eefe1f5b31c05162',
  ),
  'libbluray2': _Package(
    poolPath: 'pool/universe/libb/libbluray/libbluray2_1.3.4-1build1_amd64.deb',
    sha256: '2cfb2a7e4b6170efcfb96e0dbe3e9321b648acc43883ab4e7c248216de18ea6f',
  ),
  // image + charset detection
  'libpng16-16t64': _Package(
    poolPath: 'pool/main/libp/libpng1.6/libpng16-16t64_1.6.43-5build1_amd64.deb',
    sha256: '128d505038cc19dfc218658562ca5917ec242b79e6e2bbfb65ee27f297a53924',
  ),
  'libuchardet0': _Package(
    poolPath: 'pool/main/u/uchardet/libuchardet0_0.0.8-1build1_amd64.deb',
    sha256: 'e2c390d8c1843059922f7ff3a74106c5af6fbf03c94532c07de16bf5af256fb4',
  ),
  'libgraphite2-3': _Package(
    poolPath: 'pool/main/g/graphite2/libgraphite2-3_1.3.14-2build1_amd64.deb',
    sha256: 'e2a91c59a2b26649ed0b331bedab0c92e56cc2021cce27df1080089edaad7aba',
  ),
};

const _kArm64Packages = <String, _Package>{
  'libmpv2': _Package(
    poolPath: 'pool/universe/m/mpv/libmpv2_0.37.0-1ubuntu4_arm64.deb',
    sha256: 'e1ef60f012966ce5ecb5747181176a85e9c26fd5c8f4a715fe8384fe65f1ed05',
  ),
  'libavcodec60': _Package(
    poolPath: 'pool/universe/f/ffmpeg/libavcodec60_6.1.1-3ubuntu5_arm64.deb',
    sha256: 'c2eb6e847b8134076e170e4c2aa5851cbe8e4cf367399ff9ffb7b05f602795ff',
  ),
  'libavformat60': _Package(
    poolPath: 'pool/universe/f/ffmpeg/libavformat60_6.1.1-3ubuntu5_arm64.deb',
    sha256: '5842b1c1816144839e78c07d41062955a202c5a2ccde059ef106e1a17ced9407',
  ),
  'libavfilter9': _Package(
    poolPath: 'pool/universe/f/ffmpeg/libavfilter9_6.1.1-3ubuntu5_arm64.deb',
    sha256: '70bbce97e0d9d39d38d3b865778ff840f480e8a9d144ee79964daaa6c0501ed1',
  ),
  'libavutil58': _Package(
    poolPath: 'pool/universe/f/ffmpeg/libavutil58_6.1.1-3ubuntu5_arm64.deb',
    sha256: '446d732c91b6ca9d890e5ba054839a2e5faf9f110e8d84c2c94f75fa2497fab7',
  ),
  'libswscale7': _Package(
    poolPath: 'pool/universe/f/ffmpeg/libswscale7_6.1.1-3ubuntu5_arm64.deb',
    sha256: '80d58ac7cc2fe9efd05907a201e78775932484f8b18af0fc82cbb41142057078',
  ),
  'libswresample4': _Package(
    poolPath: 'pool/universe/f/ffmpeg/libswresample4_6.1.1-3ubuntu5_arm64.deb',
    sha256: '3d1ddc8dc72d487d4b5eb091dfc1e0af19ac24f5b6b6e7d7b728c3eedb3b459b',
  ),
  'libass9': _Package(
    poolPath: 'pool/universe/liba/libass/libass9_0.17.1-2build1_arm64.deb',
    sha256: '72d820bb9cdfa49d22a6d16a496cfd22cb2434bf02e125ac8eb94098994e3bce',
  ),
  'libfreetype6': _Package(
    poolPath: 'pool/main/f/freetype/libfreetype6_2.13.2+dfsg-1build3_arm64.deb',
    sha256: '7f61d8fb0e17b94344454211ba910c6d63752a63d628f2e86344e54583948dae',
  ),
  'libfribidi0': _Package(
    poolPath: 'pool/main/f/fribidi/libfribidi0_1.0.13-3build1_arm64.deb',
    sha256: '52d3d13602ec19e01932d653b53ea9fe43252ff39aa196b81f96b69006e4c3a2',
  ),
  'libharfbuzz0b': _Package(
    poolPath: 'pool/main/h/harfbuzz/libharfbuzz0b_8.3.0-2build2_arm64.deb',
    sha256: 'f6917480f6e2df79563398f4fcfc25167fcaa512f35fe1f595a6e3fa7b78a46d',
  ),
  'libxml2': _Package(
    poolPath: 'pool/main/libx/libxml2/libxml2_2.9.14+dfsg-1.3ubuntu3_arm64.deb',
    sha256: '6045818c821a498cfa2b9c93deeac87db5d0d6bd07f160176f1073af0c2858e4',
  ),
  'libplacebo338': _Package(
    poolPath: 'pool/universe/libp/libplacebo/libplacebo338_6.338.2-2build1_arm64.deb',
    sha256: '9367c6c1e178aa793d3fda419d6d2a1e91c78a12e135862e9f29811e0d8176c4',
  ),
  'libshaderc1': _Package(
    poolPath: 'pool/universe/s/shaderc/libshaderc1_2023.8-1build1_arm64.deb',
    sha256: 'b55e50139a5b541e71596edbf2ad585597de33ee1ee336a16f5f79797769f309',
  ),
  'libvulkan1': _Package(
    poolPath: 'pool/main/v/vulkan-loader/libvulkan1_1.3.275.0-1build1_arm64.deb',
    sha256: '9459488a53ead304d00587c874f9b31d56d59c9aeae5c46b6f78801a89d53e63',
  ),
  'libudfread0': _Package(
    poolPath: 'pool/universe/libu/libudfread/libudfread0_1.1.2-1build1_arm64.deb',
    sha256: 'c3833623e029241e1aa93eace31ec149d1962284794b8f0bbf2da94dee6f962d',
  ),
  'libbluray2': _Package(
    poolPath: 'pool/universe/libb/libbluray/libbluray2_1.3.4-1build1_arm64.deb',
    sha256: 'e090bf75675572f8f10e0ac6b7101a1ce5d606a62fdc5c4ea96502073337f0b5',
  ),
  'libpng16-16t64': _Package(
    poolPath: 'pool/main/libp/libpng1.6/libpng16-16t64_1.6.43-5build1_arm64.deb',
    sha256: '5c13f372e60f1e183f3c9426dee24a0dbecaaee762d3a12d9cbe6296b40e5801',
  ),
  'libuchardet0': _Package(
    poolPath: 'pool/main/u/uchardet/libuchardet0_0.0.8-1build1_arm64.deb',
    sha256: '1d72f4cb1d659e0f0ccfdee3c4e33db9e2dfa71e9cfceadc4ba72a3a37e85b1d',
  ),
  'libgraphite2-3': _Package(
    poolPath: 'pool/main/g/graphite2/libgraphite2-3_1.3.14-2build1_arm64.deb',
    sha256: '8f15a4393c26af67bf07751f85027f2bef5fcce239eab21194fb5fac4f5b9959',
  ),
};

/// Per-URL timeout. Matches the Windows `full_libmpv.cmake` strategy.
const _kDownloadTimeout = Duration(seconds: 90);

Future<int> main(List<String> arguments) async {
  if (arguments.length != 2) {
    stderr.writeln(
      'Usage: dart run scripts/linux/fetch_full_libmpv.dart '
      '<scratch-dir> <arch>',
    );
    stderr.writeln('  <arch> ∈ {x86_64, aarch64}');
    return 64;
  }
  final scratchDir = Directory(arguments[0]);
  final arch = arguments[1];
  final packageTable = _tableForArch(arch);
  if (packageTable == null) {
    stderr.writeln('Unsupported arch: $arch (expected x86_64 or aarch64)');
    return 64;
  }

  final cacheDir = Directory('${scratchDir.path}/.cache');
  final extractRoot = Directory('${scratchDir.path}/root');
  await cacheDir.create(recursive: true);
  await extractRoot.create(recursive: true);

  var ok = true;
  for (final entry in packageTable.entries) {
    final name = entry.key;
    final pkg = entry.value;
    final fileName = pkg.poolPath.split('/').last;
    final cached = File('${cacheDir.path}/$fileName');
    final extractedMarker = File(
      '${extractRoot.path}/.extracted.$name',
    );

    if (await extractedMarker.exists()) {
      stdout.writeln('[fetch] $name: cache hit, skipping');
      continue;
    }

    if (!(await cached.exists()) ||
        (await _sha256File(cached)) != pkg.sha256) {
      if (await cached.exists()) {
        stderr.writeln('[fetch] $name: cached file SHA mismatch, redownloading');
        await cached.delete();
      }
      try {
        await _downloadWithMirrorFallback(
          poolPath: pkg.poolPath,
          expectedSha: pkg.sha256,
          destination: cached,
          arch: arch,
        );
      } catch (error) {
        stderr.writeln('[fetch] $name: $error');
        ok = false;
        continue;
      }
    } else {
      stdout.writeln('[fetch] $name: archive cache hit (SHA verified)');
    }

    try {
      await _extractDeb(cached, extractRoot, name);
      await extractedMarker.writeAsString('ok');
    } catch (error) {
      stderr.writeln('[fetch] $name: extract failed: $error');
      ok = false;
    }
  }

  if (!ok) {
    stderr.writeln('[fetch] One or more packages failed. See above.');
    return 1;
  }

  // Final verification: the layout must contain libmpv.so.2 (or .1).
  final libmpv = await _findLibmpv(extractRoot);
  if (libmpv == null) {
    stderr.writeln(
      '[fetch] Extraction finished but libmpv.so.2 is missing under ${extractRoot.path}.',
    );
    return 1;
  }
  stdout.writeln('[fetch] Ready: ${libmpv.path}');
  return 0;
}

Map<String, _Package>? _tableForArch(String arch) {
  switch (arch) {
    case 'x86_64':
    case 'amd64':
      return _kPackages;
    case 'aarch64':
    case 'arm64':
      return _kArm64Packages;
    default:
      return null;
  }
}

String _poolBaseForArch(String arch) {
  // amd64 lives on the canonical archive, arm64 lives on the ports mirror.
  if (arch == 'aarch64' || arch == 'arm64') {
    return 'http://ports.ubuntu.com/ubuntu-ports';
  }
  return 'http://archive.ubuntu.com/ubuntu';
}

Future<void> _downloadWithMirrorFallback({
  required String poolPath,
  required String expectedSha,
  required File destination,
  required String arch,
}) async {
  final base = _poolBaseForArch(arch);
  // Primary + a known Launchpad mirror. Both are content-addressed by SHA,
  // so a single alternate source is sufficient as a fallback.
  final urls = <String>[
    '$base/$poolPath',
    'https://launchpad.net/ubuntu/+archive/primary/$poolPath',
  ];
  Object? lastError;
  for (var i = 0; i < urls.length; i++) {
    final url = urls[i];
    stdout.writeln('[fetch] trying source ${i + 1}/${urls.length}: $url');
    try {
      await _downloadToFile(
        url: url,
        destination: destination,
        timeout: _kDownloadTimeout,
      );
      final sha = await _sha256File(destination);
      if (sha != expectedSha) {
        lastError = 'SHA mismatch (got $sha)';
        if (await destination.exists()) await destination.delete();
        continue;
      }
      stdout.writeln('[fetch] downloaded and verified ${_humanSize(destination.lengthSync())}');
      return;
    } catch (error) {
      lastError = error;
      if (await destination.exists()) await destination.delete();
    }
  }
  throw StateError('All mirrors failed: $lastError');
}

Future<void> _downloadToFile({
  required String url,
  required File destination,
  required Duration timeout,
}) async {
  final client = HttpClient();
  try {
    final request = await client
        .getUrl(Uri.parse(url))
        .timeout(timeout, onTimeout: () {
      throw TimeoutException('GET $url exceeded $timeout');
    });
    final response = await request.close().timeout(timeout);
    if (response.statusCode != 200) {
      throw HttpException(
        'GET $url returned HTTP ${response.statusCode}',
      );
    }
    final partFile = File('${destination.path}.part');
    if (await partFile.exists()) await partFile.delete();
    final sink = partFile.openWrite();
    await response.listen(
      sink.add,
      onError: (Object e) => sink.addError(e),
      cancelOnError: true,
    ).asFuture<void>();
    await sink.flush();
    await sink.close();
    await partFile.rename(destination.path);
  } finally {
    client.close(force: true);
  }
}

Future<String> _sha256File(File file) async {
  // Use the system `sha256sum` because it streams in constant memory and
  // exists on both Linux (target) and macOS (where devs may run this for
  // cross-builds).
  final result = await Process.run('sha256sum', [file.path]);
  if (result.exitCode != 0) {
    throw ProcessException(
      'sha256sum',
      [file.path],
      result.stderr.toString(),
      result.exitCode,
    );
  }
  final output = result.stdout.toString();
  // Output format: "<hash>  <filename>"
  return output.split(RegExp(r'\s+')).first;
}

Future<void> _extractDeb(
  File deb,
  Directory targetRoot,
  String packageName,
) async {
  final workDir = await Directory.systemTemp.createTemp('fetch_libmpv_');
  try {
    // .deb is an ar archive containing control.tar.* + data.tar.*; the data
    // archive is what holds the .so files.
    final ar = await Process.run(
      'ar',
      ['x', deb.path],
      workingDirectory: workDir.path,
    );
    if (ar.exitCode != 0) {
      throw ProcessException('ar', ['x', deb.path], ar.stderr.toString(), ar.exitCode);
    }
    final dataArchive = await _findDataArchive(workDir);
    if (dataArchive == null) {
      throw StateError('No data.tar.* found in ${deb.path}');
    }
    await _extractDataArchive(dataArchive, targetRoot.path);
    stdout.writeln('[fetch] $packageName: extracted');
  } finally {
    if (await workDir.exists()) {
      await workDir.delete(recursive: true);
    }
  }
}

/// Extracts a `data.tar.{xz,zst}` archive. .xz is piped straight to `tar -xJf`
/// (BSD tar on macOS supports `-J`; GNU tar on Linux supports it too). .zst
/// requires a `zstd -d` pre-step because BSD tar on macOS does not understand
/// zstd natively.
Future<void> _extractDataArchive(String dataArchive, String target) async {
  if (dataArchive.endsWith('.tar.xz')) {
    final extract = await Process.run(
      'tar',
      ['-xJf', dataArchive, '-C', target],
    );
    if (extract.exitCode != 0) {
      throw ProcessException(
        'tar',
        ['-xJf', dataArchive, '-C', target],
        extract.stderr.toString(),
        extract.exitCode,
      );
    }
    return;
  }
  if (dataArchive.endsWith('.tar.zst')) {
    final zstd = await _findZstd();
    if (zstd == null) {
      throw StateError(
        'data.tar.zst found but `zstd` is not installed. '
        'Install zstd (apt: zstd, brew: zstd) and re-run.',
      );
    }
    // Pipe `zstd -d` output into `tar -xf`. We launch both processes with
    // piped stdio and wire them up manually.
    final decoder = await Process.start(zstd, ['-d', '-c', dataArchive]);
    final tar = await Process.start('tar', ['-xf', '-', '-C', target]);
    // Forward decoder.stdout -> tar.stdin.
    decoder.stdout.pipe(tar.stdin);
    // Drain both stderr streams to avoid backpressure.
    final decoderStderr = await decoder.stderr
        .transform(const SystemEncoding().decoder)
        .toList();
    final tarStderr = await tar.stderr
        .transform(const SystemEncoding().decoder)
        .toList();
    final decoderExit = await decoder.exitCode;
    final tarExit = await tar.exitCode;
    if (decoderExit != 0 || tarExit != 0) {
      throw ProcessException(
        'zstd|tar',
        [zstd, '-d', '-c', dataArchive, '|', 'tar', '-xf', '-', '-C', target],
        'zstd stderr: ${decoderStderr.join()}\ntar stderr: ${tarStderr.join()}',
        tarExit == 0 ? decoderExit : tarExit,
      );
    }
    return;
  }
  throw StateError('Unsupported data archive extension: $dataArchive');
}

Future<String?> _findZstd() async {
  // PATH first
  try {
    final which = await Process.run('which', ['zstd']);
    if (which.exitCode == 0) {
      final path = which.stdout.toString().trim();
      if (path.isNotEmpty) return path;
    }
  } catch (_) {}
  // Common install locations
  for (final candidate in <String>[
    '/usr/bin/zstd',
    '/usr/local/bin/zstd',
    '/opt/homebrew/bin/zstd',
  ]) {
    if (await File(candidate).exists()) return candidate;
  }
  return null;
}

Future<String?> _findDataArchive(Directory dir) async {
  for (final entity in dir.listSync()) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    if (name.startsWith('data.tar.')) {
      // We support both .xz and .zst; .zst requires a `zstd` binary.
      if (name.endsWith('.xz') || name.endsWith('.zst')) return entity.path;
    }
  }
  return null;
}

Future<File?> _findLibmpv(Directory root) async {
  // libmpv.so.2 is a relative symlink into the real versioned file (e.g.
  // libmpv.so.2.2.0). With followLinks: false, the symlink shows up as a
  // Link, not a File, so we inspect both and resolve the link to its target.
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    final name = entity.uri.pathSegments.last;
    if (name == 'libmpv.so.2' || name == 'libmpv.so.1') {
      if (entity is File) return entity;
      if (entity is Link) {
        try {
          return File(entity.resolveSymbolicLinksSync());
        } catch (_) {
          // Dangling link; fall through to the next candidate.
        }
      }
    }
  }
  return null;
}

String _humanSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}
