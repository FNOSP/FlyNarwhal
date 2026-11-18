import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/identity/instance_id.dart';
import '../../../../data/storage/preferences_manager.dart';
import '../../../../providers/providers.dart';

typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

typedef FileExists = bool Function(String path);

class PlayerInstanceContext {
  final String instanceId;
  final String instanceName;

  /// The value the launch-report has always sent as `deviceId`: the id this
  /// service persisted before the device→instance rename, or the instance id
  /// for a profile that already had none. Only reporting reads it, so the
  /// report payload stays exactly what older builds sent.
  final String reportDeviceId;

  const PlayerInstanceContext({
    required this.instanceId,
    required this.instanceName,
    String? reportDeviceId,
  }) : reportDeviceId = reportDeviceId ?? instanceId;
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

class PlayerInstanceContextService {
  PlayerInstanceContextService(
    this._preferencesManager, {
    ProcessRunner? processRunner,
    Random? random,
    FileExists? fileExists,
  })  : _processRunner = processRunner ?? Process.run,
        _random = random,
        _fileExists = fileExists ?? ((path) => File(path).existsSync());

  final PreferencesManager _preferencesManager;
  final ProcessRunner _processRunner;
  final Random? _random;
  final FileExists _fileExists;

  PlayerInstanceContext? _cachedContext;
  Completer<PlayerInstanceContext>? _pendingContext;

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

  Future<PlayerInstanceContext> loadContext() async {
    final cached = _cachedContext;
    if (cached != null) {
      return cached;
    }

    final pending = _pendingContext;
    if (pending != null) {
      return pending.future;
    }

    final completer = Completer<PlayerInstanceContext>();
    _pendingContext = completer;

    try {
      final instanceIdResult = await _resolveInstanceId();
      final context = PlayerInstanceContext(
        instanceId: instanceIdResult.id,
        instanceName: await _resolveInstanceName(),
        reportDeviceId: instanceIdResult.reportDeviceId,
      );
      _cachedContext = context;
      completer.complete(context);
      return context;
    } catch (e, st) {
      completer.completeError(e, st);
      rethrow;
    } finally {
      _pendingContext = null;
    }
  }

  Future<({String id, String? reportDeviceId})> _resolveInstanceId() async {
    // Always use a persisted id; the startup migration syncs the KMP-migrated
    // id into this key so it is reused as-is instead of generating a new one.
    final savedId = _preferencesManager.getInstanceId();
    if (savedId != null && savedId.isNotEmpty) {
      return (
        id: savedId,
        reportDeviceId: _preferencesManager.getLegacyReportDeviceId(),
      );
    }

    // Persist a generated id so subsequent requests stay stable.
    final environment = resolveInstanceIdEnvironment();
    final randomHex = generateInstanceIdRandomHex(_random);
    final generatedId = buildInstanceId(
      os: environment.os,
      arch: environment.arch,
      randomHex: randomHex,
    );
    final generatedReportDeviceId = buildInstanceId(
      os: environment.os,
      arch: environment.arch,
      randomHex: randomHex,
      client: legacyReportClientTag,
    );
    await _preferencesManager.saveInstanceId(generatedId);
    await _preferencesManager.saveLegacyReportDeviceId(generatedReportDeviceId);
    return (id: generatedId, reportDeviceId: generatedReportDeviceId);
  }

  Future<String> _resolveInstanceName() async {
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
}

final playerInstanceContextServiceProvider =
    Provider<PlayerInstanceContextService>((ref) {
  return PlayerInstanceContextService(ref.watch(preferencesManagerProvider));
});
