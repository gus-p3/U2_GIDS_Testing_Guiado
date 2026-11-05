// PDF §7: complete user journey from the UI through the real API and back,
// extended with the practice exercise (complete the task, log out, see login).
//
// Runs only against the local TEST backend (npm run seed:test && npm run start:test).
// Screenshots are written to SCREENSHOT_DIR as evidence.
//
// flutter test integration_test -d windows \
//   --dart-define=API_BASE_URL=http://localhost:3000/api/v1 \
//   --dart-define=SCREENSHOT_DIR=<abs path>/evidence/screenshots
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/main.dart' as app;

/// Synthetic account seeded in the test database. Never a real credential.
const testEmail = String.fromEnvironment(
  'E2E_TEST_EMAIL',
  defaultValue: 'tester@example.test',
);
const testPassword = String.fromEnvironment(
  'E2E_TEST_PASSWORD',
  defaultValue: 'local-test-password',
);
const screenshotDir = String.fromEnvironment('SCREENSHOT_DIR');

/// Pumps frames until [finder] matches or [timeout] passes. Network calls do not
/// schedule frames, so pumpAndSettle alone can return before the API answers.
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

late IntegrationTestWidgetsFlutterBinding binding;
var surfaceConverted = false;

/// Saves a PNG of the current frame as evidence.
///
/// On Android/iOS (run with `flutter drive`) the image is sent to the host
/// driver, which writes it to evidence/screenshots. On desktop it is rendered
/// from the app's own layer tree into SCREENSHOT_DIR. Either way only the app
/// is captured, never other windows or private screen content.
Future<void> screenshot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  if (Platform.isAndroid || Platform.isIOS) {
    if (Platform.isAndroid && !surfaceConverted) {
      await binding.convertFlutterSurfaceToImage();
      surfaceConverted = true;
      await tester.pumpAndSettle();
    }
    await binding.takeScreenshot(name);
    return;
  }
  if (screenshotDir.isEmpty) return;
  final view = tester.binding.renderViews.first;
  final layer = view.debugLayer! as OffsetLayer;
  final image = await layer.toImage(
    Offset.zero & view.size,
    pixelRatio: view.flutterView.devicePixelRatio,
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('$screenshotDir/$name.png');
  await file.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
}

void main() {
  binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('user can sign in, create and complete a task, and log out', (
    tester,
  ) async {
    // Start signed out: tokens from a previous run must not skip the login screen.
    await const FlutterSecureStorage().deleteAll();

    app.main();
    await waitFor(tester, find.byKey(const Key('login-button')));
    await screenshot(tester, '01-login');

    // Negative step: a wrong password shows the right message (BUG-004 fix).
    await tester.enterText(find.byKey(const Key('email-field')), testEmail);
    await tester.enterText(
      find.byKey(const Key('password-field')),
      'wrong-password-123',
    );
    await tester.tap(find.byKey(const Key('login-button')));
    await waitFor(tester, find.text('Invalid email or password.'));
    await screenshot(tester, '02-login-wrong-password');

    // Sign in with the seeded synthetic account.
    await tester.enterText(
      find.byKey(const Key('password-field')),
      testPassword,
    );
    await tester.tap(find.byKey(const Key('login-button')));
    await waitFor(tester, find.text('No tasks yet. Add your first task.'));
    await screenshot(tester, '03-empty-task-list');

    // Create a task.
    await tester.tap(find.byKey(const Key('add-task-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('task-title-field')),
      'Check release flow',
    );
    await screenshot(tester, '04-new-task-dialog');
    await tester.tap(find.byKey(const Key('save-task-button')));
    // Wait for the task in the LIST, not the text still typed in the dialog
    // field: the first run gave a false positive here and hid BUG-008.
    await waitFor(tester, find.widgetWithText(ListTile, 'Check release flow'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('save-task-button')), findsNothing);
    expect(find.byKey(const Key('action-error-banner')), findsNothing);
    expect(find.widgetWithText(ListTile, 'Check release flow'), findsOneWidget);
    await screenshot(tester, '05-task-created');

    // Validation: a blank title is rejected with a clear message.
    await tester.tap(find.byKey(const Key('add-task-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('task-title-field')), '   ');
    await tester.tap(find.byKey(const Key('save-task-button')));
    await tester.pumpAndSettle();
    expect(find.text('Title is required'), findsOneWidget);
    await screenshot(tester, '06-blank-title-rejected');

    // Markup is displayed as text (PDF §9 step 3).
    await tester.enterText(
      find.byKey(const Key('task-title-field')),
      '<script>alert(1)</script>',
    );
    await tester.tap(find.byKey(const Key('save-task-button')));
    await waitFor(
      tester,
      find.widgetWithText(ListTile, '<script>alert(1)</script>'),
    );
    await screenshot(tester, '07-markup-shown-as-text');

    // Practice exercise: mark the task complete...
    final checkbox = find.descendant(
      of: find.widgetWithText(ListTile, 'Check release flow'),
      matching: find.byType(Checkbox),
    );
    await tester.tap(checkbox);
    await waitFor(
      tester,
      find.descendant(
        of: find.widgetWithText(ListTile, 'Check release flow'),
        matching: find.text('Done'),
      ),
    );
    expect(tester.widget<Checkbox>(checkbox).value, isTrue);
    await screenshot(tester, '08-task-completed');

    // ...log out, and verify that the login screen appears.
    await tester.tap(find.byKey(const Key('logout-button')));
    await waitFor(tester, find.byKey(const Key('login-button')));
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Check release flow'), findsNothing);
    await screenshot(tester, '09-logged-out-login-screen');
  });
}
