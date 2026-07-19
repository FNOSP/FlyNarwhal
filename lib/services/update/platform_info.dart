import 'dart:io';

import '../../domain/update/entities/update_models.dart';

/// Host OS identity exposed by the infrastructure environment adapter.
enum HostOperatingSystem { windows, macos, linux, unsupported }

/// Injectable environment operations used by reliable platform detection.
abstract interface class PlatformEnvironment {
  HostOperatingSystem get hostOperatingSystem;
  String get executablePath;
  Map<String, String> get environment;
  Future<String?> runArchitectureProbe();
  Future<String?> readLinuxOsRelease();
}

/// Parsed Linux distribution metadata relevant to package selection.
final class LinuxOsReleaseInfo {
  const LinuxOsReleaseInfo({
    required this.id,
    required this.idLike,
    required this.family,
  });

  final String? id;
  final List<String> idLike;
  final LinuxDistributionFamily family;
}

/// Parses ID and ID_LIKE without relying on substring matching.
final class LinuxOsReleaseParser {
  const LinuxOsReleaseParser();

  LinuxOsReleaseInfo parse(String contents) {
    final fields = <String, String>{};
    for (final line in contents.split('\n')) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty || trimmedLine.startsWith('#')) {
        continue;
      }
      final separatorIndex = trimmedLine.indexOf('=');
      if (separatorIndex <= 0) {
        continue;
      }
      final key = trimmedLine.substring(0, separatorIndex).trim();
      final rawValue = trimmedLine.substring(separatorIndex + 1).trim();
      fields[key] = _unquote(rawValue).toLowerCase();
    }
    final id = fields['ID'];
    final idLike = fields['ID_LIKE']
            ?.split(RegExp(r'\s+'))
            .where((value) => value.isNotEmpty)
            .toList(growable: false) ??
        const <String>[];
    final identities = <String>{...idLike};
    if (id != null) {
      identities.add(id);
    }
    return LinuxOsReleaseInfo(
      id: id,
      idLike: idLike,
      family: _classify(identities),
    );
  }

  String _unquote(String value) {
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      return value.substring(1, value.length - 1).replaceAll(r'\"', '"');
    }
    return value;
  }

  LinuxDistributionFamily _classify(Set<String> identities) {
    const debianIdentities = <String>{'debian', 'ubuntu'};
    const rpmIdentities = <String>{
      'fedora',
      'rhel',
      'centos',
      'suse',
      'opensuse',
      'opensuse-leap',
      'rocky',
      'almalinux',
    };
    if (identities.any(debianIdentities.contains)) {
      return LinuxDistributionFamily.debian;
    }
    if (identities.any(rpmIdentities.contains)) {
      return LinuxDistributionFamily.rpm;
    }
    return LinuxDistributionFamily.other;
  }
}

/// Production platform adapter using explicit OS APIs and command probes.
final class IoPlatformInfo implements PlatformInfo {
  IoPlatformInfo({
    PlatformEnvironment? environment,
    LinuxOsReleaseParser osReleaseParser = const LinuxOsReleaseParser(),
  })  : _environment = environment ?? IoPlatformEnvironment(),
        _osReleaseParser = osReleaseParser;

  final PlatformEnvironment _environment;
  final LinuxOsReleaseParser _osReleaseParser;

  PlatformInfoResult detectSynchronously() {
    if (_environment is! IoPlatformEnvironment) {
      return const PlatformInfoFailure(
        PlatformInfoFailureReason.architectureProbeFailed,
      );
    }
    final environment = _environment;
    final architectureEvidence =
        environment.hostOperatingSystem == HostOperatingSystem.windows
            ? environment.environment['PROCESSOR_ARCHITEW6432'] ??
                environment.environment['PROCESSOR_ARCHITECTURE']
            : environment.runArchitectureProbeSynchronously();
    final architecture = _parseArchitecture(architectureEvidence);
    if (architecture == null) {
      return const PlatformInfoFailure(
        PlatformInfoFailureReason.architectureProbeFailed,
      );
    }
    if (architecture == UpdateArchitecture.x86) {
      return const PlatformInfoFailure(
        PlatformInfoFailureReason.unsupportedArchitecture,
      );
    }
    final operatingSystem = switch (environment.hostOperatingSystem) {
      HostOperatingSystem.windows => UpdateOperatingSystem.windows,
      HostOperatingSystem.macos => UpdateOperatingSystem.macos,
      HostOperatingSystem.linux => UpdateOperatingSystem.linux,
      HostOperatingSystem.unsupported => null,
    };
    if (operatingSystem == null) {
      return const PlatformInfoFailure(
        PlatformInfoFailureReason.unsupportedOperatingSystem,
      );
    }
    LinuxDistributionFamily? linuxFamily;
    if (operatingSystem == UpdateOperatingSystem.linux) {
      final osRelease = environment.readLinuxOsReleaseSynchronously();
      if (osRelease == null) {
        return const PlatformInfoFailure(
          PlatformInfoFailureReason.linuxDistributionProbeFailed,
        );
      }
      linuxFamily = _osReleaseParser.parse(osRelease).family;
    }
    return PlatformInfoSuccess(
      UpdatePlatform(
        operatingSystem: operatingSystem,
        architecture: architecture,
        packageTypes: _packageTypes(operatingSystem, linuxFamily),
        linuxFamily: linuxFamily,
        executablePath: environment.executablePath,
        appBundlePath: operatingSystem == UpdateOperatingSystem.macos
            ? _findAppBundlePath(environment.executablePath)
            : null,
        appImagePath: operatingSystem == UpdateOperatingSystem.linux
            ? environment.environment['APPIMAGE']
            : null,
      ),
    );
  }

