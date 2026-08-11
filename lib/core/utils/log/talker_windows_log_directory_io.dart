import 'dart:io';

import 'package:path/path.dart' as path;

const String _windowsCompanyName = 'com.jankinwu';
const String _windowsProductName = 'FlyNarwhal';

// Resolve the Windows log directory under %APPDATA%\com.jankinwu\FlyNarwhal\logs.
String? resolveWindowsLogDirectoryPath() {
  if (!Platform.isWindows) {
    return null;
  }

  final appDataDirectory = Platform.environment['APPDATA'];
  if (appDataDirectory == null || appDataDirectory.isEmpty) {
    return null;
  }

  return path.join(
    appDataDirectory,
    _windowsCompanyName,
    _windowsProductName,
    'logs',
  );
}
