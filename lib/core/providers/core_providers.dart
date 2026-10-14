import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../network/api_client.dart';
import '../network/auth_interceptor.dart';
import '../storage/secure_storage_service.dart';

import '../network/health_repository.dart';

/// Provider for secure credential storage
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

/// Reusable Provider for configured Dio instance
final dioProvider = Provider<Dio>((ref) {
  final storage = ref.watch(secureStorageProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      sendTimeout: AppConfig.sendTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.add(
    AuthInterceptor(
      storageService: storage,
      onUnauthorized: () {
        // Handled via auth state controller / routing
      },
    ),
  );

  return dio;
});

/// Provider for central ApiClient dependency injection
final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  final dio = ref.watch(dioProvider);
  return ApiClient(storageService: storage, customDio: dio);
});

/// Provider for HealthRepository
final healthRepositoryProvider = Provider<HealthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return HealthRepository(apiClient);
});

/// Provider for asynchronous backend health state
final backendHealthProvider = FutureProvider<HealthStatusModel>((ref) async {
  final repo = ref.watch(healthRepositoryProvider);
  return repo.checkHealth();
});
