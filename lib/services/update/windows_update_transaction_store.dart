import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'windows_update_install_stage_store.dart';

/// Reasons why an app-owned pending install receipt is not trustworthy.
enum WindowsUpdateTransactionFailureReason {
  corrupted,
  unsupportedSchema,
  invalidField,
  bindingMismatch,
}

/// Prevents a corrupt receipt from being treated as a recoverable transaction.
final class WindowsUpdateTransactionException implements Exception {
  const WindowsUpdateTransactionException(this.reason, this.message);

  final WindowsUpdateTransactionFailureReason reason;
  final String message;

  @override
  String toString() => message;
}

/// App-owned binding between an owned stage and a future helper reservation.
final class WindowsPendingInstallReceipt {
  const WindowsPendingInstallReceipt({
    required this.schemaVersion,
    required this.transactionId,
    required this.operationId,
    required this.stagePath,
    required this.stageProvenanceSha256,
    required this.expectedArtifactSha256,
    required this.expectedArtifactLength,
    required this.candidateVersion,
    required this.packageId,
    required this.architecture,
  });

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String transactionId;
  final String operationId;
  final String stagePath;
  final String stageProvenanceSha256;
  final String expectedArtifactSha256;
  final int expectedArtifactLength;
  final String candidateVersion;
  final String packageId;
  final String architecture;

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': schemaVersion,
        'transactionId': transactionId,
        'operationId': operationId,
        'stagePath': stagePath,
        'stageProvenanceSha256': stageProvenanceSha256,
        'expectedArtifactSha256': expectedArtifactSha256,
        'expectedArtifactLength': expectedArtifactLength,
        'candidateVersion': candidateVersion,
        'packageId': packageId,
        'architecture': architecture,
      };

  factory WindowsPendingInstallReceipt.fromJson(Map<String, Object?> json) {
    try {
      final receipt = WindowsPendingInstallReceipt(
        schemaVersion: _requiredInt(json, 'schemaVersion'),
        transactionId: _requiredString(json, 'transactionId'),
        operationId: _requiredString(json, 'operationId'),
        stagePath: _requiredString(json, 'stagePath'),
        stageProvenanceSha256: _requiredString(json, 'stageProvenanceSha256'),
        expectedArtifactSha256: _requiredString(json, 'expectedArtifactSha256'),
        expectedArtifactLength: _requiredInt(json, 'expectedArtifactLength'),
        candidateVersion: _requiredString(json, 'candidateVersion'),
        packageId: _requiredString(json, 'packageId'),
        architecture: _requiredString(json, 'architecture'),
      );
      if (receipt.schemaVersion != currentSchemaVersion ||
          receipt.expectedArtifactLength <= 0) {
        throw const FormatException();
      }
      return receipt;
    } on WindowsUpdateTransactionException {
      rethrow;
    } on Object {
      throw const WindowsUpdateTransactionException(
        WindowsUpdateTransactionFailureReason.invalidField,
        'Windows pending install receipt contains invalid fields.',
      );
    }
  }
}

typedef WindowsTransactionSupportDirectoryProvider = Future<Directory>
    Function();

/// Writes stage-local and application-owned receipts with exact readback.
final class WindowsUpdateTransactionStore {
  WindowsUpdateTransactionStore({
    WindowsTransactionSupportDirectoryProvider?
        applicationSupportDirectoryProvider,
  }) : _applicationSupportDirectoryProvider =
            applicationSupportDirectoryProvider ??
                getApplicationSupportDirectory;

  static const String _activeReceiptFileName =
      'active-windows-transaction.json';

  final WindowsTransactionSupportDirectoryProvider
      _applicationSupportDirectoryProvider;

  Future<void> save({
    required WindowsUpdateInstallStage stage,
    required WindowsPendingInstallReceipt receipt,
  }) async {
    _verifyBindings(stage, receipt);
    final receiptFile =
        File(path.join(stage.stageDirectory.path, 'pending-install.json'));
    final temporaryFile = File('${receiptFile.path}.tmp');
    final contents = jsonEncode(receipt.toJson());
    final sink = temporaryFile.openWrite(mode: FileMode.writeOnly);
    try {
      sink.write(contents);
      await sink.flush();
    } finally {
      await sink.close();
    }
    try {
      if (await receiptFile.exists()) await receiptFile.delete();
      await temporaryFile.rename(receiptFile.path);
      final reread = await load(stage);
      if (reread == null || jsonEncode(reread.toJson()) != contents) {
        throw const WindowsUpdateTransactionException(
          WindowsUpdateTransactionFailureReason.bindingMismatch,
          'Windows pending install receipt did not survive the readback check.',
        );
      }
    } finally {
      if (await temporaryFile.exists()) await temporaryFile.delete();
    }
  }

