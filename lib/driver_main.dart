import 'package:flutter_driver/driver_extension.dart';

import 'app.dart';

Future<void> main(List<String> args) async {
  final isMultiWindowChild = args.isNotEmpty && args.first == 'multi_window';

  // Keep the driver extension on the main engine only.
  if (!isMultiWindowChild) {
    enableFlutterDriverExtension();
  }

  await bootstrapApp();
}
