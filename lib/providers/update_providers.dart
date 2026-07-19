import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/remote/github_release_data_source.dart';
import '../data/repositories/update_repository_impl.dart';
import '../data/storage/update_settings_store.dart';
import '../domain/update/repositories/update_repository.dart';
import '../domain/update/services/update_asset_selector.dart';
import '../domain/update/services/update_policy.dart';
import '../services/update/app_version_service.dart';
import '../services/update/download_url_resolver.dart';
import '../services/update/sha256_verifier.dart';
import '../services/update/update_downloader.dart';
import '../services/update/update_file_store.dart';
import '../services/update/update_scheduler.dart';
import '../ui/features/update/update_controller.dart';
import '../ui/features/update/update_state.dart';
import 'providers.dart';

/// Provides persisted application update preferences.
final updateSettingsStoreProvider = Provider<UpdateSettingsStore>((ref) {
  return UpdateSettingsStore(ref.watch(sharedPreferencesProvider));
});

/// Provides package metadata and desktop platform detection.
final appVersionServiceProvider = Provider<AppVersionService>((ref) {
  return AppVersionService();
});

/// Provides the isolated GitHub client used exclusively by updates.
final updateDioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      followRedirects: true,
    ),
  );
});

final githubReleaseDataSourceProvider =
    Provider<GitHubReleaseDataSource>((ref) {
  return GitHubReleaseDataSource(
    dio: ref.watch(updateDioProvider),
    userAgent: 'FlyNarwhal desktop client',
  );
});

final updateRepositoryProvider = Provider<UpdateRepository>((ref) {
  return UpdateRepositoryImpl(ref.watch(githubReleaseDataSourceProvider));
});

final updatePolicyProvider = Provider<UpdatePolicy>((ref) {
  return const UpdatePolicy(UpdateAssetSelector());
});

final sha256VerifierProvider = Provider<Sha256Verifier>((ref) {
  return const Sha256Verifier();
});

final updateFileStoreProvider = Provider<UpdateFileStore>((ref) {
  return UpdateFileStore(sha256Verifier: ref.watch(sha256VerifierProvider));
});

final downloadUrlResolverProvider = Provider<DownloadUrlResolver>((ref) {
  return const DownloadUrlResolver();
});

final updateDownloaderProvider = Provider<UpdateDownloader>((ref) {
  return UpdateDownloader(
    dio: ref.watch(updateDioProvider),
    fileStore: ref.watch(updateFileStoreProvider),
    sha256Verifier: ref.watch(sha256VerifierProvider),
    downloadUrlResolver: ref.watch(downloadUrlResolverProvider),
  );
});

/// Provides global update discovery state for title bars and settings.
final updateControllerProvider =
    StateNotifierProvider<UpdateController, UpdateState>((ref) {
  return UpdateController(
    repository: ref.watch(updateRepositoryProvider),
    policy: ref.watch(updatePolicyProvider),
    settingsStore: ref.watch(updateSettingsStoreProvider),
    appVersionService: ref.watch(appVersionServiceProvider),
    downloader: ref.watch(updateDownloaderProvider),
  );
});

final currentAppVersionProvider = FutureProvider<String>((ref) {
  return ref.watch(appVersionServiceProvider).getCurrentVersionText();
});

/// Starts one root-scoped automatic update scheduler for desktop platforms.
final updateSchedulerProvider = Provider<UpdateScheduler>((ref) {
  final scheduler = UpdateScheduler(
    checkForUpdates: () =>
        ref.read(updateControllerProvider.notifier).handleAutomaticCheck(),
    startupDelay: const Duration(seconds: 30),
    interval: const Duration(hours: 4),
    isSupportedPlatform:
        !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux),
  );
  ref.onDispose(scheduler.dispose);
  return scheduler;
});
