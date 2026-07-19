import 'dart:io';

import 'package:fly_narwhal/tooling/windows_bundle_contract.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 2) {
    stderr.writeln(
      'Usage: dart run scripts/windows/verify_bundle_contract.dart '
      '<architecture> <bundleDirectory>',
    );
    exit(1);
  }

  try {
    final summary = await verifyWindowsBundleContract(
      architecture: arguments[0],
      bundleDirectory: arguments[1],
    );
    stdout.writeln(encodeWindowsBundleSummary(summary));
  } on WindowsBundleContractFailure catch (error) {
    stderr.writeln(error.message);
    exit(1);
  } on ArgumentError catch (error) {
    stderr.writeln(error.message);
    exit(1);
  }
}
