import 'dart:io';

import 'package:fly_narwhal/tooling/windows_bundle_contract.dart';

const applicationId = '9A262498-6C63-4816-A346-056028719600';
const applicationExecutable = 'FlyNarwhal.exe';
const nativeHelperExecutable = 'FlyNarwhalInstallHelper.exe';

Future<void> main(List<String> arguments) async {
  if (arguments.isNotEmpty && arguments.length != 2) {
    stderr.writeln(
      'Usage: dart run scripts/windows/verify_identity_contract.dart '
      '[<architecture> <bundleDirectory>]',
    );
    exit(1);
  }

  final contracts = <String, List<String>>{
    'installer/setup.iss': <String>[
      applicationId,
      applicationExecutable,
      nativeHelperExecutable,
      r'{localappdata}\FlyNarwhal',
      'ArchitecturesAllowed=x64compatible',
      'ArchitecturesAllowed=arm64',
    ],
    'windows/CMakeLists.txt': <String>[
      'set(BINARY_NAME "FlyNarwhal")',
      'set(FLYNARWHAL_NATIVE_HELPER_NAME "FlyNarwhalInstallHelper.exe")',
    ],
    'windows/runner/Runner.rc': <String>[
      '"OriginalFilename", "FlyNarwhal.exe"',
      '"InternalName", "FlyNarwhal"',
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
  final rejectsForbiddenHelpers = forbiddenWindowsHelperExecutables.every(
    (executable) => installer.contains(executable),
  );
  if (RegExp(r'ArchitecturesAllowed=.*\bx86\b').hasMatch(installer) ||
      installer.contains('fly_narwhal.exe') ||
      !rejectsForbiddenHelpers) {
    stderr.writeln('Windows installer contains a forbidden identity.');
    exitCode = 1;
  }

  if (exitCode != 0 || arguments.isEmpty) {
    return;
  }

  try {
    final summary = await verifyWindowsBundleContract(
      architecture: arguments[0],
      bundleDirectory: arguments[1],
    );
    stdout.writeln(encodeWindowsBundleSummary(summary));
  } on WindowsBundleContractFailure catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  } on ArgumentError catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  }
}
