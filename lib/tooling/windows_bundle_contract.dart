import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:fly_narwhal/services/update/update_path_safety.dart';
import 'package:path/path.dart' as path;

const windowsAppExecutable = 'FlyNarwhal.exe';
const windowsUpdaterExecutable = 'updater.exe';
const legacyWindowsUpdaterExecutables = <String>[
  'flynarwhal-updater.exe',
  'fntv-updater.exe',
];

final class WindowsBundleContractFailure implements Exception {
  const WindowsBundleContractFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

final class PortableExecutableInfo {
  const PortableExecutableInfo({required this.machine});

  final int machine;

  String get machineName {
    return switch (machine) {
      0x8664 => 'amd64',
      0xAA64 => 'arm64',
      _ => 'unknown(0x${machine.toRadixString(16)})',
    };
  }
}

final class WindowsBundleSummary {
  const WindowsBundleSummary({
    required this.architecture,
    required this.bundleDirectory,
    required this.applicationPath,
    required this.updaterPath,
    required this.updaterMachine,
    required this.updaterSize,
    required this.updaterSha256,
  });

  final String architecture;
  final String bundleDirectory;
  final String applicationPath;
  final String updaterPath;
  final int updaterMachine;
  final int updaterSize;
  final String updaterSha256;

  Map<String, Object> toJson() {
    return <String, Object>{
      'architecture': architecture,
      'bundleDirectory': bundleDirectory,
      'applicationPath': applicationPath,
      'bundleArtifact': windowsUpdaterExecutable,
      'updaterPath': updaterPath,
      'updaterMachine':
          PortableExecutableInfo(machine: updaterMachine).machineName,
      'size': updaterSize,
      'sha256': updaterSha256,
    };
  }
}

Future<WindowsBundleSummary> verifyWindowsBundleContract({
  required String architecture,
  required String bundleDirectory,
}) async {
  final bundle = Directory(bundleDirectory);
  if (!await bundle.exists()) {
    throw WindowsBundleContractFailure(
      'Windows release bundle is missing: ${bundle.path}',
    );
  }
  if (!await UpdatePathSafety.isSafeDirectoryTree(bundle.path)) {
    throw WindowsBundleContractFailure(
      'Windows release bundle is unsafe: ${bundle.path}',
    );
  }

  final appFile = File(path.join(bundle.path, windowsAppExecutable));
  final updaterFile = File(path.join(bundle.path, windowsUpdaterExecutable));
  await _ensureSafeNonEmptyFile(
    appFile,
    description: 'Windows application executable',
  );
  await _ensureSafeNonEmptyFile(
    updaterFile,
    description: 'Windows updater executable',
  );

  final updaterMatches =
      await _findFilesNamed(bundle, windowsUpdaterExecutable);
  if (updaterMatches.length != 1 ||
      !path.equals(updaterMatches.single.path, updaterFile.path)) {
    throw WindowsBundleContractFailure(
      'Expected exactly one $windowsUpdaterExecutable in the bundle root, '
      'found ${updaterMatches.length}.',
    );
  }

  for (final legacyUpdaterExecutable in legacyWindowsUpdaterExecutables) {
    final legacyMatches = await _findFilesNamed(bundle, legacyUpdaterExecutable);
    if (legacyMatches.isNotEmpty) {
      throw WindowsBundleContractFailure(
        'Windows bundle still contains legacy updater '
        '$legacyUpdaterExecutable.',
      );
    }
  }

  final expectedMachine = expectedWindowsMachine(architecture);
  final appInfo = await readPortableExecutableInfo(appFile);
  final updaterInfo = await readPortableExecutableInfo(updaterFile);
  if (appInfo.machine != expectedMachine) {
    throw WindowsBundleContractFailure(
      '$windowsAppExecutable machine ${appInfo.machineName} does not match '
      'requested architecture $architecture.',
    );
  }
  if (updaterInfo.machine != expectedMachine) {
    throw WindowsBundleContractFailure(
      '$windowsUpdaterExecutable machine ${updaterInfo.machineName} does not '
      'match requested architecture $architecture.',
    );
  }

  final bytes = await updaterFile.readAsBytes();
  return WindowsBundleSummary(
    architecture: architecture,
    bundleDirectory: bundle.path,
    applicationPath: appFile.path,
    updaterPath: updaterFile.path,
    updaterMachine: updaterInfo.machine,
    updaterSize: bytes.length,
    updaterSha256: sha256.convert(bytes).toString(),
  );
}

int expectedWindowsMachine(String architecture) {
  return switch (architecture) {
    'x64' => 0x8664,
    'arm64' => 0xAA64,
    _ => throw ArgumentError.value(architecture, 'architecture'),
  };
}

Future<PortableExecutableInfo> readPortableExecutableInfo(File file) async {
  final randomAccessFile = await file.open();
  try {
    final minimumHeader = await randomAccessFile.read(64);
    if (minimumHeader.length < 64 ||
        minimumHeader[0] != 0x4D ||
        minimumHeader[1] != 0x5A) {
      throw WindowsBundleContractFailure(
        'File is not a PE executable: ${file.path}',
      );
    }
    final dosHeader = ByteData.sublistView(Uint8List.fromList(minimumHeader));
    final peOffset = dosHeader.getUint32(0x3C, Endian.little);
    await randomAccessFile.setPosition(peOffset);
    final peHeader = await randomAccessFile.read(24);
    if (peHeader.length < 24 ||
        peHeader[0] != 0x50 ||
        peHeader[1] != 0x45 ||
        peHeader[2] != 0x00 ||
        peHeader[3] != 0x00) {
      throw WindowsBundleContractFailure(
        'File has an invalid PE header: ${file.path}',
      );
    }
    final headerData = ByteData.sublistView(Uint8List.fromList(peHeader));
    final machine = headerData.getUint16(4, Endian.little);
    return PortableExecutableInfo(machine: machine);
  } finally {
    await randomAccessFile.close();
  }
}

String encodeWindowsBundleSummary(WindowsBundleSummary summary) {
  return jsonEncode(summary.toJson());
}

Future<void> _ensureSafeNonEmptyFile(
  File file, {
  required String description,
}) async {
  if (!await file.exists()) {
    throw WindowsBundleContractFailure('$description is missing: ${file.path}');
  }
  if (!await UpdatePathSafety.isSafeRegularFile(file.path)) {
    throw WindowsBundleContractFailure(
      '$description is not a safe regular file: ${file.path}',
    );
  }
  if (await file.length() <= 0) {
    throw WindowsBundleContractFailure('$description is empty: ${file.path}');
  }
}

Future<List<File>> _findFilesNamed(Directory root, String baseName) async {
  final matches = <File>[];
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    if (entity is File &&
        path.basename(entity.path).toLowerCase() == baseName.toLowerCase()) {
      matches.add(entity);
    }
  }
  return matches;
}
