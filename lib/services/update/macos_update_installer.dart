import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'platform_update_installer.dart';

const String macOSApplicationName = 'FlyNarwhal.app';
const String macOSBundleIdentifier = 'com.jankinwu.flyNarwhal';
final path.Context _macOSPath = path.Context(style: path.Style.posix);
final RegExp _operationIdPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$');
final RegExp _sha256Pattern = RegExp(r'^[a-f0-9]{64}$');

final class MacOSUpdateInstallInput {
  const MacOSUpdateInstallInput({
    required this.processId,
    required this.dmgFilePath,
    required this.currentAppBundlePath,
    required this.expectedAppBundlePath,
    required this.bundleIdentifier,
    required this.cacheRootPath,
    required this.installRecordPath,
  });

  final int processId;
  final String dmgFilePath;
  final String currentAppBundlePath;
  final String expectedAppBundlePath;
  final String bundleIdentifier;
  final String cacheRootPath;
  final String installRecordPath;
}

enum MacOSInstallRecordStage { launched, failed, completed }

final class MacOSInstallRecord {
  const MacOSInstallRecord({
    required this.operationId,
    required this.version,
    required this.expectedSha256,
    required this.stage,
    required this.exitCode,
    required this.primaryError,
    required this.rollbackAttempted,
    required this.rollbackSucceeded,
    required this.rollbackError,
    required this.backupPath,
    required this.createdAt,
  });

  static const int schemaVersion = 2;

  final String operationId;
  final String version;
  final String expectedSha256;
  final MacOSInstallRecordStage stage;
  final int exitCode;
  final String? primaryError;
  final bool rollbackAttempted;
  final bool rollbackSucceeded;
  final String? rollbackError;
  final String? backupPath;
  final DateTime createdAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': schemaVersion,
        'operationId': operationId,
        'version': version,
        'expectedSha256': expectedSha256,
        'stage': stage.name,
        'exitCode': exitCode,
        'primaryError': primaryError,
        'rollbackAttempted': rollbackAttempted,
        'rollbackSucceeded': rollbackSucceeded,
        'rollbackError': rollbackError,
        'backupPath': backupPath,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  static MacOSInstallRecord? tryParse(String contents) {
    try {
      final decoded = jsonDecode(contents);
      if (decoded is! Map<String, dynamic> ||
          decoded['schemaVersion'] != schemaVersion) {
        return null;
      }
      final operationId = decoded['operationId'];
      final version = decoded['version'];
      final expectedSha256 = decoded['expectedSha256'];
      final stageName = decoded['stage'];
      final exitCode = decoded['exitCode'];
      final rollbackAttempted = decoded['rollbackAttempted'];
      final rollbackSucceeded = decoded['rollbackSucceeded'];
      final createdAtValue = decoded['createdAt'];
      if (operationId is! String ||
          version is! String ||
          expectedSha256 is! String ||
          stageName is! String ||
          exitCode is! int ||
          rollbackAttempted is! bool ||
          rollbackSucceeded is! bool ||
          createdAtValue is! String) {
        return null;
      }
      final stage = MacOSInstallRecordStage.values
          .where((value) => value.name == stageName)
          .firstOrNull;
      final createdAt = DateTime.tryParse(createdAtValue);
      if (stage == null || createdAt == null) return null;
      final primaryError = decoded['primaryError'];
      final rollbackError = decoded['rollbackError'];
      final backupPath = decoded['backupPath'];
      if ((primaryError != null && primaryError is! String) ||
          (rollbackError != null && rollbackError is! String) ||
          (backupPath != null && backupPath is! String)) {
        return null;
      }
      return MacOSInstallRecord(
        operationId: operationId,
        version: version,
        expectedSha256: expectedSha256,
        stage: stage,
        exitCode: exitCode,
        primaryError: primaryError as String?,
        rollbackAttempted: rollbackAttempted,
        rollbackSucceeded: rollbackSucceeded,
        rollbackError: rollbackError as String?,
        backupPath: backupPath as String?,
        createdAt: createdAt.toUtc(),
      );
    } on FormatException {
      return null;
    }
  }
}

