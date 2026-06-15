import 'package:flutter_driver/driver_extension.dart';

import 'app.dart';

Future<void> main(List<String> args) async {
  enableFlutterDriverExtension();
  await bootstrapApp();
}
