import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/core/storage/token_store.dart';
import 'package:mocktail/mocktail.dart';

class MockSecureStorage extends Mock implements FlutterSecureStorage {}

class FakeTokenStore extends TokenStore {
  FakeTokenStore({this.accessToken, this.refreshToken})
    : super(MockSecureStorage());

  String? accessToken;
  String? refreshToken;
  String? savedAccessToken;
  String? savedRefreshToken;
  bool cleared = false;

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> saveTokens(String newAccess, String newRefresh) async {
    savedAccessToken = newAccess;
    savedRefreshToken = newRefresh;
    accessToken = newAccess;
    refreshToken = newRefresh;
  }

  @override
  Future<void> clear() async {
    cleared = true;
    accessToken = null;
    refreshToken = null;
  }
}
