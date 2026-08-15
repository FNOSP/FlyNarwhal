import 'dart:convert';
import 'dart:io';

import 'package:fly_narwhal/tooling/windows_bundle_contract.dart';

const _requiredSecrets = <String>[
  'FLY_NARWHAL_API_SECRET',
  'FLY_NARWHAL_SECRET',
];

Future<void> main(List<String> arguments) async {
  final parsedArguments = _parseArguments(arguments);
  final platform = parsedArguments.platform;
  final architecture = parsedArguments.architecture;
  _validateTarget(platform, architecture);
  _validateRequiredSecrets();

  final obfuscatorDirectory = _requiredEnvironmentValue(
    'OBFUSCATOR_TOOL_DIRECTORY',
  );
  final goArchitecture = _requiredEnvironmentValue('OBFUSCATOR_GOARCH');
  final libraryName = _requiredEnvironmentValue('OBFUSCATOR_LIBNAME');
  final dryRun = parsedArguments.dryRun;

  try {
    await _runProtectedBuild(
      platform: platform,
      architecture: architecture,
      goArchitecture: goArchitecture,
      libraryName: libraryName,
      obfuscatorDirectory: obfuscatorDirectory,
      dryRun: dryRun,
    );
  } finally {
    await _deleteGeneratedSecretSource(obfuscatorDirectory, dryRun: dryRun);
  }
}

Future<void> _runProtectedBuild({
  required String platform,
  required String architecture,
  required String goArchitecture,
  required String libraryName,
  required String obfuscatorDirectory,
  required bool dryRun,
}) async {
  await _runProcess(
    executable: 'go',
    arguments: const <String>['run', './cmd/gensecret'],
    workingDirectory: obfuscatorDirectory,
    environment: Platform.environment,
    dryRun: dryRun,
  );

  final nativeLibraryPath = _nativeLibraryPath(
    obfuscatorDirectory: obfuscatorDirectory,
    platform: platform,
    goArchitecture: goArchitecture,
    libraryName: libraryName,
  );
  await Directory(nativeLibraryPath).parent.create(recursive: true);
  await _runProcess(
    executable: 'go',
    arguments: <String>[
      'build',
      '-tags',
      'secretgen',
      '-buildmode=c-shared',
      '-trimpath',
      '-ldflags',
      '-s -w',
      '-o',
      nativeLibraryPath,
      './cmd/shared',
    ],
    workingDirectory: obfuscatorDirectory,
    environment: <String, String>{
      ...Platform.environment,
      'CGO_ENABLED': '1',
      'GOOS': platform == 'macos' ? 'darwin' : platform,
      'GOARCH': goArchitecture,
    },
    dryRun: dryRun,
  );

  final flutterArguments = <String>[
    'build',
    platform,
    '--release',
    '--obfuscate',
    '--split-debug-info=symbols/$platform-$architecture',
    // flutter_tools strips prerelease suffixes from the platform version
    // fields on Apple platforms, so carry the full pubspec version via
    // dart-define for the in-app updater and settings display.
    '--dart-define=APP_FULL_VERSION=${_packageVersion()}',
  ];
  await _runProcess(
    executable: 'flutter',
    arguments: flutterArguments,
    dryRun: dryRun,
  );

  final bundleDirectory = _bundleDirectory(platform, architecture);
  final bundleLibraryPath =
      '$bundleDirectory${Platform.pathSeparator}$libraryName';
  if (dryRun) {
    stdout.writeln('Copy $nativeLibraryPath -> $bundleLibraryPath');
    if (platform == 'windows') {
      stdout.writeln(
        'CMake will build $windowsUpdaterExecutable during flutter build windows.',
      );
      stdout.writeln('Verify Windows bundle contract in $bundleDirectory');
    }
    if (platform == 'linux') {
      stdout.writeln(
        'Bundle full libmpv into $bundleDirectory/lib '
        '(sources: /usr/lib/<arch>-linux-gnu via scripts/linux/bundle_full_libmpv.dart).',
      );
      stdout.writeln(
        'Package the bundle into a .deb via dpkg-deb, a .rpm via fpm, and '
        'an .AppImage via appimagetool under dist/.',
      );
    }
    if (platform == 'macos') {
      stdout.writeln(
        'Verify full libmpv/FFmpeg in $bundleDirectory via '
        'scripts/macos/verify_full_libmpv.dart.',
      );
      stdout.writeln(
        'Ad-hoc sign .app with codesign to avoid "app is damaged" on '
        'first launch.',
      );
      stdout.writeln(
        'Package .app into a distributable .dmg via hdiutil.',
      );
    }
    return;
  }
  final nativeLibrary = File(nativeLibraryPath);
  if (!await nativeLibrary.exists()) {
    _fail('Native obfuscator library is missing after the Go build');
  }
  final bundle = Directory(bundleDirectory);
  if (!await bundle.exists()) {
    _fail('Desktop release bundle is missing after the Flutter build');
  }
  await nativeLibrary.copy(bundleLibraryPath);
  if (platform == 'linux') {
    await _applyLinuxArm64EnginePatch(
      bundleDirectory: bundleDirectory,
      architecture: architecture,
    );
    await _runLinuxFullLibmpvBundle(bundleDirectory);
    await _runLinuxPackaging(
      bundleDirectory: bundleDirectory,
      architecture: architecture,
    );
  }
  if (platform == 'macos') {
    await _runMacosFullLibmpvVerify(bundleDirectory);
    await _runMacosAdHocSign(bundleDirectory);
    await _runMacosPackageDmg(
      bundleDirectory: bundleDirectory,
      architecture: architecture,
    );
  }
  if (platform == 'windows') {
    await _runWindowsIdentityCheck();
    try {
      final summary = await verifyWindowsBundleContract(
        architecture: architecture,
        bundleDirectory: bundleDirectory,
      );
      stdout.writeln(encodeWindowsBundleSummary(summary));
    } on WindowsBundleContractFailure catch (error) {
      _fail(error.message);
    }
  }
}

