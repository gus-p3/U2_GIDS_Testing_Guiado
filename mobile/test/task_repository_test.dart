// PDF §15: a *mocked* API-client test. Fast and deterministic, it checks the
// requests the app builds and how it parses answers. It CANNOT tell whether the
// real API enforces ownership; that is covered by backend/tests/api (real DB).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/tasks/data/task_repository.dart';

import 'fake_token_store.dart';

void main() {
  late List<http.Request> requests;

  TaskRepository repoAnswering(http.Response Function(http.Request) answer) {
    requests = [];
    final client = ApiClient(
      MockClient((request) async {
        requests.add(request);
        return answer(request);
      }),
      FakeTokenStore(accessToken: 'test-access', refreshToken: 'test-refresh'),
    );
    return TaskRepository(client);
  }

  test(
    'list sends the bearer token and pagination, then parses tasks',
    () async {
      final repo = repoAnswering(
        (_) => http.Response(
          jsonEncode({
            'items': [
              {'id': 'c1', 'title': 'Plan tests', 'completed': false},
            ],
          }),
          200,
        ),
      );

      final tasks = await repo.list(page: 2, limit: 5);

      expect(tasks.single.title, 'Plan tests');
      expect(requests.single.method, 'GET');
      expect(requests.single.url.queryParameters, {'page': '2', 'limit': '5'});
      expect(requests.single.headers['authorization'], 'Bearer test-access');
    },
  );

  test('create trims the title and never sends an ownerId', () async {
    final repo = repoAnswering(
      (_) => http.Response(
        jsonEncode({
          'item': {'id': 'c2', 'title': 'Trimmed', 'completed': false},
        }),
        201,
      ),
    );

    await repo.create('  Trimmed  ', null);

    final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(body['title'], 'Trimmed');
    expect(body.containsKey('ownerId'), isFalse);
  });

  test(
    'create omits description when there is none (BUG-008 contract)',
    () async {
      final repo = repoAnswering(
        (_) => http.Response(
          jsonEncode({
            'item': {'id': 'c3', 'title': 'No details', 'completed': false},
          }),
          201,
        ),
      );

      await repo.create('No details', null);
      await repo.create('No details', '   ');

      for (final request in requests) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body.containsKey('description'), isFalse);
      }
    },
  );

  test('task ids are URL-encoded so they cannot change the path', () async {
    final repo = repoAnswering((_) => http.Response('', 204));
    await repo.delete('../auth/logout-all');
    expect(requests.single.url.path, endsWith('/tasks/..%2Fauth%2Flogout-all'));
  });

  test('a malformed item from the server becomes a FormatException', () async {
    final repo = repoAnswering(
      (_) => http.Response(
        jsonEncode({
          'items': [
            {'id': 42, 'title': null},
          ],
        }),
        200,
      ),
    );
    await expectLater(repo.list(), throwsFormatException);
  });

  test('a 404 on update surfaces the API message', () async {
    final repo = repoAnswering(
      (_) => http.Response(
        jsonEncode({
          'error': {'code': 'NOT_FOUND', 'message': 'Task not found.'},
        }),
        404,
      ),
    );
    await expectLater(
      repo.update('someone-elses', title: 'x'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
    );
  });
}
