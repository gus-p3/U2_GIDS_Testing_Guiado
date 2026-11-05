// PDF §11: automated accessibility checks with Flutter's built-in guidelines.
// They complement, not replace, a manual pass with TalkBack/VoiceOver.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/providers.dart';
import 'package:mobile/features/auth/presentation/auth_page.dart';
import 'package:mobile/features/tasks/domain/task.dart';
import 'package:mobile/features/tasks/presentation/task_page.dart';

import 'fakes.dart';

const sampleTasks = [
  Task(id: 'a', title: 'Plan tests', description: 'Week 1', completed: false),
  Task(id: 'b', title: 'Write bug report', completed: true),
];

Widget taskPage({double textScale = 1}) => ProviderScope(
  overrides: [
    taskRepositoryProvider.overrideWithValue(FakeTaskRepository(sampleTasks)),
  ],
  child: MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: const TaskPage(),
  ),
);

Widget authPage({double textScale = 1}) => ProviderScope(
  child: MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: const AuthPage(),
  ),
);

Future<void> expectGuidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

void main() {
  testWidgets('task list meets tap-target, label and contrast guidelines', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(taskPage());
    await tester.pumpAndSettle();
    await expectGuidelines(tester);
    handle.dispose();
  });

  testWidgets('login screen meets tap-target, label and contrast guidelines', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(authPage());
    await tester.pumpAndSettle();
    await expectGuidelines(tester);
    handle.dispose();
  });

  testWidgets('screen readers hear which task each checkbox controls', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(taskPage());
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Mark "Plan tests" as done'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Mark "Write bug report" as not done'),
      findsOneWidget,
    );
    expect(find.byTooltip('Delete "Plan tests"'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('login validation errors are announced as text', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(authPage());
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp('Email is required')), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Password is required')),
      findsOneWidget,
    );
    handle.dispose();
  });

  for (final scale in [1.5, 2.0]) {
    testWidgets('task list stays usable at text scale ${scale}x', (
      tester,
    ) async {
      await tester.pumpWidget(taskPage(textScale: scale));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull); // no RenderFlex overflow
      expect(find.text('Plan tests'), findsOneWidget);
    });

    testWidgets('login stays usable at text scale ${scale}x', (tester) async {
      await tester.pumpWidget(authPage(textScale: scale));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('login-button')), findsOneWidget);
    });
  }
}
