import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/dio_client.dart';
import '../data/datasources/remote/reporting_remote_data_source.dart';
import '../services/reporting/reporting_service.dart';
import '../ui/features/player/services/player_device_context_service.dart';
import 'providers.dart';
import 'update_providers.dart';

final reportingDioClientProvider = Provider<DioClient>((ref) {
  return DioClient.withCallbacks(
    getToken: () => '',
    getCookie: () => '',
    getBaseUrl: () => '',
  );
});

final reportingRemoteDataSourceProvider =
    Provider<ReportingRemoteDataSource>((ref) {
  return ReportingRemoteDataSource(ref.watch(reportingDioClientProvider));
});

final reportingPlatformInfoProvider = Provider<ReportingPlatformInfo>((ref) {
  return const IoReportingPlatformInfo();
});

final reportingServiceProvider = Provider<ReportingService>((ref) {
  final preferences = ref.watch(sharedPreferencesProvider);
  return ReportingService(
    runtimeConfiguration: ref.watch(runtimeConfigurationProvider),
    remoteDataSource: ref.watch(reportingRemoteDataSourceProvider),
    deviceContextService: ref.watch(playerDeviceContextServiceProvider),
    versionService: ref.watch(appVersionServiceProvider),
    platformInfo: ref.watch(reportingPlatformInfoProvider),
    readSetting: (key) async => preferences.getString(key),
    writeSetting: preferences.setString,
  );
});
