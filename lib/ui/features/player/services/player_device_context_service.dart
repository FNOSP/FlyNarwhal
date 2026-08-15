import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../data/storage/preferences_manager.dart';
import '../../../../providers/providers.dart';

typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

typedef FileExists = bool Function(String path);

class PlayerDeviceContext {
  final String deviceId;
  final String deviceIdType;
  final String deviceName;

  const PlayerDeviceContext({
    required this.deviceId,
    required this.deviceIdType,
    required this.deviceName,
  });
}

class WindowsVideoAdapterInfo {
  final String name;
  final String vendor;
  final String pnpDeviceId;

  const WindowsVideoAdapterInfo({
    required this.name,
    required this.vendor,
    required this.pnpDeviceId,
  });
}

// Keep base decode modes intact and only sanitize concrete hwdec APIs.
String sanitizePlayerDecodeMode(String mode, List<String> supportedHwdecApis) {
  switch (mode) {
    case 'auto':
    case 'no':
    case 'auto-copy':
    case 'auto-unsafe':
      return mode;
    default:
      return supportedHwdecApis.contains(mode) ? mode : 'auto';
  }
}

// Resolve Windows hwdec APIs from both hardware presence and runtime support.
List<String> resolveSupportedWindowsHwdecApis({
  required List<WindowsVideoAdapterInfo> adapters,
  required bool hasD3d11Runtime,
  required bool hasCudaRuntime,
  required bool hasNvdecRuntime,
}) {
  final hasHardwareAdapter = adapters.any(_isUsableWindowsVideoAdapter);
  final hasNvidiaAdapter = adapters.any(_isNvidiaWindowsVideoAdapter);
  final apis = <String>[];

  if (hasHardwareAdapter && hasD3d11Runtime) {
    apis.add('d3d11va');
  }
  if (hasNvidiaAdapter && hasNvdecRuntime) {
    apis.add('nvdec');
  }
  if (hasNvidiaAdapter && hasCudaRuntime) {
    apis.add('cuda');
  }

  return apis;
}

bool _isUsableWindowsVideoAdapter(WindowsVideoAdapterInfo adapter) {
  final combined = [
    adapter.name,
    adapter.vendor,
    adapter.pnpDeviceId,
  ].join(' ').toLowerCase();

  if (combined.trim().isEmpty) {
    return false;
  }

  const softwareMarkers = <String>[
    'microsoft basic display',
    'microsoft basic render',
    'remote display',
    'hyper-v',
    'vmware',
    'virtualbox',
    'parallels',
    'citrix',
  ];

  return !softwareMarkers.any(combined.contains);
}

bool _isNvidiaWindowsVideoAdapter(WindowsVideoAdapterInfo adapter) {
  final combined = [
    adapter.name,
    adapter.vendor,
    adapter.pnpDeviceId,
  ].join(' ').toLowerCase();
  return combined.contains('nvidia') || combined.contains('ven_10de');
}

class PlayerDeviceContextService {
  PlayerDeviceContextService(
    this._preferencesManager, {
    ProcessRunner? processRunner,
    Uuid? uuid,
    FileExists? fileExists,
  })  : _processRunner = processRunner ?? Process.run,
        _uuid = uuid ?? const Uuid(),
        _fileExists = fileExists ?? ((path) => File(path).existsSync());

  final PreferencesManager _preferencesManager;
  final ProcessRunner _processRunner;
  final Uuid _uuid;
  final FileExists _fileExists;

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

  Future<List<String>> loadSupportedHwdecApis() async {
    if (Platform.isWindows) {
      return _loadWindowsSupportedHwdecApis();
    }
    if (Platform.isLinux) {
      return const ['vaapi', 'vdpau', 'nvdec'];
    }
    if (Platform.isMacOS) {
      return const ['videotoolbox'];
    }
    return const [];
  }

  Future<PlayerDeviceContext> loadContext() async {
    final deviceIdResult = await _resolveDeviceId();
    return PlayerDeviceContext(
      deviceId: deviceIdResult.id,
      deviceIdType: deviceIdResult.type,
      deviceName: await _resolveDeviceName(),
    );
  }

