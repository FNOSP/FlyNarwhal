import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

import '../../core/utils/log/app_talker.dart';
import '../../core/version/semantic_version.dart';
import '../../domain/update/entities/verified_update_artifact.dart';
import 'update_path_safety.dart';

typedef WindowsApplicationSupportDirectoryProvider = Future<Directory>
    Function();

Future<Directory> loadWindowsNativeUpdateSupportDirectory() async {
  final localAppDataPath = Platform.environment['LOCALAPPDATA'];
  if (localAppDataPath == null || localAppDataPath.trim().isEmpty) {
    throw const WindowsUpdateInstallStageException(
      WindowsUpdateInstallStageFailureReason.unsafePath,
      'LOCALAPPDATA is unavailable for the Windows update stage.',
    );
  }
  return Directory(path.join(localAppDataPath, 'FlyNarwhal'));
}

const String _stageDirectoryPrefix = 'desktop_updater_stage_';
const String _installerFileName = 'installer.exe';
const String _authorityFileName = 'release-authority.json';
const String _provenanceFileName = '.desktop_updater_stage_provenance.json';
const String _applicationPackageId = 'fly_narwhal';

final RegExp _lowercaseUuidV4Expression = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
final RegExp _sha256Expression = RegExp(r'^[0-9a-f]{64}$');

/// Describes a rejection while creating or verifying a Windows install stage.
enum WindowsUpdateInstallStageFailureReason {
  invalidTransactionId,
  invalidArtifact,
  unsafePath,
  invalidAuthority,
  invalidProvenance,
  unexpectedStageEntry,
  stageAlreadyExists,
}

/// Reports a stage trust failure without exposing an installation command.
final class WindowsUpdateInstallStageException implements Exception {
  const WindowsUpdateInstallStageException(this.reason, this.message);

  final WindowsUpdateInstallStageFailureReason reason;
  final String message;

  @override
  String toString() => message;
}

/// Immutable app-owned authority bound to a verified GitHub release artifact.
final class WindowsUpdateInstallAuthority {
  const WindowsUpdateInstallAuthority({
    required this.schemaVersion,
    required this.transactionId,
    required this.operationId,
    required this.packageId,
    required this.version,
    required this.platform,
    required this.architecture,
    required this.packageType,
    required this.artifactFileName,
    required this.artifactLength,
    required this.artifactSha256,
    required this.source,
  });

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String transactionId;
  final String operationId;
  final String packageId;
  final String version;
  final String platform;
  final String architecture;
  final String packageType;
  final String artifactFileName;
  final int artifactLength;
  final String artifactSha256;
  final String source;

  factory WindowsUpdateInstallAuthority.fromJson(Map<String, Object?> json) {
    final authority = WindowsUpdateInstallAuthority(
      schemaVersion: _requiredInt(json, 'schemaVersion'),
      transactionId: _requiredString(json, 'transactionId'),
      operationId: _requiredString(json, 'operationId'),
      packageId: _requiredString(json, 'packageId'),
      version: _requiredString(json, 'version'),
      platform: _requiredString(json, 'platform'),
      architecture: _requiredString(json, 'architecture'),
      packageType: _requiredString(json, 'packageType'),
      artifactFileName: _requiredString(json, 'artifactFileName'),
      artifactLength: _requiredInt(json, 'artifactLength'),
      artifactSha256: _requiredString(json, 'artifactSha256'),
      source: _requiredString(json, 'source'),
    );
    authority.validate();
    return authority;
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': schemaVersion,
        'transactionId': transactionId,
        'operationId': operationId,
        'packageId': packageId,
        'version': version,
        'platform': platform,
        'architecture': architecture,
        'packageType': packageType,
        'artifactFileName': artifactFileName,
        'artifactLength': artifactLength,
        'artifactSha256': artifactSha256,
        'source': source,
      };