Future<void> _deleteGeneratedSecretSource(
  String obfuscatorDirectory, {
  required bool dryRun,
}) async {
  final sourceFile = File(
    '$obfuscatorDirectory${Platform.pathSeparator}internal${Platform.pathSeparator}'
    'secret${Platform.pathSeparator}config_gen.go',
  );
  if (dryRun) {
    stdout.writeln('Delete ${sourceFile.path}');
    return;
  }
  if (await sourceFile.exists()) {
    await sourceFile.delete();
  }
}

Future<void> _runProcess({
  required String executable,
  required List<String> arguments,
  String? workingDirectory,
  Map<String, String>? environment,
  required bool dryRun,
}) async {
  final resolvedExecutable = _resolveExecutable(executable);
  if (dryRun) {
    stdout.writeln('$resolvedExecutable ${arguments.join(' ')}');
    return;
  }
  final process = await Process.start(
    resolvedExecutable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    mode: ProcessStartMode.inheritStdio,
  );
  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    _fail('$resolvedExecutable failed with exit code $exitCode');
  }
}

String _resolveExecutable(String executable) {
  if (Platform.isWindows && executable == 'flutter') {
    return 'flutter.bat';
  }
  return executable;
}

String _nativeLibraryPath({
  required String obfuscatorDirectory,
  required String platform,
  required String goArchitecture,
  required String libraryName,
}) {
  final goOperatingSystem = platform == 'macos' ? 'darwin' : platform;
  return '$obfuscatorDirectory${Platform.pathSeparator}build${Platform.pathSeparator}'
      '${goOperatingSystem}_$goArchitecture${Platform.pathSeparator}$libraryName';
}

String _bundleDirectory(String platform, String architecture) {
  return switch (platform) {
    'windows' => 'build/windows/$architecture/runner/Release',
    'linux' => 'build/linux/$architecture/release/bundle',
    'macos' =>
      'build/macos/Build/Products/Release/FlyNarwhal.app/Contents/MacOS',
    _ => throw ArgumentError.value(platform, 'platform'),
  };
}

