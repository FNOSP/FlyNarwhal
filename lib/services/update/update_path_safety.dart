import 'dart:io';

import 'package:path/path.dart' as path;

/// Validates untrusted update paths and platform-specific containment rules.
final class UpdatePathSafety {
  const UpdatePathSafety._();

  static final RegExp _windowsReservedName = RegExp(
    r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)',
    caseSensitive: false,
  );

  static bool isSafeAssetName(String assetName) {
    if (assetName.isEmpty ||
        assetName == '.' ||
        assetName == '..' ||
        assetName.contains('/') ||
        assetName.contains(r'\') ||
        assetName.contains('\u0000') ||
        assetName.endsWith('.') ||
        assetName.endsWith(' ') ||
        path.basename(assetName) != assetName) {
      return false;
    }
    return !_windowsReservedName.hasMatch(assetName);
  }

  static bool isWithinRoot({
    required String rootPath,
    required String candidatePath,
  }) {
    if (Platform.isWindows) {
      return isWithinRootForWindows(
        rootPath: rootPath,
        candidatePath: candidatePath,
      );
    }
    final normalizedRoot = path.posix.normalize(path.absolute(rootPath));
    final normalizedCandidate =
        path.posix.normalize(path.absolute(candidatePath));
    return normalizedCandidate != normalizedRoot &&
        path.posix.isWithin(normalizedRoot, normalizedCandidate);
  }

  static bool isWithinRootForWindows({
    required String rootPath,
    required String candidatePath,
  }) {
    final windowsPath = path.Context(style: path.Style.windows);
    final normalizedRoot = windowsPath
        .normalize(windowsPath.absolute(rootPath.replaceAll('/', r'\')))
        .toLowerCase();
    final normalizedCandidate = windowsPath
        .normalize(windowsPath.absolute(candidatePath.replaceAll('/', r'\')))
        .toLowerCase();
    return normalizedCandidate != normalizedRoot &&
        windowsPath.isWithin(normalizedRoot, normalizedCandidate);
  }

  static bool sameWindowsPath({
    required String firstPath,
    required String secondPath,
  }) {
    final windowsPath = path.Context(style: path.Style.windows);
    return windowsPath
            .normalize(windowsPath.absolute(firstPath))
            .toLowerCase() ==
        windowsPath.normalize(windowsPath.absolute(secondPath)).toLowerCase();
  }

  static Future<bool> isSafeRegularFile(String filePath) async {
    final file = File(filePath);
    final type = await FileSystemEntity.type(filePath, followLinks: false);
    if (type != FileSystemEntityType.file || await file.length() < 0) {
      return false;
    }
    return _hasNoLinkComponents(filePath, includeLeaf: true);
  }

  static Future<bool> isSafeDirectoryTree(String directoryPath) async {
    final type = await FileSystemEntity.type(directoryPath, followLinks: false);
    if (type != FileSystemEntityType.directory) return false;
    return _hasNoLinkComponents(directoryPath, includeLeaf: true);
  }

  static Future<bool> _hasNoLinkComponents(
    String targetPath, {
    required bool includeLeaf,
  }) async {
    final absolutePath = path.absolute(targetPath);
    final components = path.split(absolutePath);
    var currentPath = components.first;
    final finalIndex = includeLeaf ? components.length : components.length - 1;
    for (var index = 1; index < finalIndex; index++) {
      currentPath = path.join(currentPath, components[index]);
      final type = await FileSystemEntity.type(currentPath, followLinks: false);
      if (type == FileSystemEntityType.link) return false;
    }
    return true;
  }
}
