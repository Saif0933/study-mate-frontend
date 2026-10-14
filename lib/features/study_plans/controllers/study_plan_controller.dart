import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../models/study_plan_model.dart';
import '../repositories/study_plan_repository.dart';

final studyPlanRepositoryProvider = Provider<StudyPlanRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return StudyPlanRepository(apiClient: apiClient);
});

final studyPlanControllerProvider =
    AsyncNotifierProvider<StudyPlanController, List<StudyPlanModel>>(() {
      return StudyPlanController();
    });

class StudyPlanController extends AsyncNotifier<List<StudyPlanModel>> {
  late final StudyPlanRepository _repository;
  bool _isCreating = false;
  bool _isRegenerating = false;

  bool get isCreating => _isCreating;
  bool get isRegenerating => _isRegenerating;

  @override
  Future<List<StudyPlanModel>> build() async {
    _repository = ref.watch(studyPlanRepositoryProvider);
    return await _repository.getStudyPlans();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.getStudyPlans());
  }

  /// Create a new personalized study plan with duplicate generation guard
  Future<StudyPlanModel?> createPlan({
    required String title,
    DateTime? examDate,
    required int dailyMinutes,
    String timezone = 'Asia/Kolkata',
    required List<String> subjects,
    Map<String, dynamic>? preferences,
  }) async {
    if (_isCreating) return null;
    _isCreating = true;

    try {
      final newPlan = await _repository.createStudyPlan(
        title: title,
        examDate: examDate,
        dailyMinutes: dailyMinutes,
        timezone: timezone,
        subjects: subjects,
        preferences: preferences,
      );
      final currentList = state.value ?? [];
      state = AsyncValue.data([newPlan, ...currentList]);
      return newPlan;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    } finally {
      _isCreating = false;
    }
  }

  /// Regenerate an existing plan while preserving completed tasks
  Future<StudyPlanModel?> regeneratePlan({
    required String planId,
    bool preserveCompleted = true,
    int? dailyMinutes,
    DateTime? examDate,
  }) async {
    if (_isRegenerating) return null;
    _isRegenerating = true;

    try {
      final updatedPlan = await _repository.regenerateStudyPlan(
        planId: planId,
        preserveCompleted: preserveCompleted,
        dailyMinutes: dailyMinutes,
        examDate: examDate,
      );

      final currentPlans = state.value ?? [];
      final updatedList = currentPlans.map((plan) {
        if (plan.id == planId) {
          return updatedPlan;
        }
        return plan;
      }).toList();

      state = AsyncValue.data(updatedList);
      return updatedPlan;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    } finally {
      _isRegenerating = false;
    }
  }

  /// Toggle or update task completion / status
  Future<bool> updateTaskStatus({
    required String planId,
    required String taskId,
    required String newStatus,
  }) async {
    final currentPlans = state.value ?? [];
    final planExists = currentPlans.any((p) => p.id == planId);
    if (!planExists) return false;

    // Optimistically update
    final updatedPlans = currentPlans.map((plan) {
      if (plan.id == planId) {
        final updatedTasks = plan.tasks.map((task) {
          if (task.id == taskId) {
            return task.copyWith(
              status: newStatus,
              completedAt: newStatus == 'COMPLETED' ? DateTime.now() : null,
            );
          }
          return task;
        }).toList();

        return plan.copyWith(tasks: updatedTasks);
      }
      return plan;
    }).toList();

    state = AsyncValue.data(updatedPlans);

    try {
      final serverTask = await _repository.updateTaskStatus(
        taskId: taskId,
        status: newStatus,
      );

      // Re-sync with exact server response
      final syncedPlans = (state.value ?? []).map((plan) {
        if (plan.id == planId) {
          final tasks = plan.tasks.map((t) {
            return t.id == taskId ? serverTask : t;
          }).toList();
          return plan.copyWith(tasks: tasks);
        }
        return plan;
      }).toList();
      state = AsyncValue.data(syncedPlans);
      return true;
    } catch (e) {
      // Rollback to original state on failure
      state = AsyncValue.data(currentPlans);
      return false;
    }
  }

  /// Toggle task between TODO and COMPLETED
  Future<void> toggleTaskCompletion({
    required String planId,
    required String taskId,
    required bool currentCompleted,
  }) async {
    final nextStatus = currentCompleted ? 'TODO' : 'COMPLETED';
    await updateTaskStatus(
      planId: planId,
      taskId: taskId,
      newStatus: nextStatus,
    );
  }

  /// Skip a task
  Future<bool> skipTask({
    required String planId,
    required String taskId,
  }) async {
    return await updateTaskStatus(
      planId: planId,
      taskId: taskId,
      newStatus: 'SKIPPED',
    );
  }

  /// Edit task details (title, topic, duration)
  Future<bool> editTaskDetails({
    required String planId,
    required String taskId,
    required String title,
    String? topic,
    required int durationMinutes,
    DateTime? scheduledDate,
  }) async {
    final currentPlans = state.value ?? [];

    // Optimistically update
    final updatedPlans = currentPlans.map((plan) {
      if (plan.id == planId) {
        final updatedTasks = plan.tasks.map((task) {
          if (task.id == taskId) {
            return task.copyWith(
              title: title,
              topic: topic,
              durationMinutes: durationMinutes,
              scheduledDate: scheduledDate,
            );
          }
          return task;
        }).toList();
        return plan.copyWith(tasks: updatedTasks);
      }
      return plan;
    }).toList();

    state = AsyncValue.data(updatedPlans);

    try {
      final updated = await _repository.updateTaskDetails(
        taskId: taskId,
        title: title,
        topic: topic,
        durationMinutes: durationMinutes,
        scheduledDate: scheduledDate,
      );

      final synced = (state.value ?? []).map((plan) {
        if (plan.id == planId) {
          final tasks = plan.tasks
              .map((t) => t.id == taskId ? updated : t)
              .toList();
          return plan.copyWith(tasks: tasks);
        }
        return plan;
      }).toList();
      state = AsyncValue.data(synced);
      return true;
    } catch (_) {
      state = AsyncValue.data(currentPlans);
      return false;
    }
  }

  /// Add custom task to plan
  Future<StudyTaskModel?> addTask({
    required String planId,
    required String title,
    String? topic,
    required DateTime scheduledDate,
    required int durationMinutes,
  }) async {
    try {
      final newTask = await _repository.createTask(
        planId: planId,
        title: title,
        topic: topic,
        scheduledDate: scheduledDate,
        durationMinutes: durationMinutes,
      );

      final currentPlans = state.value ?? [];
      final updatedList = currentPlans.map((plan) {
        if (plan.id == planId) {
          return plan.copyWith(tasks: [...plan.tasks, newTask]);
        }
        return plan;
      }).toList();

      state = AsyncValue.data(updatedList);
      return newTask;
    } catch (_) {
      return null;
    }
  }

  /// Delete a task
  Future<bool> deleteTask({
    required String planId,
    required String taskId,
  }) async {
    final currentPlans = state.value ?? [];
    final updatedPlans = currentPlans.map((plan) {
      if (plan.id == planId) {
        return plan.copyWith(
          tasks: plan.tasks.where((t) => t.id != taskId).toList(),
        );
      }
      return plan;
    }).toList();

    state = AsyncValue.data(updatedPlans);

    try {
      await _repository.deleteTask(taskId: taskId);
      return true;
    } catch (_) {
      state = AsyncValue.data(currentPlans);
      return false;
    }
  }
}