  void validate() {
    if (schemaVersion != currentSchemaVersion ||
        !_lowercaseUuidV4Expression.hasMatch(transactionId) ||
        operationId.isEmpty ||
        packageId != _applicationPackageId ||
        SemanticVersion.tryParse(version) == null ||
        platform != 'windows' ||
        (architecture != 'x64' && architecture != 'arm64') ||
        packageType != 'exe' ||
        artifactFileName != _installerFileName ||
        artifactLength <= 0 ||
        !_sha256Expression.hasMatch(artifactSha256) ||
        source != 'github-release-digest') {
      throw const WindowsUpdateInstallStageException(
        WindowsUpdateInstallStageFailureReason.invalidAuthority,
        'Windows update install authority is invalid.',
      );
    }
  }
}

/// One canonical inventory entry for a stage directory.
final class WindowsStageInventoryEntry {
  const WindowsStageInventoryEntry({
    required this.kind,
    required this.length,
    required this.relativePath,
    this.sha256,
  });

  final String kind;
  final int length;
  final String relativePath;
  final String? sha256;

  Map<String, Object?> toJson() => <String, Object?>{
        'kind': kind,
        'length': length,
        'relativePath': relativePath,
        if (sha256 != null) 'sha256': sha256,
      };
}

/// Canonical, compact provenance payload for an owned stage.
final class WindowsStageProvenance {
  const WindowsStageProvenance({
    required this.schemaVersion,
    required this.stageName,
    required this.entries,
  });

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String stageName;
  final List<WindowsStageInventoryEntry> entries;

  String toCanonicalJson() => jsonEncode(<String, Object?>{
        'schemaVersion': schemaVersion,
        'stageName': stageName,
        'entries': entries.map((entry) => entry.toJson()).toList(),
      });

  String get digest =>
      sha256.convert(utf8.encode(toCanonicalJson())).toString();
}

/// Immutable result returned only after the new stage has been revalidated.
final class WindowsUpdateInstallStage {
  const WindowsUpdateInstallStage({
    required this.transactionId,
    required this.stageDirectory,
    required this.installerFile,
    required this.authorityFile,
    required this.provenanceFile,
    required this.provenanceSha256,
    required this.authority,
  });

  final String transactionId;
  final Directory stageDirectory;
  final File installerFile;
  final File authorityFile;
  final File provenanceFile;
  final String provenanceSha256;
  final WindowsUpdateInstallAuthority authority;
}

/// Creates and verifies owned Windows install stages without launching a helper.
final class WindowsUpdateInstallStageStore {
  WindowsUpdateInstallStageStore({
    WindowsApplicationSupportDirectoryProvider?
        applicationSupportDirectoryProvider,
  }) : _applicationSupportDirectoryProvider =
            applicationSupportDirectoryProvider ??
                loadWindowsNativeUpdateSupportDirectory;

  final WindowsApplicationSupportDirectoryProvider
      _applicationSupportDirectoryProvider;

