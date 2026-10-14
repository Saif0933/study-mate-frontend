import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_mate_frontend/core/network/api_client.dart';
import 'package:study_mate_frontend/core/network/api_exceptions.dart';
import 'package:study_mate_frontend/features/quizzes/controllers/quiz_controller.dart';
import 'package:study_mate_frontend/features/quizzes/models/quiz_model.dart';
import 'package:study_mate_frontend/features/quizzes/repositories/quiz_repository.dart';

class FakeApiClient extends Fake implements ApiClient {
  final Map<String, dynamic> responses = {};
  final Map<String, ApiException> errors = {};
  int postCallCount = 0;
  dynamic lastPostData;
  String? lastPostPath;

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
  Future<dynamic> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    postCallCount++;
    lastPostPath = path;
    lastPostData = data;
    if (errors.containsKey(path)) {
      throw errors[path]!;
    }
    return responses[path];
  }
}

void main() {
  group('Quiz Models Unit Tests', () {
    test('QuizModel parses from JSON correctly', () {
      final json = {
        'id': 'quiz-1',
        'title': 'Photosynthesis Quiz',
        'topic': 'Light dependent reactions',
        'difficulty': 'HARD',
        'questionCount': 5,
        'status': 'READY',
        'createdAt': '2026-10-12T10:00:00.000Z',
      };

      final quiz = QuizModel.fromJson(json);
      expect(quiz.id, 'quiz-1');
      expect(quiz.title, 'Photosynthesis Quiz');
      expect(quiz.formattedDifficulty, 'Hard');
      expect(quiz.questionCount, 5);
    });

    test('QuizQuestionModel validates prompt and minimum options', () {
      final validQ = QuizQuestionModel(
        id: 'q1',
        orderIndex: 0,
        prompt: 'What organelle performs photosynthesis?',
        options: const ['Chloroplast', 'Mitochondria', 'Nucleus'],
      );
      expect(validQ.isValid, isTrue);

      final invalidPrompt = QuizQuestionModel(
        id: 'q2',
        orderIndex: 1,
        prompt: '   ',
        options: const ['Option A', 'Option B'],
      );
      expect(invalidPrompt.isValid, isFalse);

      final tooFewOptions = QuizQuestionModel(
        id: 'q3',
        orderIndex: 2,
        prompt: 'Valid question?',
        options: const ['Single Option'],
      );
      expect(tooFewOptions.isValid, isFalse);
    });

    test('QuizAttemptModel validates questions list and hides answers', () {
      final attemptJson = {
        'id': 'att-1',
        'quizId': 'quiz-1',
        'status': 'IN_PROGRESS',
        'totalQuestions': 2,
        'questions': [
          {
            'id': 'q1',
            'orderIndex': 0,
            'prompt': 'Where does glycolysis occur?',
            'options': ['Cytoplasm', 'Matrix', 'Stroma'],
            // Note: correctAnswer should be omitted by backend during attempt
          },
          {
            'id': 'q2',
            'orderIndex': 1,
            'prompt': 'What is the net ATP yield of glycolysis?',
            'options': ['2 ATP', '4 ATP', '36 ATP'],
          },
        ],
      };

      final attempt = QuizAttemptModel.fromJson(attemptJson);
      expect(attempt.isValid, isTrue);
      expect(attempt.questions.length, 2);
      expect(attempt.questions[0].correctAnswer, isNull);
      expect(attempt.questions[1].correctAnswer, isNull);
    });

    test('QuizSubmissionResult calculates percentage and pass status', () {
      final result = QuizSubmissionResult(
        attemptId: 'att-1',
        score: 4,
        totalQuestions: 5,
        review: const [
          QuestionReviewItem(
            questionId: 'q1',
            prompt: 'Question 1',
            selectedAnswer: 'A',
            correctAnswer: 'A',
            isCorrect: true,
          ),
        ],
      );

      expect(result.percentage, 80.0);
      expect(result.isPassed, isTrue);

      final failedResult = QuizSubmissionResult(
        attemptId: 'att-2',
        score: 2,
        totalQuestions: 5,
        review: const [],
      );
      expect(failedResult.percentage, 40.0);
      expect(failedResult.isPassed, isFalse);
    });
  });

  group('QuizRepository Unit Tests', () {
    late FakeApiClient apiClient;
    late QuizRepository repository;

    final sampleQuizJson = {
      'id': 'quiz-10',
      'title': 'Calculus Derivatives',
      'topic': 'Chain Rule',
      'difficulty': 'MEDIUM',
      'questionCount': 3,
      'status': 'READY',
      'createdAt': '2026-10-12T10:00:00.000Z',
    };

    setUp(() {
      apiClient = FakeApiClient();
      repository = QuizRepository(apiClient: apiClient);
    });

    test('getQuizzes fetches and parses quiz list', () async {
      apiClient.responses['/quizzes'] = [sampleQuizJson];

      final list = await repository.getQuizzes();
      expect(list.length, 1);
      expect(list.first.title, 'Calculus Derivatives');
    });

    test('createQuiz sends configuration payload to /quizzes', () async {
      apiClient.responses['/quizzes'] = sampleQuizJson;

      final created = await repository.createQuiz(
        title: 'Calculus Derivatives',
        topic: 'Chain Rule',
        difficulty: 'MEDIUM',
        questionCount: 3,
      );

      expect(apiClient.lastPostPath, '/quizzes');
      expect(apiClient.lastPostData, {
        'title': 'Calculus Derivatives',
        'topic': 'Chain Rule',
        'difficulty': 'MEDIUM',
        'questionCount': 3,
      });
      expect(created.id, 'quiz-10');
    });

    test('startAttempt calls /quizzes/:id/attempts', () async {
      apiClient.responses['/quizzes/quiz-10/attempts'] = {
        'id': 'att-99',
        'quizId': 'quiz-10',
        'status': 'IN_PROGRESS',
        'totalQuestions': 1,
        'questions': [
          {
            'id': 'q-1',
            'orderIndex': 0,
            'prompt': 'What is d/dx of sin(x)?',
            'options': ['cos(x)', '-cos(x)', 'tan(x)'],
          },
        ],
      };

      final attempt = await repository.startAttempt('quiz-10');
      expect(apiClient.lastPostPath, '/quizzes/quiz-10/attempts');
      expect(attempt.id, 'att-99');
      expect(attempt.questions.first.prompt, contains('sin(x)'));
    });

    test(
      'submitAttempt sends user answers to /quiz-attempts/:id/submit',
      () async {
        apiClient.responses['/quiz-attempts/att-99/submit'] = {
          'attemptId': 'att-99',
          'score': 1,
          'totalQuestions': 1,
          'review': [
            {
              'questionId': 'q-1',
              'prompt': 'What is d/dx of sin(x)?',
              'selectedAnswer': 'cos(x)',
              'correctAnswer': 'cos(x)',
              'isCorrect': true,
              'explanation':
                  'The derivative of sin(x) with respect to x is cos(x).',
            },
          ],
        };

        final result = await repository.submitAttempt(
          attemptId: 'att-99',
          responses: [
            {'questionId': 'q-1', 'selectedAnswer': 'cos(x)'},
          ],
        );

        expect(apiClient.lastPostPath, '/quiz-attempts/att-99/submit');
        expect(result.score, 1);
        expect(result.review.first.isCorrect, isTrue);
        expect(
          result.review.first.explanation,
          contains('derivative of sin(x)'),
        );
      },
    );
  });

  group('QuizListController Unit Tests', () {
    test(
      'createQuiz updates state with new quiz and prevents duplicate submission',
      () async {
        final apiClient = FakeApiClient();
        final repository = QuizRepository(apiClient: apiClient);

        apiClient.responses['/quizzes'] = <dynamic>[];

        final container = ProviderContainer(
          overrides: [quizRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);

        container.read(quizListControllerProvider);
        await Future<void>.delayed(const Duration(milliseconds: 30));

        final createdQuizJson = {
          'id': 'q-new',
          'title': 'Linear Algebra',
          'topic': 'Eigenvalues',
          'difficulty': 'HARD',
          'questionCount': 5,
          'status': 'READY',
          'createdAt': '2026-10-12T10:00:00.000Z',
        };
        apiClient.responses['/quizzes'] = createdQuizJson;

        final controller = container.read(quizListControllerProvider.notifier);
        final created = await controller.createQuiz(
          title: 'Linear Algebra',
          topic: 'Eigenvalues',
          difficulty: 'HARD',
          questionCount: 5,
        );

        expect(created?.id, 'q-new');
        final list = container.read(quizListControllerProvider).value!;
        expect(list.length, 1);
        expect(list.first.title, 'Linear Algebra');
      },
    );
  });

  group('QuizPlayController Unit Tests', () {
    test(
      'starts attempt, tracks selected answers, and submits successfully',
      () async {
        final apiClient = FakeApiClient();
        final repository = QuizRepository(apiClient: apiClient);

        apiClient.responses['/quizzes/quiz-10/attempts'] = {
          'id': 'att-100',
          'quizId': 'quiz-10',
          'status': 'IN_PROGRESS',
          'totalQuestions': 2,
          'questions': [
            {
              'id': 'q1',
              'orderIndex': 0,
              'prompt': 'Question 1',
              'options': ['Alpha', 'Beta'],
            },
            {
              'id': 'q2',
              'orderIndex': 1,
              'prompt': 'Question 2',
              'options': ['Gamma', 'Delta'],
            },
          ],
        };

        final container = ProviderContainer(
          overrides: [quizRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);

        final sub = container.listen(
          quizPlayControllerProvider('quiz-10'),
          (_, _) {},
        );
        addTearDown(sub.close);

        final controller = container.read(
          quizPlayControllerProvider('quiz-10').notifier,
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));

        var state = container.read(quizPlayControllerProvider('quiz-10'));
        expect(state.isLoading, isFalse);
        expect(state.attempt?.questions.length, 2);

        // Select answers
        controller.selectOption('q1', 'Alpha');
        controller.setQuestionIndex(1);
        controller.selectOption('q2', 'Delta');

        state = container.read(quizPlayControllerProvider('quiz-10'));
        expect(state.selectedAnswers['q1'], 'Alpha');
        expect(state.selectedAnswers['q2'], 'Delta');
        expect(state.currentQuestionIndex, 1);

        // Prepare submission response
        apiClient.responses['/quiz-attempts/att-100/submit'] = {
          'attemptId': 'att-100',
          'score': 2,
          'totalQuestions': 2,
          'review': [
            {
              'questionId': 'q1',
              'prompt': 'Question 1',
              'selectedAnswer': 'Alpha',
              'correctAnswer': 'Alpha',
              'isCorrect': true,
            },
            {
              'questionId': 'q2',
              'prompt': 'Question 2',
              'selectedAnswer': 'Delta',
              'correctAnswer': 'Delta',
              'isCorrect': true,
            },
          ],
        };

        final result = await controller.submit();
        expect(result, isNotNull);
        expect(result!.score, 2);
        expect(result.percentage, 100.0);

        state = container.read(quizPlayControllerProvider('quiz-10'));
        expect(state.result, isNotNull);
        expect(state.isSubmitting, isFalse);
      },
    );

    test(
      'preserves user answers on network submission failure and allows retry',
      () async {
        final apiClient = FakeApiClient();
        final repository = QuizRepository(apiClient: apiClient);

        apiClient.responses['/quizzes/quiz-10/attempts'] = {
          'id': 'att-101',
          'quizId': 'quiz-10',
          'status': 'IN_PROGRESS',
          'totalQuestions': 1,
          'questions': [
            {
              'id': 'q1',
              'orderIndex': 0,
              'prompt': 'Capital of France?',
              'options': ['Paris', 'London'],
            },
          ],
        };

        final container = ProviderContainer(
          overrides: [quizRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);

        final sub = container.listen(
          quizPlayControllerProvider('quiz-10'),
          (_, _) {},
        );
        addTearDown(sub.close);

        final controller = container.read(
          quizPlayControllerProvider('quiz-10').notifier,
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));

        controller.selectOption('q1', 'Paris');

        // First submit fails
        apiClient.errors['/quiz-attempts/att-101/submit'] = ApiException(
          code: 'TIMEOUT',
          message: 'Network timed out while submitting quiz.',
        );

        final failedResult = await controller.submit();
        expect(failedResult, isNull);

        var state = container.read(quizPlayControllerProvider('quiz-10'));
        expect(state.errorMessage, contains('Network timed out'));
        expect(state.selectedAnswers['q1'], 'Paris'); // Preserved!

        // Remove error and retry
        apiClient.errors.remove('/quiz-attempts/att-101/submit');
        apiClient.responses['/quiz-attempts/att-101/submit'] = {
          'attemptId': 'att-101',
          'score': 1,
          'totalQuestions': 1,
          'review': [
            {
              'questionId': 'q1',
              'prompt': 'Capital of France?',
              'selectedAnswer': 'Paris',
              'correctAnswer': 'Paris',
              'isCorrect': true,
            },
          ],
        };

        final successResult = await controller.submit();
        expect(successResult, isNotNull);
        expect(successResult!.score, 1);
      },
    );
  });
}
