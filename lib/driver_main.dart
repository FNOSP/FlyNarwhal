import 'package:flutter_driver/driver_extension.dart';
import 'app.dart';

Future<void> main() async {
  // Enable the driver extension before bootstrapping the app.
  enableFlutterDriverExtension();
  await bootstrapApp();
}
