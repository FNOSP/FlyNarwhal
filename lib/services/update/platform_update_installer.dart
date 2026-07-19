import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../domain/update/entities/update_models.dart';
import 'update_path_safety.dart';

final class PlatformUpdateInstallRequest {
  const PlatformUpdateInstallRequest({
    required this.operationId,
    required this.candidate,
    required this.packageFile,
  });

  final String operationId;
  final UpdateCandidate candidate;
  final File packageFile;
}

sealed class PlatformUpdateInstallResult {
  const PlatformUpdateInstallResult();
}

/// Indicates that the detached platform helper process was created.
final class PlatformUpdateHelperLaunched extends PlatformUpdateInstallResult {
  const PlatformUpdateHelperLaunched();
}

final class PlatformUpdateInstallFailure extends PlatformUpdateInstallResult {
  const PlatformUpdateInstallFailure({
    required this.code,
    required this.userMessageKey,
    required this.technicalDetail,
    required this.isRetryable,
    this.cause,
  });

  final String code;
  final String userMessageKey;
  final String technicalDetail;
  final bool isRetryable;
  final Object? cause;
}

/// Common launcher contract implemented by platform-specific modules.
abstract interface class PlatformUpdateInstaller {
  Future<PlatformUpdateInstallResult> launch(
    PlatformUpdateInstallRequest request,
  );
}

final class UnsupportedPlatformUpdateInstaller
    implements PlatformUpdateInstaller {
  const UnsupportedPlatformUpdateInstaller();

  @override
  Future<PlatformUpdateInstallResult> launch(
    PlatformUpdateInstallRequest request,
  ) async {
    return const PlatformUpdateInstallFailure(
      code: 'installer_not_configured',
      userMessageKey: 'update.install.error.notConfigured',
      technicalDetail: 'No platform update installer is configured.',
      isRetryable: false,
    );
  }
}

typedef UpdateDirectoryLoader = Future<Directory> Function();
typedef UpdateProcessStarter = Future<void> Function(
  String executable,
  List<String> arguments,
);

final class WindowsUpdateInstaller implements PlatformUpdateInstaller {
  WindowsUpdateInstaller({
    required this.updaterExecutable,
    UpdateDirectoryLoader? updateCacheDirectoryLoader,
    UpdateDirectoryLoader? installDirectoryLoader,
    UpdateProcessStarter? processStarter,
  })  : _updateCacheDirectoryLoader =
            updateCacheDirectoryLoader ?? _loadDefaultUpdateCacheDirectory,
        _installDirectoryLoader =
            installDirectoryLoader ?? _loadDefaultInstallDirectory,
        _processStarter = processStarter ?? _startDetachedProcess;

  static const String applicationExecutable = 'FlyNarwhal.exe';
  static const String applicationId = '9A262498-6C63-4816-A346-056028719600';
  static const String _manifestName = 'installer-manifest.json';

  final File updaterExecutable;
  final UpdateDirectoryLoader _updateCacheDirectoryLoader;
  final UpdateDirectoryLoader _installDirectoryLoader;
  final UpdateProcessStarter _processStarter;

