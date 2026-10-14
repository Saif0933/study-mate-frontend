import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/providers/core_providers.dart';
import '../models/quiz_model.dart';
import '../repositories/quiz_repository.dart';

final quizRepositoryProvider = Provider<QuizRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return QuizRepository(apiClient: apiClient);
});

final quizListControllerProvider =
    AsyncNotifierProvider<QuizListController, List<QuizModel>>(() {
      return QuizListController();
    });

class QuizListController extends AsyncNotifier<List<QuizModel>> {
  late final QuizRepository _repository;
  bool _isCreating = false;

  @override
  Future<List<QuizModel>> build() async {
    _repository = ref.watch(quizRepositoryProvider);
    return await _repository.getQuizzes();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.getQuizzes());
  }

  Future<QuizModel?> createQuiz({
    required String title,
    String? topic,
    String? sourceDocumentId,
    String difficulty = 'MEDIUM',
    int questionCount = 5,
  }) async {
    if (_isCreating) return null;
    _isCreating = true;

    try {
      final newQuiz = await _repository.createQuiz(
        title: title,
        topic: topic,
        sourceDocumentId: sourceDocumentId,
        difficulty: difficulty,
        questionCount: questionCount,
      );
      final currentList = state.value ?? [];
      state = AsyncValue.data([newQuiz, ...currentList]);
      return newQuiz;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    } finally {
      _isCreating = false;
    }
  }
}

class QuizPlayState {
  final bool isLoading;
  final bool isSubmitting;
  final QuizAttemptModel? attempt;
  final Map<String, String> selectedAnswers; // questionId -> selectedOption
  final int currentQuestionIndex;
  final String? errorMessage;
  final QuizSubmissionResult? result;

  const QuizPlayState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.attempt,
    this.selectedAnswers = const {},
    this.currentQuestionIndex = 0,
    this.errorMessage,
    this.result,
  });

  QuizPlayState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    QuizAttemptModel? attempt,
    Map<String, String>? selectedAnswers,
    int? currentQuestionIndex,
    String? errorMessage,
    QuizSubmissionResult? result,
    bool clearError = false,
  }) {
    return QuizPlayState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      attempt: attempt ?? this.attempt,
      selectedAnswers: selectedAnswers ?? this.selectedAnswers,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      result: result ?? this.result,
    );
  }
}

final quizPlayControllerProvider = NotifierProvider.autoDispose
    .family<QuizPlayController, QuizPlayState, String>(
      (arg) => QuizPlayController(arg),
    );

class QuizPlayController extends Notifier<QuizPlayState> {
  final String quizId;

  QuizPlayController(this.quizId);

  late final QuizRepository _repository;
  bool _isDisposed = false;

  @override
  QuizPlayState build() {
    _repository = ref.watch(quizRepositoryProvider);
    _isDisposed = false;
    ref.onDispose(() {
      _isDisposed = true;
    });

    Future.microtask(() {
      if (!_isDisposed) {
        _startAttempt();
      }
    });

    return const QuizPlayState(isLoading: true);
  }

  Future<void> retryStart() async {
    if (_isDisposed) return;
    state = state.copyWith(isLoading: true, clearError: true);
    await _startAttempt();
  }

  Future<void> _startAttempt() async {
    if (_isDisposed) return;
    try {
      final attempt = await _repository.startAttempt(quizId);
      if (_isDisposed) return;

      if (!attempt.isValid) {
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              'Quiz questions received are invalid or empty. Please regenerate the quiz.',
        );
        return;
      }
      state = state.copyWith(isLoading: false, attempt: attempt);
    } on ApiException catch (e) {
      if (_isDisposed) return;
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (e) {
      if (_isDisposed) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to start quiz attempt: $e',
      );
    }
  }

  void selectOption(String questionId, String option) {
    if (_isDisposed || state.isSubmitting || state.result != null) return;
    final updated = Map<String, String>.from(state.selectedAnswers);
    updated[questionId] = option;
    state = state.copyWith(selectedAnswers: updated);
  }

  void setQuestionIndex(int index) {
    if (_isDisposed) return;
    if (state.attempt != null &&
        index >= 0 &&
        index < state.attempt!.questions.length) {
      state = state.copyWith(currentQuestionIndex: index);
    }
  }

  Future<QuizSubmissionResult?> submit() async {
    if (_isDisposed) return null;
    final attempt = state.attempt;
    if (attempt == null || state.isSubmitting || state.result != null) {
      return null;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final responses = state.selectedAnswers.entries.map((e) {
        return {'questionId': e.key, 'selectedAnswer': e.value};
      }).toList();

      final result = await _repository.submitAttempt(
        attemptId: attempt.id,
        responses: responses,
      );

      if (_isDisposed) return result;
      state = state.copyWith(isSubmitting: false, result: result);
      return result;
    } on ApiException catch (e) {
      if (_isDisposed) return null;
      // Preserve user answers so attempt is recoverable
      state = state.copyWith(isSubmitting: false, errorMessage: e.message);
      return null;
    } catch (e) {
      if (_isDisposed) return null;
      state = state.copyWith(
        isSubmitting: false,
        errorMessage:
            'Network error submitting quiz. Answers are saved. Please retry.',
      );
      return null;
    }
  }
}