  Future<({String id, String type})> _resolveDeviceId() async {
    // Follow the KMP priority: hardware serial, hardware UUID, baseboard,
    // then fall back to a persisted UUID.
    final candidates = <({Future<String?> value, String type})>[
      (
        value: _queryWindowsValue('(Get-CimInstance Win32_BIOS).SerialNumber'),
        type: 'hardware_serial',
      ),
      (
        value: _queryWindowsValue(
          '(Get-CimInstance Win32_ComputerSystemProduct).UUID',
        ),
        type: 'hardware_uuid',
      ),
      (
        value: _queryWindowsValue(
            '(Get-CimInstance Win32_BaseBoard).SerialNumber'),
        type: 'baseboard_serial',
      ),
    ];

    for (final candidate in candidates) {
      final value = await candidate.value;
      if (_isValidId(value)) {
        return (id: value!.trim(), type: candidate.type);
      }
    }

    // Reuse the persisted fallback device id once hardware identifiers fail.
    final savedId = _preferencesManager.getFallbackDeviceId();
    if (savedId != null && savedId.isNotEmpty) {
      return (id: savedId, type: 'persisted_uuid');
    }

    // Persist a generated id so subsequent requests stay stable.
    final generatedId = 'jvm_${_uuid.v4()}';
    await _preferencesManager.saveFallbackDeviceId(generatedId);
    return (id: generatedId, type: 'generated_uuid');
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

  // Combine GPU vendor detection with required runtime DLL checks so the UI
  // only shows Windows hwdec APIs that the current machine can actually use.
  Future<List<String>> _loadWindowsSupportedHwdecApis() async {
    final adapters = await _queryWindowsVideoAdapters();
    final hasD3d11Runtime = _hasWindowsRuntimeFile('d3d11.dll');
    final hasCudaRuntime = _hasWindowsRuntimeFile('nvcuda.dll');
    final hasNvdecRuntime =
        hasCudaRuntime && _hasWindowsRuntimeFile('nvcuvid.dll');

    return resolveSupportedWindowsHwdecApis(
      adapters: adapters,
      hasD3d11Runtime: hasD3d11Runtime,
      hasCudaRuntime: hasCudaRuntime,
      hasNvdecRuntime: hasNvdecRuntime,
    );
  }

  Future<List<WindowsVideoAdapterInfo>> _queryWindowsVideoAdapters() async {
    final raw = await _queryWindowsValue(
      'Get-CimInstance Win32_VideoController | '
      'Select-Object Name,AdapterCompatibility,PNPDeviceID | '
      'ConvertTo-Json -Compress',
    );
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map(_mapWindowsVideoAdapterInfo).toList();
      }
      return [_mapWindowsVideoAdapterInfo(decoded)];
    } catch (_) {
      return const [];
    }
  }

  WindowsVideoAdapterInfo _mapWindowsVideoAdapterInfo(dynamic raw) {
    if (raw is! Map) {
      return const WindowsVideoAdapterInfo(
        name: '',
        vendor: '',
        pnpDeviceId: '',
      );
    }

    return WindowsVideoAdapterInfo(
      name: raw['Name']?.toString() ?? '',
      vendor: raw['AdapterCompatibility']?.toString() ?? '',
      pnpDeviceId: raw['PNPDeviceID']?.toString() ?? '',
    );
  }

  bool _hasWindowsRuntimeFile(String fileName) {
    final candidatePaths = <String>{
      ..._windowsSystemDirectories()
          .map((directory) => '$directory\\$fileName'),
      ..._windowsPathDirectories().map((directory) => '$directory\\$fileName'),
    };

    for (final path in candidatePaths) {
      if (_fileExists(path)) {
        return true;
      }
    }
    return false;
  }

  List<String> _windowsSystemDirectories() {
    final windir = Platform.environment['WINDIR'];
    if (windir == null || windir.isEmpty) {
      return const [];
    }
    return [
      '$windir\\System32',
      '$windir\\SysWOW64',
    ];
  }

  List<String> _windowsPathDirectories() {
    final rawPath = Platform.environment['PATH'];
    if (rawPath == null || rawPath.isEmpty) {
      return const [];
    }

    return rawPath
        .split(';')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
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
