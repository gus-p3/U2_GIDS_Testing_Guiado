// Regression tests for defects found while exploring the task screen
// (docs/03-reportes-de-bugs.md). Each one was written first, seen failing,
// and only then fixed.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/providers.dart';
import 'package:mobile/features/tasks/domain/task.dart';
import 'package:mobile/features/tasks/presentation/task_page.dart';

import 'fakes.dart';

Future<FakeTaskRepository> pumpTaskPage(
  WidgetTester tester, [
  List<Task> initial = const [],
]) async {
  final repository = FakeTaskRepository(initial);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [taskRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: TaskPage()),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  const milk = Task(id: 't1', title: 'Buy milk', completed: false);
  const tests = Task(id: 't2', title: 'Plan tests', completed: false);

  testWidgets('BUG-001: tasks stay visible when marking one complete fails', (
    tester,
  ) async {
    final repository = await pumpTaskPage(tester, [milk, tests]);
    repository.failUpdates = true;

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    // The list must survive a failed action; only the action reports an error.
    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.text('Plan tests'), findsOneWidget);
    expect(
      find.textContaining('Could not connect to the server'),
      findsOneWidget,
    );
    // And the checkbox shows the real (unchanged) server state.
    final box = tester.widget<Checkbox>(find.byType(Checkbox).first);
    expect(box.value, isFalse);
  });

  testWidgets('BUG-002: tapping Save twice quickly creates only one task', (
    tester,
  ) async {
    final repository = await pumpTaskPage(tester);
    repository.createGate = Completer<void>();

    await tester.tap(find.byKey(const Key('add-task-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('task-title-field')),
      'Only once',
    );
    await tester.tap(find.byKey(const Key('save-task-button')));
    await tester.pump();
    // Second tap while the first save is still in flight. warnIfMissed is off
    // because a correctly disabled button may not receive the hit.
    await tester.tap(
      find.byKey(const Key('save-task-button')),
      warnIfMissed: false,
    );
    await tester.pump();

    repository.createGate!.complete();
    await tester.pumpAndSettle();

    expect(repository.createCalls, 1);
    expect(find.text('Only once'), findsOneWidget);
  });
}