abstract interface class MacOSInstallerFileSystem {
  Future<bool> fileExists(String filePath);
  Future<bool> directoryExists(String directoryPath);
  Future<bool> symbolicLinkExists(String entityPath);
  Future<String> resolvePath(String entityPath);
  Future<String> createPrivateTemporaryDirectory(String parentPath);
  Future<void> copyFile(String sourcePath, String destinationPath);
  Future<void> deleteFile(String filePath);
  Future<void> deleteDirectoryIfEmpty(String directoryPath);
  Future<void> writeTextFile(String filePath, String contents);
  Future<void> makeOwnerExecutable(String filePath);
  Future<void> writeInstallRecord(String recordPath, MacOSInstallRecord record);
  Future<String?> readTextFile(String filePath);
}

final class IoMacOSInstallerFileSystem implements MacOSInstallerFileSystem {
  const IoMacOSInstallerFileSystem();

  @override
  Future<bool> fileExists(String filePath) => File(filePath).exists();

  @override
  Future<bool> directoryExists(String directoryPath) =>
      Directory(directoryPath).exists();

  @override
  Future<bool> symbolicLinkExists(String entityPath) async {
    return await FileSystemEntity.type(entityPath, followLinks: false) ==
        FileSystemEntityType.link;
  }

  @override
  Future<String> resolvePath(String entityPath) async {
    final type = await FileSystemEntity.type(entityPath, followLinks: true);
    if (type == FileSystemEntityType.notFound) {
      return File(entityPath).absolute.path;
    }
    return File(entityPath).resolveSymbolicLinks();
  }

  @override
  Future<String> createPrivateTemporaryDirectory(String parentPath) async {
    final temporaryDirectory =
        await Directory(parentPath).createTemp('macos-installer-');
    await _chmod(temporaryDirectory.path, '0700');
    return temporaryDirectory.path;
  }

  @override
  Future<void> copyFile(String sourcePath, String destinationPath) async {
    await File(sourcePath).copy(destinationPath);
    await _chmod(destinationPath, '0600');
  }

  @override
  Future<void> deleteFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> deleteDirectoryIfEmpty(String directoryPath) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) return;
    if (await directory.list(followLinks: false).isEmpty) {
      await directory.delete();
    }
  }

  @override
  Future<void> writeTextFile(String filePath, String contents) async {
    await File(filePath).writeAsString(contents, flush: true);
  }

  @override
  Future<void> makeOwnerExecutable(String filePath) => _chmod(filePath, '0700');

  @override
  Future<void> writeInstallRecord(
    String recordPath,
    MacOSInstallRecord record,
  ) async {
    final temporaryPath = '$recordPath.tmp';
    if (await symbolicLinkExists(recordPath) ||
        await symbolicLinkExists(temporaryPath)) {
      throw const FileSystemException(
        'Install record path is a symbolic link.',
      );
    }
    await File(temporaryPath).writeAsString(
      jsonEncode(record.toJson()),
      flush: true,
    );
    await _chmod(temporaryPath, '0600');
    await File(temporaryPath).rename(recordPath);
    await _chmod(recordPath, '0600');
  }

  @override
  Future<String?> readTextFile(String filePath) async {
    if (await symbolicLinkExists(filePath)) return null;
    final file = File(filePath);
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  Future<void> _chmod(String entityPath, String mode) async {
    final result = await Process.run('/bin/chmod', <String>[mode, entityPath]);
    if (result.exitCode != 0) {
      throw FileSystemException(
          'Unable to set private permissions.', entityPath);
    }
  }
}

abstract interface class MacOSInstallerProcessLauncher {
  Future<void> startDetached(String executable, List<String> arguments);
}

