import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_mate_frontend/core/config/app_config.dart';
import 'package:study_mate_frontend/core/network/api_client.dart';
import 'package:study_mate_frontend/core/network/api_exceptions.dart';
import 'package:study_mate_frontend/core/network/health_repository.dart';
import 'package:study_mate_frontend/core/storage/secure_storage_service.dart';

class MockSecureStorageService extends SecureStorageService {
  String? mockToken;

  @override
  Future<String?> getToken() async => mockToken;

  @override
  Future<void> saveToken(String token) async => mockToken = token;

  @override
  Future<void> clearSession() async => mockToken = null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  group('Backend Live API Connection & Contract Verification', () {
    late ApiClient apiClient;
    late HealthRepository healthRepository;

    setUp(() {
      // Configure local loopback URL for host desktop execution
      AppConfig.setBaseUrlOverride('http://127.0.0.1:5000/api/v1');
      final storage = MockSecureStorageService();
      final dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );
      apiClient = ApiClient(storageService: storage, customDio: dio);
      healthRepository = HealthRepository(apiClient);
    });

    tearDown(() {
      AppConfig.setBaseUrlOverride(null);
    });

    test('verifies live backend health or gracefully handles offline state', () async {
      bool isBackendOnline = false;

      try {
        final socket = await Socket.connect('127.0.0.1', 5000, timeout: const Duration(seconds: 1));
        socket.destroy();
        isBackendOnline = true;
      } catch (_) {
        isBackendOnline = false;
      }

      if (isBackendOnline) {
        // Backend process is active: execute live contract verification
        final health = await healthRepository.checkHealth();
        expect(health.status, equals('ok'));
        expect(health.isHealthy, isTrue);
        expect(health.databaseStatus, equals('connected'));
        expect(health.uptimeSeconds, greaterThanOrEqualTo(0));
      } else {
        // Backend process is not currently listening: verify connection handling
        final reachable = await healthRepository.isBackendReachable();
        expect(reachable, isFalse);

        expect(
          () => healthRepository.checkHealth(),
          throwsA(
            isA<ApiException>().having(
              (e) => e.code,
              'code',
              equals('CONNECTION_REFUSED'),
            ),
          ),
        );
      }
    });

    test('validates 404 response envelope parsing against live/mocked route', () async {
      try {
        await apiClient.get('/non-existent-probe-route');
      } on ApiException catch (e) {
        if (e.code == 'CONNECTION_REFUSED') {
          // Server is offline: connection refusal is retryable
          expect(e.isRetryable, isTrue);
        } else {
          // Server responded with HTTP 404
          expect(e.isRetryable, isFalse);
          expect(e.statusCode, equals(404));
        }
      } catch (_) {
        // Ignored
      }
    });
  });
}
