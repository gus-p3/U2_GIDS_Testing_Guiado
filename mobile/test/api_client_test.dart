import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/network/api_client.dart';

import 'fake_token_store.dart';

void main() {
  test('refreshes once on 401 and retries the original request once', () async {
    var originalCalls = 0;
    var refreshCalls = 0;

    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/auth/refresh')) {
        refreshCalls++;
        return http.Response(
          jsonEncode({
            'accessToken': 'new-access',
            'refreshToken': 'new-refresh',
          }),
          200,
        );
      }
      originalCalls++;
      if (originalCalls == 1) return http.Response('{}', 401);
      expect(request.headers['authorization'], 'Bearer new-access');
      return http.Response(jsonEncode({'items': []}), 200);
    });

    final tokens = FakeTokenStore(
      accessToken: 'old-access',
      refreshToken: 'old-refresh',
    );

    final client = ApiClient(mock, tokens);
    await client.send('GET', 'tasks');

    expect(refreshCalls, 1);
    expect(originalCalls, 2);
    expect(tokens.savedAccessToken, 'new-access');
    expect(tokens.savedRefreshToken, 'new-refresh');
  });

  test('throws ApiException on non-auth error and does not retry', () async {
    var originalCalls = 0;
    final mock = MockClient((request) async {
      originalCalls++;
      return http.Response('{"error":"Not Found"}', 404);
    });

    final tokens = FakeTokenStore(
      accessToken: 'access',
      refreshToken: 'refresh',
    );

    final client = ApiClient(mock, tokens);
    await expectLater(
      client.send('GET', 'tasks/non-existent'),
      throwsA(isA<ApiException>()),
    );
    expect(originalCalls, 1);
  });
}
