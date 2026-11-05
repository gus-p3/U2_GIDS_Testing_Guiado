import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/task_repository.dart';
import '../domain/task.dart';
import '../../../core/providers.dart';

/// Immutable state of the task screen.
///
/// [errorMessage] means the list itself could not be loaded (the screen shows a
/// retry state). [actionError] means a single action failed (complete, delete,
/// create) and must NOT hide the tasks that are already loaded (BUG-001).
class TaskListState {
  const TaskListState({
    this.loading = false,
    this.tasks = const [],
    this.errorMessage,
    this.actionError,
  });

  final bool loading;
  final List<Task> tasks;
  final String? errorMessage;
  final String? actionError;

  /// Copies the state. Both error fields are cleared unless passed explicitly.
  TaskListState copyWith({
    bool? loading,
    List<Task>? tasks,
    String? errorMessage,
    String? actionError,
  }) {
    return TaskListState(
      loading: loading ?? this.loading,
      tasks: tasks ?? this.tasks,
      errorMessage: errorMessage,
      actionError: actionError,
    );
  }
}

class TaskListNotifier extends Notifier<TaskListState> {
  @override
  TaskListState build() {
    Future.microtask(() => loadTasks());
    return const TaskListState();
  }

  TaskRepository get _repository => ref.read(taskRepositoryProvider);

  Future<void> loadTasks() async {
    state = state.copyWith(loading: true);
    try {
      final tasks = await _repository.list();
      state = state.copyWith(loading: false, tasks: tasks);
    } catch (e) {
      state = state.copyWith(loading: false, errorMessage: e.toString());
    }
  }

  Future<void> toggleCompleted(Task task) async {
    try {
      final updated = await _repository.setCompleted(task, !task.completed);
      state = state.copyWith(
        tasks: state.tasks.map((t) => t.id == task.id ? updated : t).toList(),
      );
    } catch (e) {
      state = state.copyWith(actionError: e.toString());
    }
  }

  Future<void> createTask(String title, String? description) async {
    try {
      final created = await _repository.create(title, description);
      state = state.copyWith(tasks: [created, ...state.tasks]);
    } catch (e) {
      state = state.copyWith(actionError: e.toString());
      rethrow;
    }
  }

  Future<void> deleteTask(Task task) async {
    try {
      await _repository.delete(task.id);
      state = state.copyWith(
        tasks: state.tasks.where((t) => t.id != task.id).toList(),
      );
    } catch (e) {
      state = state.copyWith(actionError: e.toString());
    }
  }

  /// Hides the current action error after the user has seen it.
  void dismissActionError() {
    state = state.copyWith();
  }
}

final taskListProvider = NotifierProvider<TaskListNotifier, TaskListState>(
  TaskListNotifier.new,
);
