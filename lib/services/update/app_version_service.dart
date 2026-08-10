import 'dart:convert';

import 'package:flutter/services.dart';
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
    final defineVersionIsValid =
        defineVersion.isNotEmpty && SemanticVersion.tryParse(defineVersion) != null;
    if (defineVersionIsValid) {
      return defineVersion;
    }
    final pubspecVersion = await _readPubspecVersion();
    if (pubspecVersion != null) {
      return pubspecVersion;
    }
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  /// Reads the full version (including prerelease suffix) from the bundled
  /// pubspec.yaml asset.
  ///
  /// flutter_tools strips prerelease suffixes from the Apple platform version
  /// fields, and the APP_FULL_VERSION dart-define is only injected by the
  /// release build script, so any other build mode (local `flutter run`,
  /// manual `flutter build`) silently loses the suffix. The bundled pubspec
  /// is always in sync with the source version and works in every build mode.
  Future<String?> _readPubspecVersion() async {
    try {
      final content = await rootBundle.loadString('pubspec.yaml');
      for (final line in const LineSplitter().convert(content)) {
        final match = RegExp(
          r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?)',
        ).firstMatch(line.trim());
        if (match == null) {
          continue;
        }
        final version = match.group(1)!;
        return SemanticVersion.tryParse(version) != null ? version : null;
      }
    } catch (_) {
      // Asset missing (e.g. stripped build) — fall back to PackageInfo.
    }
    return null;
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