  @override
  Future<PlatformUpdateInstallResult> launch(
    PlatformUpdateInstallRequest request,
  ) async {
    try {
      final cacheDirectory = await _updateCacheDirectoryLoader();
      final installDirectory = await _installDirectoryLoader();
      if (!_isTrustedInstallDirectory(installDirectory)) {
        return _failure(
          code: 'install_directory_rejected',
          detail: 'The installation directory is not trusted.',
          retryable: false,
        );
      }
      if (!await UpdatePathSafety.isSafeDirectoryTree(cacheDirectory.path) ||
          !await UpdatePathSafety.isSafeDirectoryTree(installDirectory.path)) {
        return _failure(
          code: 'reparse_path_rejected',
          detail: 'A trusted update path contains a link or reparse point.',
          retryable: false,
        );
      }
      if (!await _isTrustedUpdater(installDirectory)) {
        return _failure(
          code: 'updater_missing',
          detail: 'The Windows updater executable is missing or invalid.',
          retryable: false,
        );
      }
      if (!await _isSafeInstallerSource(request.packageFile, cacheDirectory)) {
        return _failure(
          code: 'installer_invalid',
          detail: 'The installer is not a safe executable in the update cache.',
          retryable: true,
        );
      }

      // Copy the verified package into a private, unpredictable staging directory.
      final stagedInstaller = await _stageInstaller(
        source: request.packageFile,
        cacheDirectory: cacheDirectory,
      );
      await _processStarter(updaterExecutable.path, <String>[
        stagedInstaller.path,
        installDirectory.path,
      ]);
      return const PlatformUpdateHelperLaunched();
    } on Object catch (error) {
      return PlatformUpdateInstallFailure(
        code: 'updater_launch_failed',
        userMessageKey: 'update.install.error.updaterLaunchFailed',
        technicalDetail: error.toString(),
        isRetryable: true,
        cause: error,
      );
    }
  }

  Future<bool> _isTrustedUpdater(Directory installDirectory) async {
    if (path.extension(updaterExecutable.path).toLowerCase() != '.exe' ||
        !UpdatePathSafety.isWithinRoot(
          rootPath: installDirectory.path,
          candidatePath: updaterExecutable.path,
        )) {
      return false;
    }
    return UpdatePathSafety.isSafeRegularFile(updaterExecutable.path);
  }

  Future<bool> _isSafeInstallerSource(
    File installer,
    Directory cacheDirectory,
  ) async {
    if (path.extension(installer.path).toLowerCase() != '.exe' ||
        !UpdatePathSafety.isWithinRoot(
          rootPath: cacheDirectory.path,
          candidatePath: installer.path,
        )) {
      return false;
    }
    return UpdatePathSafety.isSafeRegularFile(installer.path);
  }

  Future<File> _stageInstaller({
    required File source,
    required Directory cacheDirectory,
  }) async {
    final operationDirectory = Directory(path.join(
      cacheDirectory.path,
      'operation-${DateTime.now().microsecondsSinceEpoch}-${_randomToken()}',
    ));
    await operationDirectory.create(recursive: true);
    if (!await UpdatePathSafety.isSafeDirectoryTree(operationDirectory.path)) {
      throw const FileSystemException('Operation staging directory is unsafe.');
    }

    final stagedInstaller =
        File(path.join(operationDirectory.path, 'installer.exe'));
    await source.copy(stagedInstaller.path);
    if (!await UpdatePathSafety.isSafeRegularFile(stagedInstaller.path)) {
      throw const FileSystemException('Staged installer is unsafe.');
    }
    final stagedBytes = await stagedInstaller.readAsBytes();
    final manifest = <String, Object>{
      'schemaVersion': 1,
      'installer': <String, Object>{
        'path': stagedInstaller.absolute.path,
        'size': stagedBytes.length,
        'sha256': sha256.convert(stagedBytes).toString(),
      },
    };
    final manifestFile =
        File(path.join(operationDirectory.path, _manifestName));
    await manifestFile.writeAsString(jsonEncode(manifest), flush: true);
    if (!await UpdatePathSafety.isSafeRegularFile(manifestFile.path)) {
      throw const FileSystemException(
          'Protected installer manifest is unsafe.');
    }
    return stagedInstaller;
  }

