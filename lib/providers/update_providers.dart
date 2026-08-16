import 'dart:io' show Directory, Platform, exit, pid;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import '../data/datasources/remote/github_release_data_source.dart';
import '../data/repositories/update_repository_impl.dart';
import '../data/storage/github_release_response_cache.dart';
import '../data/storage/update_settings_store.dart';
import '../domain/update/entities/update_models.dart';
import '../domain/update/repositories/update_repository.dart';
import '../domain/update/services/update_asset_selector.dart';
import '../domain/update/services/update_policy.dart';
import '../services/update/app_version_service.dart';
import '../services/update/download_url_resolver.dart';
import '../services/update/linux_package_identity.dart';
import '../services/update/linux_update_installer.dart';
import '../services/update/macos_update_installer.dart';
import '../services/update/platform_update_installer.dart';
import '../services/update/windows_native_update_installer.dart';
import '../services/update/windows_native_updater_bridge.dart';
import '../services/update/windows_platform_update_recovery.dart';
import '../services/update/windows_update_install_stage_store.dart';
import '../services/update/windows_update_transaction_store.dart';
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

/// Provides the ETag cache that keeps conditional-request quota usage low.
final githubReleaseResponseCacheProvider =
    Provider<GitHubReleaseResponseCache>((ref) {
  return const FileGitHubReleaseResponseCache();
});

