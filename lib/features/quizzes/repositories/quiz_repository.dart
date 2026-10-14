import '../../../core/network/api_client.dart';
import '../models/quiz_model.dart';

class QuizRepository {
  final ApiClient apiClient;

  QuizRepository({required this.apiClient});

  /// Fetch user's generated quizzes
  Future<List<QuizModel>> getQuizzes() async {
    final response = await apiClient.get('/quizzes');
    if (response is List) {
      return response
          .map((item) => QuizModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } else if (response is Map<String, dynamic>) {
      final list = response['quizzes'] ?? response['items'] ?? response['data'];
      if (list is List) {
        return list
            .map((item) => QuizModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    }
    return [];
  }

  /// Fetch single quiz details
  Future<QuizModel> getQuiz(String quizId) async {
    final response = await apiClient.get('/quizzes/$quizId');
    return QuizModel.fromJson(response as Map<String, dynamic>);
  }

  /// Generate a new quiz from a topic or an uploaded ready PDF document
  Future<QuizModel> createQuiz({
    required String title,
    String? topic,
    String? sourceDocumentId,
    String difficulty = 'MEDIUM',
    int questionCount = 5,
  }) async {
    final response = await apiClient.post(
      '/quizzes',
      data: {
        'title': title,
        if (topic != null && topic.trim().isNotEmpty) 'topic': topic.trim(),
        if (sourceDocumentId != null && sourceDocumentId.trim().isNotEmpty)
          'sourceDocumentId': sourceDocumentId.trim(),
        'difficulty': difficulty,
        'questionCount': questionCount,
      },
    );
    return QuizModel.fromJson(response as Map<String, dynamic>);
  }

  /// Start a quiz attempt and receive questions with answer keys masked
  Future<QuizAttemptModel> startAttempt(String quizId) async {
    final response = await apiClient.post('/quizzes/$quizId/attempts');
    return QuizAttemptModel.fromJson(response as Map<String, dynamic>);
  }

  /// Submit quiz responses and receive calculated score with explanations
  Future<QuizSubmissionResult> submitAttempt({
    required String attemptId,
    required List<Map<String, dynamic>> responses,
  }) async {
    final response = await apiClient.post(
      '/quiz-attempts/$attemptId/submit',
      data: {'responses': responses},
    );
    return QuizSubmissionResult.fromJson(response as Map<String, dynamic>);
  }

  /// Fetch past attempt review/results
  Future<QuizSubmissionResult> getAttempt(String attemptId) async {
    final response = await apiClient.get('/quiz-attempts/$attemptId');
    return QuizSubmissionResult.fromJson(response as Map<String, dynamic>);
  }
}
