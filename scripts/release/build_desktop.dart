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
