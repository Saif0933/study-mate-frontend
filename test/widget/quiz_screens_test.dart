import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_mate_frontend/core/network/api_client.dart';
import 'package:study_mate_frontend/core/network/api_exceptions.dart';
import 'package:study_mate_frontend/core/theme/app_theme.dart';
import 'package:study_mate_frontend/features/documents/controllers/document_list_controller.dart';
import 'package:study_mate_frontend/features/documents/models/document_model.dart';
import 'package:study_mate_frontend/features/quizzes/controllers/quiz_controller.dart';
import 'package:study_mate_frontend/features/quizzes/models/quiz_model.dart';
import 'package:study_mate_frontend/features/quizzes/repositories/quiz_repository.dart';
import 'package:study_mate_frontend/features/quizzes/screens/quiz_create_screen.dart';
import 'package:study_mate_frontend/features/quizzes/screens/quiz_list_screen.dart';
import 'package:study_mate_frontend/features/quizzes/screens/quiz_play_screen.dart';
import 'package:study_mate_frontend/features/quizzes/screens/quiz_result_screen.dart';

class MockQuizRepository implements QuizRepository {
  @override
  ApiClient get apiClient => throw UnimplementedError();

  List<QuizModel> quizzes;
  QuizAttemptModel? attemptToReturn;
  QuizSubmissionResult? submissionToReturn;
  Object? errorOnList;
  Object? errorOnStart;
  Object? errorOnSubmit;
  Object? errorOnCreate;
  bool createCalled = false;
  bool submitCalled = false;
  List<Map<String, dynamic>>? lastSubmittedResponses;

  MockQuizRepository({
    this.quizzes = const [],
    this.attemptToReturn,
    this.submissionToReturn,
    this.errorOnList,
    this.errorOnStart,
    this.errorOnSubmit,
    this.errorOnCreate,
  });

  @override
  Future<List<QuizModel>> getQuizzes() async {
    if (errorOnList != null) throw errorOnList!;
    return quizzes;
  }

  @override
  Future<QuizModel> getQuiz(String quizId) async {
    return quizzes.firstWhere((q) => q.id == quizId);
  }

  @override
  Future<QuizModel> createQuiz({
    required String title,
    String? topic,
    String? sourceDocumentId,
    String difficulty = 'MEDIUM',
    int questionCount = 5,
  }) async {
    createCalled = true;
    if (errorOnCreate != null) throw errorOnCreate!;
    final created = QuizModel(
      id: 'quiz-generated-1',
      title: title,
      topic: topic,
      sourceDocumentId: sourceDocumentId,
      difficulty: difficulty,
      questionCount: questionCount,
      status: 'READY',
      createdAt: DateTime(2026, 10, 13),
    );
    quizzes = [created, ...quizzes];
    return created;
  }

  @override
  Future<QuizAttemptModel> startAttempt(String quizId) async {
    if (errorOnStart != null) throw errorOnStart!;
    if (attemptToReturn != null) return attemptToReturn!;
    return QuizAttemptModel(
      id: 'att-100',
      quizId: quizId,
      status: 'IN_PROGRESS',
      totalQuestions: 2,
      startedAt: DateTime(2026, 10, 13),
      questions: [
        QuizQuestionModel(
          id: 'q1',
          orderIndex: 0,
          prompt: 'What organelle produces ATP in eukaryotic cells?',
          options: [
            'Mitochondria',
            'Ribosome',
            'Endoplasmic reticulum',
            'Golgi body',
          ],
        ),
        QuizQuestionModel(
          id: 'q2',
          orderIndex: 1,
          prompt: 'What green pigment absorbs light during photosynthesis?',
          options: ['Chlorophyll', 'Carotenoid', 'Hemoglobin', 'Anthocyanin'],
        ),
      ],
    );
  }

  @override
  Future<QuizSubmissionResult> submitAttempt({
    required String attemptId,
    required List<Map<String, dynamic>> responses,
  }) async {
    submitCalled = true;
    lastSubmittedResponses = responses;
    if (errorOnSubmit != null) throw errorOnSubmit!;
    if (submissionToReturn != null) return submissionToReturn!;
    return QuizSubmissionResult(
      attemptId: attemptId,
      score: 2,
      totalQuestions: 2,
      review: [
        QuestionReviewItem(
          questionId: 'q1',
          prompt: 'What organelle produces ATP in eukaryotic cells?',
          selectedAnswer: 'Mitochondria',
          correctAnswer: 'Mitochondria',
          isCorrect: true,
          explanation:
              'Mitochondria produce the majority of cellular ATP via oxidative phosphorylation.',
        ),
        QuestionReviewItem(
          questionId: 'q2',
          prompt: 'What green pigment absorbs light during photosynthesis?',
          selectedAnswer: 'Chlorophyll',
          correctAnswer: 'Chlorophyll',
          isCorrect: true,
          explanation:
              'Chlorophyll absorbs blue and red wavelengths of light while reflecting green.',
        ),
      ],
    );
  }

