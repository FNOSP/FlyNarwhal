import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../data/storage/preferences_manager.dart';
import '../../../../providers/providers.dart';

typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

class PlayerDeviceContext {
  final String deviceId;
  final String deviceName;

  const PlayerDeviceContext({
    required this.deviceId,
    required this.deviceName,
  });
}

class PlayerDeviceContextService {
  PlayerDeviceContextService(
    this._preferencesManager, {
    ProcessRunner? processRunner,
    Uuid? uuid,
  })  : _processRunner = processRunner ?? Process.run,
        _uuid = uuid ?? const Uuid();

  final PreferencesManager _preferencesManager;
  final ProcessRunner _processRunner;
  final Uuid _uuid;

  static const Set<String> _invalidValues = {
    'unknown',
    'none',
    'default string',
    'to be filled by o.e.m.',
    '00000000-0000-0000-0000-000000000000',
    'not available',
    'system serial number',
    'chassis serial number',
    'to be filled by oem',
    'system product name',
    'ffffffff-ffff-ffff-ffff-ffffffffffff',
    '03000200-0400-0500-0006-000700080009',
    '5ekpm18320000397',
    'fefefefe-fefe-fefe-fefe-fefefefefefe',
    'not applicable',
    'standard',
  };

  Future<PlayerDeviceContext> loadContext() async {
    return PlayerDeviceContext(
      deviceId: await _resolveDeviceId(),
      deviceName: await _resolveDeviceName(),
    );
  }

  Future<String> _resolveDeviceId() async {
    // Follow the KMP priority: hardware serial, hardware UUID, baseboard,
    // then fall back to a persisted UUID.
    final candidates = <Future<String?>>[
      _queryWindowsValue('(Get-CimInstance Win32_BIOS).SerialNumber'),
      _queryWindowsValue('(Get-CimInstance Win32_ComputerSystemProduct).UUID'),
      _queryWindowsValue('(Get-CimInstance Win32_BaseBoard).SerialNumber'),
    ];

    for (final candidate in candidates) {
      final value = await candidate;
      if (_isValidId(value)) {
        return value!.trim();
      }
    }

    // Reuse the persisted fallback device id once hardware identifiers fail.
    final savedId = _preferencesManager.getFallbackDeviceId();
    if (savedId != null && savedId.isNotEmpty) {
      return savedId;
    }

    // Persist a generated id so subsequent requests stay stable.
    final generatedId = 'jvm_${_uuid.v4()}';
    await _preferencesManager.saveFallbackDeviceId(generatedId);
    return generatedId;
  }

  Future<String> _resolveDeviceName() async {
    // Prefer the desktop machine name before falling back to generic host data.
    final windowsName = await _queryWindowsValue(
      '(Get-CimInstance Win32_ComputerSystem).Name',
    );
    if (windowsName != null && windowsName.trim().isNotEmpty) {
      return windowsName.trim();
    }

    final dnsHostName = await _queryWindowsValue(
      '(Get-CimInstance Win32_ComputerSystem).DNSHostName',
    );
    if (dnsHostName != null && dnsHostName.trim().isNotEmpty) {
      return dnsHostName.trim();
    }

    final localHostName = Platform.localHostname.trim();
    if (localHostName.isNotEmpty) {
      return localHostName;
    }

    return Platform.operatingSystem;
  }

  Future<String?> _queryWindowsValue(String script) async {
    if (!Platform.isWindows) {
      return null;
    }

    try {
      final result = await _processRunner(
        'powershell',
        ['-NoProfile', '-Command', script],
      );
      if (result.exitCode != 0) {
        return null;
      }
      final output = result.stdout?.toString().trim();
      if (output == null || output.isEmpty) {
        return null;
      }
      return output;
    } catch (_) {
      return null;
    }
  }

  bool _isValidId(String? value) {
    if (value == null) {
      return false;
    }

    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    if (_invalidValues.contains(normalized)) {
      return false;
    }
    if (normalized.length <= 3) {
      return false;
    }
    return !normalized.split('').every(
          (char) => char == '0' || char == '1' || char == 'x' || char == '-',
        );
  }
}

final playerDeviceContextServiceProvider =
    Provider<PlayerDeviceContextService>((ref) {
  return PlayerDeviceContextService(ref.watch(preferencesManagerProvider));
});
