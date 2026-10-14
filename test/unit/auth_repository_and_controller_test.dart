import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_mate_frontend/core/network/api_client.dart';
import 'package:study_mate_frontend/core/network/api_exceptions.dart';
import 'package:study_mate_frontend/core/storage/secure_storage_service.dart';
import 'package:study_mate_frontend/features/auth/controllers/auth_controller.dart';
import 'package:study_mate_frontend/features/auth/models/user_model.dart';
import 'package:study_mate_frontend/features/auth/repositories/auth_repository.dart';

class FakeSecureStorageService extends Fake implements SecureStorageService {
  final Map<String, dynamic> memory = {};

  @override
  Future<void> saveToken(String token) async {
    memory['token'] = token;
  }

  @override
  Future<String?> getToken() async => memory['token'] as String?;

  @override
  Future<void> saveRefreshToken(String token) async {
    memory['refreshToken'] = token;
  }

  @override
  Future<String?> getRefreshToken() async => memory['refreshToken'] as String?;

  @override
  Future<void> saveUser(Map<String, dynamic> userJson) async {
    memory['user'] = userJson;
  }

  @override
  Future<Map<String, dynamic>?> getUser() async =>
      memory['user'] as Map<String, dynamic>?;

  @override
  Future<void> clearSession() async {
    memory.clear();
  }

  @override
  Future<bool> hasToken() async =>
      memory.containsKey('token') && memory['token'] != null;
}

class FakeApiClient extends Fake implements ApiClient {
  final Map<String, dynamic> responses = {};
  final Map<String, ApiException> errors = {};

  @override
  Future<dynamic> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (errors.containsKey(path)) {
      throw errors[path]!;
    }
    return responses[path];
  }

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (errors.containsKey(path)) {
      throw errors[path]!;
    }
    return responses[path];
  }

  @override
  Future<dynamic> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (errors.containsKey(path)) {
      throw errors[path]!;
    }
    return responses[path];
  }
}

