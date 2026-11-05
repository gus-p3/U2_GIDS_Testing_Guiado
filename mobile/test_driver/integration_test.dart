// Host-side driver for `flutter drive`: receives screenshots taken on the
// device with binding.takeScreenshot() and saves them on this PC.
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final dir =
      Platform.environment['SCREENSHOT_DIR'] ?? '../evidence/screenshots';
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      final file = File('$dir/$name.png');
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);
      return true;
    },
  );
}
