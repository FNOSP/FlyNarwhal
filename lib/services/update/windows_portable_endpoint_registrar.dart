import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

import '../../core/utils/log/app_talker.dart';
import 'app_version_service.dart';
import 'platform_info.dart';
import 'windows_update_transaction_store.dart';

/// Outcome of one portable endpoint registration attempt.
enum WindowsPortableEndpointRegistrationResult {
  skippedNotWindows,
  skippedNotPortable,
  skippedActiveTransaction,
  skippedMissingHelpers,
  alreadyRegistered,
  registered,
  failed,
}

/// Registers the protected updater endpoint for portable Windows bundles.
///
/// The Inno Setup installer normally writes the endpoint metadata
/// (`installer/setup.iss` `WriteProtectedEndpointMetadata`). A portable
/// bundle has no installer, so the app itself mirrors that ceremony on
/// startup: it copies the two protected helpers next to the app into
/// `%LOCALAPPDATA%\FlyNarwhal\updater\protected`, writes
/// `endpoint-policy.json`, and publishes the registry descriptor under
/// `HKCU\Software\JankinWu\FlyNarwhal\Updater\Endpoint\Current`.
///
/// The registration is self-healing: after a portable update replaces the
/// bundle the stored digests no longer match, and the next launch rewrites
/// the endpoint. The endpoint key is shared with an installed copy of the
/// app on a last-writer-wins basis; validation only requires the descriptor
/// to be internally consistent, so coexistence is safe. An older portable
/// bundle may downgrade the endpoint version; this is accepted for now.
final class WindowsPortableEndpointRegistrar {
  WindowsPortableEndpointRegistrar({
    required WindowsUpdateTransactionStore transactionStore,
    AppVersionService? appVersionService,
  })  : _transactionStore = transactionStore,
        _appVersionService = appVersionService ?? AppVersionService();

  static const String _protectedHelperExecutable =
      'FlyNarwhalProtectedHelper.exe';
  static const String _recoveryHostExecutable = 'FlyNarwhalRecoveryHost.exe';
  static const String _policyFileName = 'endpoint-policy.json';

  final WindowsUpdateTransactionStore _transactionStore;
  final AppVersionService _appVersionService;

