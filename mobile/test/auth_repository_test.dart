// Mocked API-client tests for authentication (PDF §15): fast and deterministic,
// but they only prove the client handles the responses we *assume* the API sends.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/data/auth_repository.dart';

import 'fake_token_store.dart';

http.Response apiError(int status, String code, String message) =>
    http.Response(
      jsonEncode({
        'error': {'code': code, 'message': message},
      }),
      status,
    );

AuthRepository repositoryReturning(
  http.Response response,
  FakeTokenStore tokens,
) {
  final client = ApiClient(MockClient((_) async => response), tokens);
  return AuthRepository(client, tokens);
}

void main() {
  test(
    'BUG-004: a wrong password says so instead of "session expired"',
    () async {
      final tokens = FakeTokenStore();
      final repo = repositoryReturning(
        apiError(401, 'UNAUTHENTICATED', 'Invalid email or password.'),
        tokens,
      );

      await expectLater(
        repo.login('tester@example.test', 'wrong-password'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Invalid email or password.',
          ),
        ),
      );
      expect(tokens.savedAccessToken, isNull);
    },
  );

  test('a duplicate registration explains how to recover', () async {
    final repo = repositoryReturning(
      apiError(409, 'CONFLICT', 'An account with this email already exists.'),
      FakeTokenStore(),
    );
    await expectLater(
      repo.register('tester@example.test', 'long-enough-password'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('already exists'),
        ),
      ),
    );
  });

  test('rate limiting is reported as such', () async {
    final repo = repositoryReturning(
      apiError(429, 'RATE_LIMITED', 'Too many requests. Try again later.'),
      FakeTokenStore(),
    );
    await expectLater(
      repo.login('tester@example.test', 'whatever-password'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'Too many requests. Try again later.',
        ),
      ),
    );
  });

  test('a 500 never leaks the server message', () async {
    final repo = repositoryReturning(
      apiError(
        500,
        'INTERNAL_ERROR',
        'PrismaClientKnownRequestError at db.js:12',
      ),
      FakeTokenStore(),
    );
    await expectLater(
      repo.login('tester@example.test', 'whatever-password'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          isNot(contains('Prisma')),
        ),
      ),
    );
  });

  test('successful login stores both tokens', () async {
    final tokens = FakeTokenStore();
    final repo = repositoryReturning(
      http.Response(
        jsonEncode({'accessToken': 'a-token', 'refreshToken': 'r-token'}),
        200,
      ),
      tokens,
    );
    await repo.login('tester@example.test', 'local-test-password');
    expect(tokens.savedAccessToken, 'a-token');
    expect(tokens.savedRefreshToken, 'r-token');
  });

  test(
    'logout clears local tokens even when the server is unreachable',
    () async {
      final tokens = FakeTokenStore(accessToken: 'a', refreshToken: 'r');
      final client = ApiClient(
        MockClient((_) async => throw http.ClientException('offline')),
        tokens,
      );
      await AuthRepository(client, tokens).logout();
      expect(tokens.cleared, isTrue);
    },
  );
}