Future<void> _runWindowsIdentityCheck() async {
  await _runProcess(
    executable: 'dart',
    arguments: const <String>[
      'run',
      'scripts/windows/verify_identity_contract.dart'
    ],
    dryRun: false,
  );
}

/// The official Flutter linux-arm64 release engine is built without
/// fontconfig, so it cannot discover system CJK fonts and Chinese text
/// renders as boxes (the bundled SourceHanSansSC variable font also fails to
/// render on Linux). A fontconfig-enabled libflutter_linux_gtk.so is committed
/// per Flutter version under scripts/linux/patched-engine/ and swapped into
/// the bundle before packaging. The linux-x64 engine already ships fontconfig
/// and needs no patch.
Future<void> _applyLinuxArm64EnginePatch({
  required String bundleDirectory,
  required String architecture,
}) async {
  if (architecture != 'arm64') {
    return;
  }
  final flutterVersion = await _flutterFrameworkVersion();
  final patchedEngine = File(
    'scripts/linux/patched-engine/linux-arm64-$flutterVersion/'
    'libflutter_linux_gtk.so',
  );
  if (!await patchedEngine.exists()) {
    _fail(
      'No fontconfig-patched engine for Flutter $flutterVersion at '
      '${patchedEngine.path}. The official linux-arm64 engine cannot render '
      'CJK text; build a patched libflutter_linux_gtk.so (--enable-fontconfig) '
      'for this Flutter version and commit it under '
      'scripts/linux/patched-engine/.',
    );
  }
  final target = File('$bundleDirectory/lib/libflutter_linux_gtk.so');
  await patchedEngine.copy(target.path);
  stdout.writeln(
    'Applied fontconfig-patched linux-arm64 engine for Flutter '
    '$flutterVersion.',
  );
}

Future<String> _flutterFrameworkVersion() async {
  final result = await Process.run(
    _resolveExecutable('flutter'),
    const <String>['--version', '--machine'],
  );
  if (result.exitCode != 0) {
    _fail('flutter --version --machine failed: ${result.stderr}');
  }
  final info = jsonDecode(result.stdout as String) as Map<String, dynamic>;
  final version = info['frameworkVersion'] as String?;
  if (version == null || version.isEmpty) {
    _fail('Could not parse frameworkVersion from flutter --version --machine');
  }
  return version;
}

Future<void> _runLinuxFullLibmpvBundle(String bundleDirectory) async {
  // The Ubuntu Noble runners (x64 + arm64) expose libmpv.so.2 under
  // /usr/lib/<arch>-linux-gnu. We deliberately point the script at that root
  // so it can resolve the full dependency closure (libass, libavcodec, ...).
  const sourceRoots = <String>[
    '/usr/lib/x86_64-linux-gnu',
    '/usr/lib/aarch64-linux-gnu',
    '/usr/lib64',
    '/usr/lib',
  ];
  for (final root in sourceRoots) {
    if (Directory(root).existsSync()) {
      await _runProcess(
        executable: 'dart',
        arguments: <String>[
          'run',
          'scripts/linux/bundle_full_libmpv.dart',
          bundleDirectory,
          root,
        ],
        dryRun: false,
      );
      return;
    }
  }
  _fail(
    'Could not find a libmpv source directory under '
    '${sourceRoots.join(', ')}. Install mpv/libmpv-dev before building Linux.',
  );
}

