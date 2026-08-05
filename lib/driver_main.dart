// ignore: depend_on_referenced_packages
import 'package:flutter_driver/driver_extension.dart';

import 'app.dart';
import 'tooling/driver_test_mode.dart';

Future<void> main(List<String> args) async {
  kDriverTestMode = true;
  enableFlutterDriverExtension();
  await bootstrapApp();
}