  bool _isTrustedInstallDirectory(Directory installDirectory) {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData == null || localAppData.trim().isEmpty) return false;
    return UpdatePathSafety.sameWindowsPath(
      firstPath: installDirectory.path,
      secondPath: path.join(localAppData, 'FlyNarwhal'),
    );
  }

  String _randomToken() {
    return List<String>.generate(
      4,
      (_) => Random.secure().nextInt(0x7fffffff).toRadixString(16),
    ).join();
  }

  PlatformUpdateInstallFailure _failure({
    required String code,
    required String detail,
    required bool retryable,
  }) {
    return PlatformUpdateInstallFailure(
      code: code,
      userMessageKey: 'update.install.error.$code',
      technicalDetail: detail,
      isRetryable: retryable,
    );
  }

  static Future<Directory> _loadDefaultUpdateCacheDirectory() async {
    final temporaryDirectory = await getTemporaryDirectory();
    return Directory(path.join(temporaryDirectory.path, 'updates'));
  }

  static Future<Directory> _loadDefaultInstallDirectory() async {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData == null || localAppData.trim().isEmpty) {
      throw const FileSystemException('LOCALAPPDATA is unavailable.');
    }
    return Directory(path.join(localAppData, 'FlyNarwhal'));
  }

  static Future<void> _startDetachedProcess(
    String executable,
    List<String> arguments,
  ) async {
    await Process.start(
      executable,
      arguments,
      mode: ProcessStartMode.detached,
      runInShell: false,
    );
  }
}

final class WindowsInstallResult {
  const WindowsInstallResult({
    required this.schemaVersion,
    required this.status,
    required this.code,
    required this.technicalDetail,
    required this.installerPath,
    required this.installDir,
    required this.updatedAt,
  });

  static const int schemaVersionValue = 1;

  factory WindowsInstallResult.fromJson(Map<String, Object?> json) {
    final schemaVersion = json['schemaVersion'];
    final status = json['status'];
    final code = json['code'];
    final technicalDetail = json['technicalDetail'];
    final installerPath = json['installerPath'];
    final installDir = json['installDir'];
    final updatedAt = json['updatedAt'];
    if (schemaVersion is! int ||
        schemaVersion != schemaVersionValue ||
        status is! String ||
        (status != 'success' && status != 'failure') ||
        code is! String ||
        code.isEmpty ||
        code.length > 128 ||
        technicalDetail is! String ||
        technicalDetail.length > 4096 ||
        installerPath is! String ||
        installerPath.isEmpty ||
        installDir is! String ||
        installDir.isEmpty ||
        updatedAt is! String) {
      throw const FormatException('Invalid Windows updater result schema.');
    }
    final parsedUpdatedAt = DateTime.tryParse(updatedAt)?.toUtc();
    if (parsedUpdatedAt == null || !updatedAt.endsWith('Z')) {
      throw const FormatException('Invalid Windows updater result timestamp.');
    }
    return WindowsInstallResult(
      schemaVersion: schemaVersion,
      status: status,
      code: code,
      technicalDetail: technicalDetail,
      installerPath: installerPath,
      installDir: installDir,
      updatedAt: parsedUpdatedAt,
    );
  }

  final int schemaVersion;
  final String status;
  final String code;
  final String technicalDetail;
  final String installerPath;
  final String installDir;
  final DateTime updatedAt;

  bool get isFailure => status == 'failure';
}

final class WindowsInstallResultStore {
  WindowsInstallResultStore({UpdateDirectoryLoader? installDirectoryLoader})
      : _installDirectoryLoader = installDirectoryLoader ??
            WindowsUpdateInstaller._loadDefaultInstallDirectory;

  final UpdateDirectoryLoader _installDirectoryLoader;

  Future<WindowsInstallResult?> consume() async {
    final installDirectory = await _installDirectoryLoader();
    if (!await UpdatePathSafety.isSafeDirectoryTree(installDirectory.path)) {
      return null;
    }
    final resultFile = File(path.join(
      installDirectory.path,
      'updates',
      'install-result.json',
    ));
    if (!await UpdatePathSafety.isSafeRegularFile(resultFile.path)) return null;
    final bytes = await resultFile.readAsBytes();
    if (bytes.length > 64 * 1024) return null;
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, Object?>) return null;
    final result = WindowsInstallResult.fromJson(decoded);
    if (!UpdatePathSafety.sameWindowsPath(
      firstPath: result.installDir,
      secondPath: installDirectory.path,
    )) {
      throw const FormatException(
          'Windows updater result has an untrusted install directory.');
    }
    await resultFile.delete();
    return result;
  }
}
