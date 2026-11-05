// PDF §8 practice exercise applied to the password field (client-side), with
// synthetic passwords only.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/presentation/auth_page.dart';

Future<void> pumpRegisterForm(WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(child: MaterialApp(home: AuthPage())),
  );
  await tester.tap(find.byKey(const Key('toggle-auth-mode-button')));
  await tester.pump();
}

Future<void> submit(WidgetTester tester, String email, String password) async {
  await tester.enterText(find.byKey(const Key('email-field')), email);
  await tester.enterText(find.byKey(const Key('password-field')), password);
  // Validation runs before any network call, so the form never reaches the API
  // when it is invalid. Valid cases are not submitted here (no API in widget tests).
  final form = tester.state<FormState>(find.byType(Form));
  form.validate();
  await tester.pump();
}

void main() {
  const email = 'tester@example.test';

  final cases = <String, (String, String?)>{
    'empty': ('', 'Password is required'),
    'just under minimum (11)': (
      'p' * 11,
      'Password must be at least 12 characters',
    ),
    'minimum (12)': ('p' * 12, null),
    'typical': ('correct-horse-battery', null),
    'maximum (72 bytes)': ('p' * 72, null),
    'over maximum (73 bytes)': ('p' * 73, 'Password must be at most 72 bytes'),
    '37 x "ñ" = 74 bytes': ('ñ' * 37, 'Password must be at most 72 bytes'),
  };

  cases.forEach((name, data) {
    final (password, expectedError) = data;
    testWidgets('register password: $name', (tester) async {
      await pumpRegisterForm(tester);
      await submit(tester, email, password);
      if (expectedError == null) {
        expect(find.textContaining('Password must'), findsNothing);
        expect(find.text('Password is required'), findsNothing);
      } else {
        expect(find.text(expectedError), findsOneWidget);
      }
    });
  });

  testWidgets('email is validated before sending', (tester) async {
    await pumpRegisterForm(tester);
    await submit(tester, 'not-an-email', 'p' * 20);
    expect(find.text('Enter a valid email address'), findsOneWidget);
  });

  testWidgets('the password field is obscured', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AuthPage())),
    );
    final field = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('password-field')),
        matching: find.byType(EditableText),
      ),
    );
    expect(field.obscureText, isTrue);
  });
}
