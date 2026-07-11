import 'dart:convert';
import 'dart:io';

const _requiredSecrets = <String>[
  'FLY_NARWHAL_API_SECRET',
  'FLY_NARWHAL_SECRET',
];

const _allConfigurationKeys = <String>[
  ..._requiredSecrets,
  'REPORT_URL',
  'REPORT_API_SECRET',
];

Future<void> main(List<String> arguments) async {
  if (arguments.length != 2) {
    stderr.writeln(
        'Usage: dart run scripts/release/build_desktop.dart <platform> <architecture>');
    exitCode = 64;
    return;
  }

  final platform = arguments[0];
  final architecture = arguments[1];
  _validateTarget(platform, architecture);
  final configuration = _readBuildConfiguration();
  final privateToolDirectory =
      Platform.environment['OBFUSCATOR_TOOL_DIRECTORY'];
  if (privateToolDirectory == null || privateToolDirectory.isEmpty) {
    _fail(
        'OBFUSCATOR_TOOL_DIRECTORY must reference the verified private checkout');
  }

  final workspaceDirectory = Directory.current;
  final outputDirectory = Directory(
    '${workspaceDirectory.path}${Platform.pathSeparator}generated-obfuscator${Platform.pathSeparator}$platform-$architecture',
  );
  if (outputDirectory.existsSync()) {
    await outputDirectory.delete(recursive: true);
  }
  await outputDirectory.create(recursive: true);

  try {
    await _runPrivateGenerator(
      privateToolDirectory: privateToolDirectory,
      outputDirectory: outputDirectory.path,
      platform: platform,
      architecture: architecture,
      configuration: configuration,
    );
    await _runFlutterBuild(platform, architecture, outputDirectory.path);
  } finally {
    configuration.clear();
  }
}

Map<String, String> _readBuildConfiguration() {
  final configuration = <String, String>{};
  for (final key in _allConfigurationKeys) {
    configuration[key] = Platform.environment[key] ?? '';
  }
  for (final key in _requiredSecrets) {
    if (configuration[key]!.trim().isEmpty) {
      _fail('$key is required for release builds');
    }
  }
  return configuration;
}

Future<void> _runPrivateGenerator({
  required String privateToolDirectory,
  required String outputDirectory,
  required String platform,
  required String architecture,
  required Map<String, String> configuration,
}) async {
  final executable = Platform.isWindows ? 'generate.exe' : 'generate';
  final generatorPath =
      '$privateToolDirectory${Platform.pathSeparator}bin${Platform.pathSeparator}$executable';
  if (!File(generatorPath).existsSync()) {
    _fail('Verified private generator executable is missing');
  }

  final generatorInput = <String, Object>{
    'protocolVersion': 1,
    'platform': platform,
    'architecture': architecture,
    'outputDirectory': outputDirectory,
    'configuration': configuration,
  };
  final process = await Process.start(
    generatorPath,
    const <String>[],
    workingDirectory: privateToolDirectory,
  );
  process.stdin
    ..write(jsonEncode(generatorInput))
    ..close();
  final stdoutFuture = process.stdout.drain<void>();
  final stderrFuture = process.stderr.drain<void>();
  final exitCode = await process.exitCode;
  await Future.wait(<Future<void>>[stdoutFuture, stderrFuture]);
  if (exitCode != 0) {
    _fail('Private obfuscator generator failed');
  }
}

Future<void> _runFlutterBuild(
  String platform,
  String architecture,
  String generatedOutputDirectory,
) async {
  final flutterArguments = <String>[
    'build',
    platform,
    '--release',
    '--obfuscate',
    '--split-debug-info=symbols/$platform-$architecture',
  ];
  if (platform == 'windows') {
    flutterArguments
        .addAll(<String>['--target-platform', 'windows-$architecture']);
  }
  final process = await Process.start(
    'flutter',
    flutterArguments,
    environment: <String, String>{
      ...Platform.environment,
      'FLY_NARWHAL_OBFUSCATOR_OUTPUT': generatedOutputDirectory,
    },
    mode: ProcessStartMode.inheritStdio,
  );
  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    _fail('Flutter $platform release build failed with exit code $exitCode');
  }
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
