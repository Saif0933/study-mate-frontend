import '../../../core/network/api_client.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../models/auth_session.dart';
import '../models/user_model.dart';

class AuthRepository {
  final ApiClient apiClient;
  final SecureStorageService storageService;

  AuthRepository({required this.apiClient, required this.storageService});

  /// Register a new account
  Future<AuthSession> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final response = await apiClient.post(
      '/auth/register',
      data: {
        'email': email,
        'password': password,
        if (displayName != null && displayName.isNotEmpty)
          'displayName': displayName,
      },
    );

    final session = AuthSession.fromJson(response as Map<String, dynamic>);
    await storageService.saveToken(session.token);
    await storageService.saveUser(session.user.toJson());
    return session;
  }

  /// Sign in with credentials
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await apiClient.post(
      '/auth/session',
      data: {'email': email, 'password': password},
    );

    final session = AuthSession.fromJson(response as Map<String, dynamic>);
    await storageService.saveToken(session.token);
    await storageService.saveUser(session.user.toJson());
    return session;
  }

  /// Request a password reset token/link for an email.
  /// If the backend does not provide this endpoint, throws a clear typed ApiException.
  Future<String> forgotPassword({required String email}) async {
    try {
      final response = await apiClient.post(
        '/auth/forgot-password',
        data: {'email': email},
      );
      if (response is Map<String, dynamic> && response['message'] is String) {
        return response['message'] as String;
      }
      return 'Password reset instructions have been sent to your email address.';
    } on ApiException catch (e) {
      if (e.statusCode == 404 || e.code == 'RESOURCE_NOT_FOUND') {
        throw const ApiException(
          code: 'ENDPOINT_UNAVAILABLE',
          statusCode: 404,
          message:
              'Password reset is not yet supported by the server API (POST /api/v1/auth/forgot-password).',
        );
      }
      rethrow;
    }
  }

  /// Reset account password using token and new password.
  /// If the backend does not provide this endpoint, throws a clear typed ApiException.
  Future<String> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      final response = await apiClient.post(
        '/auth/reset-password',
        data: {'token': token, 'password': newPassword},
      );
      if (response is Map<String, dynamic> && response['message'] is String) {
        return response['message'] as String;
      }
      return 'Your password has been successfully reset. Please sign in with your new password.';
    } on ApiException catch (e) {
      if (e.statusCode == 404 || e.code == 'RESOURCE_NOT_FOUND') {
        throw const ApiException(
          code: 'ENDPOINT_UNAVAILABLE',
          statusCode: 404,
          message:
              'Password reset is not yet supported by the server API (POST /api/v1/auth/reset-password).',
        );
      }
      rethrow;
    }
  }

  /// Get current authenticated user profile
  Future<UserModel> getMe() async {
    final response = await apiClient.get('/me');
    final user = UserModel.fromJson(response as Map<String, dynamic>);
    await storageService.saveUser(user.toJson());
    return user;
  }

  /// Delete current user account and all personal data
  Future<void> deleteAccount() async {
    await apiClient.delete('/me');
    await storageService.clearSession();
  }

  /// Update current user profile (e.g. displayName)
  Future<UserModel> updateProfile({required String displayName}) async {
    final response = await apiClient.patch(
      '/me',
      data: {'displayName': displayName.trim()},
    );
    final user = UserModel.fromJson(response as Map<String, dynamic>);
    await storageService.saveUser(user.toJson());
    return user;
  }

  /// Logout and clear saved tokens
  Future<void> logout() async {
    try {
      await apiClient.post('/auth/logout');
    } catch (_) {
      // Best effort backend notification; always purge local tokens
    } finally {
      await storageService.clearSession();
    }
  }

  /// Check if session exists in secure storage
  Future<UserModel?> getCachedUser() async {
    final json = await storageService.getUser();
    if (json != null) {
      return UserModel.fromJson(json);
    }
    return null;
  }

  Future<bool> hasSavedToken() async {
    return await storageService.hasToken();
  }
}
