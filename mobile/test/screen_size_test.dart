// PDF §12 practice exercise: the task list on a small and a large screen.
// Looks for overflow, clipped text and controls that are hard to tap.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/providers.dart';
import 'package:mobile/features/auth/presentation/auth_page.dart';
import 'package:mobile/features/tasks/domain/task.dart';
import 'package:mobile/features/tasks/presentation/task_page.dart';

import 'fakes.dart';

/// Logical sizes of representative devices from the compatibility matrix.
const devices = <String, Size>{
  'small phone (iPhone SE 1st gen, 320x568)': Size(320, 568),
  'mainstream phone (393x852)': Size(393, 852),
  'tablet portrait (820x1180)': Size(820, 1180),
  'desktop window (1280x800)': Size(1280, 800),
};

final longTasks = [
  Task(id: 'long', title: 'L' * 120, description: 'D' * 300, completed: false),
  for (var i = 0; i < 25; i++)
    Task(id: 't$i', title: 'Task number $i', completed: i.isEven),
];

void main() {
  devices.forEach((name, size) {
    testWidgets('task list renders without overflow on $name', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskRepositoryProvider.overrideWithValue(
              FakeTaskRepository(longTasks),
            ),
          ],
          child: const MaterialApp(home: TaskPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // The 120-char title is wrapped, not cut off: its full text is in the tree.
      expect(find.text('L' * 120), findsOneWidget);
      // Primary controls are visible and at least 48x48 logical pixels.
      final fab = tester.getSize(find.byKey(const Key('add-task-button')));
      expect(fab.height, greaterThanOrEqualTo(48));
      final logout = tester.getSize(find.byKey(const Key('logout-button')));
      expect(logout.width, greaterThanOrEqualTo(48));
      expect(logout.height, greaterThanOrEqualTo(48));
    });

    testWidgets('login screen fits on $name', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AuthPage())),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final button = tester.getRect(find.byKey(const Key('login-button')));
      expect(button.height, greaterThanOrEqualTo(48));
      expect(button.right, lessThanOrEqualTo(size.width));
    });
  });

  testWidgets('create dialog fits a small phone with the keyboard open', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(FakeTaskRepository()),
        ],
        child: MaterialApp(
          // Simulate a ~260 px software keyboard.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(viewInsets: const EdgeInsets.only(bottom: 260)),
            child: child!,
          ),
          home: const TaskPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-task-button')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('save-task-button')), findsOneWidget);
  });
}