final class IoMacOSInstallerProcessLauncher
    implements MacOSInstallerProcessLauncher {
  const IoMacOSInstallerProcessLauncher();

  @override
  Future<void> startDetached(String executable, List<String> arguments) async {
    await Process.start(executable, arguments, mode: ProcessStartMode.detached);
  }
}

typedef MacOSInstallInputFactory = Future<MacOSUpdateInstallInput> Function(
  PlatformUpdateInstallRequest request,
);

final class MacOSUpdateInstaller implements PlatformUpdateInstaller {
  MacOSUpdateInstaller({
    required MacOSInstallInputFactory inputFactory,
    MacOSInstallerFileSystem fileSystem = const IoMacOSInstallerFileSystem(),
    MacOSInstallerProcessLauncher processLauncher =
        const IoMacOSInstallerProcessLauncher(),
    DateTime Function()? now,
  })  : _inputFactory = inputFactory,
        _fileSystem = fileSystem,
        _processLauncher = processLauncher,
        _now = now ?? DateTime.now;

  static const String scriptFileName = 'install-update.sh';
  static const String privateDmgFileName = 'verified-update.dmg';
  static const String scriptContents = _macOSInstallerScript;
  static const Duration launchedRecordTimeout = Duration(minutes: 10);

  final MacOSInstallInputFactory _inputFactory;
  final MacOSInstallerFileSystem _fileSystem;
  final MacOSInstallerProcessLauncher _processLauncher;
  final DateTime Function() _now;

  @override
  Future<PlatformUpdateInstallResult> launch(
    PlatformUpdateInstallRequest request,
  ) async {
    String? helperDirectory;
    try {
      final expectedSha256 = _extractSha256(request.candidate.asset.digest);
      _validateOperationId(request.operationId);
      final input = await _inputFactory(request);
      final validatedInput = await _validateInput(input);
      await _validateRecordBoundary(validatedInput);
      helperDirectory = await _fileSystem.createPrivateTemporaryDirectory(
        validatedInput.cacheRootPath,
      );
      final scriptPath = _macOSPath.join(helperDirectory, scriptFileName);
      final privateDmgPath =
          _macOSPath.join(helperDirectory, privateDmgFileName);

      // Seal the verified package inside the private helper directory.
      await _fileSystem.copyFile(validatedInput.dmgFilePath, privateDmgPath);
      await _fileSystem.writeTextFile(scriptPath, scriptContents);
      await _fileSystem.makeOwnerExecutable(scriptPath);
      await _processLauncher.startDetached('/bin/sh', <String>[
        scriptPath,
        validatedInput.processId.toString(),
        privateDmgPath,
        validatedInput.currentAppBundlePath,
        validatedInput.bundleIdentifier,
        validatedInput.installRecordPath,
        _macOSPath.dirname(validatedInput.installRecordPath),
        request.operationId,
        request.candidate.version.toString(),
        expectedSha256,
      ]);
      return const PlatformUpdateHelperLaunched();
    } on MacOSInstallerValidationException catch (error) {
      if (helperDirectory != null) {
        await _cleanupFailedHelper(helperDirectory);
      }
      return PlatformUpdateInstallFailure(
        code: error.code,
        userMessageKey: 'update.install.error.invalidTarget',
        technicalDetail: error.message,
        isRetryable: false,
        cause: error,
      );
    } on Object catch (error) {
      if (helperDirectory != null) {
        await _cleanupFailedHelper(helperDirectory);
      }
      return PlatformUpdateInstallFailure(
        code: 'macos_helper_launch_failed',
        userMessageKey: 'update.install.error.launchFailed',
        technicalDetail: 'The macOS installer helper could not be created.',
        isRetryable: true,
        cause: error,
      );
    }
  }

