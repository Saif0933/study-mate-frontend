import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_mate_frontend/core/network/api_client.dart';
import 'package:study_mate_frontend/core/network/api_exceptions.dart';
import 'package:study_mate_frontend/core/storage/secure_storage_service.dart';
import 'package:study_mate_frontend/features/auth/controllers/auth_controller.dart';
import 'package:study_mate_frontend/features/auth/models/user_model.dart';
import 'package:study_mate_frontend/features/auth/repositories/auth_repository.dart';
import 'package:study_mate_frontend/features/settings/models/feedback_model.dart';
import 'package:study_mate_frontend/features/settings/models/usage_model.dart';
import 'package:study_mate_frontend/features/settings/repositories/feedback_repository.dart';
import 'package:study_mate_frontend/features/settings/repositories/usage_repository.dart';

class FakeSecureStorageService extends Fake implements SecureStorageService {
  final Map<String, dynamic> memory = {};

  @override
  Future<void> saveToken(String token) async {
    memory['token'] = token;
  }

  @override
  Future<String?> getToken() async => memory['token'] as String?;

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
  final List<({String method, String path, dynamic data})> requests = [];

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    requests.add((method: 'GET', path: path, data: queryParameters));
    if (errors.containsKey(path)) {
      throw errors[path]!;
    }
    return responses[path];
  }

  @override
  Future<dynamic> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    requests.add((method: 'POST', path: path, data: data));
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
    requests.add((method: 'DELETE', path: path, data: data));
    if (errors.containsKey(path)) {
      throw errors[path]!;
    }
    return responses[path];
  }
}

