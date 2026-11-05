import 'dart:async';

import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/tasks/data/task_repository.dart';
import 'package:mobile/features/tasks/domain/task.dart';

/// In-memory [TaskRepository] with switches to simulate failures and slow saves.
///
/// Used by widget tests so screens can be exercised without a real API (PDF §5, §15).
class FakeTaskRepository implements TaskRepository {
  FakeTaskRepository([List<Task>? initial]) : tasks = [...?initial];

  /// Current server-side tasks.
  final List<Task> tasks;

  /// When true, completion updates fail as if the device went offline.
  bool failUpdates = false;

  /// When set, `create` waits for this completer (simulates a slow network).
  Completer<void>? createGate;

  /// Number of times `create` was called.
  int createCalls = 0;

  static const offline = ApiException(
    'Could not connect to the server. Check your connection and try again.',
  );

  @override
  Future<List<Task>> list({int page = 1, int limit = 20}) async => [...tasks];

  @override
  Future<Task> create(String title, String? description) async {
    createCalls++;
    await createGate?.future;
    final task = Task(
      id: 'task-$createCalls',
      title: title,
      description: description,
      completed: false,
    );
    tasks.insert(0, task);
    return task;
  }

  @override
  Future<Task> setCompleted(Task task, bool completed) async {
    if (failUpdates) throw offline;
    final updated = Task(
      id: task.id,
      title: task.title,
      description: task.description,
      completed: completed,
    );
    tasks[tasks.indexWhere((t) => t.id == task.id)] = updated;
    return updated;
  }

  @override
  Future<Task> update(
    String taskId, {
    String? title,
    String? description,
    bool? completed,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> delete(String taskId) async {
    tasks.removeWhere((t) => t.id == taskId);
  }
}
