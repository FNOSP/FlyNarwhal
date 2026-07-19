import 'dart:io';

const applicationId = '9A262498-6C63-4816-A346-056028719600';
const applicationExecutable = 'FlyNarwhal.exe';
const updaterExecutable = 'updater.exe';

Future<void> main() async {
  final contracts = <String, List<String>>{
    'installer/setup.iss': <String>[
      applicationId,
      applicationExecutable,
      updaterExecutable,
      r'{localappdata}\FlyNarwhal',
      'ArchitecturesAllowed=x64compatible',
      'ArchitecturesAllowed=arm64',
    ],
    'windows/CMakeLists.txt': <String>['set(BINARY_NAME "FlyNarwhal")'],
    'windows/runner/Runner.rc': <String>[
      '"OriginalFilename", "FlyNarwhal.exe"',
      '"InternalName", "FlyNarwhal"',
    ],
    'updater/internal/updater/contract.go': <String>[
      applicationId,
      applicationExecutable,
      updaterExecutable,
    ],
    'lib/services/update/platform_update_installer.dart': <String>[
      applicationId,
      applicationExecutable,
      updaterExecutable,
    ],
  };

  for (final contract in contracts.entries) {
    final contents = await File(contract.key).readAsString();
    for (final expectedValue in contract.value) {
      if (!contents.contains(expectedValue)) {
        stderr.writeln('${contract.key} is missing $expectedValue');
        exitCode = 1;
      }
    }
  }

  final installer = await File('installer/setup.iss').readAsString();
  if (RegExp(r'ArchitecturesAllowed=.*\bx86\b').hasMatch(installer) ||
      installer.contains('fly_narwhal.exe')) {
    stderr.writeln('Windows installer contains a forbidden identity.');
    exitCode = 1;
  }
}