void main() {
  group('UsageModel Tests', () {
    test('parses flat usage JSON correctly', () {
      final json = {
        'totalTokens': 1500,
        'requestCount': 25,
        'estimatedCost': 0.045,
        'featureBreakdown': {'TUTOR_CHAT': 15, 'DOCUMENT_QA': 10},
      };

      final usage = UsageModel.fromJson(json);

      expect(usage.totalTokens, 1500);
      expect(usage.requestCount, 25);
      expect(usage.estimatedCost, 0.045);
      expect(usage.featureBreakdown['TUTOR_CHAT'], 15);
      expect(usage.featureBreakdown['DOCUMENT_QA'], 10);
      expect(usage.quotaLimit, isNull);
      expect(usage.requestsRemaining, isNull);
      expect(usage.isExhausted, isFalse);
      expect(usage.quotaMessage, isNull);
      expect(usage.resetTime, isNull);
    });

    test('parses nested quota details and exhaustion status', () {
      final json = {
        'totalTokens': 50000,
        'requestCount': 100,
        'estimatedCost': 1.25,
        'quota': {
          'limit': 100,
          'remaining': 0,
          'isExhausted': true,
          'message': 'Daily AI token limit reached. Resets at midnight UTC.',
          'resetTime': '2026-10-14T00:00:00.000Z',
        },
      };

      final usage = UsageModel.fromJson(json);

      expect(usage.quotaLimit, 100);
      expect(usage.requestsRemaining, 0);
      expect(usage.isExhausted, isTrue);
      expect(usage.quotaMessage, contains('Daily AI token limit reached'));
      expect(usage.resetTime, isNotNull);
      expect(usage.resetTime!.year, 2026);
    });

    test('detects exhaustion when requestCount reaches quotaLimit', () {
      final json = {
        'totalTokens': 10000,
        'requestCount': 50,
        'quotaLimit': 50,
        'requestsRemaining': 0,
      };

      final usage = UsageModel.fromJson(json);
      expect(usage.isExhausted, isTrue);
    });

    test('never invents costs or reset times when absent', () {
      final json = <String, dynamic>{};
      final usage = UsageModel.fromJson(json);

      expect(usage.totalTokens, 0);
      expect(usage.requestCount, 0);
      expect(usage.estimatedCost, 0.0);
      expect(usage.quotaLimit, isNull);
      expect(usage.resetTime, isNull);
      expect(usage.quotaMessage, isNull);
    });

    test('serializes to JSON correctly', () {
      final usage = UsageModel(
        totalTokens: 200,
        requestCount: 5,
        estimatedCost: 0.01,
        quotaLimit: 20,
        requestsRemaining: 15,
        isExhausted: false,
        quotaMessage: 'Standard quota active',
        resetTime: DateTime.parse('2026-10-15T12:00:00.000Z'),
      );

      final json = usage.toJson();
      expect(json['totalTokens'], 200);
      expect(json['requestCount'], 5);
      expect(json['quotaLimit'], 20);
      expect(json['requestsRemaining'], 15);
      expect(json['isExhausted'], isFalse);
      expect(json['quotaMessage'], 'Standard quota active');
      expect(json['resetTime'], '2026-10-15T12:00:00.000Z');
    });
  });

  group('FeedbackModel Tests', () {
    test('parses from JSON correctly', () {
      final json = {
        'id': 'fb-123',
        'rating': 'POSITIVE',
        'category': 'HELPFULNESS',
        'comment': 'The tutor gave a very clear summary of thermodynamics.',
        'messageId': 'msg-999',
        'createdAt': '2026-10-13T10:00:00.000Z',
      };

      final feedback = FeedbackModel.fromJson(json);

      expect(feedback.id, 'fb-123');
      expect(feedback.rating, 'POSITIVE');
      expect(feedback.category, 'HELPFULNESS');
      expect(feedback.comment, contains('thermodynamics'));
      expect(feedback.messageId, 'msg-999');
      expect(feedback.createdAt, isNotNull);
    });

    test('serializes to JSON accurately', () {
      final feedback = const FeedbackModel(
        rating: 'NEGATIVE',
        category: 'ACCURACY',
        comment: 'Incorrect formula on page 3.',
      );

      final json = feedback.toJson();
      expect(json['rating'], 'NEGATIVE');
      expect(json['category'], 'ACCURACY');
      expect(json['comment'], 'Incorrect formula on page 3.');
      expect(json.containsKey('messageId'), isFalse);
    });
  });

  group('UsageRepository Tests', () {
    late FakeApiClient apiClient;
    late UsageRepository repository;

    setUp(() {
      apiClient = FakeApiClient();
      repository = UsageRepository(apiClient: apiClient);
    });

    test('getUsage calls GET /usage and parses response', () async {
      apiClient.responses['/usage'] = {
        'totalTokens': 3450,
        'requestCount': 12,
        'estimatedCost': 0.025,
        'featureBreakdown': {'TUTOR_CHAT': 12},
      };

      final result = await repository.getUsage();

      expect(result.totalTokens, 3450);
      expect(result.requestCount, 12);
      expect(apiClient.requests.first.path, '/usage');
      expect(apiClient.requests.first.method, 'GET');
    });

    test('getUsage returns empty model on non-map response', () async {
      apiClient.responses['/usage'] = null;

      final result = await repository.getUsage();
      expect(result.totalTokens, 0);
      expect(result.requestCount, 0);
    });
  });

  group('FeedbackRepository Tests', () {
    late FakeApiClient apiClient;
    late FeedbackRepository repository;

    setUp(() {
      apiClient = FakeApiClient();
      repository = FeedbackRepository(apiClient: apiClient);
    });

    test('submitFeedback calls POST /feedback with correct payload', () async {
      apiClient.responses['/feedback'] = {
        'id': 'fb-success-1',
        'rating': 'POSITIVE',
        'category': 'HELPFULNESS',
        'comment': 'Great explanations!',
        'createdAt': '2026-10-13T12:00:00.000Z',
      };

      final result = await repository.submitFeedback(
        rating: 'POSITIVE',
        category: 'HELPFULNESS',
        comment: 'Great explanations!',
      );

      expect(result.id, 'fb-success-1');
      expect(result.rating, 'POSITIVE');
      expect(apiClient.requests.first.path, '/feedback');
      expect(apiClient.requests.first.method, 'POST');
      final data = apiClient.requests.first.data as Map<String, dynamic>;
      expect(data['rating'], 'POSITIVE');
      expect(data['category'], 'HELPFULNESS');
      expect(data['comment'], 'Great explanations!');
    });
  });

  group('AuthController Deletion Failure Rollback Tests', () {
    late FakeApiClient apiClient;
    late FakeSecureStorageService storageService;
    late AuthRepository authRepository;

    final testUser = const UserModel(
      id: 'usr-1',
      email: 'student@example.com',
      displayName: 'Alice Learner',
      status: 'ACTIVE',
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
      'deleteAccount on success clears storage and sets Unauthenticated',
      () async {
        await storageService.saveToken('token-alice');
        await storageService.saveUser(testUser.toJson());
        apiClient.responses['/me'] = {'deleted': true};

        final container = ProviderContainer(
          overrides: [authRepositoryProvider.overrideWithValue(authRepository)],
        );

        final controller = container.read(authControllerProvider.notifier);
        // Log in Alice
        apiClient.responses['/auth/session'] = {
          'token': 'token-alice',
          'user': testUser.toJson(),
        };
        await controller.login('student@example.com', 'Pass123!');
        expect(container.read(authControllerProvider), isA<Authenticated>());

        final result = await controller.deleteAccount();

        expect(result.success, isTrue);
        expect(result.error, isNull);
        expect(container.read(authControllerProvider), isA<Unauthenticated>());
        expect(await storageService.hasToken(), isFalse);
        container.dispose();
      },
    );

    test(
      'deleteAccount on failure restores Authenticated state and does NOT log user out',
      () async {
        await storageService.saveToken('token-alice');
        await storageService.saveUser(testUser.toJson());

        // Simulate server error during DELETE /me
        apiClient.errors['/me'] = const ApiException(
          code: 'INTERNAL_SERVER_ERROR',
          statusCode: 500,
          message: 'Database error: unable to delete user cascades.',
        );

        final container = ProviderContainer(
          overrides: [authRepositoryProvider.overrideWithValue(authRepository)],
        );

        final controller = container.read(authControllerProvider.notifier);
        apiClient.responses['/auth/session'] = {
          'token': 'token-alice',
          'user': testUser.toJson(),
        };
        await controller.login('student@example.com', 'Pass123!');
        expect(container.read(authControllerProvider), isA<Authenticated>());

        final result = await controller.deleteAccount();

        // Deletion failed
        expect(result.success, isFalse);
        expect(result.error, contains('Database error'));

        // CRITICAL: User is NOT set to AuthError or Unauthenticated (which would falsely bounce to LoginScreen)
        final state = container.read(authControllerProvider);
        expect(state, isA<Authenticated>());
        expect((state as Authenticated).user.email, 'student@example.com');

        // Local tokens were NOT cleared because deletion failed on server
        expect(await storageService.hasToken(), isTrue);

        container.dispose();
      },
    );
  });
}