  Future<WindowsUpdateInstallStage> createStage({
    required VerifiedUpdateArtifact artifact,
    required String transactionId,
    required String operationId,
    required String architecture,
  }) async {
    AppTalker.info(
      'WindowsUpdateStage',
      'Creating Windows install stage for transaction $transactionId.',
    );
    _validateTransactionId(transactionId);
    if (operationId.isEmpty ||
        (architecture != 'x64' && architecture != 'arm64')) {
      throw const WindowsUpdateInstallStageException(
        WindowsUpdateInstallStageFailureReason.invalidArtifact,
        'Windows update stage request is invalid.',
      );
    }
    await _validateVerifiedArtifact(artifact);
    final stagingRoot = await _loadStagingRoot();
    AppTalker.info(
      'WindowsUpdateStage',
      'Resolved staging root ${stagingRoot.path}.',
    );
    final stageDirectory = Directory(path.join(
      stagingRoot.path,
      '$_stageDirectoryPrefix$transactionId',
    ));
    if (await stageDirectory.exists()) {
      throw const WindowsUpdateInstallStageException(
        WindowsUpdateInstallStageFailureReason.stageAlreadyExists,
        'A Windows update stage already exists for this transaction.',
      );
    }

    await stageDirectory.create();
    try {
      await _assertOwnedStageDirectory(stageDirectory, stagingRoot);
      final installerFile =
          File(path.join(stageDirectory.path, _installerFileName));
      await artifact.file.copy(installerFile.path);
      AppTalker.info(
        'WindowsUpdateStage',
        'Copied verified installer to ${installerFile.path}.',
      );
      final actualDigest = await _digestFile(installerFile);
      if (await installerFile.length() != artifact.length ||
          actualDigest != artifact.sha256) {
        throw const WindowsUpdateInstallStageException(
          WindowsUpdateInstallStageFailureReason.invalidArtifact,
          'Copied installer no longer matches the verified artifact.',
        );
      }

      final authority = WindowsUpdateInstallAuthority(
        schemaVersion: WindowsUpdateInstallAuthority.currentSchemaVersion,
        transactionId: transactionId,
        operationId: operationId,
        packageId: _applicationPackageId,
        version: artifact.candidate.version.toString(),
        platform: 'windows',
        architecture: architecture,
        packageType: 'exe',
        artifactFileName: _installerFileName,
        artifactLength: artifact.length,
        artifactSha256: artifact.sha256,
        source: 'github-release-digest',
      );
      authority.validate();
      final authorityFile =
          File(path.join(stageDirectory.path, _authorityFileName));
      await _writeFileAndFlush(authorityFile, jsonEncode(authority.toJson()));
      AppTalker.info(
        'WindowsUpdateStage',
        'Wrote authority receipt to ${authorityFile.path}.',
      );

      final provenanceFile =
          File(path.join(stageDirectory.path, _provenanceFileName));
      final provenance = await _buildProvenance(stageDirectory);
      await _writeFileAndFlush(provenanceFile, provenance.toCanonicalJson());
      AppTalker.info(
        'WindowsUpdateStage',
        'Wrote provenance receipt to ${provenanceFile.path}.',
      );
      return loadAndVerifyStage(stageDirectory.path);
    } on Object {
      if (await _isOwnedStageDirectory(stageDirectory, stagingRoot)) {
        await stageDirectory.delete(recursive: true);
      }
      rethrow;
    }
  }

  Future<WindowsUpdateInstallStage> loadAndVerifyStage(String stagePath) async {
    AppTalker.info(
      'WindowsUpdateStage',
      'Loading and verifying stage $stagePath.',
    );
    final stagingRoot = await _loadStagingRoot();
    final stageDirectory = Directory(stagePath);
    await _assertOwnedStageDirectory(stageDirectory, stagingRoot);
    final installerFile =
        File(path.join(stageDirectory.path, _installerFileName));
    final authorityFile =
        File(path.join(stageDirectory.path, _authorityFileName));
    final provenanceFile =
        File(path.join(stageDirectory.path, _provenanceFileName));
    if (!await UpdatePathSafety.isSafeRegularFile(installerFile.path) ||
        !await UpdatePathSafety.isSafeRegularFile(authorityFile.path) ||
        !await UpdatePathSafety.isSafeRegularFile(provenanceFile.path)) {
      throw const WindowsUpdateInstallStageException(
        WindowsUpdateInstallStageFailureReason.unsafePath,
        'Windows update stage contains an unsafe required file.',
      );
    }

    final authorityJson = jsonDecode(await authorityFile.readAsString());
    if (authorityJson is! Map<String, Object?>) {
      throw const WindowsUpdateInstallStageException(
        WindowsUpdateInstallStageFailureReason.invalidAuthority,
        'Windows update authority must be an object.',
      );
    }
    final authority = WindowsUpdateInstallAuthority.fromJson(authorityJson);
    if (authority.transactionId !=
            _transactionIdFromStageName(stageDirectory.path) ||
        await installerFile.length() != authority.artifactLength ||
        await _digestFile(installerFile) != authority.artifactSha256) {
      throw const WindowsUpdateInstallStageException(
        WindowsUpdateInstallStageFailureReason.invalidAuthority,
        'Windows update authority does not match the staged installer.',
      );
    }

    final storedProvenance = await provenanceFile.readAsString();
    final currentProvenance = await _buildProvenance(stageDirectory);
    if (storedProvenance != currentProvenance.toCanonicalJson()) {
      throw const WindowsUpdateInstallStageException(
        WindowsUpdateInstallStageFailureReason.invalidProvenance,
        'Windows update stage provenance does not match its contents.',
      );
    }
    return WindowsUpdateInstallStage(
      transactionId: authority.transactionId,
      stageDirectory: stageDirectory,
      installerFile: installerFile,
      authorityFile: authorityFile,
      provenanceFile: provenanceFile,
      provenanceSha256: currentProvenance.digest,
      authority: authority,
    );
  }