Future<void> _runLinuxPackaging({
  required String bundleDirectory,
  required String architecture,
}) async {
  // The .deb and the .rpm share the same staged payload; the AppImage is
  // assembled separately from the raw bundle because it needs a relative
  // Exec/Icon layout instead of absolute /opt paths.
  final stagingRoot = await _stageLinuxPackageTree(
    bundleDirectory: bundleDirectory,
    architecture: architecture,
  );
  try {
    // Build the rpm before the deb control file is written into the staging
    // tree, otherwise fpm would package the DEBIAN/ directory as payload.
    await _runLinuxPackageRpm(
      stagingRoot: stagingRoot,
      architecture: architecture,
    );
    await _runLinuxPackageDeb(
      stagingRoot: stagingRoot,
      architecture: architecture,
    );
  } finally {
    if (await stagingRoot.exists()) {
      await stagingRoot.delete(recursive: true);
    }
  }
  await _runLinuxPackageAppImage(
    bundleDirectory: bundleDirectory,
    architecture: architecture,
  );
}

/// Stages the Linux bundle as a filesystem payload shared by the .deb and
/// .rpm packages. bundleDirectory points at .../bundle; the Flutter bundle is
/// laid out as
///   bundle/fly_narwhal   (ELF binary)
///   bundle/lib/          (shared libs + native assets)
///   bundle/data/         (flutter_assets)
/// The ELF links against $ORIGIN/lib, so the whole tree must be installed
/// together. We place it under /opt/fly_narwhal and push a /usr/bin symlink.
Future<Directory> _stageLinuxPackageTree({
  required String bundleDirectory,
  required String architecture,
}) async {
  final stagingRoot = Directory('build/linux/$architecture/pkg-staging');
  if (await stagingRoot.exists()) {
    await stagingRoot.delete(recursive: true);
  }
  final optDir = Directory('${stagingRoot.path}/opt/fly_narwhal');
  await optDir.create(recursive: true);

  final bundle = Directory(bundleDirectory);
  await _copyDirectory(bundle, optDir);

  // /usr/bin/fly_narwhal -> /opt/fly_narwhal/fly_narwhal
  final usrBin = Directory('${stagingRoot.path}/usr/bin');
  await usrBin.create(recursive: true);
  await Process.run('ln', <String>[
    '-s',
    '/opt/fly_narwhal/fly_narwhal',
    '${usrBin.path}/fly_narwhal',
  ]);

  // /usr/share/applications/fly-narwhal.desktop launcher
  final desktopDir = Directory('${stagingRoot.path}/usr/share/applications');
  await desktopDir.create(recursive: true);
  final desktopFile = File('${desktopDir.path}/fly-narwhal.desktop');
  await desktopFile.writeAsString('''
[Desktop Entry]
Type=Application
Name=FlyNarwhal
Name[zh_CN]=飞鲸影视
Comment=Flutter desktop media player
Exec=/opt/fly_narwhal/fly_narwhal
Terminal=false
Categories=AudioVideo;Player;
''');

  // /usr/share/icons/hicolor/.../apps/fly-narwhal.png (from the Linux runner)
  final iconSource = File('linux/runner/resources/app_icon.png');
  if (await iconSource.exists()) {
    final iconDir =
        Directory('${stagingRoot.path}/usr/share/icons/hicolor/512x512/apps');
    await iconDir.create(recursive: true);
    await iconSource.copy('${iconDir.path}/fly-narwhal.png');
    desktopFile.writeAsStringSync(
      '${await desktopFile.readAsString()}'
      'Icon=/usr/share/icons/hicolor/512x512/apps/fly-narwhal.png\n',
    );
  }
  return stagingRoot;
}

