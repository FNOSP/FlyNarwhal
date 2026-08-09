import 'package:package_info_plus/package_info_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../core/version/semantic_version.dart';
import '../../domain/update/entities/update_models.dart';
import 'platform_info.dart';

/// Reads package metadata and delegates desktop detection to PlatformInfo.
final class AppVersionService {
  AppVersionService({PlatformInfo? platformInfo})
      : _platformInfo = platformInfo ?? IoPlatformInfo();

  final PlatformInfo _platformInfo;

  Future<SemanticVersion> getCurrentVersion() async {
    final versionText = await getCurrentVersionText();
    final version = SemanticVersion.tryParse(versionText);
    if (version == null) {
      throw FormatException(
        '当前应用版本不是有效的 Semantic Version: $versionText',
      );
    }
    return version;
  }

  Future<String> getCurrentVersionText() async {
    final defineVersion = AppConstants.appFullVersion.trim();
    if (defineVersion.isNotEmpty &&
        SemanticVersion.tryParse(defineVersion) != null) {
      return defineVersion;
    }
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  Future<UpdatePlatform> detectCurrentPlatform() async {
    final result = await _platformInfo.detect();
    return switch (result) {
      PlatformInfoSuccess(:final platform) => platform,
      PlatformInfoFailure(:final reason) => throw UnsupportedError(reason.name),
    };
  }

  /// Compatibility bridge for the synchronous M01 controller path.
  UpdatePlatform getCurrentPlatform() {
    if (_platformInfo case final IoPlatformInfo ioPlatformInfo) {
      final result = ioPlatformInfo.detectSynchronously();
      return switch (result) {
        PlatformInfoSuccess(:final platform) => platform,
        PlatformInfoFailure(:final reason) =>
          throw UnsupportedError(reason.name),
      };
    }
    throw StateError(
      'Injected PlatformInfo requires asynchronous detection.',
    );
  }
}
