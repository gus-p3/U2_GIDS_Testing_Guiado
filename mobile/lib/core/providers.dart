import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'network/api_client.dart';
import 'storage/token_store.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/tasks/data/task_repository.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final tokenStoreProvider = Provider<TokenStore>((ref) {
  return TokenStore(ref.watch(secureStorageProvider));
});

class AuthNotifier extends Notifier<bool> {
  @override
  bool build() {
    checkInitialState();
    return false;
  }

  Future<void> checkInitialState() async {
    final token = await ref.read(tokenStoreProvider).readAccessToken();
    state = token != null;
  }

  void signIn() {
    state = true;
  }

  void signOut() {
    state = false;
  }
}

final authStateProvider = NotifierProvider<AuthNotifier, bool>(
  AuthNotifier.new,
);

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    http.Client(),
    ref.watch(tokenStoreProvider),
    onSessionExpired: () => ref.read(authStateProvider.notifier).signOut(),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStoreProvider),
  );
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(ref.watch(apiClientProvider));
});