  Future<WindowsPendingInstallReceipt?> load(
      WindowsUpdateInstallStage stage) async {
    final receiptFile =
        File(path.join(stage.stageDirectory.path, 'pending-install.json'));
    if (!await receiptFile.exists()) return null;
    try {
      final decoded = jsonDecode(await receiptFile.readAsString());
      if (decoded is! Map<String, Object?>) throw const FormatException();
      final receipt = WindowsPendingInstallReceipt.fromJson(decoded);
      _verifyBindings(stage, receipt);
      return receipt;
    } on WindowsUpdateTransactionException {
      rethrow;
    } on Object {
      throw const WindowsUpdateTransactionException(
        WindowsUpdateTransactionFailureReason.corrupted,
        'Windows pending install receipt is corrupted.',
      );
    }
  }

  Future<void> delete(WindowsUpdateInstallStage stage) async {
    final receiptFile =
        File(path.join(stage.stageDirectory.path, 'pending-install.json'));
    if (await receiptFile.exists()) await receiptFile.delete();
  }

  Future<void> saveActive(WindowsPendingInstallReceipt receipt) async {
    final activeFile = await _activeReceiptFile();
    await activeFile.parent.create(recursive: true);
    final contents = jsonEncode(receipt.toJson());
    await _replaceAndVerify(activeFile, contents);
  }

  Future<bool> hasActive() async {
    final activeFile = await _activeReceiptFile();
    return activeFile.exists();
  }

  Future<WindowsPendingInstallReceipt?> loadActive() async {
    final activeFile = await _activeReceiptFile();
    if (!await activeFile.exists()) return null;
    try {
      final decoded = jsonDecode(await activeFile.readAsString());
      if (decoded is! Map<String, Object?>) throw const FormatException();
      return WindowsPendingInstallReceipt.fromJson(decoded);
    } on WindowsUpdateTransactionException {
      rethrow;
    } on Object {
      throw const WindowsUpdateTransactionException(
        WindowsUpdateTransactionFailureReason.corrupted,
        'The active Windows update transaction index is corrupted.',
      );
    }
  }

  Future<void> clearActive({String? transactionId}) async {
    final activeFile = await _activeReceiptFile();
    if (!await activeFile.exists()) return;
    if (transactionId != null) {
      final receipt = await loadActive();
      if (receipt?.transactionId != transactionId) return;
    }
    await activeFile.delete();
  }

  Future<File> _activeReceiptFile() async {
    final supportDirectory = await _applicationSupportDirectoryProvider();
    return File(path.join(
      supportDirectory.path,
      'updates',
      _activeReceiptFileName,
    ));
  }

  Future<void> _replaceAndVerify(File destination, String contents) async {
    final temporaryFile = File('${destination.path}.tmp');
    final sink = temporaryFile.openWrite(mode: FileMode.writeOnly);
    try {
      sink.write(contents);
      await sink.flush();
    } finally {
      await sink.close();
    }
    try {
      if (await destination.exists()) await destination.delete();
      await temporaryFile.rename(destination.path);
      if (await destination.readAsString() != contents) {
        throw const WindowsUpdateTransactionException(
          WindowsUpdateTransactionFailureReason.bindingMismatch,
          'The active Windows transaction did not survive exact readback.',
        );
      }
    } finally {
      if (await temporaryFile.exists()) await temporaryFile.delete();
    }
  }

  void _verifyBindings(
    WindowsUpdateInstallStage stage,
    WindowsPendingInstallReceipt receipt,
  ) {
    final authority = stage.authority;
    final bindingsMatch = receipt.transactionId == stage.transactionId &&
        receipt.operationId == authority.operationId &&
        receipt.stagePath == stage.stageDirectory.path &&
        receipt.stageProvenanceSha256 == stage.provenanceSha256 &&
        receipt.expectedArtifactSha256 == authority.artifactSha256 &&
        receipt.expectedArtifactLength == authority.artifactLength &&
        receipt.candidateVersion == authority.version &&
        receipt.packageId == authority.packageId &&
        receipt.architecture == authority.architecture;
    if (!bindingsMatch) {
      throw const WindowsUpdateTransactionException(
        WindowsUpdateTransactionFailureReason.bindingMismatch,
        'Windows pending install receipt does not match the owned stage.',
      );
    }
  }
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) throw const FormatException();
  return value;
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw const FormatException();
  return value;
}
