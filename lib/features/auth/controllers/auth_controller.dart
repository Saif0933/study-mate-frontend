import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/providers/core_providers.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';

sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class Authenticated extends AuthState {
  final UserModel user;
  const Authenticated(this.user);
}

class Unauthenticated extends AuthState {
  const Unauthenticated();
}

class AuthError extends AuthState {
  final String message;
  final String? code;
  const AuthError(this.message, [this.code]);
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final storage = ref.watch(secureStorageProvider);
  return AuthRepository(apiClient: apiClient, storageService: storage);
});

final authControllerProvider = NotifierProvider<AuthController, AuthState>(() {
  return AuthController();
});

class AuthController extends Notifier<AuthState> {
  late final AuthRepository _repository;

  @override
  AuthState build() {
    _repository = ref.watch(authRepositoryProvider);
    // Initialize session asynchronously
    _checkInitialSession();
    return const AuthInitial();
  }

  Future<void> _checkInitialSession() async {
    try {
      final hasToken = await _repository.hasSavedToken();
      if (!hasToken) {
        state = const Unauthenticated();
        return;
      }

      // Check cached user first for instant display
      final cachedUser = await _repository.getCachedUser();
      if (cachedUser != null) {
        state = Authenticated(cachedUser);
      }

      // Refresh from server
      final freshUser = await _repository.getMe();
      state = Authenticated(freshUser);
    } catch (e) {
      if (e is ApiException && e.isAuthError) {
        await _repository.logout();
        state = const Unauthenticated();
      } else {
        // If network issue, but we had cached user, keep user authenticated
        final cached = await _repository.getCachedUser();
        if (cached != null) {
          state = Authenticated(cached);
        } else {
          state = const Unauthenticated();
        }
      }
    }
  }

  Future<bool> login(String email, String password) async {
    state = const AuthLoading();
    try {
      final session = await _repository.login(
        email: email.trim(),
        password: password,
      );
      state = Authenticated(session.user);
      return true;
    } on ApiException catch (e) {
      final failure = ErrorMapper.map(e);
      state = AuthError(failure.message, failure.code);
      return false;
    } catch (e) {
      final failure = ErrorMapper.map(e);
      state = AuthError(failure.message, failure.code);
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = const AuthLoading();
    try {
      final session = await _repository.register(
        email: email.trim(),
        password: password,
        displayName: displayName?.trim(),
      );
      state = Authenticated(session.user);
      return true;
    } on ApiException catch (e) {
      final failure = ErrorMapper.map(e);
      state = AuthError(failure.message, failure.code);
      return false;
    } catch (e) {
      final failure = ErrorMapper.map(e);
      state = AuthError(failure.message, failure.code);
      return false;
    }
  }

  Future<String?> forgotPassword(String email) async {
    try {
      final result = await _repository.forgotPassword(email: email.trim());
      return result;
    } on ApiException catch (e) {
      final failure = ErrorMapper.map(e);
      return failure.message;
    } catch (e) {
      final failure = ErrorMapper.map(e);
      return failure.message;
    }
  }

  Future<String?> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      final result = await _repository.resetPassword(
        token: token.trim(),
        newPassword: newPassword,
      );
      return result;
    } on ApiException catch (e) {
      final failure = ErrorMapper.map(e);
      return failure.message;
    } catch (e) {
      final failure = ErrorMapper.map(e);
      return failure.message;
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const Unauthenticated();
  }

  Future<({bool success, String? error})> deleteAccount() async {
    final previousState = state;
    state = const AuthLoading();
    try {
      await _repository.deleteAccount();
      state = const Unauthenticated();
      return (success: true, error: null);
    } on ApiException catch (e) {
      final failure = ErrorMapper.map(e);
      state = previousState;
      return (success: false, error: failure.message);
    } catch (e) {
      final failure = ErrorMapper.map(e);
      state = previousState;
      return (success: false, error: failure.message);
    }
  }

  void clearError() {
    if (state is AuthError) {
      state = const Unauthenticated();
    }
  }
}