  Future<MacOSUpdateInstallInput> _validateInput(
    MacOSUpdateInstallInput input,
  ) async {
    if (input.processId <= 0) {
      throw const MacOSInstallerValidationException(
        'macos_invalid_pid',
        'The application process ID must be positive.',
      );
    }
    if (input.bundleIdentifier != macOSBundleIdentifier) {
      throw const MacOSInstallerValidationException(
        'macos_bundle_identifier_mismatch',
        'The requested bundle identifier does not match the product identity.',
      );
    }
    if (!input.currentAppBundlePath.endsWith('.app') ||
        !await _fileSystem.directoryExists(input.currentAppBundlePath)) {
      throw const MacOSInstallerValidationException(
        'macos_invalid_app_bundle',
        'The current application path is not an existing app bundle.',
      );
    }
    if (!await _fileSystem.fileExists(input.dmgFilePath)) {
      throw const MacOSInstallerValidationException(
        'macos_dmg_missing',
        'The DMG package does not exist.',
      );
    }

    final resolvedCacheRoot =
        await _fileSystem.resolvePath(input.cacheRootPath);
    final resolvedDmgPath = await _fileSystem.resolvePath(input.dmgFilePath);
    final resolvedCurrentApp =
        await _fileSystem.resolvePath(input.currentAppBundlePath);
    final resolvedExpectedApp =
        await _fileSystem.resolvePath(input.expectedAppBundlePath);
    if (!_pathsEqual(input.currentAppBundlePath, resolvedCurrentApp) ||
        !_pathsEqual(input.expectedAppBundlePath, resolvedExpectedApp)) {
      throw const MacOSInstallerValidationException(
        'macos_app_bundle_symlink_rejected',
        'Symbolic links are not accepted for the current app bundle.',
      );
    }
    if (!_pathsEqual(resolvedCurrentApp, resolvedExpectedApp)) {
      throw const MacOSInstallerValidationException(
        'macos_platform_target_mismatch',
        'The app bundle does not match the PlatformInfo target.',
      );
    }
    if (!_macOSPath.isWithin(resolvedCacheRoot, resolvedDmgPath)) {
      throw const MacOSInstallerValidationException(
        'macos_dmg_outside_cache',
        'The DMG package must be inside the update cache.',
      );
    }
    return MacOSUpdateInstallInput(
      processId: input.processId,
      dmgFilePath: resolvedDmgPath,
      currentAppBundlePath: resolvedCurrentApp,
      expectedAppBundlePath: resolvedExpectedApp,
      bundleIdentifier: input.bundleIdentifier,
      cacheRootPath: resolvedCacheRoot,
      installRecordPath: _macOSPath.normalize(input.installRecordPath),
    );
  }

  Future<void> _validateRecordBoundary(MacOSUpdateInstallInput input) async {
    final recordParent = _macOSPath.dirname(input.installRecordPath);
    if (!await _fileSystem.directoryExists(recordParent)) {
      throw const MacOSInstallerValidationException(
        'macos_record_parent_missing',
        'The install record parent must already exist.',
      );
    }
    final resolvedParent = await _fileSystem.resolvePath(recordParent);
    if (!_pathsEqual(recordParent, resolvedParent) ||
        !_macOSPath.isWithin(input.cacheRootPath, resolvedParent)) {
      throw const MacOSInstallerValidationException(
        'macos_record_parent_unsafe',
        'The install record parent escaped the real cache boundary.',
      );
    }
    if (await _fileSystem.symbolicLinkExists(input.installRecordPath) ||
        await _fileSystem
            .symbolicLinkExists('${input.installRecordPath}.tmp')) {
      throw const MacOSInstallerValidationException(
        'macos_record_symlink_rejected',
        'Symbolic links are not accepted for install records.',
      );
    }
  }

  String _extractSha256(String? digest) {
    final normalized = digest?.toLowerCase();
    final value = normalized?.startsWith('sha256:') == true
        ? normalized!.substring('sha256:'.length)
        : null;
    if (value == null || !_sha256Pattern.hasMatch(value)) {
      throw const MacOSInstallerValidationException(
        'macos_digest_invalid',
        'A valid SHA-256 digest is required.',
      );
    }
    return value;
  }

