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

// Only the lib64 roots are treated as system-library locations. The generic
// '/lib' and '/usr/lib' prefixes are deliberately NOT listed: on Debian/Ubuntu
// the full libmpv + FFmpeg closure lives under /usr/lib/<arch>-linux-gnu and
// must be copied into the bundle. True low-level system loaders (ld-linux,
// libc, libm, ...) are excluded via the soname allowlist below instead.
const _kSystemLibPrefixes = <String>[
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

// PulseAudio's private helper library is dlopened by libpulse.so.0 under a
// hard-coded, version-pinned soname (e.g. libpulsecommon-16.1.so). Bundling
// the build host's copy makes the app crash on any distro shipping a newer
// or older PulseAudio — e.g. an Ubuntu Noble (16.1) bundle fails to start on
// Arch with libpulse 17.0 because /usr/lib/pulseaudio/ is shadowed by the
// bundle and libpulsecommon-16.1.so cannot be loaded. The versioned helper
// always resolves from the target system, matching what every other AppImage
// does.
final _kDlopenedVersionedLibs = RegExp(r'^libpulsecommon-[0-9.]+\.so$');

// Driver-boundary libraries must be resolved from the machine the app runs
// on, not the machine it was built on. libmpv depends on them, so the
// dependency walk below would otherwise copy the build host's copies into the
// bundle.
//
// Observed failure (Ubuntu Noble build running on Arch Linux ARM): the bundle
// carried Ubuntu's glvnd dispatcher libGLdispatch.so.0, which cannot
// enumerate the host's Mesa vendor, so libepoxy aborted the app at startup
// with "No provider of eglGetPlatformDisplayEXT found" before the first
// frame. A host-provided glvnd/EGL stack fixes it because the dispatcher then
// loads the host's vendor driver (libEGL_mesa.so.0 via glvnd's
// /usr/share/glvnd/egl_vendor.d).
//
// The scope is deliberately narrow. The rest of the graphics stack stays
// bundled because it is a self-consistent ABI layer that works across
// distros, and because libmpv links some of it unconditionally:
//   * libXss.so.1 and libXpresent.so.1 are hard NEEDED entries of the Ubuntu
//     libmpv/SDL2 build, but Arch does not ship those sonames at all. Excluding
//     them turns a working bundle into a loader failure ("cannot open shared
//     object file"), so they are bundled.
//   * The X11/XCB client stack is likewise bundled: it is only ever a client
//     of whatever X server is present, and libXss/libXpresent need it.
// Application dependencies (libass, libplacebo, FFmpeg, libvulkan) are
// unaffected by this list.
final _kHostDriverLibs = RegExp(
  '^('
  // glvnd dispatch layer -> host vendor driver (Mesa, NVIDIA, ...)
  'libEGL|libGL|libGLX|libGLdispatch|libOpenGL|libGLESv2|'
  // Kernel DRM/KMS and the GBM buffer allocator.
  'libgbm|libdrm|'
  // Wayland client protocol + xkb keymap (must match the compositor).
  'libwayland-client|libwayland-egl|libwayland-cursor|libwayland-server|libxkbcommon|'
  // Audio servers: libpulse.so.0 hard-codes a version-pinned
  // libpulsecommon-NN.so soname resolved from the host, and its RUNPATH is
  // the Debian-only /usr/lib/<arch>-linux-gnu/pulseaudio.
  'libpulse|libpulse-simple|'
  // GTK3 and its text/rendering stack. The app links libgtk-3.so.0 from the
  // host, so it always pulls in GTK's own Pango/Cairo/HarfBuzz/freetype at
  // runtime. Shipping the build host's older copies alongside it splits the
  // stack across two versions and the host's newer objects abort with
  // "undefined symbol" (observed: Arch's libpangoft2-1.0.so.0 needs
  // pango_font_description_get_width, absent from Ubuntu Noble's Pango).
  // These libraries come in as libmpv/libass dependencies, hence the
  // exclusion.
  'libgtk-3|libgdk-3|libatk|libpangocairo|libpangoft2|libpango-1\\.0|'
  'libcairo-gobject|libcairo|libharfbuzz|libfreetype|libfontconfig|'
  'libgdk_pixbuf|libepoxy'
  // Trailing qualifier: XCB's sibling libraries append a word
  // (libxcb-dri3.so.0) while pango/atk/cairo append a version
  // (libpango-1.0.so.0, libatk-1.0.so.0).
  r')(-[a-z0-9.]+)?\.so(\.[0-9.]+)?$',
);

Future<int> main(List<String> arguments) async {
  if (arguments.length != 2) {
    stderr.writeln(
      'Usage: dart run scripts/linux/bundle_full_libmpv.dart '
      '<bundle-dir> <libmpv-source-dir>',
    );
    return 64;
  }
  // Extra search roots are added on top of the system paths so the recursive
  // dependency walk can resolve NEEDED entries (e.g. libavcodec.so.61) from
  // a scratch directory populated by `scripts/linux/fetch_full_libmpv.dart`.
  // They are read from the environment because CMake POST_BUILD hooks prefer
  // env vars over extra CLI args; the CI fast path leaves this unset.
  final extraRoots = (Platform.environment['LIBMPV_EXTRA_SEARCH_ROOTS'] ?? '')
      .split(Platform.pathSeparator)
      .where((p) => p.trim().isNotEmpty)
      .map((p) => Directory(p).absolute.path)
      .toList(growable: false);
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
  if (extraRoots.isNotEmpty) {
    stdout.writeln(
      '[bundle] extra search roots: ${extraRoots.join(', ')}',
    );
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
    if (await _isSystemLoader(resolved, extraRoots: extraRoots)) continue;
    // The entry point must land under its dlopen name (libmpv.so.2) so the
    // app finds it via $ORIGIN/lib regardless of the source file's real name
    // (which may be the versioned libmpv.so.2.2.0).
    final targetName = identical(next.path, libmpvFile.path)
        ? 'libmpv.so.2'
        : next.uri.pathSegments.last;
    final target = File('${libOut.path}/$targetName');
    if (!await target.exists()) {
      await next.copy(target.path);
    }
    final deps = await _readNeededLibs(next);
    for (final dep in deps) {
      final resolvedDep = await _resolveDep(dep, extraRoots: extraRoots);
      if (resolvedDep == null) continue;
      if (await _isSystemLoader(resolvedDep, extraRoots: extraRoots)) continue;
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

  // 4. RPATH normalization. The Flutter Linux plugin template links every
  //    plugin with an absolute INSTALL_RPATH baked to the build machine's
  //    CMake ephemeral directory (e.g.
  //    /home/runner/work/<proj>/linux/flutter/ephemeral). A DT_RUNPATH is
  //    searched for the dependencies of the object that carries it, and it
  //    takes precedence over the executable's own $ORIGIN/lib, so on an
  //    installed copy the plugins look for libmpv.so.2 (and friends) under a
  //    directory that does not exist and the app dies in the loader with
  //    "libmpv.so.2: cannot open shared object file".
  //
  //    The AppImage hid this because its AppRun exports LD_LIBRARY_PATH, which
  //    is also consulted for transitive dependencies; the .deb/.rpm/.pacman
  //    builds exec the binary directly and therefore failed.
  //
  //    Rewrite every bundled object to a relocatable $ORIGIN-equivalent rpath
  //    so the install is self-contained. The executable keeps $ORIGIN/lib
  //    (libraries live one level down); libraries live alongside each other in
  //    lib/, so $ORIGIN is enough for them.
  final exe = _pickBundleExecutable(bundleDir);
  if (exe == null) {
    stderr.writeln('Could not locate bundle executable under ${bundleDir.path}');
    return 1;
  }
  final normalized = await _normalizeRunpaths(
    bundleDir: bundleDir,
    libDir: libOut,
    executable: exe,
  );
  if (!normalized) return 1;

  stdout.writeln('libmpv bundle ready: ${libOut.path} (entry: ${exe.path})');
  return 0;
}

/// Rewrites the rpath of the bundle executable and every shared object in
/// [libDir] so the bundle resolves its own libraries after being installed to
/// an arbitrary prefix. Returns false (after reporting) if patchelf fails.
///
/// Objects that need no rewrite are skipped: the executable already carries
/// $ORIGIN/lib and the Flutter engine already carries $ORIGIN.
Future<bool> _normalizeRunpaths({
  required Directory bundleDir,
  required Directory libDir,
  required File executable,
}) async {
  if (!await _hasPatchelf()) {
    stderr.writeln(
      'patchelf is required to normalize bundle rpaths. Install it '
      '(e.g. `apt-get install -y patchelf`) before building Linux releases.',
    );
    return false;
  }

  final targets = <File>[
    executable,
    ...await _collectSharedObjects(bundleDir),
  ];
  for (final target in targets) {
    final desired = target.path == executable.path ? r'$ORIGIN/lib' : r'$ORIGIN';
    final current = await _readRunpath(target);
    if (current == desired) continue;
    final result = await Process.run('patchelf', [
      '--set-rpath',
      desired,
      target.path,
    ]);
    if (result.exitCode != 0) {
      stderr.writeln(
        'patchelf --set-rpath $desired failed for ${target.path}: '
        '${result.stderr}',
      );
      return false;
    }
    if (current.isNotEmpty) {
      stdout.writeln(
        'Normalized rpath of ${target.uri.pathSegments.last}: '
        '$current -> $desired',
      );
    }
  }
  return true;
}

Future<bool> _hasPatchelf() async {
  try {
    final result = await Process.run('patchelf', ['--version']);
    return result.exitCode == 0;
  } on ProcessException {
    return false;
  }
}

/// Every regular file under the bundle (lib/ plus the executable's directory)
/// that is an ELF shared object.
Future<List<File>> _collectSharedObjects(Directory bundleDir) async {
  final objects = <File>[];
  await for (final entity in bundleDir.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    if (!name.contains('.so')) continue;
    final header = await _readMagic(entity);
    if (header != _elfMagic) continue;
    objects.add(entity);
  }
  return objects;
}

const _elfMagic = '\x7FELF';

Future<String> _readMagic(File file) async {
  final handle = await file.open();
  try {
    final bytes = await handle.read(4);
    return String.fromCharCodes(bytes);
  } finally {
    await handle.close();
  }
}

Future<String> _readRunpath(File file) async {
  final result = await Process.run('patchelf', ['--print-rpath', file.path]);
  if (result.exitCode != 0) return '';
  return (result.stdout as String).trim();
}

Future<File?> _findLibmpv(Directory root) async {
  // libmpv.so.2 is normally a relative symlink into the real versioned file
  // (e.g. libmpv.so.2.2.0). With followLinks: false the symlink surfaces as a
  // Link, not a File, so we inspect both and resolve a link to its target.
  final candidates = <File>[];
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    final name = entity.uri.pathSegments.last;
    if (name == 'libmpv.so.2' || name == 'libmpv.so.1') {
      if (entity is File) {
        candidates.add(entity);
      } else if (entity is Link) {
        try {
          candidates.add(File(entity.resolveSymbolicLinksSync()));
        } catch (_) {
          // Dangling link; ignore.
        }
      }
    }
  }
  if (candidates.isEmpty) return null;
  candidates.sort((a, b) => b.path.length.compareTo(a.path.length));
  return candidates.first;
}

Future<bool> _isSystemLoader(
  String path, {
  List<String> extraRoots = const [],
}) async {
  // A path that lives under one of the extra roots (e.g. a downloaded scratch
  // directory populated by fetch_full_libmpv.dart) is bundle-internal even
  // though its components live under `…/usr/lib/…`. Skip the system-loader
  // early-out for those paths so they get copied into the bundle.
  for (final root in extraRoots) {
    if (path.startsWith('$root/') || path == root) return false;
  }
  for (final loader in _kSystemLoaderPaths) {
    if (path.endsWith('/$loader')) return true;
  }
  for (final prefix in _kSystemLibPrefixes) {
    if (path.startsWith('$prefix/')) return true;
  }
  // dlopened version-pinned private libs must always come from the target
  // system, even when they were fetched into an extra search root.
  final baseName = path.split('/').last;
  if (_kDlopenedVersionedLibs.hasMatch(baseName)) return true;
  if (_kHostDriverLibs.hasMatch(baseName)) return true;
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

Future<String?> _resolveDep(
  String soname, {
  List<String> extraRoots = const [],
}) async {
  // 1. Try the cache. We cannot use ldconfig without invoking a binary; use
  //    the obvious multiarch paths instead, which is what CI runners expose.
  //    Extra roots (e.g. a downloaded scratch directory) are prepended so
  //    NEEDED entries from a freshly-fetched libmpv resolve before falling
  //    through to the system paths.
  final archDirs = <String>[
    ...extraRoots,
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
