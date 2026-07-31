import 'package:flutter_driver/driver_extension.dart';

import 'app.dart';
import 'core/debug/test_hooks.dart';

Future<void> main(List<String> args) async {
  // Driver-enabled entrypoint. Enables the flutter_driver extension and arms
  // the debug-only seam that auto-opens the NAS subtitle dialog once after the
  // player loads, so the dialog can be verified without the hover-driven flyout
  // (which flutter_driver cannot reproduce). None of this exists in the
  // production entrypoint (main.dart).
  debugAutoOpenNasDialogOnce = true;
  enableFlutterDriverExtension();
  await bootstrapApp();
}
