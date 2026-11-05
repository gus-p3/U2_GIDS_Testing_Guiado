import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/task.dart';
import 'task_controller.dart';
import '../../../core/providers.dart';

class TaskPage extends ConsumerWidget {
  const TaskPage({super.key});

  void _showCreateTaskDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => CreateTaskDialog(
        onSave: (title, description) =>
            ref.read(taskListProvider.notifier).createTask(title, description),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Task task) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-delete-button'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              ref.read(taskListProvider.notifier).deleteTask(task);
              Navigator.of(ctx).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(taskListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Task Manager'),
        actions: [
          IconButton(
            key: const Key('logout-button'),
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authRepositoryProvider).logout();
              ref.read(authStateProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: TaskListView(
        loading: state.loading,
        tasks: state.tasks,
        errorMessage: state.errorMessage,
        actionError: state.actionError,
        onDismissActionError: () =>
            ref.read(taskListProvider.notifier).dismissActionError(),
        onRetry: () => ref.read(taskListProvider.notifier).loadTasks(),
        onToggle: (task) =>
            ref.read(taskListProvider.notifier).toggleCompleted(task),
        onDelete: (task) => _confirmDelete(context, ref, task),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-task-button'),
        onPressed: () => _showCreateTaskDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Task'),
      ),
    );
  }
}

/// Dialog that collects a new task and saves it at most once per submission.
class CreateTaskDialog extends StatefulWidget {
  /// Creates the dialog. [onSave] persists the task and may throw on failure.
  const CreateTaskDialog({super.key, required this.onSave});

  /// Persists the trimmed title and optional description.
  final Future<void> Function(String title, String? description) onSave;

  @override
  State<CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends State<CreateTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // A second tap while a save is in flight is ignored (BUG-002).
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final description = _descriptionController.text.trim();
    try {
      await widget.onSave(
        _titleController.text.trim(),
        description.isEmpty ? null : description,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Task'),
      // Scrollable so the keyboard on small phones cannot overflow it (BUG-006).
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('task-title-field'),
                controller: _titleController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  hintText: 'Enter task title',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Title is required';
                  }
                  if (val.trim().length > Task.maxTitleLength) {
                    return 'Maximum ${Task.maxTitleLength} characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('task-description-field'),
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Enter details',
                ),
                maxLines: 3,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('save-task-button'),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

/// Renders an asynchronous task-list result.
class TaskListView extends StatelessWidget {
  /// Creates a task list view.
  const TaskListView({
    super.key,
    required this.loading,
    required this.tasks,
    required this.errorMessage,
    required this.onRetry,
    required this.onToggle,
    required this.onDelete,
    this.actionError,
    this.onDismissActionError,
  });

  /// Whether the repository is loading tasks.
  final bool loading;

  /// Tasks to display after a successful load.
  final List<Task> tasks;

  /// Safe error message, if loading the list failed.
  final String? errorMessage;

  /// Safe error message for a failed action; the list stays visible.
  final String? actionError;

  /// Callback to retry loading.
  final VoidCallback onRetry;

  /// Callback for completion changes.
  final ValueChanged<Task> onToggle;

  /// Callback for deletion.
  final ValueChanged<Task> onDelete;

  /// Hides [actionError].
  final VoidCallback? onDismissActionError;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(semanticsLabel: 'Loading tasks'),
      );
    }
    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
                semanticLabel: 'Error',
              ),
              const SizedBox(height: 12),
              Text(errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('retry-button'),
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final banner = actionError == null
        ? null
        : MaterialBanner(
            key: const Key('action-error-banner'),
            leading: const Icon(Icons.warning_amber_rounded),
            content: Text(actionError!),
            actions: [
              TextButton(
                onPressed: onDismissActionError,
                child: const Text('Dismiss'),
              ),
            ],
          );

    if (tasks.isEmpty) {
      return Column(
        children: [
          ?banner,
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.task_alt,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No tasks yet. Add your first task.',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        ?banner,
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => onRetry(),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              itemCount: tasks.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) => _TaskTile(
                task: tasks[index],
                onToggle: onToggle,
                onDelete: onDelete,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.onToggle,
    required this.onDelete,
  });

  final Task task;
  final ValueChanged<Task> onToggle;
  final ValueChanged<Task> onDelete;

  @override
  Widget build(BuildContext context) {
    final decoration = task.completed ? TextDecoration.lineThrough : null;
    return Card(
      elevation: 0,
      color: task.completed
          ? Theme.of(context).colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.5)
          : null,
      child: ListTile(
        leading: Checkbox(
          key: Key('complete-${task.id}'),
          value: task.completed,
          // Screen readers announce which task the checkbox controls.
          semanticLabel: task.completed
              ? 'Mark "${task.title}" as not done'
              : 'Mark "${task.title}" as done',
          onChanged: (_) => onToggle(task),
        ),
        title: Text(
          task.title,
          style: TextStyle(decoration: decoration, fontWeight: FontWeight.w600),
        ),
        // Status is also given as text, so colour/strike-through is not the only cue.
        subtitle: Text(
          [
            task.completed ? 'Done' : 'Pending',
            if (task.description != null) task.description!,
          ].join(' · '),
          style: TextStyle(decoration: decoration),
        ),
        trailing: IconButton(
          key: Key('delete-${task.id}'),
          tooltip: 'Delete "${task.title}"',
          icon: Icon(
            Icons.delete_outline,
            color: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => onDelete(task),
        ),
      ),
    );
  }
}