Future<void> _runLinuxPackageDeb({
  required Directory stagingRoot,
  required String architecture,
}) async {
  final version = _packageVersion();
  final debArch = architecture == 'arm64' ? 'arm64' : 'amd64';

  // Match the in-app updater's asset regex so the release is discoverable:
  // FlyNarwhal_Setup_Linux_(amd64|aarch64)_<version>.deb
  final debName =
      'FlyNarwhal_Setup_Linux_${_updateArch(architecture)}_$version.deb';
  final distDir = Directory('dist');
  await distDir.create(recursive: true);
  final debPath = '${distDir.path}/$debName';

  // dpkg-deb control file
  final controlDir = Directory('${stagingRoot.path}/DEBIAN');
  await controlDir.create(recursive: true);
  await File('${controlDir.path}/control').writeAsString('''
Package: fly-narwhal
Version: $version
Section: video
Priority: optional
Architecture: $debArch
Maintainer: FlyNarwhal <dev@flynarwhal.app>
Description: FlyNarwhal desktop media player
 Flutter-based desktop media player for FlyNarwhal.
''');

  await _runProcess(
    executable: 'dpkg-deb',
    arguments: <String>[
      '--build',
      '--root-owner-group',
      stagingRoot.path,
      debPath,
    ],
    dryRun: false,
  );
  await _validateDebPackage(File(debPath));
  stdout.writeln('Created Debian package: $debPath');
}

Future<void> _runLinuxPackageRpm({
  required Directory stagingRoot,
  required String architecture,
}) async {
  final version = _packageVersion();
  // RPM versions cannot contain '-', so a prerelease suffix such as
  // 2.0.3-Alpha moves into the Release/iteration field (2.0.3 / Alpha) while
  // the published filename keeps the full version for the updater contract.
  final dashIndex = version.indexOf('-');
  final rpmVersion = dashIndex < 0 ? version : version.substring(0, dashIndex);
  final rpmIteration = dashIndex < 0 ? '1' : version.substring(dashIndex + 1);
  final rpmArch = architecture == 'arm64' ? 'aarch64' : 'x86_64';

  // Match the in-app updater's asset regex so the release is discoverable:
  // FlyNarwhal_Setup_Linux_(amd64|aarch64)_<version>.rpm
  final rpmName =
      'FlyNarwhal_Setup_Linux_${_updateArch(architecture)}_$version.rpm';
  final distDir = Directory('dist');
  await distDir.create(recursive: true);
  final rpmPath = '${distDir.path}/$rpmName';

  // fpm packages the staged payload (opt/, usr/) from the staging root using
  // the paths as-is, mirroring the .deb layout. The output path is pinned with
  // --package so the filename is deterministic regardless of fpm's defaults.
  await _runProcess(
    executable: 'fpm',
    arguments: <String>[
      '--force',
      '-s',
      'dir',
      '-t',
      'rpm',
      '-n',
      'fly-narwhal',
      '-v',
      rpmVersion,
      '--iteration',
      rpmIteration,
      '-a',
      rpmArch,
      '--category',
      'video',
      '--maintainer',
      'FlyNarwhal <dev@flynarwhal.app>',
      '--description',
      'FlyNarwhal desktop media player',
      '-C',
      stagingRoot.path,
      '--package',
      rpmPath,
      'opt',
      'usr',
    ],
    dryRun: false,
  );
  await _validateRpmPackage(File(rpmPath), architecture);
  stdout.writeln('Created RPM package: $rpmPath');
}