  Future<void> deleteStage(WindowsUpdateInstallStage stage) async {
    AppTalker.info(
      'WindowsUpdateStage',
      'Deleting stage ${stage.stageDirectory.path}.',
    );
    final stagingRoot = await _loadStagingRoot();
    await _assertOwnedStageDirectory(stage.stageDirectory, stagingRoot);
    await stage.stageDirectory.delete(recursive: true);
  }

  Future<Directory> _loadStagingRoot() async {
    final supportDirectory = await _applicationSupportDirectoryProvider();
    final stagingRoot = Directory(path.join(
      supportDirectory.path,
      'updates',
      'install-staging',
    ));
    await stagingRoot.create(recursive: true);
    if (!await UpdatePathSafety.isSafeDirectoryTree(stagingRoot.path)) {
      throw const WindowsUpdateInstallStageException(
        WindowsUpdateInstallStageFailureReason.unsafePath,
        'Windows update staging root is unsafe.',
      );
    }
    return stagingRoot;
  }

  Future<void> _validateVerifiedArtifact(
      VerifiedUpdateArtifact artifact) async {
    if (path.extension(artifact.file.path).toLowerCase() != '.exe' ||
        artifact.length <= 0 ||
        !_sha256Expression.hasMatch(artifact.sha256) ||
        !await UpdatePathSafety.isSafeRegularFile(artifact.file.path) ||
        await artifact.file.length() != artifact.length ||
        await _digestFile(artifact.file) != artifact.sha256) {
      throw const WindowsUpdateInstallStageException(
        WindowsUpdateInstallStageFailureReason.invalidArtifact,
        'Verified update artifact is invalid for a Windows install stage.',
      );
    }
  }