  void _validateOperationId(String operationId) {
    if (!_operationIdPattern.hasMatch(operationId)) {
      throw const MacOSInstallerValidationException(
        'macos_operation_id_invalid',
        'The operation ID contains unsafe characters or is too long.',
      );
    }
  }

  bool _pathsEqual(String firstPath, String secondPath) {
    return _macOSPath.equals(
      _macOSPath.normalize(firstPath),
      _macOSPath.normalize(secondPath),
    );
  }

  Future<void> _cleanupFailedHelper(String helperDirectory) async {
    await _fileSystem.deleteFile(
      _macOSPath.join(helperDirectory, privateDmgFileName),
    );
    await _fileSystem
        .deleteFile(_macOSPath.join(helperDirectory, scriptFileName));
    await _fileSystem.deleteDirectoryIfEmpty(helperDirectory);
  }

  Future<PlatformUpdateInstallFailure?> recoverFailure(
    String installRecordPath, {
    String? expectedOperationId,
    String? expectedVersion,
    String? expectedDigest,
  }) async {
    final contents = await _fileSystem.readTextFile(installRecordPath);
    if (contents == null) return null;
    final record = MacOSInstallRecord.tryParse(contents);
    if (record == null ||
        (expectedOperationId != null &&
            record.operationId != expectedOperationId) ||
        (expectedVersion != null && record.version != expectedVersion) ||
        (expectedDigest != null &&
            record.expectedSha256 != _extractSha256(expectedDigest))) {
      return null;
    }

    final launchedTimedOut = record.stage == MacOSInstallRecordStage.launched &&
        _now().toUtc().difference(record.createdAt) >= launchedRecordTimeout;
    if (record.stage != MacOSInstallRecordStage.failed && !launchedTimedOut) {
      return null;
    }

    // Consume a matching terminal record to prevent repeated stale failures.
    await _fileSystem.deleteFile(installRecordPath);
    final failureCode = launchedTimedOut
        ? 'macos_install_record_timeout'
        : record.rollbackAttempted && !record.rollbackSucceeded
            ? 'macos_rollback_failed'
            : record.primaryError ?? 'macos_install_failed';
    return PlatformUpdateInstallFailure(
      code: failureCode,
      userMessageKey: 'update.install.error.failed',
      technicalDetail: jsonEncode(record.toJson()),
      isRetryable: true,
    );
  }
}

final class MacOSInstallerValidationException implements Exception {
  const MacOSInstallerValidationException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}

enum MacOSHelperPhase {
  validating,
  mounted,
  backedUp,
  copied,
  detached,
  opened
}

enum MacOSHelperAction {
  continueInstall,
  detach,
  rollback,
  preserveBackup,
  cleanupSuccess,
  cleanupFailure,
}

final class MacOSHelperState {
  const MacOSHelperState({
    this.phase = MacOSHelperPhase.validating,
    this.primaryError,
    this.rollbackAttempted = false,
    this.rollbackSucceeded = false,
    this.rollbackError,
  });

  final MacOSHelperPhase phase;
  final String? primaryError;
  final bool rollbackAttempted;
  final bool rollbackSucceeded;
  final String? rollbackError;
}

final class MacOSHelperTransition {
  const MacOSHelperTransition(this.state, this.actions);

  final MacOSHelperState state;
  final List<MacOSHelperAction> actions;
}

/// Pure state reducer used to lock failure precedence without executing macOS.
final class MacOSHelperStateReducer {
  const MacOSHelperStateReducer();

  MacOSHelperTransition validateDmg({
    required int appCount,
    required bool bundleMatches,
  }) {
    if (appCount != 1) {
      return const MacOSHelperTransition(
        MacOSHelperState(primaryError: 'macos_app_count_invalid'),
        <MacOSHelperAction>[MacOSHelperAction.detach],
      );
    }
    if (!bundleMatches) {
      return const MacOSHelperTransition(
        MacOSHelperState(primaryError: 'macos_bundle_identifier_mismatch'),
        <MacOSHelperAction>[MacOSHelperAction.detach],
      );
    }
    return const MacOSHelperTransition(
      MacOSHelperState(phase: MacOSHelperPhase.mounted),
      <MacOSHelperAction>[MacOSHelperAction.continueInstall],
    );
  }

