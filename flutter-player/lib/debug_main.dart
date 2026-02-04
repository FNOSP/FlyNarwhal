import 'package:flutter_player/main.dart';

Future<void> main(List<String> args) async {
  await startPlayerApp(
    args: args,
    enableWindowManager: true,
    enablePlayerEngine: true,
  );
}