void main() {
  group('AuthRepository Unit Tests (Phase 2)', () {
    late FakeApiClient apiClient;
    late FakeSecureStorageService storageService;
    late AuthRepository authRepository;

    final testUserJson = {
      'id': 'usr-123',
      'email': 'student@example.com',
      'displayName': 'Alex Learner',
      'role': 'STUDENT',
      'createdAt': '2026-10-12T10:00:00Z',
    };

    final testSessionJson = {
      'token': 'jwt-access-token-12345',
      'user': testUserJson,
    };

    setUp(() {
      apiClient = FakeApiClient();
      storageService = FakeSecureStorageService();
      authRepository = AuthRepository(
        apiClient: apiClient,
        storageService: storageService,
      );
    });

    test(
      'login stores token and user in secure storage upon success',
      () async {
        apiClient.responses['/auth/session'] = testSessionJson;

        final session = await authRepository.login(
          email: 'student@example.com',
          password: 'Password123!',
        );

        expect(session.token, 'jwt-access-token-12345');
        expect(session.user.email, 'student@example.com');
        expect(await storageService.getToken(), 'jwt-access-token-12345');
        expect((await storageService.getUser())?['id'], 'usr-123');
      },
    );

    test('register stores session and persists token', () async {
      apiClient.responses['/auth/register'] = testSessionJson;

      final session = await authRepository.register(
        email: 'student@example.com',
        password: 'Password123!',
        displayName: 'Alex Learner',
      );

      expect(session.token, 'jwt-access-token-12345');
      expect(session.user.displayName, 'Alex Learner');
      expect(await storageService.hasToken(), isTrue);
    });

    test('getMe retrieves profile and refreshes cached user', () async {
      apiClient.responses['/me'] = testUserJson;

      final user = await authRepository.getMe();

      expect(user.id, 'usr-123');
      expect(user.email, 'student@example.com');
      expect(await storageService.getUser(), isNotNull);
    });

    test('logout clears secure storage credentials', () async {
      await storageService.saveToken('existing-token');
      await storageService.saveUser(testUserJson);

      await authRepository.logout();

      expect(await storageService.hasToken(), isFalse);
      expect(await storageService.getUser(), isNull);
    });

    test('deleteAccount calls backend DELETE /me and clears session', () async {
      await storageService.saveToken('token-to-delete');
      apiClient.responses['/me'] = {'deleted': true};

      await authRepository.deleteAccount();

      expect(await storageService.hasToken(), isFalse);
    });

    test('forgotPassword throws ENDPOINT_UNAVAILABLE on 404', () async {
      apiClient.errors['/auth/forgot-password'] = const ApiException(
        code: 'RESOURCE_NOT_FOUND',
        statusCode: 404,
        message: 'Cannot POST /api/v1/auth/forgot-password',
      );

      expect(
        () => authRepository.forgotPassword(email: 'student@example.com'),
        throwsA(
          predicate(
            (e) =>
                e is ApiException &&
                e.code == 'ENDPOINT_UNAVAILABLE' &&
                e.statusCode == 404,
          ),
        ),
      );
    });

    test('resetPassword throws ENDPOINT_UNAVAILABLE on 404', () async {
      apiClient.errors['/auth/reset-password'] = const ApiException(
        code: 'RESOURCE_NOT_FOUND',
        statusCode: 404,
        message: 'Cannot POST /api/v1/auth/reset-password',
      );

      expect(
        () => authRepository.resetPassword(
          token: 'token-abc',
          newPassword: 'NewPassword123!',
        ),
        throwsA(
          predicate(
            (e) =>
                e is ApiException &&
                e.code == 'ENDPOINT_UNAVAILABLE' &&
                e.statusCode == 404,
          ),
        ),
      );
    });
  });

  group('AuthController Unit Tests (Phase 2)', () {
    late FakeApiClient apiClient;
    late FakeSecureStorageService storageService;
    late AuthRepository authRepository;

    final testUser = UserModel(
      id: 'usr-999',
      email: 'test@example.com',
      displayName: 'Test User',
      createdAt: DateTime.now(),
    );

    setUp(() {
      apiClient = FakeApiClient();
      storageService = FakeSecureStorageService();
      authRepository = AuthRepository(
        apiClient: apiClient,
        storageService: storageService,
      );
    });

    test(
      'Initializes with Unauthenticated when storage has no token',
      () async {
        final element = ProviderContainer(
          overrides: [authRepositoryProvider.overrideWithValue(authRepository)],
        );

        final state = element.read(authControllerProvider);
        expect(state, isA<AuthInitial>());

        // Wait for async initialization
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(element.read(authControllerProvider), isA<Unauthenticated>());
        element.dispose();
      },
    );

    test('Restores session when token and user profile exist', () async {
      await storageService.saveToken('valid-jwt-token');
      await storageService.saveUser(testUser.toJson());
      apiClient.responses['/me'] = testUser.toJson();

      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(authRepository)],
      );

      // Trigger initialization
      container.read(authControllerProvider);

      // Wait for session check
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final state = container.read(authControllerProvider);
      expect(state, isA<Authenticated>());
      expect((state as Authenticated).user.email, 'test@example.com');
      container.dispose();
    });

    test('Clears session on 401 AUTH_REQUIRED during restoration', () async {
      await storageService.saveToken('expired-jwt-token');
      apiClient.errors['/me'] = const ApiException(
        code: 'AUTH_REQUIRED',
        statusCode: 401,
        message: 'Token expired',
      );

      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(authRepository)],
      );

      // Trigger initialization
      container.read(authControllerProvider);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final state = container.read(authControllerProvider);
      expect(state, isA<Unauthenticated>());
      expect(await storageService.hasToken(), isFalse);
      container.dispose();
    });

    test('login transitions to Authenticated on valid credentials', () async {
      apiClient.responses['/auth/session'] = {
        'token': 'new-jwt-token',
        'user': testUser.toJson(),
      };

      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(authRepository)],
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));
      final controller = container.read(authControllerProvider.notifier);
      final result = await controller.login(
        'test@example.com',
        'ValidPass123!',
      );

      expect(result, isTrue);
      final state = container.read(authControllerProvider);
      expect(state, isA<Authenticated>());
      expect((state as Authenticated).user.email, 'test@example.com');
      container.dispose();
    });

    test('login transitions to AuthError on invalid credentials', () async {
      apiClient.errors['/auth/session'] = const ApiException(
        code: 'AUTH_FAILED',
        statusCode: 401,
        message: 'Invalid email or password',
      );

      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(authRepository)],
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));
      final controller = container.read(authControllerProvider.notifier);
      final result = await controller.login('test@example.com', 'WrongPass!');

      expect(result, isFalse);
      final state = container.read(authControllerProvider);
      expect(state, isA<AuthError>());
      expect((state as AuthError).message, 'Invalid email or password');
      container.dispose();
    });

    test('logout transitions state to Unauthenticated', () async {
      apiClient.responses['/auth/session'] = {
        'token': 'new-jwt-token',
        'user': testUser.toJson(),
      };

      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(authRepository)],
      );

      final controller = container.read(authControllerProvider.notifier);
      await controller.login('test@example.com', 'ValidPass123!');
      expect(container.read(authControllerProvider), isA<Authenticated>());

      await controller.logout();
      expect(container.read(authControllerProvider), isA<Unauthenticated>());
      expect(await storageService.hasToken(), isFalse);
      container.dispose();
    });

    test('clearError resets AuthError back to Unauthenticated', () async {
      apiClient.errors['/auth/session'] = const ApiException(
        code: 'VALIDATION_ERROR',
        message: 'Password required',
      );

      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(authRepository)],
      );

      final controller = container.read(authControllerProvider.notifier);
      await controller.login('test@example.com', '');
      expect(container.read(authControllerProvider), isA<AuthError>());

      controller.clearError();
      expect(container.read(authControllerProvider), isA<Unauthenticated>());
      container.dispose();
    });
  });
}
