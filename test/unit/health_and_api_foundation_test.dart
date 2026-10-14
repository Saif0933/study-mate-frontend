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
  group('AppConfig & Environment Resolution Tests', () {
    tearDown(() {
      AppConfig.setBaseUrlOverride(null);
    });

    test('resolves default apiBaseUrl with /api/v1 suffix', () {
      final url = AppConfig.apiBaseUrl;
      expect(url, isNotEmpty);
      expect(url, endsWith('/api/v1'));
      expect(url, startsWith('http'));
    });

    test('respects runtime override via setBaseUrlOverride', () {
      AppConfig.setBaseUrlOverride('http://192.168.1.150:5000/api/v1');
      expect(AppConfig.apiBaseUrl, equals('http://192.168.1.150:5000/api/v1'));

      AppConfig.setBaseUrlOverride('https://api.studymate.ai/api/v1');
      expect(AppConfig.apiBaseUrl, equals('https://api.studymate.ai/api/v1'));

      AppConfig.setBaseUrlOverride(null);
      expect(AppConfig.apiBaseUrl, endsWith('/api/v1'));
    });
  });

  group('HealthStatusModel Tests', () {
    test('parses healthy backend response correctly', () {
      final json = {
        'status': 'ok',
        'timestamp': '2026-10-14T10:00:00.000Z',
        'uptimeSeconds': 3600,
        'environment': 'development',
        'services': {
          'database': {
            'status': 'connected',
            'latencyMs': 12,
          },
        },
      };

      final model = HealthStatusModel.fromJson(json);

      expect(model.status, equals('ok'));
      expect(model.uptimeSeconds, equals(3600));
      expect(model.environment, equals('development'));
      expect(model.databaseStatus, equals('connected'));
      expect(model.databaseLatencyMs, equals(12));
      expect(model.isHealthy, isTrue);
    });

    test('marks isHealthy as false when database is disconnected', () {
      final json = {
        'status': 'degraded',
        'timestamp': '2026-10-14T10:00:00.000Z',
        'uptimeSeconds': 100,
        'environment': 'development',
        'services': {
          'database': {
            'status': 'disconnected',
          },
        },
      };

      final model = HealthStatusModel.fromJson(json);
      expect(model.isHealthy, isFalse);
      expect(model.status, equals('degraded'));
    });
  });

  group('HealthRepository Tests', () {
    late ApiClient apiClient;
    late MockSecureStorageService storage;
    late Dio dio;

    setUp(() {
      storage = MockSecureStorageService();
      dio = Dio(BaseOptions(baseUrl: 'http://localhost:5000/api/v1'));
      apiClient = ApiClient(storageService: storage, customDio: dio);
    });

    test('checkHealth returns HealthStatusModel on successful backend response', () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('/health')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'status': 'ok',
                    'timestamp': '2026-10-14T10:00:00.000Z',
                    'uptimeSeconds': 120,
                    'environment': 'development',
                    'services': {
                      'database': {
                        'status': 'connected',
                        'latencyMs': 5,
                      },
                    },
                  },
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      final repo = HealthRepository(apiClient);
      final health = await repo.checkHealth();

      expect(health.isHealthy, isTrue);
      expect(health.databaseStatus, equals('connected'));

      final isReachable = await repo.isBackendReachable();
      expect(isReachable, isTrue);
    });

    test('isBackendReachable returns false on connection error', () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
                error: 'Connection refused',
              ),
            );
          },
        ),
      );

      final repo = HealthRepository(apiClient);
      final isReachable = await repo.isBackendReachable();
      expect(isReachable, isFalse);
    });
  });

  group('Dio Error Handling & Resilience Tests', () {
    late ApiClient apiClient;
    late MockSecureStorageService storage;
    late Dio dio;

    setUp(() {
      storage = MockSecureStorageService();
      dio = Dio(BaseOptions(baseUrl: 'http://localhost:5000/api/v1'));
      apiClient = ApiClient(storageService: storage, customDio: dio);
    });

    test('maps connectionError to CONNECTION_REFUSED with actionable troubleshooting guidance', () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
                message: 'Connection refused',
              ),
            );
          },
        ),
      );

      try {
        await apiClient.get('/test-route');
        fail('Should have thrown ApiException');
      } on ApiException catch (e) {
        expect(e.code, equals('CONNECTION_REFUSED'));
        expect(e.message, contains('Unable to connect to the backend server'));
        expect(e.isRetryable, isTrue);
      }
    });

    test('maps timeout to TIMEOUT_ERROR', () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.receiveTimeout,
                message: 'Receive timeout',
              ),
            );
          },
        ),
      );

      try {
        await apiClient.get('/test-route');
        fail('Should have thrown ApiException');
      } on ApiException catch (e) {
        expect(e.code, equals('TIMEOUT_ERROR'));
        expect(e.isRetryable, isTrue);
      }
    });

    test('maps FormatException to INVALID_JSON', () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.unknown,
                error: const FormatException('Unexpected character at line 1'),
              ),
            );
          },
        ),
      );

      try {
        await apiClient.get('/test-route');
        fail('Should have thrown ApiException');
      } on ApiException catch (e) {
        expect(e.code, equals('INVALID_JSON'));
      }
    });

    test('parses backend PRD error envelope on 400 Bad Request', () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response(
                  requestOptions: options,
                  statusCode: 400,
                  data: {
                    'error': {
                      'code': 'VALIDATION_ERROR',
                      'message': 'Invalid email address provided',
                      'requestId': 'req-val-123',
                    },
                  },
                ),
              ),
            );
          },
        ),
      );

      try {
        await apiClient.get('/test-route');
        fail('Should have thrown ApiException');
      } on ApiException catch (e) {
        expect(e.code, equals('VALIDATION_ERROR'));
        expect(e.message, equals('Invalid email address provided'));
        expect(e.requestId, equals('req-val-123'));
        expect(e.statusCode, equals(400));
      }
    });
  });
}
