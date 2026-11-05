/// Sends authenticated requests to the versioned Task Manager API.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../storage/token_store.dart';

/// A safe API failure with a user-displayable message.
class ApiException implements Exception {
  /// Creates an API exception.
  const ApiException(this.message, {this.statusCode});

  /// A safe message that does not contain server internals.
  final String message;

  /// HTTP status code, when available.
  final int? statusCode;

  @override
  String toString() => message;
}

/// Builds requests, attaches tokens, and performs one refresh-and-retry cycle.
class ApiClient {
  /// Creates a client with injectable HTTP and token-storage dependencies.
  ApiClient(this._http, this._tokens, {this.onSessionExpired});

  final http.Client _http;
  final TokenStore _tokens;

  /// Called after refresh fails and local credentials have been cleared.
  final VoidCallback? onSessionExpired;

  Future<bool>? _refreshInFlight;

  /// Builds a fresh request so the request can safely be retried.
  Future<http.Request> _buildRequest(
    String method,
    String path,
    Map<String, dynamic>? body, {
    bool withAuth = true,
  }) async {
    final normalizedBase = AppConfig.apiBaseUrl.endsWith('/')
        ? AppConfig.apiBaseUrl.substring(0, AppConfig.apiBaseUrl.length - 1)
        : AppConfig.apiBaseUrl;
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    final uri = Uri.parse('$normalizedBase/$normalizedPath');
    final request = http.Request(method, uri)
      ..headers['accept'] = 'application/json'
      ..headers['content-type'] = 'application/json';

    if (withAuth) {
      final token = await _tokens.readAccessToken();
      if (token != null) request.headers['authorization'] = 'Bearer $token';
    }

    if (body != null) request.body = jsonEncode(body);
    return request;
  }

  /// Sends a JSON request and returns its decoded response object.
  ///
  /// A protected request that receives 401 may refresh once and retry once.
  /// Throws [ApiException] for unsuccessful responses or malformed JSON.
  Future<Map<String, dynamic>> send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final isAuthPath =
        path.contains('auth/refresh') ||
        path.contains('auth/login') ||
        path.contains('auth/register') ||
        path.contains('auth/logout');

    var response = await _sendRequest(await _buildRequest(method, path, body));

    if (response.statusCode == 401 && !isAuthPath) {
      if (await _refreshTokens()) {
        response = await _sendRequest(await _buildRequest(method, path, body));
      } else {
        throw const ApiException(
          'Your session has expired. Please sign in again.',
          statusCode: 401,
        );
      }
    }

    return _decodeResponse(response, isAuthPath: isAuthPath);
  }

  Future<http.Response> _sendRequest(http.Request request) async {
    try {
      final streamed = await _http
          .send(request)
          .timeout(const Duration(seconds: 15));
      return await http.Response.fromStream(streamed);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'Could not connect to the server. Check your connection and try again.',
      );
    }
  }

  Future<Map<String, dynamic>> _decodeResponse(
    http.Response response, {
    required bool isAuthPath,
  }) async {
    // On login/register a 401 means bad credentials, not an expired session (BUG-004).
    if (response.statusCode == 401 && !isAuthPath) {
      throw const ApiException(
        'Your session has expired. Please sign in again.',
        statusCode: 401,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _clientErrorMessage(response) ??
            'The request could not be completed. Try again.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode == 204 || response.body.isEmpty) return {};

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const ApiException('The server returned unexpected data.');
      }
      return decoded;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('The server returned unexpected data.');
    }
  }

  /// Returns the API's own message for 4xx answers, which the server keeps safe
  /// and actionable ("already exists", "too many requests"). 5xx bodies are never
  /// shown because they could describe server internals.
  String? _clientErrorMessage(http.Response response) {
    if (response.statusCode < 400 || response.statusCode >= 500) return null;
    try {
      final decoded = jsonDecode(response.body);
      final error = decoded is Map ? decoded['error'] : null;
      final message = error is Map ? error['message'] : null;
      return message is String && message.isNotEmpty ? message : null;
    } catch (_) {
      return null;
    }
  }

  /// Refreshes credentials once; concurrent callers share the same operation.
  Future<bool> _refreshTokens() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;

    final refresh = _performRefresh();
    _refreshInFlight = refresh;
    return refresh.whenComplete(() => _refreshInFlight = null);
  }

  Future<bool> _performRefresh() async {
    try {
      final refreshToken = await _tokens.readRefreshToken();
      if (refreshToken == null) throw const ApiException('Session expired.');

      final request = await _buildRequest('POST', 'auth/refresh', {
        'refreshToken': refreshToken,
      }, withAuth: false);
      final response = await _sendRequest(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const ApiException('Session expired.');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final accessToken = decoded['accessToken'];
      final newRefreshToken = decoded['refreshToken'];
      if (accessToken is! String || newRefreshToken is! String) {
        throw const ApiException('Session expired.');
      }

      await _tokens.saveTokens(accessToken, newRefreshToken);
      return true;
    } catch (_) {
      await _tokens.clear();
      onSessionExpired?.call();
      return false;
    }
  }
}