  MacOSHelperTransition copyFinished({required bool succeeded}) {
    if (succeeded) {
      return const MacOSHelperTransition(
        MacOSHelperState(phase: MacOSHelperPhase.copied),
        <MacOSHelperAction>[MacOSHelperAction.detach],
      );
    }
    return const MacOSHelperTransition(
      MacOSHelperState(
        phase: MacOSHelperPhase.backedUp,
        primaryError: 'macos_copy_failed',
      ),
      <MacOSHelperAction>[MacOSHelperAction.rollback],
    );
  }

  MacOSHelperTransition rollbackFinished({required bool succeeded}) {
    return MacOSHelperTransition(
      MacOSHelperState(
        phase: MacOSHelperPhase.backedUp,
        primaryError: 'macos_copy_failed',
        rollbackAttempted: true,
        rollbackSucceeded: succeeded,
        rollbackError: succeeded ? null : 'macos_rollback_restore_failed',
      ),
      <MacOSHelperAction>[
        if (!succeeded) MacOSHelperAction.preserveBackup,
        MacOSHelperAction.detach,
      ],
    );
  }

  MacOSHelperTransition detachFinished(
    MacOSHelperState state, {
    required bool succeeded,
  }) {
    final primaryError =
        state.primaryError ?? (succeeded ? null : 'macos_detach_failed');
    return MacOSHelperTransition(
      MacOSHelperState(
        phase: succeeded ? MacOSHelperPhase.detached : state.phase,
        primaryError: primaryError,
        rollbackAttempted: state.rollbackAttempted,
        rollbackSucceeded: state.rollbackSucceeded,
        rollbackError: state.rollbackError,
      ),
      <MacOSHelperAction>[
        if (primaryError == null)
          MacOSHelperAction.continueInstall
        else
          MacOSHelperAction.cleanupFailure,
      ],
    );
  }

  MacOSHelperTransition openFinished({required bool succeeded}) {
    return MacOSHelperTransition(
      MacOSHelperState(
        phase: succeeded ? MacOSHelperPhase.opened : MacOSHelperPhase.detached,
        primaryError: succeeded ? null : 'macos_open_failed',
      ),
      <MacOSHelperAction>[
        succeeded
            ? MacOSHelperAction.cleanupSuccess
            : MacOSHelperAction.rollback,
      ],
    );
  }
}

