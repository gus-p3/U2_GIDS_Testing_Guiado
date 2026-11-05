// PDF §4: unit tests for the Task model, plus the §4 practice exercise
// (missing id, title at the maximum allowed length) and §8 boundaries.
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/tasks/domain/task.dart';

void main() {
  test('parses a valid task', () {
    final task = Task.fromJson({'id': 'task-1', 'title': 'Plan tests'});

    expect(task.id, 'task-1');
    expect(task.title, 'Plan tests');
    expect(task.completed, isFalse);
  });

  test('rejects an empty title', () {
    expect(
      () => Task.fromJson({'id': 'task-1', 'title': '   '}),
      throwsFormatException,
    );
  });

  test('rejects a missing id', () {
    expect(() => Task.fromJson({'title': 'Plan tests'}), throwsFormatException);
  });

  test('accepts a title at the maximum allowed length (120)', () {
    final title = 'a' * Task.maxTitleLength;
    expect(Task.fromJson({'id': 't', 'title': title}).title, title);
  });

  test('rejects a title one character over the maximum (121)', () {
    expect(
      () =>
          Task.fromJson({'id': 't', 'title': 'a' * (Task.maxTitleLength + 1)}),
      throwsFormatException,
    );
  });

  test('accepts the minimum valid title (1 char)', () {
    expect(Task.fromJson({'id': 't', 'title': 'a'}).title, 'a');
  });

  group('rejects malformed server data instead of crashing', () {
    final cases = <String, Map<String, dynamic>>{
      'numeric id': {'id': 42, 'title': 'x'},
      'empty id': {'id': '', 'title': 'x'},
      'numeric title': {'id': 't', 'title': 42},
      'null title': {'id': 't', 'title': null},
      'string completed': {'id': 't', 'title': 'x', 'completed': 'yes'},
      'numeric description': {'id': 't', 'title': 'x', 'description': 7},
    };
    cases.forEach((name, json) {
      test(
        name,
        () => expect(() => Task.fromJson(json), throwsFormatException),
      );
    });
  });

  test('keeps optional description and completion state', () {
    final task = Task.fromJson({
      'id': 't',
      'title': 'x',
      'description': 'details',
      'completed': true,
    });
    expect(task.description, 'details');
    expect(task.completed, isTrue);
  });
}
