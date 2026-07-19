/// Authoritative Linux package identity shared by packaging and installation.
final class LinuxPackageIdentity {
  const LinuxPackageIdentity._({
    required this.packageName,
    required this.desktopId,
    required this.executableName,
    required this.installedExecutablePath,
    required this.sources,
  });

  factory LinuxPackageIdentity.fromConfiguration({
    required Iterable<LinuxPackageIdentityConfiguration> configurations,
  }) {
    final entries = configurations.toList(growable: false);
    if (entries.isEmpty) {
      throw const LinuxPackageIdentityException(
        'linux_identity_missing',
        'No Linux package identity configuration was supplied.',
      );
    }

    final firstEntry = entries.first;
    for (final entry in entries.skip(1)) {
      if (!firstEntry.hasSameIdentity(entry)) {
        throw LinuxPackageIdentityException(
          'linux_identity_conflict',
          'Linux package identity conflicts between '
              '${firstEntry.source} and ${entry.source}.',
        );
      }
    }

    final values = <String, String>{
      'packageName': firstEntry.packageName,
      'desktopId': firstEntry.desktopId,
      'executableName': firstEntry.executableName,
      'installedExecutablePath': firstEntry.installedExecutablePath,
    };
    for (final MapEntry(key: fieldName, value: fieldValue) in values.entries) {
      if (fieldValue.trim().isEmpty) {
        throw LinuxPackageIdentityException(
          'linux_identity_missing',
          'Linux package identity field $fieldName is missing.',
        );
      }
    }
    if (!firstEntry.installedExecutablePath.startsWith('/') ||
        firstEntry.installedExecutablePath.endsWith('/')) {
      throw const LinuxPackageIdentityException(
        'linux_identity_install_path_invalid',
        'The installed executable path must be an absolute file path.',
      );
    }
    if (firstEntry.installedExecutablePath.split('/').last !=
        firstEntry.executableName) {
      throw const LinuxPackageIdentityException(
        'linux_identity_executable_conflict',
        'The installed path and executable name do not agree.',
      );
    }

    return LinuxPackageIdentity._(
      packageName: firstEntry.packageName,
      desktopId: firstEntry.desktopId,
      executableName: firstEntry.executableName,
      installedExecutablePath: firstEntry.installedExecutablePath,
      sources: entries.map((entry) => entry.source).toList(growable: false),
    );
  }

  final String packageName;
  final String desktopId;
  final String executableName;
  final String installedExecutablePath;
  final List<String> sources;
}

final class LinuxPackageIdentityConfiguration {
  const LinuxPackageIdentityConfiguration({
    required this.source,
    required this.packageName,
    required this.desktopId,
    required this.executableName,
    required this.installedExecutablePath,
  });

  final String source;
  final String packageName;
  final String desktopId;
  final String executableName;
  final String installedExecutablePath;

  bool hasSameIdentity(LinuxPackageIdentityConfiguration other) {
    return packageName == other.packageName &&
        desktopId == other.desktopId &&
        executableName == other.executableName &&
        installedExecutablePath == other.installedExecutablePath;
  }
}

final class LinuxPackageIdentityException implements Exception {
  const LinuxPackageIdentityException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}

/// Values directly evidenced by the checked-in Flutter Linux runner.
abstract final class FlutterLinuxRunnerIdentity {
  static const executableName = 'fly_narwhal';
  static const applicationId = 'com.jankinwu.fly_narwhal';
  static const source = 'linux/CMakeLists.txt';
}