const String _macOSInstallerScript = r'''#!/bin/sh
set -u

PID="$1"
DMG_PATH="$2"
TARGET_APP="$3"
EXPECTED_BUNDLE_ID="$4"
RECORD_PATH="$5"
EXPECTED_RECORD_PARENT="$6"
OPERATION_ID="$7"
VERSION="$8"
EXPECTED_SHA256="$9"
HELPER_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
MOUNT_POINT="$HELPER_DIR/mount"
BACKUP_APP="${TARGET_APP}.update-backup"
MOUNTED=0
BACKUP_CREATED=0
PRIMARY_CODE=0
PRIMARY_ERROR=""
ROLLBACK_ATTEMPTED=false
ROLLBACK_SUCCEEDED=false
ROLLBACK_ERROR=""

write_record() {
  RECORD_PARENT=$(dirname -- "$RECORD_PATH")
  REAL_RECORD_PARENT=$(CDPATH= cd -- "$RECORD_PARENT" 2>/dev/null && pwd -P) || return 1
  [ "$REAL_RECORD_PARENT" = "$EXPECTED_RECORD_PARENT" ] || return 1
  [ ! -L "$RECORD_PATH" ] && [ ! -L "$RECORD_PATH.tmp" ] || return 1
  CREATED_AT=$(/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')
  /usr/bin/plutil -create json "$RECORD_PATH.tmp" || return 1
  /usr/bin/plutil -insert schemaVersion -integer 2 "$RECORD_PATH.tmp" || return 1
  /usr/bin/plutil -insert operationId -string "$OPERATION_ID" "$RECORD_PATH.tmp" || return 1
  /usr/bin/plutil -insert version -string "$VERSION" "$RECORD_PATH.tmp" || return 1
  /usr/bin/plutil -insert expectedSha256 -string "$EXPECTED_SHA256" "$RECORD_PATH.tmp" || return 1
  /usr/bin/plutil -insert stage -string "$1" "$RECORD_PATH.tmp" || return 1
  /usr/bin/plutil -insert exitCode -integer "$2" "$RECORD_PATH.tmp" || return 1
  /usr/bin/plutil -insert primaryError -string "$3" "$RECORD_PATH.tmp" || return 1
  /usr/bin/plutil -insert rollbackAttempted -bool "$ROLLBACK_ATTEMPTED" "$RECORD_PATH.tmp" || return 1
  /usr/bin/plutil -insert rollbackSucceeded -bool "$ROLLBACK_SUCCEEDED" "$RECORD_PATH.tmp" || return 1
  /usr/bin/plutil -insert rollbackError -string "$ROLLBACK_ERROR" "$RECORD_PATH.tmp" || return 1
  /usr/bin/plutil -insert backupPath -string "$BACKUP_APP" "$RECORD_PATH.tmp" || return 1
  /usr/bin/plutil -insert createdAt -string "$CREATED_AT" "$RECORD_PATH.tmp" || return 1
  /bin/chmod 0600 "$RECORD_PATH.tmp" || return 1
  /bin/mv -f "$RECORD_PATH.tmp" "$RECORD_PATH" || return 1
  /bin/chmod 0600 "$RECORD_PATH"
}

fail() {
  if [ "$PRIMARY_CODE" -eq 0 ]; then
    PRIMARY_CODE="$1"
    PRIMARY_ERROR="$2"
  fi
}

rollback() {
  ROLLBACK_ATTEMPTED=true
  /bin/rm -rf "$TARGET_APP" || {
    ROLLBACK_ERROR=macos_rollback_delete_failed
    return 1
  }
  /bin/mv "$BACKUP_APP" "$TARGET_APP" || {
    ROLLBACK_ERROR=macos_rollback_restore_failed
    return 1
  }
  BACKUP_CREATED=0
  ROLLBACK_SUCCEEDED=true
  return 0
}

finish() {
  if [ "$MOUNTED" -eq 1 ]; then
    /usr/bin/hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1 || fail 28 macos_detach_failed
    MOUNTED=0
  fi
  if [ "$PRIMARY_CODE" -ne 0 ]; then
    if [ "$BACKUP_CREATED" -eq 1 ]; then
      rollback || {
        PRIMARY_CODE=35
        PRIMARY_ERROR=macos_rollback_failed
      }
    fi
    write_record failed "$PRIMARY_CODE" "$PRIMARY_ERROR" || true
    /bin/rm -rf "$MOUNT_POINT"
    /bin/rm -f -- "$DMG_PATH" "$0"
    /bin/rmdir "$HELPER_DIR" >/dev/null 2>&1 || true
    exit "$PRIMARY_CODE"
  fi
}
trap finish EXIT HUP INT TERM
write_record launched 0 "" || exit 36

case "$PID" in ''|*[!0-9]*) fail 20 macos_invalid_pid ;; *) [ "$PID" -gt 0 ] || fail 20 macos_invalid_pid ;; esac
[ "$PRIMARY_CODE" -eq 0 ] || exit "$PRIMARY_CODE"
ACTUAL_SHA256=$(/usr/bin/shasum -a 256 "$DMG_PATH" | /usr/bin/awk '{print $1}') || { fail 37 macos_digest_probe_failed; exit "$PRIMARY_CODE"; }
[ "$ACTUAL_SHA256" = "$EXPECTED_SHA256" ] || { fail 38 macos_digest_mismatch; exit "$PRIMARY_CODE"; }

WAIT_COUNT=0
while /bin/kill -0 "$PID" >/dev/null 2>&1; do
  WAIT_COUNT=$((WAIT_COUNT + 1))
  [ "$WAIT_COUNT" -lt 120 ] || { fail 23 macos_wait_timeout; exit "$PRIMARY_CODE"; }
  /bin/sleep 1
done

TARGET_PARENT=$(dirname -- "$TARGET_APP")
REAL_PARENT=$(CDPATH= cd -- "$TARGET_PARENT" 2>/dev/null && pwd -P) || { fail 39 macos_target_parent_invalid; exit "$PRIMARY_CODE"; }
[ "$TARGET_APP" = "$REAL_PARENT/$(basename -- "$TARGET_APP")" ] || { fail 40 macos_target_changed; exit "$PRIMARY_CODE"; }
[ -d "$TARGET_APP" ] && [ ! -L "$TARGET_APP" ] || { fail 29 macos_target_missing; exit "$PRIMARY_CODE"; }
[ -w "$REAL_PARENT" ] || { fail 30 macos_target_parent_not_writable; exit "$PRIMARY_CODE"; }
[ ! -e "$BACKUP_APP" ] && [ ! -L "$BACKUP_APP" ] || { fail 31 macos_backup_exists; exit "$PRIMARY_CODE"; }

/bin/mkdir "$MOUNT_POINT" || { fail 24 macos_mount_directory_failed; exit "$PRIMARY_CODE"; }
/usr/bin/hdiutil attach -nobrowse -readonly -mountpoint "$MOUNT_POINT" "$DMG_PATH" >/dev/null || { fail 25 macos_mount_failed; exit "$PRIMARY_CODE"; }
MOUNTED=1
APP_COUNT=$(/usr/bin/find "$MOUNT_POINT" -type d -name 'FlyNarwhal.app' -prune -print | /usr/bin/wc -l | /usr/bin/tr -d ' ')
[ "$APP_COUNT" = "1" ] || { fail 26 macos_app_count_invalid; exit "$PRIMARY_CODE"; }
SOURCE_APP=$(/usr/bin/find "$MOUNT_POINT" -type d -name 'FlyNarwhal.app' -prune -print -quit)
ACTUAL_BUNDLE_ID=$(/usr/bin/plutil -extract CFBundleIdentifier raw "$SOURCE_APP/Contents/Info.plist" 2>/dev/null) || { fail 27 macos_bundle_identifier_unreadable; exit "$PRIMARY_CODE"; }
[ "$ACTUAL_BUNDLE_ID" = "$EXPECTED_BUNDLE_ID" ] || { fail 27 macos_bundle_identifier_mismatch; exit "$PRIMARY_CODE"; }

/bin/mv "$TARGET_APP" "$BACKUP_APP" || { fail 32 macos_backup_move_failed; exit "$PRIMARY_CODE"; }
BACKUP_CREATED=1
/usr/bin/ditto "$SOURCE_APP" "$TARGET_APP" || { fail 33 macos_copy_failed; exit "$PRIMARY_CODE"; }
/usr/bin/hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1 || { fail 28 macos_detach_failed; exit "$PRIMARY_CODE"; }
MOUNTED=0
/usr/bin/open "$TARGET_APP" || { fail 34 macos_open_failed; exit "$PRIMARY_CODE"; }
BACKUP_CREATED=0
write_record completed 0 "" || exit 36
/bin/rm -f -- "$DMG_PATH"
/bin/rm -rf "$BACKUP_APP" "$MOUNT_POINT"
/bin/rm -f -- "$0"
trap - EXIT HUP INT TERM
/bin/rmdir "$HELPER_DIR" >/dev/null 2>&1 || true
exit 0
''';