  @override
  Future<PlatformInfoResult> detect() async {
    final operatingSystem = switch (_environment.hostOperatingSystem) {
      HostOperatingSystem.windows => UpdateOperatingSystem.windows,
      HostOperatingSystem.macos => UpdateOperatingSystem.macos,
      HostOperatingSystem.linux => UpdateOperatingSystem.linux,
      HostOperatingSystem.unsupported => null,
    };
    if (operatingSystem == null) {
      return const PlatformInfoFailure(
        PlatformInfoFailureReason.unsupportedOperatingSystem,
      );
    }

    final architecture = await _detectArchitecture();
    if (architecture == null) {
      return const PlatformInfoFailure(
        PlatformInfoFailureReason.architectureProbeFailed,
      );
    }
    if (architecture == UpdateArchitecture.x86) {
      return const PlatformInfoFailure(
        PlatformInfoFailureReason.unsupportedArchitecture,
      );
    }

    LinuxDistributionFamily? linuxFamily;
    if (operatingSystem == UpdateOperatingSystem.linux) {
      final osRelease = await _environment.readLinuxOsRelease();
      if (osRelease == null) {
        return const PlatformInfoFailure(
          PlatformInfoFailureReason.linuxDistributionProbeFailed,
        );
      }
      linuxFamily = _osReleaseParser.parse(osRelease).family;
    }
    final packageTypes = _packageTypes(operatingSystem, linuxFamily);
    return PlatformInfoSuccess(
      UpdatePlatform(
        operatingSystem: operatingSystem,
        architecture: architecture,
        packageTypes: packageTypes,
        linuxFamily: linuxFamily,
        executablePath: _environment.executablePath,
        appBundlePath: operatingSystem == UpdateOperatingSystem.macos
            ? _findAppBundlePath(_environment.executablePath)
            : null,
        appImagePath: operatingSystem == UpdateOperatingSystem.linux
            ? _environment.environment['APPIMAGE']
            : null,
      ),
    );
  }

  Future<UpdateArchitecture?> _detectArchitecture() async {
    if (_environment.hostOperatingSystem == HostOperatingSystem.windows) {
      final architecture = _environment.environment['PROCESSOR_ARCHITEW6432'] ??
          _environment.environment['PROCESSOR_ARCHITECTURE'];
      return _parseArchitecture(architecture);
    }
    final probeOutput = await _environment.runArchitectureProbe();
    return _parseArchitecture(probeOutput);
  }

  UpdateArchitecture? _parseArchitecture(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'amd64' || 'x86_64' || 'x64' => UpdateArchitecture.x64,
      'arm64' || 'aarch64' => UpdateArchitecture.arm64,
      'x86' || 'i386' || 'i686' => UpdateArchitecture.x86,
      _ => null,
    };
  }

  List<UpdatePackageType> _packageTypes(
    UpdateOperatingSystem operatingSystem,
    LinuxDistributionFamily? linuxFamily,
  ) {
    return switch (operatingSystem) {
      UpdateOperatingSystem.windows => const <UpdatePackageType>[
          UpdatePackageType.exe,
        ],
      UpdateOperatingSystem.macos => const <UpdatePackageType>[
          UpdatePackageType.dmg,
        ],
      UpdateOperatingSystem.linux => switch (linuxFamily) {
          LinuxDistributionFamily.debian => const <UpdatePackageType>[
              UpdatePackageType.deb,
              UpdatePackageType.appImage,
            ],
          LinuxDistributionFamily.rpm => const <UpdatePackageType>[
              UpdatePackageType.rpm,
              UpdatePackageType.appImage,
            ],
          _ => const <UpdatePackageType>[UpdatePackageType.appImage],
        },
    };
  }

  String? _findAppBundlePath(String executablePath) {
    final markerIndex = executablePath.indexOf('.app/');
    if (markerIndex < 0) {
      return null;
    }
    return executablePath.substring(0, markerIndex + 4);
  }
}

/// Real environment implementation kept outside the pure domain layer.
final class IoPlatformEnvironment implements PlatformEnvironment {
  @override
  HostOperatingSystem get hostOperatingSystem {
    if (Platform.isWindows) return HostOperatingSystem.windows;
    if (Platform.isMacOS) return HostOperatingSystem.macos;
    if (Platform.isLinux) return HostOperatingSystem.linux;
    return HostOperatingSystem.unsupported;
  }

  @override
  String get executablePath => Platform.resolvedExecutable;

  @override
  Map<String, String> get environment => Platform.environment;

  String? runArchitectureProbeSynchronously() {
    try {
      final result = Process.runSync('uname', const <String>['-m']);
      if (result.exitCode != 0) {
        return null;
      }
      return result.stdout.toString().trim();
    } on ProcessException {
      return null;
    }
  }

  String? readLinuxOsReleaseSynchronously() {
    try {
      return File('/etc/os-release').readAsStringSync();
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<String?> runArchitectureProbe() async {
    try {
      final result = await Process.run('uname', const <String>['-m']);
      if (result.exitCode != 0) {
        return null;
      }
      return result.stdout.toString().trim();
    } on ProcessException {
      return null;
    }
  }

  @override
  Future<String?> readLinuxOsRelease() async {
    try {
      return await File('/etc/os-release').readAsString();
    } on FileSystemException {
      return null;
    }
  }
}
