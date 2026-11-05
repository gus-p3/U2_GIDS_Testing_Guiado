/// Defines the task data used by the Flutter application.
library;

/// Represents a task owned by the signed-in user.
class Task {
  /// Creates a task value.
  ///
  /// [id] is the server-generated task identifier.
  /// [title] is the task title.
  /// [description] is optional detail.
  /// [completed] indicates whether the task is complete.
  const Task({
    required this.id,
    required this.title,
    this.description,
    required this.completed,
  });

  /// Maximum title length accepted by the API.
  static const maxTitleLength = 120;

  /// Server-generated task identifier.
  final String id;

  /// Short task title.
  final String title;

  /// Optional task details.
  final String? description;

  /// Completion state.
  final bool completed;

  /// Parses a task from the API JSON response.
  ///
  /// Throws [FormatException] when required fields are missing or invalid, so a
  /// malformed server answer becomes one predictable error instead of a crash
  /// (PDF §4, "unsafe consumption of APIs").
  factory Task.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final description = json['description'];
    final completed = json['completed'] ?? false;

    if (id is! String ||
        id.isEmpty ||
        title is! String ||
        title.trim().isEmpty ||
        title.length > maxTitleLength ||
        (description != null && description is! String) ||
        completed is! bool) {
      throw const FormatException('Invalid task data.');
    }

    return Task(
      id: id,
      title: title,
      description: description as String?,
      completed: completed,
    );
  }

  /// Converts editable fields into a request payload.
  ///
  /// Returns only task fields accepted by the API.
  Map<String, dynamic> toWriteJson() => {
    'title': title,
    'description': description,
    'completed': completed,
  };
}
