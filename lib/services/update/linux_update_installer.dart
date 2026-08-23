import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../../domain/update/entities/update_models.dart';
import 'linux_package_identity.dart';
import 'platform_update_installer.dart';

enum LinuxInstallerMode { deb, rpmDnf, rpmZypper, rpmDirect, appImage, pacman }

enum LinuxInstallRecordStage { launched, failed, completed }

enum LinuxAppImageUnsupportedReason {
  notCurrentRuntime,
  sourceMissing,
  sourceNotWritable,
  parentNotWritable,
  parentNotExecutable,
}

final class LinuxInstallRecord {
  const LinuxInstallRecord({
    required this.operationId,
    required this.stage,
    required this.exitCode,
    required this.errorCode,
  });

  final String operationId;
  final LinuxInstallRecordStage stage;
  final int exitCode;
  final String? errorCode;

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': 1,
        'operationId': operationId,
        'stage': stage.name,
        'exitCode': exitCode,
        'errorCode': errorCode,
      };

  static LinuxInstallRecord? tryParse(String contents) {
    try {
      final decoded = jsonDecode(contents);
      if (decoded is! Map<String, dynamic> || decoded['schemaVersion'] != 1) {
        return null;
      }
      final operationId = decoded['operationId'];
      final stageName = decoded['stage'];
      final exitCode = decoded['exitCode'];
      final errorCode = decoded['errorCode'];
      if (operationId is! String ||
          stageName is! String ||
          exitCode is! int ||
          (errorCode != null && errorCode is! String)) {
        return null;
      }
      final stage = LinuxInstallRecordStage.values
          .where((value) => value.name == stageName)
          .firstOrNull;
      if (stage == null) return null;
      return LinuxInstallRecord(
        operationId: operationId,
        stage: stage,
        exitCode: exitCode,
        errorCode: errorCode as String?,
      );
    } on FormatException {
      return null;
    }
  }
}

final class LinuxUpdateInstallInput {
  const LinuxUpdateInstallInput({
    required this.processId,
    required this.packageType,
    required this.packageFilePath,
    required this.cacheRootPath,
    required this.installRecordPath,
    required this.distributionFamily,
    required this.distributionId,
    required this.currentExecutablePath,
    required this.appImageEnvironmentPath,
  });

  final int processId;
  final UpdatePackageType packageType;
  final String packageFilePath;
  final String cacheRootPath;
  final String installRecordPath;
  final LinuxDistributionFamily distributionFamily;
  final String? distributionId;
  final String currentExecutablePath;
  final String? appImageEnvironmentPath;
}

abstract interface class LinuxInstallerFileSystem {
  Future<bool> fileExists(String filePath);
  Future<String> resolveFilePath(String filePath);
  Future<bool> isFileWritable(String filePath);
  Future<bool> isDirectoryWritable(String directoryPath);
  Future<bool> isDirectoryExecutable(String directoryPath);
  Future<String> createPrivateTemporaryDirectory(String parentPath);
  Future<void> copyFile(String sourcePath, String destinationPath);
  Future<void> makeOwnerExecutable(String filePath);
  Future<void> writeTextFile(String filePath, String contents);
  Future<void> writeInstallRecord(String recordPath, LinuxInstallRecord record);
  Future<String?> readTextFile(String filePath);
}

final class IoLinuxInstallerFileSystem implements LinuxInstallerFileSystem {
  const IoLinuxInstallerFileSystem();

  @override
  Future<bool> fileExists(String filePath) => File(filePath).exists();

  @override
  Future<String> resolveFilePath(String filePath) {
    return File(filePath).resolveSymbolicLinks();
  }

  @override
  Future<bool> isFileWritable(String filePath) async {
    final result = await Process.run('/usr/bin/test', <String>['-w', filePath]);
    return result.exitCode == 0;
  }

  @override
  Future<bool> isDirectoryWritable(String directoryPath) async {
    final result =
        await Process.run('/usr/bin/test', <String>['-w', directoryPath]);
    return result.exitCode == 0;
  }

  @override
  Future<bool> isDirectoryExecutable(String directoryPath) async {
    final result =
        await Process.run('/usr/bin/test', <String>['-x', directoryPath]);
    return result.exitCode == 0;
  }