  Future<WindowsPortableEndpointRegistrationResult> ensureRegistered() async {
    if (!Platform.isWindows) {
      return WindowsPortableEndpointRegistrationResult.skippedNotWindows;
    }
    try {
      final bundleDirectory = path.dirname(Platform.resolvedExecutable);
      if (!File(path.join(bundleDirectory, windowsPortableMarkerFileName))
          .existsSync()) {
        return WindowsPortableEndpointRegistrationResult.skippedNotPortable;
      }
      // Never touch the endpoint while an update transaction is in flight.
      if (await _transactionStore.loadActive() != null) {
        AppTalker.info(
          'WindowsPortableEndpoint',
          'Endpoint registration skipped because an update transaction is active.',
        );
        return WindowsPortableEndpointRegistrationResult
            .skippedActiveTransaction;
      }

      final bundleProtectedHelper =
          File(path.join(bundleDirectory, _protectedHelperExecutable));
      final bundleRecoveryHost =
          File(path.join(bundleDirectory, _recoveryHostExecutable));
      if (!await bundleProtectedHelper.exists() ||
          !await bundleRecoveryHost.exists()) {
        AppTalker.warning(
          'WindowsPortableEndpoint',
          'Portable bundle is missing protected helper executables.',
        );
        return WindowsPortableEndpointRegistrationResult
            .skippedMissingHelpers;
      }

      final bundleProtectedSha = await _digestFile(bundleProtectedHelper);
      final bundleRecoverySha = await _digestFile(bundleRecoveryHost);
      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData == null || localAppData.trim().isEmpty) {
        throw const WindowsPortableEndpointRegistryException(
          'LOCALAPPDATA is unavailable for the portable endpoint.',
        );
      }
      final protectedRoot = path.join(
        localAppData,
        'FlyNarwhal',
        'updater',
        'protected',
      );
      if (await _isAlreadyRegistered(
        protectedRoot: protectedRoot,
        bundleProtectedSha: bundleProtectedSha,
        bundleRecoverySha: bundleRecoverySha,
      )) {
        return WindowsPortableEndpointRegistrationResult.alreadyRegistered;
      }

      await Directory(protectedRoot).create(recursive: true);
      final targetProtectedHelper =
          File(path.join(protectedRoot, _protectedHelperExecutable));
      final targetRecoveryHost =
          File(path.join(protectedRoot, _recoveryHostExecutable));
      await bundleProtectedHelper.copy(targetProtectedHelper.path);
      await bundleRecoveryHost.copy(targetRecoveryHost.path);

      final endpointVersion =
          await _appVersionService.getCurrentVersionText();
      final policyPath = path.join(protectedRoot, _policyFileName);
      final policyJson = jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'endpointVersion': endpointVersion,
        'protectedRoot': protectedRoot,
      });
      await File(policyPath).writeAsString(policyJson);

      _writeEndpointRegistry(
        endpointVersion: endpointVersion,
        protectedHelperPath: targetProtectedHelper.path,
        protectedHelperSha: bundleProtectedSha,
        recoveryHostPath: targetRecoveryHost.path,
        recoveryHostSha: bundleRecoverySha,
        policyPath: policyPath,
      );
      AppTalker.info(
        'WindowsPortableEndpoint',
        'Portable endpoint registered for version $endpointVersion.',
      );
      return WindowsPortableEndpointRegistrationResult.registered;
    } on Object catch (error, stackTrace) {
      AppTalker.error(
        'WindowsPortableEndpoint',
        error: error,
        stackTrace: stackTrace,
        message: 'Portable endpoint registration failed.',
      );
      return WindowsPortableEndpointRegistrationResult.failed;
    }
  }

  Future<bool> _isAlreadyRegistered({
    required String protectedRoot,
    required String bundleProtectedSha,
    required String bundleRecoverySha,
  }) async {
    final registryProtectedSha =
        _readRegistryStringValue('ProtectedHelperSha256');
    final registryRecoverySha =
        _readRegistryStringValue('RecoveryHostSha256');
    if (registryProtectedSha != bundleProtectedSha ||
        registryRecoverySha != bundleRecoverySha) {
      return false;
    }
    final protectedHelper =
        File(path.join(protectedRoot, _protectedHelperExecutable));
    final recoveryHost =
        File(path.join(protectedRoot, _recoveryHostExecutable));
    if (!await protectedHelper.exists() || !await recoveryHost.exists()) {
      return false;
    }
    return await _digestFile(protectedHelper) == bundleProtectedSha &&
        await _digestFile(recoveryHost) == bundleRecoverySha;
  }

  void _writeEndpointRegistry({
    required String endpointVersion,
    required String protectedHelperPath,
    required String protectedHelperSha,
    required String recoveryHostPath,
    required String recoveryHostSha,
    required String policyPath,
  }) {
    final key = _openRegistryKey(writable: true);
    try {
      _writeRegistryDword(key, 'SchemaVersion', 1);
      _writeRegistryString(key, 'EndpointVersion', endpointVersion);
      _writeRegistryString(key, 'ProtectedHelperPath', protectedHelperPath);
      _writeRegistryString(key, 'ProtectedHelperSha256', protectedHelperSha);
      _writeRegistryString(key, 'RecoveryHostPath', recoveryHostPath);
      _writeRegistryString(key, 'RecoveryHostSha256', recoveryHostSha);
      _writeRegistryString(key, 'PolicyPath', policyPath);
    } finally {
      _regCloseKey(key);
    }
  }

  Future<String> _digestFile(File file) {
    return sha256
        .bind(file.openRead())
        .single
        .then((digest) => digest.toString());
  }
}

// Minimal advapi32 bindings, kept private to this registrar so the rest of
// the app never touches the Windows registry directly.

const int _hkeyCurrentUser = 0x80000001;
const int _keyRead = 0x20019;
const int _keyWrite = 0x20006;
const int _registrySz = 1;
const int _registryDword = 4;
const int _errorSuccess = 0;
const String _endpointRegistrySubKey =
    r'Software\JankinWu\FlyNarwhal\Updater\Endpoint\Current';

final DynamicLibrary _advapi32 = DynamicLibrary.open('advapi32.dll');

final int Function(
  int hKey,
  Pointer<Utf16> subKey,
  int reserved,
  Pointer<Utf16> className,
  int options,
  int samDesired,
  Pointer<Void> securityAttributes,
  Pointer<IntPtr> resultKey,
  Pointer<Uint32> disposition,
) _regCreateKeyExW = _advapi32.lookupFunction<
    Int32 Function(IntPtr, Pointer<Utf16>, Uint32, Pointer<Utf16>, Uint32,
        Uint32, Pointer<Void>, Pointer<IntPtr>, Pointer<Uint32>),
    int Function(int, Pointer<Utf16>, int, Pointer<Utf16>, int, int,
        Pointer<Void>, Pointer<IntPtr>, Pointer<Uint32>)>('RegCreateKeyExW');