  @override
  Future<QuizSubmissionResult> getAttempt(String attemptId) async {
    if (submissionToReturn != null) return submissionToReturn!;
    return QuizSubmissionResult(
      attemptId: attemptId,
      score: 0,
      totalQuestions: 0,
      review: const [],
    );
  }
}

class MockDocumentListController extends DocumentListController {
  final List<DocumentModel> docs;
  MockDocumentListController({this.docs = const []});

  @override
  Future<List<DocumentModel>> build() async => docs;
}

Widget createTestApp({
  required Widget child,
  required MockQuizRepository repository,
  List<DocumentModel> documents = const [],
}) {
  return ProviderScope(
    overrides: [
      quizRepositoryProvider.overrideWithValue(repository),
      documentListControllerProvider.overrideWith(
        () => MockDocumentListController(docs: documents),
      ),
    ],
    child: MaterialApp(theme: AppTheme.darkTheme, home: child),
  );
}

void main() {
  group('QuizListScreen Widget Tests', () {
    testWidgets(
      'displays empty state view when no quizzes exist and navigates to create screen',
      (tester) async {
        final repository = MockQuizRepository(quizzes: []);

        await tester.pumpWidget(
          createTestApp(child: const QuizListScreen(), repository: repository),
        );
        await tester.pumpAndSettle();

        expect(find.text('Practice Quizzes'), findsOneWidget);
        expect(find.text('No quizzes generated yet'), findsOneWidget);
        expect(find.text('Generate Practice Quiz'), findsOneWidget);

        await tester.tap(find.text('Generate Practice Quiz'));
        await tester.pumpAndSettle();

        expect(find.byType(QuizCreateScreen), findsOneWidget);
      },
    );

    testWidgets(
      'displays list of quizzes with title, difficulty, and question count',
      (tester) async {
        final sampleQuizzes = <QuizModel>[
          QuizModel(
            id: 'quiz-1',
            title: 'Cell Biology Review',
            topic: 'Cell Structure',
            difficulty: 'MEDIUM',
            questionCount: 5,
            status: 'READY',
            createdAt: DateTime(2026, 10, 1),
          ),
          QuizModel(
            id: 'quiz-2',
            title: 'Calculus Derivatives',
            difficulty: 'HARD',
            questionCount: 10,
            status: 'READY',
            createdAt: DateTime(2026, 10, 2),
          ),
        ];
        final repository = MockQuizRepository(quizzes: sampleQuizzes);

        await tester.pumpWidget(
          createTestApp(child: const QuizListScreen(), repository: repository),
        );
        await tester.pumpAndSettle();

        expect(find.text('Cell Biology Review'), findsOneWidget);
        expect(find.text('Cell Structure'), findsOneWidget);
        expect(find.text('MEDIUM'), findsOneWidget);
        expect(find.text('5 Questions'), findsOneWidget);

        expect(find.text('Calculus Derivatives'), findsOneWidget);
        expect(find.text('HARD'), findsOneWidget);
        expect(find.text('10 Questions'), findsOneWidget);
      },
    );

    testWidgets('floating action button navigates to QuizCreateScreen', (
      tester,
    ) async {
      final repository = MockQuizRepository(
        quizzes: [
          QuizModel(
            id: 'quiz-1',
            title: 'Sample Quiz',
            difficulty: 'EASY',
            questionCount: 3,
            status: 'READY',
            createdAt: DateTime.now(),
          ),
        ],
      );

      await tester.pumpWidget(
        createTestApp(child: const QuizListScreen(), repository: repository),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.byType(QuizCreateScreen), findsOneWidget);
    });

    testWidgets('tapping quiz card navigates to QuizPlayScreen', (
      tester,
    ) async {
      final targetQuiz = QuizModel(
        id: 'quiz-target',
        title: 'Photosynthesis Masterclass',
        difficulty: 'MEDIUM',
        questionCount: 2,
        status: 'READY',
        createdAt: DateTime.now(),
      );
      final repository = MockQuizRepository(quizzes: [targetQuiz]);

      await tester.pumpWidget(
        createTestApp(child: const QuizListScreen(), repository: repository),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Photosynthesis Masterclass'));
      await tester.pumpAndSettle();

      expect(find.byType(QuizPlayScreen), findsOneWidget);
      expect(find.text('Photosynthesis Masterclass'), findsOneWidget);
    });
  });

  group('QuizCreateScreen Widget Tests', () {
    testWidgets('validates required quiz title and topic/source document', (
      tester,
    ) async {
      final repository = MockQuizRepository();

      await tester.pumpWidget(
        createTestApp(child: const QuizCreateScreen(), repository: repository),
      );
      await tester.pumpAndSettle();

      // Submit with empty fields
      await tester.tap(find.text('Generate Quiz with AI'));
      await tester.pumpAndSettle();

      expect(find.text('Please provide a title for the quiz'), findsOneWidget);

      // Fill in title but empty topic & no document
      await tester.enterText(
        find.byType(TextFormField).first,
        'Quantum Physics Quiz',
      );
      await tester.tap(find.text('Generate Quiz with AI'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Please enter a topic or select an uploaded PDF notes document.',
        ),
        findsOneWidget,
      );
      expect(repository.createCalled, isFalse);
    });

    testWidgets(
      'allows selecting difficulty and question count, and creates quiz',
      (tester) async {
        final repository = MockQuizRepository();

        await tester.pumpWidget(
          createTestApp(
            child: const QuizCreateScreen(),
            repository: repository,
          ),
        );
        await tester.pumpAndSettle();

        // Enter title
        await tester.enterText(
          find.byType(TextFormField).first,
          'World War II Quiz',
        );
        // Enter topic
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'European Theater 1939-1945',
        );

        // Select 'Hard' difficulty
        await tester.tap(find.text('Hard'));
        await tester.pumpAndSettle();

        // Tap generate
        await tester.tap(find.text('Generate Quiz with AI'));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(repository.createCalled, isTrue);
        // Should have transitioned to QuizPlayScreen
        expect(find.byType(QuizPlayScreen), findsOneWidget);
      },
    );

    testWidgets('shows dropdown with uploaded ready PDF notes', (tester) async {
      final repository = MockQuizRepository();
      final docs = <DocumentModel>[
        DocumentModel(
          id: 'doc-123',
          originalName: 'Lecture4_Genetics.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 1024,
          status: 'READY',
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        createTestApp(
          child: const QuizCreateScreen(),
          repository: repository,
          documents: docs,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Or Generate from Uploaded PDF:'), findsOneWidget);
      expect(find.text('None (Use topic only)'), findsOneWidget);
    });
  });

  group('QuizPlayScreen Widget Tests', () {
    final testQuiz = QuizModel(
      id: 'quiz-play-1',
      title: 'Biology 101 Quiz',
      difficulty: 'MEDIUM',
      questionCount: 2,
      status: 'READY',
      createdAt: DateTime.now(),
    );

    testWidgets(
      'renders questions, options, progress, and selectable options without revealing answers',
      (tester) async {
        final repository = MockQuizRepository();

        await tester.pumpWidget(
          createTestApp(
            child: QuizPlayScreen(quiz: testQuiz),
            repository: repository,
          ),
        );
        await tester.pump(); // Start attempt microtask
        await tester.pumpAndSettle();

        // Verify question 1 prompt is visible
        expect(
          find.text('What organelle produces ATP in eukaryotic cells?'),
          findsOneWidget,
        );
        expect(find.text('Question 1 of 2'), findsOneWidget);
        expect(find.text('0/2 Answered'), findsOneWidget);

        // Check options rendered with labels A, B, C, D
        expect(find.text('Mitochondria'), findsOneWidget);
        expect(find.text('Ribosome'), findsOneWidget);
        expect(find.text('A'), findsOneWidget);
        expect(find.text('B'), findsOneWidget);

        // None should reveal whether it is correct or incorrect yet!
        expect(find.text('Correct'), findsNothing);
        expect(find.text('Incorrect'), findsNothing);

        // Select an option
        await tester.tap(find.text('Mitochondria'));
        await tester.pumpAndSettle();

        expect(find.text('1/2 Answered'), findsOneWidget);
        expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'navigates between questions using Next, Previous, and jump chips',
      (tester) async {
        final repository = MockQuizRepository();

        await tester.pumpWidget(
          createTestApp(
            child: QuizPlayScreen(quiz: testQuiz),
            repository: repository,
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Question 1 of 2'), findsOneWidget);
        await tester.tap(find.text('Mitochondria'));
        await tester.pumpAndSettle();

        // Tap Next Question
        await tester.tap(find.text('Next Question'));
        await tester.pumpAndSettle();

        expect(find.text('Question 2 of 2'), findsOneWidget);
        expect(
          find.text('What green pigment absorbs light during photosynthesis?'),
          findsOneWidget,
        );
        expect(find.text('Previous'), findsOneWidget);
        expect(find.text('Submit Quiz'), findsOneWidget);

        // Tap Previous
        await tester.tap(find.text('Previous'));
        await tester.pumpAndSettle();

        expect(find.text('Question 1 of 2'), findsOneWidget);

        // Tap question 2 chip directly
        await tester.tap(find.text('2'));
        await tester.pumpAndSettle();

        expect(find.text('Question 2 of 2'), findsOneWidget);
      },
    );

    testWidgets(
      'shows warning dialog when attempting to submit with unanswered questions',
      (tester) async {
        final repository = MockQuizRepository();

        await tester.pumpWidget(
          createTestApp(
            child: QuizPlayScreen(quiz: testQuiz),
            repository: repository,
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        // Go to question 2 without answering anything
        await tester.tap(find.text('Next Question'));
        await tester.pumpAndSettle();

        // Try to submit
        await tester.tap(find.text('Submit Quiz'));
        await tester.pumpAndSettle();

        expect(find.text('Unanswered Questions'), findsOneWidget);
        expect(
          find.text(
            'You have 2 unanswered question(s). Are you sure you want to submit your quiz now?',
          ),
          findsOneWidget,
        );
        expect(find.text('Go Back'), findsOneWidget);
        expect(find.text('Submit Anyway'), findsOneWidget);

        // Tap Go Back closes dialog
        await tester.tap(find.text('Go Back'));
        await tester.pumpAndSettle();

        expect(find.text('Unanswered Questions'), findsNothing);
      },
    );

    testWidgets(
      'preserves answers and displays recoverable error banner on network submit failure',
      (tester) async {
        final repository = MockQuizRepository(
          errorOnSubmit: ApiException(
            code: 'NETWORK_TIMEOUT',
            message: 'Submission timed out. Please retry.',
          ),
        );

        await tester.pumpWidget(
          createTestApp(
            child: QuizPlayScreen(quiz: testQuiz),
            repository: repository,
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        // Answer question 1
        await tester.tap(find.text('Mitochondria'));
        await tester.pumpAndSettle();

        // Answer question 2
        await tester.tap(find.text('Next Question'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Chlorophyll'));
        await tester.pumpAndSettle();

        // Submit
        await tester.tap(find.text('Submit Quiz'));
        await tester.pumpAndSettle();

        // Verify error banner is shown with Retry button
        expect(
          find.text('Submission timed out. Please retry.'),
          findsWidgets, // SnackBar and/or Banner
        );
        expect(find.text('Retry'), findsOneWidget);

        // Verify answers are preserved
        expect(find.text('2/2 Answered'), findsOneWidget);
        expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);

        // Clear error on repository and click Retry
        repository.errorOnSubmit = null;
        await tester.tap(find.text('Retry'));
        await tester.pump();
        await tester.pumpAndSettle();

        // Successfully transitioned to QuizResultScreen
        expect(find.byType(QuizResultScreen), findsOneWidget);
      },
    );
  });

  group('QuizResultScreen Widget Tests', () {
    final sampleResult = QuizSubmissionResult(
      attemptId: 'att-res-1',
      score: 1,
      totalQuestions: 2,
      review: [
        QuestionReviewItem(
          questionId: 'q1',
          prompt: 'What organelle produces ATP in eukaryotic cells?',
          selectedAnswer: 'Mitochondria',
          correctAnswer: 'Mitochondria',
          isCorrect: true,
          explanation:
              'Mitochondria produce ATP through oxidative phosphorylation.',
        ),
        QuestionReviewItem(
          questionId: 'q2',
          prompt: 'What green pigment absorbs light during photosynthesis?',
          selectedAnswer: 'Carotenoid',
          correctAnswer: 'Chlorophyll',
          isCorrect: false,
          explanation:
              'Chlorophyll absorbs light for photosynthesis, whereas carotenoids are accessory pigments.',
        ),
      ],
    );

    testWidgets(
      'displays score percentage, pass/practice badge, and detailed question breakdown',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: QuizResultScreen(
              result: sampleResult,
              quizTitle: 'Biology 101 Quiz',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Quiz Results'), findsOneWidget);
        expect(find.text('50%'), findsOneWidget);
        expect(
          find.text('You scored 1 out of 2 questions correctly'),
          findsOneWidget,
        );
        expect(find.text('Needs Practice'), findsOneWidget);

        // Check accessibility badges: Correct and Incorrect text tags with icons
        expect(find.text('Correct'), findsOneWidget);
        expect(find.text('Incorrect'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
        expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);

        // Check answers displayed
        expect(find.text('Mitochondria'), findsWidgets);
        expect(find.text('Carotenoid'), findsOneWidget);
        expect(find.text('Chlorophyll'), findsOneWidget);

        // Check explanations
        expect(
          find.text(
            'Mitochondria produce ATP through oxidative phosphorylation.',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            'Chlorophyll absorbs light for photosynthesis, whereas carotenoids are accessory pigments.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('displays Passed badge for score >= 70%', (tester) async {
      final passingResult = QuizSubmissionResult(
        attemptId: 'att-res-pass',
        score: 4,
        totalQuestions: 5,
        review: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: QuizResultScreen(
            result: passingResult,
            quizTitle: 'Biology 101 Quiz',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('80%'), findsOneWidget);
      expect(find.text('Passed'), findsOneWidget);
    });
  });
}