  @override
  Future<String> createPrivateTemporaryDirectory(String parentPath) async {
    final parent = Directory(parentPath);
    await parent.create(recursive: true);
    final directory = await parent.createTemp('linux-installer-');
    final result = await Process.run(
      '/bin/chmod',
      <String>['0700', directory.path],
    );
    if (result.exitCode != 0) {
      await directory.delete(recursive: true);
      throw FileSystemException(
        'Unable to protect installer temporary directory.',
        directory.path,
      );
    }
    return directory.path;
  }

  @override
  Future<void> copyFile(String sourcePath, String destinationPath) async {
    await File(sourcePath).copy(destinationPath);
  }

  @override
  Future<void> makeOwnerExecutable(String filePath) async {
    final result = await Process.run('/bin/chmod', <String>['0700', filePath]);
    if (result.exitCode != 0) {
      throw FileSystemException('Unable to protect executable.', filePath);
    }
  }

  @override
  Future<void> writeTextFile(String filePath, String contents) async {
    await File(filePath).writeAsString(contents, flush: true);
  }

  @override
  Future<void> writeInstallRecord(
    String recordPath,
    LinuxInstallRecord record,
  ) async {
    final recordFile = File(recordPath);
    await recordFile.parent.create(recursive: true);
    final temporaryFile = File('$recordPath.tmp');
    await temporaryFile.writeAsString(jsonEncode(record.toJson()), flush: true);
    await temporaryFile.rename(recordPath);
  }

  @override
  Future<String?> readTextFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return null;
    return file.readAsString();
  }
}

abstract interface class LinuxInstallerProcessLauncher {
  Future<bool> commandExists(String executableName);
  Future<void> startDetached(String executable, List<String> arguments);
}

final class IoLinuxInstallerProcessLauncher
    implements LinuxInstallerProcessLauncher {
  const IoLinuxInstallerProcessLauncher();

  @override
  Future<bool> commandExists(String executableName) async {
    final result = await Process.run(
      '/usr/bin/env',
      <String>['which', executableName],
    );
    return result.exitCode == 0;
  }

  @override
  Future<void> startDetached(String executable, List<String> arguments) async {
    await Process.start(executable, arguments, mode: ProcessStartMode.detached);
  }
}

typedef LinuxInstallInputFactory = Future<LinuxUpdateInstallInput> Function(
  PlatformUpdateInstallRequest request,
);

final class LinuxUpdateInstaller implements PlatformUpdateInstaller {
  LinuxUpdateInstaller({
    required LinuxPackageIdentity identity,
    required LinuxInstallInputFactory inputFactory,
    LinuxInstallerFileSystem fileSystem = const IoLinuxInstallerFileSystem(),
    LinuxInstallerProcessLauncher processLauncher =
        const IoLinuxInstallerProcessLauncher(),
  })  : _identity = identity,
        _inputFactory = inputFactory,
        _fileSystem = fileSystem,
        _processLauncher = processLauncher;

  static const scriptFileName = 'install-update.sh';
  static const scriptContents = _linuxInstallerScript;

  final LinuxPackageIdentity _identity;
  final LinuxInstallInputFactory _inputFactory;
  final LinuxInstallerFileSystem _fileSystem;
  final LinuxInstallerProcessLauncher _processLauncher;

