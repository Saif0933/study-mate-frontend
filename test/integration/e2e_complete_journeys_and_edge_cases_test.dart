import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_mate_frontend/core/network/api_client.dart';
import 'package:study_mate_frontend/core/network/api_exceptions.dart';
import 'package:study_mate_frontend/core/providers/core_providers.dart';
import 'package:study_mate_frontend/core/storage/secure_storage_service.dart';
import 'package:study_mate_frontend/features/auth/controllers/auth_controller.dart';
import 'package:study_mate_frontend/features/documents/controllers/document_list_controller.dart';
import 'package:study_mate_frontend/features/quizzes/controllers/quiz_controller.dart';
import 'package:study_mate_frontend/features/settings/repositories/feedback_repository.dart';
import 'package:study_mate_frontend/features/settings/repositories/usage_repository.dart';
import 'package:study_mate_frontend/features/study_plans/controllers/study_plan_controller.dart';
import 'package:study_mate_frontend/features/tutor/controllers/conversation_list_controller.dart';

class MockMemoryStorage extends Fake implements SecureStorageService {
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

class MockBackendApiClient extends Fake implements ApiClient {
  final Map<String, dynamic> responses = {};
  final Map<String, ApiException> errors = {};
  final List<({String method, String path, dynamic data})> callLog = [];

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    callLog.add((method: 'GET', path: path, data: queryParameters));
    if (errors.containsKey(path)) throw errors[path]!;
    return responses[path];
  }

  @override
  Future<dynamic> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    callLog.add((method: 'POST', path: path, data: data));
    if (errors.containsKey(path)) throw errors[path]!;
    return responses[path];
  }

  @override
  Future<dynamic> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    callLog.add((method: 'PATCH', path: path, data: data));
    if (errors.containsKey(path)) throw errors[path]!;
    return responses[path];
  }

  @override
  Future<dynamic> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    callLog.add((method: 'DELETE', path: path, data: data));
    if (errors.containsKey(path)) throw errors[path]!;
    return responses[path];
  }
}