Future<void> _runLinuxPackageAppImage({
  required String bundleDirectory,
  required String architecture,
}) async {
  final version = _packageVersion();

  // Match the in-app updater's asset regex so the release is discoverable:
  // FlyNarwhal_Setup_Linux_(amd64|aarch64)_<version>.AppImage
  final appImageName =
      'FlyNarwhal_Setup_Linux_${_updateArch(architecture)}_$version.AppImage';
  final distDir = Directory('dist');
  await distDir.create(recursive: true);
  final appImagePath = '${distDir.path}/$appImageName';

  // AppDir layout: the Flutter bundle sits at the AppDir root. The ELF binary
  // resolves its libraries via the $ORIGIN/lib rpath, so no relocation is
  // needed and AppRun can simply exec the binary from its own directory.
  final stagingRoot = Directory('build/linux/$architecture/appimage-staging');
  if (await stagingRoot.exists()) {
    await stagingRoot.delete(recursive: true);
  }
  final appDirRoot = Directory('${stagingRoot.path}/FlyNarwhal.AppDir');
  await appDirRoot.create(recursive: true);
  await _copyDirectory(Directory(bundleDirectory), appDirRoot);

  // appimagetool requires a root-level .desktop whose Exec/Icon entries are
  // relative to the AppDir (unlike the absolute paths in the deb/rpm payload).
  await File('${appDirRoot.path}/fly-narwhal.desktop').writeAsString('''
[Desktop Entry]
Type=Application
Name=FlyNarwhal
Name[zh_CN]=飞鲸影视
Comment=Flutter desktop media player
Exec=fly_narwhal
Icon=fly-narwhal
Terminal=false
Categories=AudioVideo;Player;
X-AppImage-Version=$version
''');

  final iconSource = File('linux/runner/resources/app_icon.png');
  if (!await iconSource.exists()) {
    _fail('Linux app icon is missing: ${iconSource.path}');
  }
  await iconSource.copy('${appDirRoot.path}/fly-narwhal.png');
  await iconSource.copy('${appDirRoot.path}/.DirIcon');

  final appRun = File('${appDirRoot.path}/AppRun');
  await appRun.writeAsString('''
#!/bin/sh
SELF="\$(readlink -f "\$0")"
HERE="\$(dirname "\$SELF")"
export LD_LIBRARY_PATH="\$HERE/lib\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
exec "\$HERE/fly_narwhal" "\$@"
''');
  final chmodResult = await Process.run('chmod', <String>['+x', appRun.path]);
  if (chmodResult.exitCode != 0) {
    _fail('Failed to make AppRun executable: ${chmodResult.stderr}');
  }

  await _runProcess(
    executable: 'appimagetool',
    arguments: <String>[
      '--appimage-extract-and-run',
      appDirRoot.path,
      appImagePath,
    ],
    // appimagetool picks the embedded runtime by architecture; make the
    // choice explicit instead of relying on its ELF sniffing.
    environment: <String, String>{
      'ARCH': architecture == 'arm64' ? 'aarch64' : 'x86_64',
    },
    dryRun: false,
  );
  await stagingRoot.delete(recursive: true);
  await _validateAppImagePackage(File(appImagePath));
  stdout.writeln('Created AppImage: $appImagePath');
}

String _updateArch(String architecture) =>
    architecture == 'arm64' ? 'aarch64' : 'amd64';

/// Verifies that a built package exists and is non-empty.
Future<void> _validatePackageExists(File package) async {
  if (!await package.exists()) {
    _fail('Package is missing: ${package.path}');
  }
  final size = await package.length();
  if (size == 0) {
    _fail('Package is empty: ${package.path}');
  }
}

/// Validates a Debian package with dpkg-deb.
Future<void> _validateDebPackage(File deb) async {
  await _validatePackageExists(deb);
  // dpkg-deb is only guaranteed to exist on Debian/Ubuntu hosts. On other
  // platforms this is a warning rather than a hard failure because the real
  // release builds always run on Ubuntu.
  if (!Platform.isLinux) {
    stdout.writeln('Skipping dpkg-deb validation on non-Linux host');
    return;
  }
  final result = await Process.run(
    'dpkg-deb',
    <String>['--info', deb.path],
  );
  if (result.exitCode != 0) {
    _fail('dpkg-deb validation failed for ${deb.path}: ${result.stderr}');
  }
}

/// Validates an RPM package with rpm -qpi and checks the architecture field.
Future<void> _validateRpmPackage(File rpm, String architecture) async {
  await _validatePackageExists(rpm);
  if (!Platform.isLinux) {
    stdout.writeln('Skipping rpm validation on non-Linux host');
    return;
  }
  final result = await Process.run(
    'rpm',
    <String>['-qpi', rpm.path],
  );
  if (result.exitCode != 0) {
    _fail('rpm validation failed for ${rpm.path}: ${result.stderr}');
  }
  final expectedArch =
      _updateArch(architecture) == 'aarch64' ? 'aarch64' : 'x86_64';
  final output = result.stdout.toString();
  if (!output.contains('Architecture: $expectedArch')) {
    _fail(
      'RPM architecture mismatch for ${rpm.path}: expected $expectedArch, '
      'rpm output was:\n$output',
    );
  }
}