  @override
  Future<PlatformUpdateInstallResult> launch(
    PlatformUpdateInstallRequest request,
  ) async {
    try {
      final input = await _validateInput(await _inputFactory(request));
      final mode = await _selectMode(input);
      final helperDirectory = await _fileSystem.createPrivateTemporaryDirectory(
        input.cacheRootPath,
      );
      final scriptPath = path.posix.join(helperDirectory, scriptFileName);
      var packageArgument = input.packageFilePath;
      var targetArgument = _identity.installedExecutablePath;

      if (mode == LinuxInstallerMode.appImage) {
        final stagingPath = '${input.currentExecutablePath}.update-new';
        await _fileSystem.copyFile(input.packageFilePath, stagingPath);
        await _fileSystem.makeOwnerExecutable(stagingPath);
        packageArgument = stagingPath;
        targetArgument = input.currentExecutablePath;
      }

      // Keep script bytes fixed; pass every runtime value as a position argument.
      await _fileSystem.writeTextFile(scriptPath, scriptContents);
      await _fileSystem.makeOwnerExecutable(scriptPath);
      await _fileSystem.writeInstallRecord(
        input.installRecordPath,
        LinuxInstallRecord(
          operationId: request.operationId,
          stage: LinuxInstallRecordStage.launched,
          exitCode: 0,
          errorCode: null,
        ),
      );
      await _processLauncher.startDetached('/bin/sh', <String>[
        scriptPath,
        mode.name,
        input.processId.toString(),
        packageArgument,
        targetArgument,
        input.cacheRootPath,
        input.installRecordPath,
        request.operationId,
        input.packageFilePath,
      ]);
      return const PlatformUpdateHelperLaunched();
    } on LinuxAppImageUnsupportedException catch (error) {
      return PlatformUpdateInstallFailure(
        code: 'linux_appimage_manual_install_required_${error.reason.name}',
        userMessageKey: 'update.install.error.appImageManualInstallRequired',
        technicalDetail:
            'AppImage self-replacement is unavailable; open the package location.',
        isRetryable: false,
        cause: error,
      );
    } on LinuxInstallerValidationException catch (error) {
      return PlatformUpdateInstallFailure(
        code: error.code,
        userMessageKey: 'update.install.error.invalidTarget',
        technicalDetail: error.message,
        isRetryable: false,
        cause: error,
      );
    } on Object catch (error) {
      return PlatformUpdateInstallFailure(
        code: 'linux_helper_launch_failed',
        userMessageKey: 'update.install.error.launchFailed',
        technicalDetail: 'The Linux installer helper could not be created.',
        isRetryable: true,
        cause: error,
      );
    }
  }

  Future<LinuxUpdateInstallInput> _validateInput(
    LinuxUpdateInstallInput input,
  ) async {
    if (input.processId <= 0) {
      throw const LinuxInstallerValidationException(
        'linux_invalid_pid',
        'The application process ID must be positive.',
      );
    }
    if (!await _fileSystem.fileExists(input.packageFilePath)) {
      throw const LinuxInstallerValidationException(
        'linux_package_missing',
        'The update package does not exist.',
      );
    }
    final resolvedCacheRoot = path.posix.normalize(input.cacheRootPath);
    final resolvedPackage =
        await _fileSystem.resolveFilePath(input.packageFilePath);
    if (!path.posix.isWithin(resolvedCacheRoot, resolvedPackage)) {
      throw const LinuxInstallerValidationException(
        'linux_package_outside_cache',
        'The update package must be inside the update cache.',
      );
    }
    if (!path.posix.isWithin(resolvedCacheRoot, input.installRecordPath)) {
      throw const LinuxInstallerValidationException(
        'linux_record_outside_cache',
        'The install record must be inside the update cache.',
      );
    }
    String currentExecutablePath = input.currentExecutablePath;
    if (input.packageType == UpdatePackageType.appImage) {
      currentExecutablePath = await _validateAppImage(input);
    } else if (input.packageType != UpdatePackageType.deb &&
        input.packageType != UpdatePackageType.rpm &&
        input.packageType != UpdatePackageType.pacman) {
      throw const LinuxInstallerValidationException(
        'linux_package_type_unsupported',
        'The selected package type is not supported by Linux installer.',
      );
    }
    return LinuxUpdateInstallInput(
      processId: input.processId,
      packageType: input.packageType,
      packageFilePath: resolvedPackage,
      cacheRootPath: resolvedCacheRoot,
      installRecordPath: path.posix.normalize(input.installRecordPath),
      distributionFamily: input.distributionFamily,
      distributionId: input.distributionId?.toLowerCase(),
      currentExecutablePath: currentExecutablePath,
      appImageEnvironmentPath: input.appImageEnvironmentPath,
    );
  }