final int Function(
  int hKey,
  Pointer<Utf16> valueName,
  int reserved,
  int type,
  Pointer<Uint8> data,
  int dataSize,
) _regSetValueExW = _advapi32.lookupFunction<
    Int32 Function(IntPtr, Pointer<Utf16>, Uint32, Uint32, Pointer<Uint8>,
        Uint32),
    int Function(int, Pointer<Utf16>, int, int, Pointer<Uint8>,
        int)>('RegSetValueExW');

final int Function(
  int hKey,
  Pointer<Utf16> valueName,
  Pointer<Uint32> reserved,
  Pointer<Uint32> type,
  Pointer<Uint8> data,
  Pointer<Uint32> dataSize,
) _regQueryValueExW = _advapi32.lookupFunction<
    Int32 Function(IntPtr, Pointer<Utf16>, Pointer<Uint32>, Pointer<Uint32>,
        Pointer<Uint8>, Pointer<Uint32>),
    int Function(int, Pointer<Utf16>, Pointer<Uint32>, Pointer<Uint32>,
        Pointer<Uint8>, Pointer<Uint32>)>('RegQueryValueExW');

final int Function(int hKey) _regCloseKey = _advapi32.lookupFunction<
    Int32 Function(IntPtr),
    int Function(int)>('RegCloseKey');

int _openRegistryKey({required bool writable}) {
  final subKey = _endpointRegistrySubKey.toNativeUtf16();
  final resultKey = calloc<IntPtr>();
  try {
    final status = _regCreateKeyExW(
      _hkeyCurrentUser,
      subKey,
      0,
      nullptr,
      0,
      writable ? (_keyRead | _keyWrite) : _keyRead,
      nullptr,
      resultKey,
      nullptr,
    );
    if (status != _errorSuccess) {
      throw WindowsPortableEndpointRegistryException(
        'Endpoint registry key could not be opened (status $status).',
      );
    }
    return resultKey.value;
  } finally {
    calloc.free(resultKey);
    calloc.free(subKey);
  }
}

final class WindowsPortableEndpointRegistryException implements Exception {
  const WindowsPortableEndpointRegistryException(this.message);

  final String message;

  @override
  String toString() => message;
}

void _writeRegistryString(int key, String valueName, String value) {
  final name = valueName.toNativeUtf16();
  final data = value.toNativeUtf16();
  try {
    final byteLength = (value.length + 1) * 2;
    final status = _regSetValueExW(
        key, name, 0, _registrySz, data.cast<Uint8>(), byteLength);
    if (status != _errorSuccess) {
      throw WindowsPortableEndpointRegistryException(
        'Endpoint registry value "$valueName" could not be written (status $status).',
      );
    }
  } finally {
    calloc.free(name);
    calloc.free(data);
  }
}

void _writeRegistryDword(int key, String valueName, int value) {
  final name = valueName.toNativeUtf16();
  final data = calloc<Uint32>();
  try {
    data.value = value;
    final status = _regSetValueExW(
        key, name, 0, _registryDword, data.cast<Uint8>(), 4);
    if (status != _errorSuccess) {
      throw WindowsPortableEndpointRegistryException(
        'Endpoint registry value "$valueName" could not be written (status $status).',
      );
    }
  } finally {
    calloc.free(name);
    calloc.free(data);
  }
}

String? _readRegistryStringValue(String valueName) {
  int? key;
  final name = valueName.toNativeUtf16();
  try {
    try {
      key = _openRegistryKey(writable: false);
    } on WindowsPortableEndpointRegistryException {
      return null;
    }
    final dataSize = calloc<Uint32>();
    Pointer<Uint8>? buffer;
    try {
      var status =
          _regQueryValueExW(key, name, nullptr, nullptr, nullptr, dataSize);
      if (status != _errorSuccess || dataSize.value == 0) {
        return null;
      }
      buffer = calloc<Uint8>(dataSize.value);
      status =
          _regQueryValueExW(key, name, nullptr, nullptr, buffer, dataSize);
      if (status != _errorSuccess) {
        return null;
      }
      // toDartString stops at the trailing NUL written with REG_SZ data.
      return buffer.cast<Utf16>().toDartString();
    } finally {
      calloc.free(dataSize);
      if (buffer != null) {
        calloc.free(buffer);
      }
    }
  } finally {
    if (key != null) {
      _regCloseKey(key);
    }
    calloc.free(name);
  }
}
