import 'dart:convert';
import 'dart:io';

import '../../core/config/runtime_configuration.dart';
import '../../core/network/api_result.dart';
import '../../data/datasources/remote/reporting_remote_data_source.dart';
import '../../services/update/app_version_service.dart';
import '../../ui/features/player/services/player_device_context_service.dart';
import 'reporting_models.dart';

abstract interface class ReportingPlatformInfo {
  Future<
      ({
        String osName,
        String osArch,
        String cpuModel,
        String gpuModel,
        String gpuType
      })> load();
}

final class IoReportingPlatformInfo implements ReportingPlatformInfo {
  const IoReportingPlatformInfo();

  @override
  Future<
      ({
        String osName,
        String osArch,
        String cpuModel,
        String gpuModel,
        String gpuType
      })> load() async {
    final osName = Platform.operatingSystem;
    final osArch = Platform.environment['PROCESSOR_ARCHITEW6432'] ??
        Platform.environment['PROCESSOR_ARCHITECTURE'] ??
        Platform.version.split(' ').first;
    final cpuModel = await _readCpuModel();
    return (
      osName: osName,
      osArch: osArch.toLowerCase(),
      cpuModel: cpuModel,
      gpuModel: 'unknown',
      gpuType: 'unknown',
    );
  }

  Future<String> _readCpuModel() async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('powershell', const [
          '-NoProfile',
          '-Command',
          '(Get-CimInstance Win32_Processor).Name',
        ]);
        if (result.exitCode == 0 &&
            result.stdout.toString().trim().isNotEmpty) {
          return result.stdout.toString().trim();
        }
      } else {
        final result = await Process.run('uname', const ['-p']);
        if (result.exitCode == 0 &&
            result.stdout.toString().trim().isNotEmpty) {
          return result.stdout.toString().trim();
        }
      }
    } catch (_) {}
    return 'unknown';
  }
}

final class ReportingService {
  ReportingService({
    required RuntimeConfiguration runtimeConfiguration,
    required ReportingRemoteDataSource remoteDataSource,
    required PlayerDeviceContextService deviceContextService,
    required AppVersionService versionService,
    required ReportingPlatformInfo platformInfo,
    required Future<String?> Function(String key) readSetting,
    required Future<bool> Function(String key, String value) writeSetting,
    DateTime Function()? now,
  })  : _runtimeConfiguration = runtimeConfiguration,
        _remoteDataSource = remoteDataSource,
        _deviceContextService = deviceContextService,
        _versionService = versionService,
        _platformInfo = platformInfo,
        _readSetting = readSetting,
        _writeSetting = writeSetting,
        _now = now ?? DateTime.now;

  static const lastReportInfoKey = 'last_report_info';

  final RuntimeConfiguration _runtimeConfiguration;
  final ReportingRemoteDataSource _remoteDataSource;
  final PlayerDeviceContextService _deviceContextService;
  final AppVersionService _versionService;
  final ReportingPlatformInfo _platformInfo;
  final Future<String?> Function(String key) _readSetting;
  final Future<bool> Function(String key, String value) _writeSetting;
  final DateTime Function() _now;

  Future<void> reportLaunch() async {
    final version = await _versionService.getCurrentVersionText();
    final today = _dateText(_now());
    final reportInfo = '$version|$today';
    if (await _readSetting(lastReportInfoKey) == reportInfo) return;

    final reportUrlBytes = await _runtimeConfiguration.resolveOptionalValue(
      RuntimeSecret.reportUrl,
    );
    if (reportUrlBytes == null || reportUrlBytes.isEmpty) return;

    final secretBytes = await _runtimeConfiguration.resolveOptionalValue(
      RuntimeSecret.reportApiSecret,
    );
    if (secretBytes == null || secretBytes.isEmpty) {
      if (reportUrlBytes.isNotEmpty) {
        await _runtimeConfiguration.zeroize(reportUrlBytes);
      }
      return;
    }

    try {
      final request = await _createRequest(version);
      final result = await _remoteDataSource.reportLaunch(
        reportUrl: utf8.decode(reportUrlBytes),
        body: request.toSignedJson(utf8.decode(secretBytes)),
      );
      if (result is Success<bool> && result.data) {
        await _writeSetting(lastReportInfoKey, reportInfo);
      }
    } finally {
      await _runtimeConfiguration.zeroize(reportUrlBytes);
      await _runtimeConfiguration.zeroize(secretBytes);
    }
  }

  Future<ReportingLaunchRequest> _createRequest(String version) async {
    final device = await _deviceContextService.loadContext();
    final platform = await _platformInfo.load();
    return ReportingLaunchRequest(
      deviceId: device.deviceId,
      deviceIdType: device.deviceIdType,
      osName: platform.osName,
      osArch: platform.osArch,
      cpuModel: platform.cpuModel,
      gpuModel: platform.gpuModel,
      gpuType: platform.gpuType,
      version: version,
      timestamp: _now().millisecondsSinceEpoch,
    );
  }

  String _dateText(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}