  Future<String> _validateAppImage(LinuxUpdateInstallInput input) async {
    final appImagePath = input.appImageEnvironmentPath;
    if (appImagePath == null || appImagePath.trim().isEmpty) {
      throw const LinuxAppImageUnsupportedException(
        LinuxAppImageUnsupportedReason.notCurrentRuntime,
      );
    }
    if (!await _fileSystem.fileExists(appImagePath)) {
      throw const LinuxAppImageUnsupportedException(
        LinuxAppImageUnsupportedReason.sourceMissing,
      );
    }
    final resolvedAppImage = await _fileSystem.resolveFilePath(appImagePath);
    final resolvedExecutable =
        await _fileSystem.resolveFilePath(input.currentExecutablePath);
    if (!path.posix.equals(resolvedAppImage, resolvedExecutable)) {
      throw const LinuxAppImageUnsupportedException(
        LinuxAppImageUnsupportedReason.notCurrentRuntime,
      );
    }
    if (!await _fileSystem.isFileWritable(resolvedAppImage)) {
      throw const LinuxAppImageUnsupportedException(
        LinuxAppImageUnsupportedReason.sourceNotWritable,
      );
    }
    final parentDirectory = path.posix.dirname(resolvedAppImage);
    if (!await _fileSystem.isDirectoryWritable(parentDirectory)) {
      throw const LinuxAppImageUnsupportedException(
        LinuxAppImageUnsupportedReason.parentNotWritable,
      );
    }
    if (!await _fileSystem.isDirectoryExecutable(parentDirectory)) {
      throw const LinuxAppImageUnsupportedException(
        LinuxAppImageUnsupportedReason.parentNotExecutable,
      );
    }
    return resolvedAppImage;
  }

  Future<LinuxInstallerMode> _selectMode(LinuxUpdateInstallInput input) async {
    if (input.packageType == UpdatePackageType.deb) {
      return LinuxInstallerMode.deb;
    }
    if (input.packageType == UpdatePackageType.pacman) {
      return LinuxInstallerMode.pacman;
    }
    if (input.packageType == UpdatePackageType.appImage) {
      return LinuxInstallerMode.appImage;
    }
    final distributionId = input.distributionId;
    final isSuse = distributionId == 'suse' ||
        distributionId == 'opensuse' ||
        distributionId == 'opensuse-leap';
    if (isSuse && await _processLauncher.commandExists('zypper')) {
      return LinuxInstallerMode.rpmZypper;
    }
    if (!isSuse && await _processLauncher.commandExists('dnf')) {
      return LinuxInstallerMode.rpmDnf;
    }
    if (await _processLauncher.commandExists('rpm')) {
      return LinuxInstallerMode.rpmDirect;
    }
    throw const LinuxInstallerValidationException(
      'linux_package_manager_missing',
      'No supported RPM package manager command is available.',
    );
  }

  Future<PlatformUpdateInstallFailure?> recoverFailure(
    String installRecordPath,
  ) async {
    final contents = await _fileSystem.readTextFile(installRecordPath);
    if (contents == null) return null;
    final record = LinuxInstallRecord.tryParse(contents);
    if (record == null || record.stage != LinuxInstallRecordStage.failed) {
      return null;
    }
    final policyKitCancelled = record.exitCode == 126 ||
        record.errorCode == 'linux_policykit_cancelled';
    return PlatformUpdateInstallFailure(
      code: policyKitCancelled
          ? 'linux_policykit_cancelled'
          : record.errorCode ?? 'linux_install_failed',
      userMessageKey: policyKitCancelled
          ? 'update.install.error.authorizationCancelled'
          : 'update.install.error.failed',
      technicalDetail:
          'The Linux helper exited with structured code ${record.exitCode}.',
      isRetryable: true,
    );
  }
}

final class LinuxInstallerValidationException implements Exception {
  const LinuxInstallerValidationException(this.code, this.message);

  final String code;
  final String message;
}

final class LinuxAppImageUnsupportedException implements Exception {
  const LinuxAppImageUnsupportedException(this.reason);

  final LinuxAppImageUnsupportedReason reason;
}

