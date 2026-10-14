import '../../../core/network/api_client.dart';
import '../models/study_plan_model.dart';

class StudyPlanRepository {
  final ApiClient apiClient;

  StudyPlanRepository({required this.apiClient});

  /// Fetch user's study plans
  Future<List<StudyPlanModel>> getStudyPlans() async {
    final response = await apiClient.get('/study-plans');
    if (response is List) {
      return response
          .map((item) => StudyPlanModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } else if (response is Map<String, dynamic>) {
      final list =
          response['studyPlans'] ?? response['items'] ?? response['data'];
      if (list is List) {
        return list
            .map(
              (item) => StudyPlanModel.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      }
    }
    return [];
  }

  /// Fetch single study plan details
  Future<StudyPlanModel> getStudyPlan(String planId) async {
    final response = await apiClient.get('/study-plans/$planId');
    return StudyPlanModel.fromJson(response as Map<String, dynamic>);
  }

  /// Generate a tailored study plan with structured tasks
  Future<StudyPlanModel> createStudyPlan({
    required String title,
    DateTime? examDate,
    required int dailyMinutes,
    String timezone = 'Asia/Kolkata',
    required List<String> subjects,
    Map<String, dynamic>? preferences,
  }) async {
    final response = await apiClient.post(
      '/study-plans',
      data: {
        'title': title,
        if (examDate != null)
          'examDate':
              '${examDate.year.toString().padLeft(4, '0')}-${examDate.month.toString().padLeft(2, '0')}-${examDate.day.toString().padLeft(2, '0')}',
        'dailyMinutes': dailyMinutes,
        'timezone': timezone,
        'subjects': subjects,
        'preferences': ?preferences,
      },
    );
    return StudyPlanModel.fromJson(response as Map<String, dynamic>);
  }

  /// Regenerate an existing plan while preserving completed tasks
  Future<StudyPlanModel> regenerateStudyPlan({
    required String planId,
    bool preserveCompleted = true,
    int? dailyMinutes,
    DateTime? examDate,
  }) async {
    final response = await apiClient.post(
      '/study-plans/$planId/regenerate',
      data: {
        'preserveCompleted': preserveCompleted,
        'dailyMinutes': ?dailyMinutes,
        if (examDate != null)
          'examDate':
              '${examDate.year.toString().padLeft(4, '0')}-${examDate.month.toString().padLeft(2, '0')}-${examDate.day.toString().padLeft(2, '0')}',
      },
    );
    return StudyPlanModel.fromJson(response as Map<String, dynamic>);
  }

  /// Update task status (e.g. TODO, IN_PROGRESS, COMPLETED, SKIPPED)
  Future<StudyTaskModel> updateTaskStatus({
    required String taskId,
    required String status,
  }) async {
    final response = await apiClient.patch(
      '/study-tasks/$taskId',
      data: {
        'status': status,
        if (status == 'COMPLETED')
          'completedAt': DateTime.now().toIso8601String(),
        if (status != 'COMPLETED') 'completedAt': null,
      },
    );
    return StudyTaskModel.fromJson(response as Map<String, dynamic>);
  }

  /// Edit task details (title, topic, duration, date)
  Future<StudyTaskModel> updateTaskDetails({
    required String taskId,
    String? title,
    String? topic,
    int? durationMinutes,
    DateTime? scheduledDate,
  }) async {
    final response = await apiClient.patch(
      '/study-tasks/$taskId',
      data: {
        'title': ?title,
        'topic': ?topic,
        'durationMinutes': ?durationMinutes,
        if (scheduledDate != null)
          'scheduledDate':
              '${scheduledDate.year.toString().padLeft(4, '0')}-${scheduledDate.month.toString().padLeft(2, '0')}-${scheduledDate.day.toString().padLeft(2, '0')}',
      },
    );
    return StudyTaskModel.fromJson(response as Map<String, dynamic>);
  }

  /// Add a custom or ad-hoc task to a plan
  Future<StudyTaskModel> createTask({
    required String planId,
    required String title,
    String? topic,
    required DateTime scheduledDate,
    required int durationMinutes,
  }) async {
    final response = await apiClient.post(
      '/study-plans/$planId/tasks',
      data: {
        'title': title,
        'topic': ?topic,
        'scheduledDate':
            '${scheduledDate.year.toString().padLeft(4, '0')}-${scheduledDate.month.toString().padLeft(2, '0')}-${scheduledDate.day.toString().padLeft(2, '0')}',
        'durationMinutes': durationMinutes,
      },
    );
    return StudyTaskModel.fromJson(response as Map<String, dynamic>);
  }

  /// Delete a task
  Future<bool> deleteTask({required String taskId}) async {
    await apiClient.delete('/study-tasks/$taskId');
    return true;
  }
}