/// Validates an AppImage by checking it is executable and the embedded runtime
/// can report its own version (a headless-safe operation that does not launch
/// the payload).
Future<void> _validateAppImagePackage(File appImage) async {
  await _validatePackageExists(appImage);
  final stat = await appImage.stat();
  if (stat.mode & 0x111 == 0) {
    _fail('AppImage is not executable: ${appImage.path}');
  }
  if (!Platform.isLinux) {
    stdout.writeln('Skipping AppImage runtime validation on non-Linux host');
    return;
  }
  final result = await Process.run(
    appImage.path,
    <String>['--appimage-version'],
    environment: <String, String>{...Platform.environment},
  );
  if (result.exitCode != 0) {
    _fail(
      'AppImage runtime validation failed for ${appImage.path}: ${result.stderr}',
    );
  }
}

Future<void> _copyDirectory(Directory source, Directory target) async {
  for (final entity in source.listSync(recursive: true)) {
    final relative = entity.path.substring(source.path.length + 1);
    final destination = '${target.path}/$relative';
    if (entity is File) {
      await File(entity.path).copy(destination);
    } else if (entity is Directory) {
      await Directory(destination).create(recursive: true);
    }
  }
}

Future<void> _runMacosFullLibmpvVerify(String bundleDirectory) async {
  // bundleDirectory points at .../Contents/MacOS; the .app root is two
  // directories up from there (Contents/MacOS -> Contents -> FlyNarwhal.app).
  final appRoot = Directory(bundleDirectory).parent.parent.path;
  await _runProcess(
    executable: 'dart',
    arguments: <String>[
      'run',
      'scripts/macos/verify_full_libmpv.dart',
      appRoot,
    ],
    dryRun: false,
  );
}

Future<void> _runMacosAdHocSign(String bundleDirectory) async {
  // bundleDirectory points at .../Contents/MacOS; the .app root is two
  // directories up from there (Contents/MacOS -> Contents -> FlyNarwhal.app).
  final appRoot = Directory(bundleDirectory).parent.parent.path;
  if (!Directory(appRoot).existsSync()) {
    _fail('FlyNarwhal.app is missing; cannot ad-hoc sign');
  }

  // Ad-hoc signing does not require an Apple Developer certificate and is
  // sufficient to prevent the "app is damaged" Gatekeeper prompt on first
  // launch. Users will still see an "unidentified developer" warning that can
  // be bypassed via System Settings or xattr (see README).
  stdout.writeln('Ad-hoc signing $appRoot...');
  await _runProcess(
    executable: 'codesign',
    arguments: <String>[
      '--force',
      '--deep',
      '--sign',
      '-',
      appRoot,
    ],
    dryRun: false,
  );
}