final githubReleaseDataSourceProvider =
    Provider<GitHubReleaseDataSource>((ref) {
  return GitHubReleaseDataSource(
    dio: ref.watch(updateDioProvider),
    userAgent: 'FlyNarwhal desktop client',
    responseCache: ref.watch(githubReleaseResponseCacheProvider),
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

/// Shared update cache root, matching UpdateFileStore._defaultUpdatesDirectory.
Future<Directory> _defaultUpdateCacheDirectory() async {
  final temporaryRoot = await getTemporaryDirectory();
  return Directory(path.join(temporaryRoot.path, 'updates'));
}

/// macOS install record path, kept inside the update cache root.
String _macOSInstallRecordPath(String cacheRoot) {
  return path.join(cacheRoot, 'macos-install-record.json');
}

/// Linux install record path, kept inside the update cache root.
String _linuxInstallRecordPath(String cacheRoot) {
  return path.join(cacheRoot, 'linux-install-record.json');
}

final windowsUpdateInstallStageStoreProvider =
    Provider<WindowsUpdateInstallStageStore>((ref) {
  return WindowsUpdateInstallStageStore();
});

final windowsUpdateTransactionStoreProvider =
    Provider<WindowsUpdateTransactionStore>((ref) {
  return WindowsUpdateTransactionStore(
    applicationSupportDirectoryProvider:
        loadWindowsNativeUpdateSupportDirectory,
  );
});

final windowsDesktopUpdaterBridgeProvider =
    Provider<WindowsNativeUpdaterBridge>((ref) {
  return ProcessWindowsNativeUpdaterBridge();
});

final windowsNativeUpdateInstallerProvider =
    Provider<WindowsNativeUpdateInstaller>((ref) {
  return WindowsNativeUpdateInstaller(
    stageStore: ref.watch(windowsUpdateInstallStageStoreProvider),
    transactionStore: ref.watch(windowsUpdateTransactionStoreProvider),
    bridge: ref.watch(windowsDesktopUpdaterBridgeProvider),
  );
});

final platformUpdateInstallerProvider =
    Provider<PlatformUpdateInstaller>((ref) {
  if (kIsWeb) {
    return const UnsupportedPlatformUpdateInstaller();
  }
  if (Platform.isWindows) {
    return ref.watch(windowsNativeUpdateInstallerProvider);
  }
  if (Platform.isMacOS) {
    return ref.watch(macOSUpdateInstallerProvider);
  }
  if (Platform.isLinux) {
    return ref.watch(linuxUpdateInstallerProvider);
  }
  return const UnsupportedPlatformUpdateInstaller();
});

final macOSUpdateInstallerProvider = Provider<MacOSUpdateInstaller>((ref) {
  return MacOSUpdateInstaller(
    inputFactory: (request) async {
      final cacheRootDir = await _defaultUpdateCacheDirectory();
      final cacheRoot = cacheRootDir.path;
      await cacheRootDir.create(recursive: true);
      final appBundlePath = ref
              .watch(appVersionServiceProvider)
              .getCurrentPlatform()
              .appBundlePath ??
          '';
      return MacOSUpdateInstallInput(
        processId: pid,
        dmgFilePath: request.packageFile.path,
        currentAppBundlePath: appBundlePath,
        expectedAppBundlePath: appBundlePath,
        bundleIdentifier: macOSBundleIdentifier,
        cacheRootPath: cacheRoot,
        installRecordPath: _macOSInstallRecordPath(cacheRoot),
      );
    },
  );
});

final linuxUpdateInstallerProvider = Provider<LinuxUpdateInstaller>((ref) {
  final identity = LinuxPackageIdentity.fromConfiguration(
    configurations: const <LinuxPackageIdentityConfiguration>[
      LinuxPackageIdentityConfiguration(
        source: FlutterLinuxRunnerIdentity.source,
        packageName: FlutterLinuxRunnerIdentity.executableName,
        desktopId: FlutterLinuxRunnerIdentity.applicationId,
        executableName: FlutterLinuxRunnerIdentity.executableName,
        installedExecutablePath:
            '/usr/bin/${FlutterLinuxRunnerIdentity.executableName}',
      ),
    ],
  );
  return LinuxUpdateInstaller(
    identity: identity,
    inputFactory: (request) async {
      final cacheRootDir = await _defaultUpdateCacheDirectory();
      final cacheRoot = cacheRootDir.path;
      await cacheRootDir.create(recursive: true);
      final platform =
          ref.watch(appVersionServiceProvider).getCurrentPlatform();
      final packageType = const CanonicalUpdateAssetNameParser()
              .tryParse(request.candidate.asset.name)
              ?.packageType ??
          UpdatePackageType.appImage;
      return LinuxUpdateInstallInput(
        processId: pid,
        packageType: packageType,
        packageFilePath: request.packageFile.path,
        cacheRootPath: cacheRoot,
        installRecordPath: _linuxInstallRecordPath(cacheRoot),
        distributionFamily:
            platform.linuxFamily ?? LinuxDistributionFamily.other,
        distributionId: null,
        currentExecutablePath: platform.executablePath ?? '',
        appImageEnvironmentPath: platform.appImagePath,
      );
    },
  );
});

final windowsInstallResultStoreProvider = Provider<WindowsInstallResultStore?>(
  (ref) {
    if (kIsWeb || !Platform.isWindows) {
      return null;
    }
    return WindowsInstallResultStore();
  },
);

final updateInstallFailureRecoveryProvider =
    Provider<UpdateInstallFailureRecovery>((ref) {
  if (kIsWeb) {
    return () async => null;
  }
  if (Platform.isWindows) {
    final transactionStore = ref.watch(windowsUpdateTransactionStoreProvider);
    final recovery = WindowsPlatformUpdateRecovery(
      stageStore: ref.watch(windowsUpdateInstallStageStoreProvider),
      transactionStore: transactionStore,
      bridge: ref.watch(windowsDesktopUpdaterBridgeProvider),
    );
    final legacyStore = ref.watch(windowsInstallResultStoreProvider);
    return () async {
      final nativeFailure = await recovery.recoverFailure();
      if (nativeFailure != null || await transactionStore.hasActive()) {
        return nativeFailure;
      }

      // Consume the legacy Go result only when no native transaction exists.
      try {
        final result = await legacyStore?.consume();
        return result?.toFailure();
      } on FormatException {
        return null;
      }
    };
  }
  if (Platform.isMacOS) {
    final installer = ref.watch(macOSUpdateInstallerProvider);
    return () async {
      final cacheRootDir = await _defaultUpdateCacheDirectory();
      return installer.recoverFailure(
        _macOSInstallRecordPath(cacheRootDir.path),
      );
    };
  }
  if (Platform.isLinux) {
    final installer = ref.watch(linuxUpdateInstallerProvider);
    return () async {
      final cacheRootDir = await _defaultUpdateCacheDirectory();
      return installer
          .recoverFailure(_linuxInstallRecordPath(cacheRootDir.path));
    };
  }
  return () async => null;
});

final updateExitRequesterProvider = Provider<UpdateExitRequester>((ref) {
  if (kIsWeb) {
    return () async {};
  }
  if (Platform.isWindows) {
    return () async {
      await windowManager.setPreventClose(false);
      await windowManager.close();
    };
  }
  if (Platform.isMacOS || Platform.isLinux) {
    // The detached platform helper waits for the current process to exit
    // before replacing the running app bundle or package.
    return () async => exit(0);
  }
  return () async {};
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
    installer: ref.watch(platformUpdateInstallerProvider),
    exitRequester: ref.watch(updateExitRequesterProvider),
    installFailureRecovery: ref.watch(updateInstallFailureRecoveryProvider),
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