const String _linuxInstallerScript = r'''#!/bin/sh
set -u

MODE="$1"
PID="$2"
PACKAGE_PATH="$3"
TARGET_PATH="$4"
CACHE_ROOT="$5"
RECORD_PATH="$6"
OPERATION_ID="$7"
CACHE_PACKAGE="$8"
BACKUP_PATH="${TARGET_PATH}.bak"
PRIMARY_CODE=0
PRIMARY_ERROR=""
BACKUP_CREATED=0

write_record() {
  /usr/bin/printf '{"schemaVersion":1,"operationId":"%s","stage":"%s","exitCode":%s,"errorCode":"%s"}\n' \
    "$OPERATION_ID" "$1" "$2" "$3" > "$RECORD_PATH.tmp"
  /bin/mv -f "$RECORD_PATH.tmp" "$RECORD_PATH"
}

fail() {
  PRIMARY_CODE="$1"
  PRIMARY_ERROR="$2"
}

finish() {
  if [ "$PRIMARY_CODE" -ne 0 ]; then
    if [ "$BACKUP_CREATED" -eq 1 ]; then
      /bin/rm -f -- "$TARGET_PATH"
      /bin/mv -- "$BACKUP_PATH" "$TARGET_PATH" >/dev/null 2>&1 || true
    fi
    write_record failed "$PRIMARY_CODE" "$PRIMARY_ERROR"
  fi
  /bin/rm -f -- "$0"
  /bin/rmdir "$(dirname -- "$0")" >/dev/null 2>&1 || true
}
trap finish EXIT HUP INT TERM

case "$PID" in
  ''|*[!0-9]*) fail 20 linux_invalid_pid ;;
  *) [ "$PID" -gt 0 ] || fail 20 linux_invalid_pid ;;
esac
[ "$PRIMARY_CODE" -eq 0 ] || exit "$PRIMARY_CODE"
[ -f "$PACKAGE_PATH" ] || { fail 21 linux_package_missing; exit "$PRIMARY_CODE"; }
case "$CACHE_PACKAGE" in
  "$CACHE_ROOT"/*) ;;
  *) fail 22 linux_package_outside_cache; exit "$PRIMARY_CODE" ;;
esac

WAIT_COUNT=0
while /bin/kill -0 "$PID" >/dev/null 2>&1; do
  WAIT_COUNT=$((WAIT_COUNT + 1))
  [ "$WAIT_COUNT" -lt 120 ] || { fail 23 linux_wait_timeout; exit "$PRIMARY_CODE"; }
  /bin/sleep 1
done

case "$MODE" in
  deb) /usr/bin/pkexec /usr/bin/dpkg -i "$PACKAGE_PATH" ;;
  rpmDnf) /usr/bin/pkexec /usr/bin/dnf install -y "$PACKAGE_PATH" ;;
  rpmZypper) /usr/bin/pkexec /usr/bin/zypper --non-interactive install "$PACKAGE_PATH" ;;
  rpmDirect) /usr/bin/pkexec /usr/bin/rpm -Uvh "$PACKAGE_PATH" ;;
  pacman) /usr/bin/pkexec /usr/bin/pacman -U --noconfirm "$PACKAGE_PATH" ;;
  appImage)
    [ "$(dirname -- "$PACKAGE_PATH")" = "$(dirname -- "$TARGET_PATH")" ] || {
      fail 24 linux_appimage_cross_filesystem
      exit "$PRIMARY_CODE"
    }
    [ ! -e "$BACKUP_PATH" ] || { fail 25 linux_appimage_backup_exists; exit "$PRIMARY_CODE"; }
    /bin/mv -- "$TARGET_PATH" "$BACKUP_PATH" || { fail 26 linux_appimage_backup_failed; exit "$PRIMARY_CODE"; }
    BACKUP_CREATED=1
    /bin/mv -- "$PACKAGE_PATH" "$TARGET_PATH" || { fail 27 linux_appimage_replace_failed; exit "$PRIMARY_CODE"; }
    "$TARGET_PATH" >/dev/null 2>&1 &
    NEW_PID=$!
    /bin/sleep 1
    /bin/kill -0 "$NEW_PID" >/dev/null 2>&1 || {
      fail 28 linux_appimage_launch_failed
      exit "$PRIMARY_CODE"
    }
    BACKUP_CREATED=0
    /bin/rm -f -- "$BACKUP_PATH" "$CACHE_PACKAGE"
    write_record completed 0 ""
    trap - EXIT HUP INT TERM
    finish
    exit 0
    ;;
  *) fail 29 linux_mode_invalid; exit "$PRIMARY_CODE" ;;
esac
COMMAND_CODE=$?
if [ "$COMMAND_CODE" -ne 0 ]; then
  if [ "$COMMAND_CODE" -eq 126 ]; then
    fail 126 linux_policykit_cancelled
  elif [ "$COMMAND_CODE" -eq 127 ]; then
    fail 127 linux_command_missing
  else
    fail "$COMMAND_CODE" linux_package_manager_failed
  fi
  exit "$PRIMARY_CODE"
fi

"$TARGET_PATH" >/dev/null 2>&1 &
NEW_PID=$!
[ "$NEW_PID" -gt 0 ] || { fail 30 linux_restart_failed; exit "$PRIMARY_CODE"; }
/bin/rm -f -- "$CACHE_PACKAGE"
write_record completed 0 ""
trap - EXIT HUP INT TERM
finish
exit 0
''';
