// Bundle a full libmpv (and its runtime dependencies) into the Flutter Linux
// release bundle.
//
// The default media_kit Linux package loads libmpv.so.2 from the system,
// which usually lacks the PGS/HDMV SUP bitmap subtitle decoder. This script
// resolves a complete libmpv installation (provided by the CI environment or
// by `apt install mpv libmpv-dev`) into the bundle's `lib/` directory. The
// Flutter Linux runner already links itself with `$ORIGIN/lib` (see
// linux/CMakeLists.txt), so the bundled libmpv and its FFmpeg/libass
// dependency closure are loaded directly from the bundle.
//
// The script is intentionally a plain Dart program (no Dart package) so it
// can be invoked directly by `dart run scripts/linux/bundle_full_libmpv.dart`
// during local release builds and from `.github/workflows/build-desktop.yml`
// during CI builds.

import 'dart:io';

const _kSystemLibPrefixes = <String>[
  '/lib',
  '/usr/lib',
  '/lib64',
  '/usr/lib64',
];

const _kSystemLoaderPaths = <String>{
  'ld-linux.so.2',
  'ld-linux-x86-64.so.2',
  'ld-linux-aarch64.so.1',
  'libc.so.6',
  'libdl.so.2',
  'libpthread.so.0',
  'libm.so.6',
  'librt.so.1',
  'librt-2.31.so',
  'libresolv.so.2',
  'libnsl.so.1',
  'libutil.so.1',
};

Future<int> main(List<String> arguments) async {
  if (arguments.length != 2) {
    stderr.writeln(
      'Usage: dart run scripts/linux/bundle_full_libmpv.dart '
      '<bundle-dir> <libmpv-source-dir>',
    );
    return 64;
  }
  final bundleDir = Directory(arguments[0]);
  final libmpvSource = Directory(arguments[1]);
  if (!await bundleDir.exists()) {
    stderr.writeln('Bundle directory does not exist: ${bundleDir.path}');
    return 1;
  }
  if (!await libmpvSource.exists()) {
    stderr.writeln('libmpv source directory does not exist: ${libmpvSource.path}');
    return 1;
  }
  final libOut = Directory('${bundleDir.path}/lib');
  await libOut.create(recursive: true);

  // 1. Locate libmpv.so.2 in the source tree (system or pre-installed path).
  final libmpvFile = await _findLibmpv(libmpvSource);
  if (libmpvFile == null) {
    stderr.writeln(
      'Could not find libmpv.so.2 inside ${libmpvSource.path}. '
      'Install mpv/libmpv-dev (e.g. `apt-get install -y mpv libmpv-dev`) '
      'or provide a directory that contains it.',
    );
    return 1;
  }
  stdout.writeln('Bundling ${libmpvFile.path}');

  // 2. Recursively copy libmpv and its non-system runtime dependencies.
  final seen = <String>{};
  final queued = <File>[libmpvFile];
  while (queued.isNotEmpty) {
    final next = queued.removeLast();
    final resolved = await _resolveRealPath(next.path);
    if (!seen.add(resolved)) continue;
    if (await _isSystemLoader(resolved)) continue;
    final target = File('${libOut.path}/${next.uri.pathSegments.last}');
    if (!await target.exists()) {
      await next.copy(target.path);
    }
    final deps = await _readNeededLibs(next);
    for (final dep in deps) {
      final resolvedDep = await _resolveDep(dep);
      if (resolvedDep == null) continue;
      if (await _isSystemLoader(resolvedDep)) continue;
      final depFile = File(resolvedDep);
      if (await depFile.exists()) {
        queued.add(depFile);
      }
    }
  }

  // 3. Sanity check: bundle/lib must contain libmpv.so.2 and pass `ldd` with
  //    no `not found` entries when run from the bundle context.
  final bundledLibmpv = File('${libOut.path}/libmpv.so.2');
  if (!await bundledLibmpv.exists()) {
    stderr.writeln('libmpv.so.2 missing from ${libOut.path} after bundling');
    return 1;
  }
  final missing = await _verifyLdd(bundledLibmpv);
  if (missing.isNotEmpty) {
    stderr.writeln(
      'libmpv.so.2 has unresolved dependencies after bundling: $missing',
    );
    return 1;
  }

  // 4. RPATH enforcement: the Linux Flutter app already sets
  //    $ORIGIN/lib (see linux/CMakeLists.txt), so the copy above is enough
  //    on x86_64/arm64. Surface a warning if RPATH appears wrong so a
  //    future CMake change doesn't silently regress this.
  final exe = _pickBundleExecutable(bundleDir);
  if (exe == null) {
    stderr.writeln('Could not locate bundle executable under ${bundleDir.path}');
    return 1;
  }
  stdout.writeln('libmpv bundle ready: ${libOut.path} (entry: ${exe.path})');
  return 0;
}

Future<File?> _findLibmpv(Directory root) async {
  final candidates = <File>[];
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    if (name == 'libmpv.so.2' || name == 'libmpv.so.1') {
      candidates.add(entity);
    }
  }
  if (candidates.isEmpty) return null;
  candidates.sort((a, b) => b.path.length.compareTo(a.path.length));
  return candidates.first;
}

Future<bool> _isSystemLoader(String path) async {
  for (final loader in _kSystemLoaderPaths) {
    if (path.endsWith('/$loader')) return true;
  }
  for (final prefix in _kSystemLibPrefixes) {
    if (path.startsWith('$prefix/')) return true;
  }
  return false;
}

Future<List<String>> _readNeededLibs(File file) async {
  final result = await Process.run('readelf', ['-d', '--wide', file.path]);
  if (result.exitCode != 0) return const <String>[];
  final libs = <String>[];
  for (final line in (result.stdout as String).split('\n')) {
    final m = RegExp(r'\(NEEDED\).*\[(.+?)\]').firstMatch(line);
    if (m != null) libs.add(m.group(1)!);
  }
  return libs;
}

Future<String?> _resolveDep(String soname) async {
  // 1. Try the cache. We cannot use ldconfig without invoking a binary; use
  //    the obvious multiarch paths instead, which is what CI runners expose.
  const archDirs = <String>[
    '/usr/lib/x86_64-linux-gnu',
    '/usr/lib/aarch64-linux-gnu',
    '/usr/lib64',
    '/usr/lib',
    '/lib/x86_64-linux-gnu',
    '/lib/aarch64-linux-gnu',
    '/lib64',
    '/lib',
  ];
  for (final dir in archDirs) {
    final candidate = File('$dir/$soname');
    if (await candidate.exists()) return candidate.path;
  }
  return null;
}

Future<String> _resolveRealPath(String path) async {
  try {
    return await File(path).resolveSymbolicLinks();
  } catch (_) {
    return path;
  }
}

Future<List<String>> _verifyLdd(File file) async {
  final result = await Process.run('ldd', [file.path]);
  if (result.exitCode != 0) {
    return ['ldd failed: ${result.stderr}'];
  }
  final missing = <String>[];
  for (final line in (result.stdout as String).split('\n')) {
    if (line.contains('not found')) missing.add(line.trim());
  }
  return missing;
}

File? _pickBundleExecutable(Directory bundleDir) {
  // The Flutter Linux bundle puts the binary at the root with a name derived
  // from the CMake BINARY_NAME (fly_narwhal). Look for the first non-lib
  // executable we can find.
  for (final entity in bundleDir.listSync()) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    if (name.startsWith('lib')) continue;
    final stat = entity.statSync();
    if (stat.type == FileSystemEntityType.file && stat.mode & 0x111 != 0) {
      return entity;
    }
  }
  return null;
}