Future<void> _runMacosPackageDmg({
  required String bundleDirectory,
  required String architecture,
}) async {
  // bundleDirectory points at .../FlyNarwhal.app/Contents/MacOS; the .app root
  // is two directories up, and the release products dir (where the update
  // workflow expects *_*.dmg) is one further up.
  final appRoot = Directory(bundleDirectory).parent.parent.path;
  final releaseDir = Directory(bundleDirectory).parent.parent.parent.path;
  if (!Directory(appRoot).existsSync()) {
    _fail('FlyNarwhal.app is missing; cannot build a DMG');
  }

  // Archive naming must match the app's update-asset regex
  // (^FlyNarwhal_Setup_(Windows|MacOS|Linux)_(amd64|aarch64)_([^/]+)\.dmg$)
  // so the in-app auto-updater can discover and install it.
  final archTag = architecture == 'arm64' ? 'aarch64' : 'amd64';
  final version = _packageVersion();
  final dmgName = 'FlyNarwhal_Setup_MacOS_${archTag}_$version.dmg';
  final dmgPath = '$releaseDir/$dmgName';

  // create-dmg assembles the volume (app + Applications symlink + background),
  // but its Finder-pretty AppleScript step needs a GUI session and is flaky on
  // CI, so we pass --skip-jenkins and instead inject a pre-generated .DS_Store
  // (assets/macos/dmg/DS_Store) that encodes the same icon-view layout: window
  // 600x400 at (200,120), icon size 96, FlyNarwhal.app at (150,210) and the
  // Applications link at (450,210), dark gradient background. The result is
  // deterministic on CI and locally. The .DS_Store is generated by
  // scripts/macos/generate_dmg_dsstore.py (pip install ds_store mac_alias);
  // the background is rendered by scripts/macos/generate_dmg_background.swift.
  // Keep the coordinates in those scripts in sync with the flags below.
  final volumeIcon = '$appRoot/Contents/Resources/AppIcon.icns';
  final arguments = <String>[
    '--volname', 'FlyNarwhal',
    '--background', 'assets/macos/dmg-background.png',
    '--window-pos', '200', '120',
    '--window-size', '600', '400',
    '--icon-size', '96',
    '--icon', 'FlyNarwhal.app', '150', '210',
    '--app-drop-link', '450', '210',
    '--skip-jenkins',
    '--overwrite',
    // --add-file takes target, source, x and y; the coordinates are only used
    // by the (skipped) AppleScript, so park the hidden .DS_Store off-view.
    '--add-file', '.DS_Store', 'assets/macos/dmg/DS_Store', '0', '0',
    if (File(volumeIcon).existsSync()) ...['--volicon', volumeIcon],
    dmgPath,
    appRoot,
  ];
  await _runProcess(
    executable: 'create-dmg',
    arguments: arguments,
    dryRun: false,
  );
  stdout.writeln('Created macOS disk image: $dmgPath');
}

String _packageVersion() {
  final pubspec = File('pubspec.yaml');
  for (final line in pubspec.readAsLinesSync()) {
    // Match the full major.minor.patch plus any prerelease suffix (e.g. -Alpha),
    // stopping before +build metadata. Asset filenames must embed the same
    // version the in-app updater parses from the release tag, so a prerelease
    // tag like v2.0.2-Alpha must produce _2.0.2-Alpha.dmg, not _2.0.2.dmg.
    final match =
        RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?)')
            .firstMatch(line.trim());
    if (match != null) {
      return match.group(1)!;
    }
  }
  _fail('Could not read version from pubspec.yaml');
}

_BuildArguments _parseArguments(List<String> arguments) {
  final normalizedArguments = List<String>.of(arguments);
  final dryRun = normalizedArguments.remove('--dry-run');
  if (normalizedArguments.length != 2) {
    _fail(
      'Usage: dart run scripts/release/build_desktop.dart '
      '<platform> <architecture> [--dry-run]',
    );
  }
  return _BuildArguments(
    platform: normalizedArguments[0],
    architecture: normalizedArguments[1],
    dryRun: dryRun,
  );
}

void _validateRequiredSecrets() {
  for (final key in _requiredSecrets) {
    if ((Platform.environment[key] ?? '').trim().isEmpty) {
      _fail('$key is required for release builds');
    }
  }
}

String _requiredEnvironmentValue(String key) {
  final value = Platform.environment[key]?.trim();
  if (value == null || value.isEmpty) {
    _fail('$key is required');
  }
  return value;
}

void _validateTarget(String platform, String architecture) {
  const supportedPlatforms = <String>{'windows', 'macos', 'linux'};
  const supportedArchitectures = <String>{'x64', 'arm64'};
  if (!supportedPlatforms.contains(platform) ||
      !supportedArchitectures.contains(architecture)) {
    _fail('Unsupported desktop target: $platform-$architecture');
  }
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}

class _BuildArguments {
  const _BuildArguments({
    required this.platform,
    required this.architecture,
    required this.dryRun,
  });

  final String platform;
  final String architecture;
  final bool dryRun;
}