void main() {
  group('Phase 8: End-to-End Integration & Complete Journeys', () {
    late MockMemoryStorage storage;
    late MockBackendApiClient apiClient;
    late ProviderContainer container;

    setUp(() {
      storage = MockMemoryStorage();
      apiClient = MockBackendApiClient();

      container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(storage),
          apiClientProvider.overrideWithValue(apiClient),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    // =========================================================================
    // JOURNEY 1: Authentication, Registration, Session Restoration & Sign Out
    // =========================================================================
    test(
      'Journey 1: Register, authenticate, restore session from cache, and log out',
      () async {
        final authRepo = container.read(authRepositoryProvider);

        // 1. Register new user
        apiClient.responses['/auth/register'] = {
          'token': 'jwt-alice-session-token',
          'user': {
            'id': 'usr-alice-1',
            'email': 'alice@example.com',
            'displayName': 'Alice Smith',
            'status': 'ACTIVE',
          },
        };

        final registeredSession = await authRepo.register(
          email: 'alice@example.com',
          password: 'Password123!',
          displayName: 'Alice Smith',
        );

        expect(registeredSession.token, 'jwt-alice-session-token');
        expect(registeredSession.user.displayName, 'Alice Smith');
        expect(await storage.hasToken(), isTrue);

        // 2. App relaunch: restore user session from local secure cache
        final cachedUser = await authRepo.getCachedUser();
        expect(cachedUser, isNotNull);
        expect(cachedUser!.email, 'alice@example.com');

        // 3. Re-verify with GET /me
        apiClient.responses['/me'] = {
          'id': 'usr-alice-1',
          'email': 'alice@example.com',
          'displayName': 'Alice Smith',
          'status': 'ACTIVE',
        };
        final meUser = await authRepo.getMe();
        expect(meUser.id, 'usr-alice-1');

        // 4. Log out and clear all secure storage
        await authRepo.logout();
        expect(await storage.hasToken(), isFalse);
        expect(await storage.getUser(), isNull);
      },
    );

    // =========================================================================
    // JOURNEY 2: AI Tutor Chat & Conversation Management
    // =========================================================================
    test(
      'Journey 2: Create conversation, send messages, and fetch message history',
      () async {
        final tutorRepo = container.read(tutorRepositoryProvider);

        // 1. Create a new conversation
        apiClient.responses['/conversations'] = {
          'id': 'conv-physics-101',
          'title': 'Thermodynamics Review',
          'createdAt': '2026-10-13T10:00:00.000Z',
          'updatedAt': '2026-10-13T10:00:00.000Z',
        };

        final conversation = await tutorRepo.createConversation(
          title: 'Thermodynamics Review',
        );
        expect(conversation.id, 'conv-physics-101');

        // 2. Send tutor message
        apiClient.responses['/conversations/conv-physics-101/messages'] = {
          'id': 'msg-assistant-1',
          'conversationId': 'conv-physics-101',
          'role': 'ASSISTANT',
          'content':
              'The Second Law of Thermodynamics states that the total entropy of an isolated system always increases over time.',
          'inputTokens': 45,
          'outputTokens': 30,
          'createdAt': '2026-10-13T10:01:00.000Z',
        };

        final message = await tutorRepo.sendMessage(
          conversationId: 'conv-physics-101',
          content: 'Explain the Second Law of Thermodynamics',
        );

        expect(message.isAssistant, isTrue);
        expect(message.content, contains('Second Law of Thermodynamics'));
        expect(message.inputTokens, 45);

        // 3. Fetch conversation messages
        apiClient.responses['/conversations/conv-physics-101/messages'] = [
          {
            'id': 'msg-user-1',
            'conversationId': 'conv-physics-101',
            'role': 'user',
            'content': 'Explain the Second Law of Thermodynamics',
            'createdAt': '2026-10-13T10:00:30.000Z',
          },
          {
            'id': 'msg-assistant-1',
            'conversationId': 'conv-physics-101',
            'role': 'assistant',
            'content': 'The Second Law of Thermodynamics...',
            'createdAt': '2026-10-13T10:01:00.000Z',
          },
        ];

        final messages = await tutorRepo.getMessages('conv-physics-101');
        expect(messages.length, 2);
        expect(messages.first.isUser, isTrue);
        expect(messages.last.isAssistant, isTrue);
      },
    );

    // =========================================================================
    // JOURNEY 3: PDF Document Library, Processing States & Document QA
    // =========================================================================
    test(
      'Journey 3: Track document lifecycle, ask question with citations, and delete document',
      () async {
        final docRepo = container.read(documentRepositoryProvider);

        // 1. Fetch document list with various statuses
        apiClient.responses['/documents'] = [
          {
            'id': 'doc-quantum-notes',
            'originalName': 'quantum_mechanics.pdf',
            'mimeType': 'application/pdf',
            'sizeBytes': 2048576,
            'status': 'READY',
            'pageCount': 18,
            'createdAt': '2026-10-13T09:00:00.000Z',
          },
          {
            'id': 'doc-chem-notes',
            'originalName': 'organic_chem.pdf',
            'mimeType': 'application/pdf',
            'sizeBytes': 1024000,
            'status': 'PROCESSING',
            'createdAt': '2026-10-13T09:30:00.000Z',
          },
        ];

        final docs = await docRepo.getDocuments();
        expect(docs.length, 2);
        expect(docs.first.status, 'READY');
        expect(docs.first.isReady, isTrue);
        expect(docs.last.status, 'PROCESSING');
        expect(docs.last.isProcessing, isTrue);

        // 2. Ask document question with source citations
        apiClient.responses['/documents/doc-quantum-notes/questions'] = {
          'answer':
              'Wave-particle duality posits that every particle or quantum entity exhibits both wave and particle characteristics.',
          'sources': [
            {'documentId': 'doc-quantum-notes', 'page': 3, 'chunkId': 'chk-42'},
            {'documentId': 'doc-quantum-notes', 'page': 4, 'chunkId': 'chk-43'},
          ],
        };

        final qaResponse = await docRepo.askQuestion(
          documentId: 'doc-quantum-notes',
          question: 'What is wave-particle duality?',
        );

        expect(qaResponse.answer, contains('Wave-particle duality'));
        expect(qaResponse.sources.length, 2);
        expect(qaResponse.sources.first.page, 3);
        expect(qaResponse.sources.last.page, 4);

        // 3. Delete document
        apiClient.responses['/documents/doc-quantum-notes'] = {'deleted': true};
        await docRepo.deleteDocument('doc-quantum-notes');

        expect(
          apiClient.callLog.any(
            (c) =>
                c.method == 'DELETE' &&
                c.path == '/documents/doc-quantum-notes',
          ),
          isTrue,
        );
      },
    );

    // =========================================================================
    // JOURNEY 4: Quiz Generation, Attempt, Scoring & Review Mode
    // =========================================================================
    test(
      'Journey 4: Generate quiz, hide answer key during play, submit attempt, and review',
      () async {
        final quizRepo = container.read(quizRepositoryProvider);

        // 1. Generate a quiz
        apiClient.responses['/quizzes'] = {
          'id': 'quiz-cell-biology',
          'title': 'Cell Biology Quick Quiz',
          'topic': 'Cell Biology',
          'difficulty': 'MEDIUM',
          'questionCount': 2,
          'status': 'READY',
          'createdAt': '2026-10-13T08:00:00.000Z',
        };

        final quiz = await quizRepo.createQuiz(
          title: 'Cell Biology Quick Quiz',
          topic: 'Cell Biology',
          difficulty: 'MEDIUM',
          questionCount: 2,
        );

        expect(quiz.id, 'quiz-cell-biology');
        expect(quiz.difficulty, 'MEDIUM');

        // 2. Start attempt
        apiClient.responses['/quizzes/quiz-cell-biology/attempts'] = {
          'id': 'att-101',
          'quizId': 'quiz-cell-biology',
          'status': 'IN_PROGRESS',
          'score': null,
          'totalQuestions': 2,
          'startedAt': '2026-10-13T08:05:00.000Z',
          'questions': [
            {
              'id': 'q-1',
              'orderIndex': 0,
              'prompt': 'What is the primary function of mitochondria?',
              'options': [
                'ATP Synthesis',
                'Protein Folding',
                'Lipid Storage',
                'DNA Replication',
              ],
              // Note: correctAnswer is omitted during active attempt
            },
            {
              'id': 'q-2',
              'orderIndex': 1,
              'prompt': 'Which organelle contains hydrolytic enzymes?',
              'options': ['Lysosome', 'Ribosome', 'Golgi apparatus', 'Vacuole'],
            },
          ],
        };

        final attempt = await quizRepo.startAttempt('quiz-cell-biology');
        expect(attempt.id, 'att-101');
        expect(attempt.status, 'IN_PROGRESS');
        expect(attempt.score, isNull);
        expect(attempt.questions.first.correctAnswer, isNull);

        // 3. Submit answers and receive server-calculated score and explanations
        apiClient.responses['/quiz-attempts/att-101/submit'] = {
          'attemptId': 'att-101',
          'score': 2,
          'totalQuestions': 2,
          'review': [
            {
              'questionId': 'q-1',
              'prompt': 'What is the primary function of mitochondria?',
              'selectedAnswer': 'ATP Synthesis',
              'correctAnswer': 'ATP Synthesis',
              'isCorrect': true,
              'explanation': 'Mitochondria generate cellular energy via ATP.',
            },
            {
              'questionId': 'q-2',
              'prompt': 'Which organelle contains hydrolytic enzymes?',
              'selectedAnswer': 'Lysosome',
              'correctAnswer': 'Lysosome',
              'isCorrect': true,
              'explanation':
                  'Lysosomes degrade biomolecules with acidic hydrolases.',
            },
          ],
        };

        final result = await quizRepo.submitAttempt(
          attemptId: 'att-101',
          responses: [
            {'questionId': 'q-1', 'selectedAnswer': 'ATP Synthesis'},
            {'questionId': 'q-2', 'selectedAnswer': 'Lysosome'},
          ],
        );

        expect(result.score, 2);
        expect(result.totalQuestions, 2);
        expect(result.percentage, 100.0);
        expect(result.isPassed, isTrue);
        expect(result.review.first.explanation, contains('ATP'));
      },
    );

    // =========================================================================
    // JOURNEY 5: Study Plan Generation, Agenda & Task Management
    // =========================================================================
    test(
      'Journey 5: Generate study plan, render agenda tasks, and toggle task completion',
      () async {
        final planRepo = container.read(studyPlanRepositoryProvider);

        // 1. Generate study plan
        apiClient.responses['/study-plans'] = {
          'id': 'plan-midterms-2026',
          'title': 'Midterm Revision Plan',
          'dailyMinutes': 90,
          'timezone': 'Asia/Kolkata',
          'status': 'ACTIVE',
          'createdAt': '2026-10-13T07:00:00.000Z',
          'tasks': [
            {
              'id': 'tsk-1',
              'planId': 'plan-midterms-2026',
              'title': 'Calculus: Integration by Parts',
              'topic': 'Mathematics',
              'scheduledDate': '2026-10-14T00:00:00.000Z',
              'durationMinutes': 45,
              'status': 'TODO',
              'orderIndex': 0,
            },
            {
              'id': 'tsk-2',
              'planId': 'plan-midterms-2026',
              'title': 'Physics: Kinetic Theory',
              'topic': 'Physics',
              'scheduledDate': '2026-10-14T00:00:00.000Z',
              'durationMinutes': 45,
              'status': 'TODO',
              'orderIndex': 1,
            },
          ],
        };

        final plan = await planRepo.createStudyPlan(
          title: 'Midterm Revision Plan',
          subjects: ['Mathematics', 'Physics'],
          dailyMinutes: 90,
          timezone: 'Asia/Kolkata',
        );

        expect(plan.id, 'plan-midterms-2026');
        expect(plan.tasks.length, 2);
        expect(plan.dailyMinutes, 90);

        // 2. Toggle task to COMPLETED
        apiClient.responses['/study-tasks/tsk-1'] = {
          'id': 'tsk-1',
          'planId': 'plan-midterms-2026',
          'title': 'Calculus: Integration by Parts',
          'topic': 'Mathematics',
          'scheduledDate': '2026-10-14T00:00:00.000Z',
          'durationMinutes': 45,
          'status': 'COMPLETED',
          'orderIndex': 0,
        };

        final updatedTask = await planRepo.updateTaskStatus(
          taskId: 'tsk-1',
          status: 'COMPLETED',
        );

        expect(updatedTask.status, 'COMPLETED');
      },
    );

    // =========================================================================
    // JOURNEY 6: Settings, AI Usage, Feedback & Account Deletion
    // =========================================================================
    test(
      'Journey 6: AI Usage, feedback submission, and account deletion rollback on error',
      () async {
        final usageRepo = container.read(usageRepositoryProvider);
        final feedbackRepo = container.read(feedbackRepositoryProvider);
        final authRepo = container.read(authRepositoryProvider);

        // 1. Fetch real AI usage
        apiClient.responses['/usage'] = {
          'totalTokens': 15400,
          'requestCount': 42,
          'quotaLimit': 50,
          'requestsRemaining': 8,
          'estimatedCost': 0.038,
          'featureBreakdown': {
            'TUTOR_CHAT': 25,
            'DOCUMENT_QA': 10,
            'QUIZ_GENERATION': 7,
          },
        };

        final usage = await usageRepo.getUsage();
        expect(usage.totalTokens, 15400);
        expect(usage.requestCount, 42);
        expect(usage.requestsRemaining, 8);
        expect(usage.isExhausted, isFalse);

        // 2. Submit user feedback
        apiClient.responses['/feedback'] = {
          'id': 'fb-rev-1',
          'rating': 'POSITIVE',
          'category': 'HELPFULNESS',
          'comment': 'The PDF summary helped me pass my quiz!',
          'createdAt': '2026-10-13T11:00:00.000Z',
        };

        final feedback = await feedbackRepo.submitFeedback(
          rating: 'POSITIVE',
          category: 'HELPFULNESS',
          comment: 'The PDF summary helped me pass my quiz!',
        );

        expect(feedback.id, 'fb-rev-1');
        expect(feedback.category, 'HELPFULNESS');

        // 3. Account deletion: failure rollback protection
        await storage.saveToken('valid-user-token');
        apiClient.errors['/me'] = const ApiException(
          code: 'INTERNAL_SERVER_ERROR',
          statusCode: 500,
          message: 'Database conflict: unable to purge records.',
        );

        expect(() => authRepo.deleteAccount(), throwsA(isA<ApiException>()));

        // Verify tokens were NOT cleared because deletion failed on the backend
        expect(await storage.hasToken(), isTrue);
      },
    );

    // =========================================================================
    // EDGE CASES: Timeouts, 429 Rate Limits, 401 Expirations, Quota Exhaustion
    // =========================================================================
    group('Edge Cases & Resilient State Handling', () {
      test('handles 429 RATE_LIMITED exception gracefully', () async {
        final tutorRepo = container.read(tutorRepositoryProvider);

        apiClient.errors['/conversations/c-1/messages'] = const ApiException(
          code: 'RATE_LIMITED',
          statusCode: 429,
          message:
              'Too many requests. Please wait a moment before sending another message.',
        );

        expect(
          () => tutorRepo.sendMessage(
            conversationId: 'c-1',
            content: 'Hello again!',
          ),
          throwsA(
            predicate(
              (e) =>
                  e is ApiException &&
                  e.statusCode == 429 &&
                  e.code == 'RATE_LIMITED',
            ),
          ),
        );
      });

      test('handles network TIMEOUT_ERROR gracefully', () async {
        final docRepo = container.read(documentRepositoryProvider);

        apiClient.errors['/documents/doc-1/questions'] = const ApiException(
          code: 'TIMEOUT_ERROR',
          statusCode: 408,
          message:
              'The connection timed out. Please check your internet connection.',
        );

        expect(
          () => docRepo.askQuestion(
            documentId: 'doc-1',
            question: 'Summarize page 1',
          ),
          throwsA(
            predicate((e) => e is ApiException && e.code == 'TIMEOUT_ERROR'),
          ),
        );
      });

      test(
        'handles malformed / empty responses safely without crash',
        () async {
          final usageRepo = container.read(usageRepositoryProvider);
          apiClient.responses['/usage'] = null;

          final usage = await usageRepo.getUsage();
          expect(usage.totalTokens, 0);
          expect(usage.requestCount, 0);
          expect(usage.isExhausted, isFalse);
        },
      );
    });
  });
}