  Future<WindowsStageProvenance> _buildProvenance(
      Directory stageDirectory) async {
    final entries = <WindowsStageInventoryEntry>[
      const WindowsStageInventoryEntry(
          kind: 'directory', length: 0, relativePath: '.'),
    ];
    await for (final entity
        in stageDirectory.list(recursive: true, followLinks: false)) {
      final relativePath = path
          .relative(entity.path, from: stageDirectory.path)
          .replaceAll(r'\', '/');
      if (relativePath == _provenanceFileName ||
          relativePath == 'pending-install.json') {
        continue;
      }
      if (!_isAllowedStageEntry(relativePath)) {
        throw const WindowsUpdateInstallStageException(
          WindowsUpdateInstallStageFailureReason.unexpectedStageEntry,
          'Windows update stage contains an unexpected entry.',
        );
      }
      final entityType =
          await FileSystemEntity.type(entity.path, followLinks: false);
      if (entityType == FileSystemEntityType.directory) {
        entries.add(WindowsStageInventoryEntry(
            kind: 'directory', length: 0, relativePath: relativePath));
      } else if (entityType == FileSystemEntityType.file) {
        final file = File(entity.path);
        entries.add(WindowsStageInventoryEntry(
          kind: 'file',
          length: await file.length(),
          relativePath: relativePath,
          sha256: await _digestFile(file),
        ));
      } else {
        throw const WindowsUpdateInstallStageException(
          WindowsUpdateInstallStageFailureReason.unsafePath,
          'Windows update stage contains a link or unsupported entity.',
        );
      }
    }
    entries.sort((first, second) =>
        _compareUtf8(first.relativePath, second.relativePath));
    return WindowsStageProvenance(
      schemaVersion: WindowsStageProvenance.currentSchemaVersion,
      stageName: path.basename(stageDirectory.path),
      entries: List<WindowsStageInventoryEntry>.unmodifiable(entries),
    );
  }

  bool _isAllowedStageEntry(String relativePath) {
    return relativePath == _installerFileName ||
        relativePath == _authorityFileName ||
        relativePath == 'pending-install.json';
  }

  Future<void> _assertOwnedStageDirectory(
    Directory stageDirectory,
    Directory stagingRoot,
  ) async {
    if (!await _isOwnedStageDirectory(stageDirectory, stagingRoot)) {
      throw const WindowsUpdateInstallStageException(
        WindowsUpdateInstallStageFailureReason.unsafePath,
        'Windows update stage is not an owned staging-root child.',
      );
    }
  }

  Future<bool> _isOwnedStageDirectory(
    Directory stageDirectory,
    Directory stagingRoot,
  ) async {
    final stageName = path.basename(stageDirectory.path);
    final isDirectChild = UpdatePathSafety.sameWindowsPath(
      firstPath: stageDirectory.parent.path,
      secondPath: stagingRoot.path,
    );
    return isDirectChild &&
        stageName.startsWith(_stageDirectoryPrefix) &&
        _lowercaseUuidV4Expression.hasMatch(
          stageName.substring(_stageDirectoryPrefix.length),
        ) &&
        await UpdatePathSafety.isSafeDirectoryTree(stageDirectory.path);
  }

  String _transactionIdFromStageName(String stagePath) {
    final stageName = path.basename(stagePath);
    if (!stageName.startsWith(_stageDirectoryPrefix)) {
      throw const WindowsUpdateInstallStageException(
        WindowsUpdateInstallStageFailureReason.unsafePath,
        'Windows update stage has an invalid name.',
      );
    }
    final transactionId = stageName.substring(_stageDirectoryPrefix.length);
    _validateTransactionId(transactionId);
    return transactionId;
  }

  void _validateTransactionId(String transactionId) {
    if (!_lowercaseUuidV4Expression.hasMatch(transactionId)) {
      throw const WindowsUpdateInstallStageException(
        WindowsUpdateInstallStageFailureReason.invalidTransactionId,
        'Windows update transaction ID must be a lowercase UUID v4.',
      );
    }
  }

  Future<String> _digestFile(File file) =>
      sha256.bind(file.openRead()).single.then((digest) => digest.toString());

  Future<void> _writeFileAndFlush(File file, String contents) async {
    final sink = file.openWrite(mode: FileMode.writeOnly);
    try {
      sink.write(contents);
      await sink.flush();
    } finally {
      await sink.close();
    }
  }
}

int _compareUtf8(String first, String second) {
  final firstBytes = utf8.encode(first);
  final secondBytes = utf8.encode(second);
  final comparedLength = firstBytes.length < secondBytes.length
      ? firstBytes.length
      : secondBytes.length;
  for (var index = 0; index < comparedLength; index++) {
    final difference = firstBytes[index] - secondBytes[index];
    if (difference != 0) return difference;
  }
  return firstBytes.length - secondBytes.length;
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw const WindowsUpdateInstallStageException(
      WindowsUpdateInstallStageFailureReason.invalidAuthority,
      'Windows update authority contains an invalid string field.',
    );
  }
  return value;
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw const WindowsUpdateInstallStageException(
      WindowsUpdateInstallStageFailureReason.invalidAuthority,
      'Windows update authority contains an invalid integer field.',
    );
  }
  return value;
}
