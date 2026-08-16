import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import '../../domain/update/entities/update_models.dart';
import '../../domain/update/entities/verified_update_artifact.dart';
import 'update_path_safety.dart';

final class PlatformUpdateInstallRequest {
  const PlatformUpdateInstallRequest({
    required this.operationId,
    required this.artifact,
  });

  final String operationId;
  final VerifiedUpdateArtifact artifact;

  UpdateCandidate get candidate => artifact.candidate;
  File get packageFile => artifact.file;
}

sealed class PlatformUpdateInstallResult {
  const PlatformUpdateInstallResult();
}

final class PlatformUpdateHelperLaunched extends PlatformUpdateInstallResult {
  const PlatformUpdateHelperLaunched();
}

/// Indicates that the Windows helper durably accepted commit-after-exit.
final class PlatformUpdateCommitAccepted extends PlatformUpdateInstallResult {
  const PlatformUpdateCommitAccepted();
}

/// Indicates that the existing Windows transaction must be recovered.
final class PlatformUpdateRecoveryRequired extends PlatformUpdateInstallResult {
  const PlatformUpdateRecoveryRequired({
    required this.transactionId,
    required this.technicalDetail,
  });

  final String transactionId;
  final String technicalDetail;
}

/// Indicates that automatic mutation and cleanup must stop for manual action.
final class PlatformUpdateManualActionRequired
    extends PlatformUpdateInstallResult {
  const PlatformUpdateManualActionRequired({
    required this.transactionId,
    required this.technicalDetail,
  });

  final String transactionId;
  final String technicalDetail;
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
typedef CurrentExecutableLoader = Future<File> Function();
typedef CurrentProcessIdLoader = int Function();
typedef UpdateProcessStarter = Future<void> Function(
  String executable,
  List<String> arguments,
);

final class WindowsUpdateInstaller implements PlatformUpdateInstaller {
  WindowsUpdateInstaller({
    required this.updaterExecutable,
    UpdateDirectoryLoader? updateCacheDirectoryLoader,
    UpdateDirectoryLoader? installDirectoryLoader,
    CurrentExecutableLoader? currentExecutableLoader,
    CurrentProcessIdLoader? currentProcessIdLoader,
    UpdateProcessStarter? processStarter,
    String? trustedLocalAppDataPath,
  })  : _updateCacheDirectoryLoader =
            updateCacheDirectoryLoader ?? _loadDefaultUpdateCacheDirectory,
        _installDirectoryLoader =
            installDirectoryLoader ?? _loadDefaultInstallDirectory,
        _currentExecutableLoader =
            currentExecutableLoader ?? _loadCurrentExecutable,
        _currentProcessIdLoader =
            currentProcessIdLoader ?? _loadCurrentProcessId,
        _processStarter = processStarter ?? _startDetachedProcess,
        _trustedLocalAppDataPath = trustedLocalAppDataPath;

  static const String applicationExecutable = 'FlyNarwhal.exe';
  static const String applicationId = '9A262498-6C63-4816-A346-056028719600';
  static const String updaterExecutableName = 'updater.exe';
  static const String _manifestName = 'installer-manifest.json';

  final File updaterExecutable;
  final UpdateDirectoryLoader _updateCacheDirectoryLoader;
  final UpdateDirectoryLoader _installDirectoryLoader;
  final CurrentExecutableLoader _currentExecutableLoader;
  final CurrentProcessIdLoader _currentProcessIdLoader;
  final UpdateProcessStarter _processStarter;
  final String? _trustedLocalAppDataPath;

  @override
  Future<PlatformUpdateInstallResult> launch(
    PlatformUpdateInstallRequest request,
  ) async {
    try {
      final cacheDirectory = await _updateCacheDirectoryLoader();
      final installDirectory = await _installDirectoryLoader();
      final currentExecutable = await _currentExecutableLoader();

      await _ensureDirectoryExists(cacheDirectory);
      await _ensureDirectoryExists(installDirectory);

      final installDirectoryTrusted = _isTrustedInstallDirectory(
        installDirectory,
      );
      if (!installDirectoryTrusted) {
        return _failure(
          code: 'install_directory_rejected',
          detail: 'The installation directory is not trusted.',
          retryable: false,
        );
      }

      final cacheDirectorySafe = await UpdatePathSafety.isSafeDirectoryTree(
        cacheDirectory.path,
      );
      final installDirectorySafe = await UpdatePathSafety.isSafeDirectoryTree(
        installDirectory.path,
      );
      if (!cacheDirectorySafe || !installDirectorySafe) {
        return _failure(
          code: 'reparse_path_rejected',
          detail: 'A trusted update path contains a link or reparse point.',
          retryable: false,
        );
      }

      final currentExecutableTrusted = await _isTrustedCurrentExecutable(
        currentExecutable,
        installDirectory,
      );
      if (!currentExecutableTrusted) {
        return _failure(
          code: 'application_identity_invalid',
          detail: 'The running executable is not the trusted FlyNarwhal.exe.',
          retryable: false,
        );
      }

      final updaterTrusted = await _isTrustedUpdater(
        currentExecutable.parent,
      );
      if (!updaterTrusted) {
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

      final stagedInstaller = await _stageInstaller(
        source: request.packageFile,
        cacheDirectory: cacheDirectory,
        operationId: request.operationId,
      );
      final runningApplicationProcessId = _currentProcessIdLoader();
      await _processStarter(updaterExecutable.path, <String>[
        stagedInstaller.path,
        installDirectory.path,
        runningApplicationProcessId.toString(),
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

  Future<void> _ensureDirectoryExists(Directory directory) async {
    if (await directory.exists()) {
      return;
    }
    await directory.create(recursive: true);
  }

  Future<bool> _isTrustedUpdater(Directory installDirectory) async {
    if (path.basename(updaterExecutable.path) != updaterExecutableName ||
        path.extension(updaterExecutable.path).toLowerCase() != '.exe' ||
        !UpdatePathSafety.isWithinRoot(
          rootPath: installDirectory.path,
          candidatePath: updaterExecutable.path,
        )) {
      return false;
    }
    return UpdatePathSafety.isSafeRegularFile(updaterExecutable.path);
  }

  Future<bool> _isTrustedCurrentExecutable(
    File currentExecutable,
    Directory installDirectory,
  ) async {
    final executableNameMatches =
        path.basename(currentExecutable.path) == applicationExecutable;
    final executableInsideTrustedDirectory = UpdatePathSafety.sameWindowsPath(
      firstPath: currentExecutable.parent.path,
      secondPath: installDirectory.path,
    );
    final isSafeFile = await UpdatePathSafety.isSafeRegularFile(
      currentExecutable.path,
    );
    final relaxedForDebugBuild =
        kDebugMode && !executableInsideTrustedDirectory;
    final isTrusted = executableNameMatches &&
        isSafeFile &&
        (executableInsideTrustedDirectory || relaxedForDebugBuild);
    return isTrusted;
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
    required String operationId,
  }) async {
    final operationDirectory = Directory(path.join(
      cacheDirectory.path,
      'operation-${_sanitizeOperationId(operationId)}-${_randomToken()}',
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
    final localAppData =
        _trustedLocalAppDataPath ?? Platform.environment['LOCALAPPDATA'];
    final trustedInstallDirectory =
        localAppData == null || localAppData.trim().isEmpty
            ? null
            : path.join(localAppData, 'FlyNarwhal');
    final isTrusted = trustedInstallDirectory != null &&
        UpdatePathSafety.sameWindowsPath(
          firstPath: installDirectory.path,
          secondPath: trustedInstallDirectory,
        );
    return isTrusted;
  }

  String _randomToken() {
    return List<String>.generate(
      4,
      (_) => Random.secure().nextInt(0x7fffffff).toRadixString(16),
    ).join();
  }

  String _sanitizeOperationId(String operationId) {
    final sanitized = operationId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return sanitized.isEmpty ? 'unknown' : sanitized;
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
    final temporaryRoot = Platform.environment['TEMP'] ??
        Platform.environment['TMP'] ??
        Directory.systemTemp.path;
    return Directory(path.join(temporaryRoot, 'updates'));
  }

  static Future<Directory> _loadDefaultInstallDirectory() async {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData == null || localAppData.trim().isEmpty) {
      throw const FileSystemException('LOCALAPPDATA is unavailable.');
    }
    return Directory(path.join(localAppData, 'FlyNarwhal'));
  }

  static Future<File> _loadCurrentExecutable() async {
    return File(Platform.resolvedExecutable);
  }

  static int _loadCurrentProcessId() {
    return pid;
  }

  static const MethodChannel _updaterProcessChannel =
      MethodChannel('fly_narwhal/updater_process');

  static Future<void> _startDetachedProcess(
    String executable,
    List<String> arguments,
  ) async {
    await _updaterProcessChannel.invokeMethod<void>(
      'launchUpdaterDetached',
      <String, Object>{
        'executable': executable,
        'arguments': arguments,
      },
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

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'status': status,
      'code': code,
      'technicalDetail': technicalDetail,
      'installerPath': installerPath,
      'installDir': installDir,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  PlatformUpdateInstallFailure? toFailure() {
    if (!isFailure) return null;
    return PlatformUpdateInstallFailure(
      code: code,
      userMessageKey: 'update.install.error.failed',
      technicalDetail: jsonEncode(toJson()),
      isRetryable: true,
    );
  }
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
