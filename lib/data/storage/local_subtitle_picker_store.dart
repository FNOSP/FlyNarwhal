import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the directory used last time by the "添加电脑字幕文件" picker.
///
/// The next open resumes at the recorded directory; if it no longer exists
/// the nearest existing ancestor is used, falling back level by level until
/// the root; with no record at all the current user's home directory is the
/// default. View style / sort / grouping are restored by each OS's native
/// dialog on a per-directory basis (macOS NSNavPanel defaults, Linux GTK
/// dconf), so only the directory itself needs persisting.
///
/// The memory is isolated per logged-in user (keyed by the user guid, e.g.
/// `local_subtitle_picker_last_directory::<guid>`), matching how smart-skip
/// settings are stored. An empty guid (not logged in / guid missing) falls
/// into a dedicated `anonymous` bucket so it never leaks into any user's.
class LocalSubtitlePickerStore {
  LocalSubtitlePickerStore(this._preferences, {this.userGuid});

  static const String _lastDirectoryKeyPrefix =
      'local_subtitle_picker_last_directory';
  static const String _anonymousUserBucket = 'anonymous';

  final SharedPreferences _preferences;
  final String? userGuid;

  String get _lastDirectoryKey {
    final normalized = userGuid?.trim() ?? '';
    final bucket = normalized.isEmpty ? _anonymousUserBucket : normalized;
    return '$_lastDirectoryKeyPrefix::$bucket';
  }

  /// Resolves the directory the picker should open at this time:
  /// last record → nearest existing ancestor → user home directory.
  String resolveInitialDirectory() {
    final saved = _preferences.getString(_lastDirectoryKey);
    if (saved != null) {
      final resolved = _nearestExistingDirectory(saved);
      if (resolved != null) return resolved;
    }
    return _userHomeDirectory();
  }

  Future<void> saveLastDirectory(String path) {
    return _preferences.setString(_lastDirectoryKey, path);
  }

  static String? _nearestExistingDirectory(String path) {
    var directory = Directory(path);
    while (!FileSystemEntity.isDirectorySync(directory.path)) {
      final parent = directory.parent;
      // Reached the filesystem root and it still is not a directory.
      if (parent.path == directory.path) return null;
      directory = parent;
    }
    return directory.path;
  }

  static String _userHomeDirectory() {
    final environment = Platform.environment;
    final home = environment['HOME'] ?? environment['USERPROFILE'];
    if (home != null && Directory(home).existsSync()) return home;
    return Directory.systemTemp.path;
  }
}
