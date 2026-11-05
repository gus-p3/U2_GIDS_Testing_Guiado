// PDF §5: widget tests for loading, empty, error and data states, with state
// injected so no real API is needed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/tasks/domain/task.dart';
import 'package:mobile/features/tasks/presentation/task_page.dart';

Widget panel({
  bool loading = false,
  List<Task> tasks = const [],
  String? errorMessage,
  String? actionError,
  VoidCallback? onRetry,
  ValueChanged<Task>? onToggle,
  ValueChanged<Task>? onDelete,
}) {
  return MaterialApp(
    home: Scaffold(
      body: TaskListView(
        loading: loading,
        tasks: tasks,
        errorMessage: errorMessage,
        actionError: actionError,
        onRetry: onRetry ?? () {},
        onToggle: onToggle ?? (_) {},
        onDelete: onDelete ?? (_) {},
      ),
    ),
  );
}

const planTests = Task(
  id: 'task-1',
  title: 'Plan tests',
  description: 'Write acceptance criteria',
  completed: false,
);

void main() {
  testWidgets('shows loading state', (tester) async {
    await tester.pumpWidget(panel(loading: true));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows empty state', (tester) async {
    await tester.pumpWidget(panel());
    expect(find.text('No tasks yet. Add your first task.'), findsOneWidget);
  });

  testWidgets('shows error state', (tester) async {
    await tester.pumpWidget(panel(errorMessage: 'Could not load tasks.'));
    expect(find.text('Could not load tasks.'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('shows task data', (tester) async {
    await tester.pumpWidget(panel(tasks: const [planTests]));
    expect(find.text('Plan tests'), findsOneWidget);
    expect(find.text('Pending · Write acceptance criteria'), findsOneWidget);
  });

  // PDF §5 practice exercise.
  testWidgets('tapping Retry invokes the callback exactly once', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      panel(errorMessage: 'Could not load tasks.', onRetry: () => retries++),
    );

    await tester.tap(find.byKey(const Key('retry-button')));
    await tester.pump();

    expect(retries, 1);
  });

  testWidgets('loading wins over a stale error message', (tester) async {
    await tester.pumpWidget(panel(loading: true, errorMessage: 'old error'));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('old error'), findsNothing);
  });

  testWidgets('an action error keeps the list visible (BUG-001)', (
    tester,
  ) async {
    await tester.pumpWidget(
      panel(tasks: const [planTests], actionError: 'Could not save.'),
    );
    expect(find.text('Plan tests'), findsOneWidget);
    expect(find.byKey(const Key('action-error-banner')), findsOneWidget);
  });

  testWidgets('checkbox and delete report the right task', (tester) async {
    Task? toggled;
    Task? deleted;
    await tester.pumpWidget(
      panel(
        tasks: const [planTests],
        onToggle: (t) => toggled = t,
        onDelete: (t) => deleted = t,
      ),
    );

    await tester.tap(find.byKey(const Key('complete-task-1')));
    await tester.tap(find.byKey(const Key('delete-task-1')));

    expect(toggled?.id, 'task-1');
    expect(deleted?.id, 'task-1');
  });

  testWidgets('a completed task says "Done" in text, not only with style', (
    tester,
  ) async {
    await tester.pumpWidget(
      panel(
        tasks: const [Task(id: 'd', title: 'Shipped', completed: true)],
      ),
    );
    expect(find.text('Done'), findsOneWidget);
  });

  // PDF §9 step 3: markup must be shown as text, never interpreted.
  testWidgets('markup-like titles are rendered literally', (tester) async {
    const markup = '<script>alert(1)</script>';
    await tester.pumpWidget(
      panel(
        tasks: const [Task(id: 'x', title: markup, completed: false)],
      ),
    );
    expect(find.text(markup), findsOneWidget);
  });
}
