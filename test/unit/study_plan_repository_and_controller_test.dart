import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_mate_frontend/core/network/api_client.dart';
import 'package:study_mate_frontend/core/network/api_exceptions.dart';
import 'package:study_mate_frontend/features/study_plans/controllers/study_plan_controller.dart';
import 'package:study_mate_frontend/features/study_plans/models/study_plan_model.dart';
import 'package:study_mate_frontend/features/study_plans/repositories/study_plan_repository.dart';

class FakeApiClient extends Fake implements ApiClient {
  final Map<String, dynamic> responses = {};
  final Map<String, ApiException> errors = {};
  int postCallCount = 0;
  dynamic lastPostData;
  String? lastPostPath;
  int patchCallCount = 0;
  dynamic lastPatchData;
  String? lastPatchPath;
  int deleteCallCount = 0;
  String? lastDeletePath;

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

  @override
  Future<dynamic> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    patchCallCount++;
    lastPatchPath = path;
    lastPatchData = data;
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
    deleteCallCount++;
    lastDeletePath = path;
    if (errors.containsKey(path)) {
      throw errors[path]!;
    }
    return responses[path];
  }
}

void main() {
  group('Study Plan Models & Timezone Date Handling Tests', () {
    test('StudyPlanModel parses from JSON correctly with tasks', () {
      final json = {
        'id': 'plan-10',
        'title': 'Calculus & Mechanics Finals',
        'examDate': '2026-11-20',
        'dailyMinutes': 90,
        'timezone': 'Asia/Kolkata',
        'status': 'ACTIVE',
        'createdAt': '2026-10-13T10:00:00.000Z',
        'tasks': [
          {
            'id': 'task-1',
            'planId': 'plan-10',
            'title': 'Integration by Parts Practice',
            'topic': 'Calculus',
            'scheduledDate': '2026-10-15T00:00:00.000Z',
            'durationMinutes': 45,
            'status': 'COMPLETED',
            'orderIndex': 0,
            'completedAt': '2026-10-15T16:30:00.000Z',
          },
          {
            'id': 'task-2',
            'planId': 'plan-10',
            'title': 'Newtonian Mechanics Review',
            'topic': 'Physics',
            'scheduledDate': '2026-10-16',
            'durationMinutes': 45,
            'status': 'TODO',
            'orderIndex': 1,
          },
        ],
      };

      final plan = StudyPlanModel.fromJson(json);
      expect(plan.id, 'plan-10');
      expect(plan.title, 'Calculus & Mechanics Finals');
      expect(plan.dailyMinutes, 90);
      expect(plan.timezone, 'Asia/Kolkata');
      expect(plan.tasks.length, 2);
      expect(plan.completedTaskCount, 1);
      expect(plan.completionProgress, 0.5);
      expect(plan.isCompleted, isFalse);

      expect(plan.tasks[0].isCompleted, isTrue);
      expect(plan.tasks[0].statusLabel, 'Completed');
      expect(plan.tasks[1].isTodo, isTrue);
      expect(plan.tasks[1].statusLabel, 'To Do');
    });

    test('parseDateSafe prevents timezone day-shifting across timezones', () {
      // UTC midnight string
      final utcMidnight = '2026-10-15T00:00:00.000Z';
      final parsedDate1 = StudyTaskModel.parseDateSafe(utcMidnight);
      expect(parsedDate1.year, 2026);
      expect(parsedDate1.month, 10);
      expect(parsedDate1.day, 15);

      // Date-only string
      final dateOnly = '2026-10-15';
      final parsedDate2 = StudyTaskModel.parseDateSafe(dateOnly);
      expect(parsedDate2.year, 2026);
      expect(parsedDate2.month, 10);
      expect(parsedDate2.day, 15);

      // JSON formatting produces consistent YYYY-MM-DD
      final task = StudyTaskModel(
        id: 'task-test',
        planId: 'plan-test',
        title: 'Safe Date Task',
        scheduledDate: parsedDate1,
        durationMinutes: 30,
        status: 'TODO',
      );
      final json = task.toJson();
      expect(json['scheduledDate'], '2026-10-15');
    });

    test('tasksGroupedByDate groups tasks chronologically by calendar day', () {
      final tasks = [
        StudyTaskModel(
          id: 't1',
          planId: 'p1',
          title: 'Task A',
          scheduledDate: DateTime(2026, 10, 16),
          durationMinutes: 30,
          status: 'TODO',
          orderIndex: 0,
        ),
        StudyTaskModel(
          id: 't2',
          planId: 'p1',
          title: 'Task B',
          scheduledDate: DateTime(2026, 10, 15),
          durationMinutes: 45,
          status: 'COMPLETED',
          orderIndex: 0,
        ),
        StudyTaskModel(
          id: 't3',
          planId: 'p1',
          title: 'Task C',
          scheduledDate: DateTime(2026, 10, 15),
          durationMinutes: 30,
          status: 'TODO',
          orderIndex: 1,
        ),
      ];

      final plan = StudyPlanModel(
        id: 'p1',
        title: 'Grouping Test',
        dailyMinutes: 60,
        status: 'ACTIVE',
        createdAt: DateTime.now(),
        tasks: tasks,
      );

      final grouped = plan.tasksGroupedByDate;
      expect(grouped.length, 2);

      final day15 = DateTime(2026, 10, 15);
      final day16 = DateTime(2026, 10, 16);

      expect(grouped.containsKey(day15), isTrue);
      expect(grouped.containsKey(day16), isTrue);
      expect(grouped[day15]!.length, 2);
      expect(grouped[day15]![0].title, 'Task B');
      expect(grouped[day15]![1].title, 'Task C');
      expect(grouped[day16]!.length, 1);
    });
  });

  group('StudyPlanRepository Unit Tests', () {
    test('getStudyPlans parses plans from backend response list', () async {
      final apiClient = FakeApiClient();
      final repository = StudyPlanRepository(apiClient: apiClient);

      apiClient.responses['/study-plans'] = [
        {
          'id': 'plan-1',
          'title': 'AI Course Schedule',
          'dailyMinutes': 60,
          'timezone': 'Asia/Kolkata',
          'status': 'ACTIVE',
          'createdAt': '2026-10-10T08:00:00.000Z',
          'tasks': [],
        },
      ];

      final result = await repository.getStudyPlans();
      expect(result.length, 1);
      expect(result.first.title, 'AI Course Schedule');
    });

    test(
      'createStudyPlan posts valid constraints payload to /study-plans',
      () async {
        final apiClient = FakeApiClient();
        final repository = StudyPlanRepository(apiClient: apiClient);

        apiClient.responses['/study-plans'] = {
          'id': 'plan-generated',
          'title': 'Biology Midterms',
          'examDate': '2026-11-01',
          'dailyMinutes': 45,
          'timezone': 'Asia/Kolkata',
          'status': 'ACTIVE',
          'createdAt': '2026-10-13T10:00:00.000Z',
          'tasks': [
            {
              'id': 't1',
              'planId': 'plan-generated',
              'title': 'Cell Respiration Review',
              'scheduledDate': '2026-10-14',
              'durationMinutes': 45,
              'status': 'TODO',
            },
          ],
        };

        final plan = await repository.createStudyPlan(
          title: 'Biology Midterms',
          examDate: DateTime(2026, 11, 1),
          dailyMinutes: 45,
          timezone: 'Asia/Kolkata',
          subjects: ['Cell Respiration', 'Photosynthesis'],
          preferences: {'confidenceLevel': 'BEGINNER'},
        );

        expect(apiClient.lastPostPath, '/study-plans');
        expect(apiClient.lastPostData['title'], 'Biology Midterms');
        expect(apiClient.lastPostData['dailyMinutes'], 45);
        expect(apiClient.lastPostData['examDate'], '2026-11-01');
        expect(apiClient.lastPostData['subjects'], [
          'Cell Respiration',
          'Photosynthesis',
        ]);
        expect(plan.id, 'plan-generated');
        expect(plan.tasks.length, 1);
      },
    );

    test(
      'regenerateStudyPlan posts to /study-plans/:id/regenerate preserving completed tasks',
      () async {
        final apiClient = FakeApiClient();
        final repository = StudyPlanRepository(apiClient: apiClient);

        apiClient.responses['/study-plans/plan-10/regenerate'] = {
          'id': 'plan-10',
          'title': 'Updated Biology Midterms',
          'dailyMinutes': 60,
          'status': 'ACTIVE',
          'createdAt': '2026-10-13T10:00:00.000Z',
          'tasks': [
            {
              'id': 't1',
              'planId': 'plan-10',
              'title': 'Preserved Completed Task',
              'scheduledDate': '2026-10-13',
              'durationMinutes': 30,
              'status': 'COMPLETED',
            },
            {
              'id': 't2-new',
              'planId': 'plan-10',
              'title': 'Regenerated Task',
              'scheduledDate': '2026-10-14',
              'durationMinutes': 60,
              'status': 'TODO',
            },
          ],
        };

        final updated = await repository.regenerateStudyPlan(
          planId: 'plan-10',
          preserveCompleted: true,
          dailyMinutes: 60,
        );

        expect(apiClient.lastPostPath, '/study-plans/plan-10/regenerate');
        expect(apiClient.lastPostData['preserveCompleted'], isTrue);
        expect(apiClient.lastPostData['dailyMinutes'], 60);
        expect(updated.tasks.length, 2);
        expect(updated.completedTaskCount, 1);
      },
    );

    test('updateTaskStatus sends PATCH request with completedAt', () async {
      final apiClient = FakeApiClient();
      final repository = StudyPlanRepository(apiClient: apiClient);

      apiClient.responses['/study-tasks/task-5'] = {
        'id': 'task-5',
        'planId': 'plan-1',
        'title': 'Practice Problems',
        'scheduledDate': '2026-10-15',
        'durationMinutes': 30,
        'status': 'COMPLETED',
        'completedAt': '2026-10-15T12:00:00.000Z',
      };

      final updated = await repository.updateTaskStatus(
        taskId: 'task-5',
        status: 'COMPLETED',
      );

      expect(apiClient.lastPatchPath, '/study-tasks/task-5');
      expect(apiClient.lastPatchData['status'], 'COMPLETED');
      expect(apiClient.lastPatchData['completedAt'], isNotNull);
      expect(updated.isCompleted, isTrue);
    });
  });

  group('StudyPlanController Unit Tests', () {
    test('createPlan prevents duplicate concurrent submission', () async {
      final apiClient = FakeApiClient();
      final repository = StudyPlanRepository(apiClient: apiClient);

      apiClient.responses['/study-plans'] = [];

      final container = ProviderContainer(
        overrides: [studyPlanRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final controller = container.read(studyPlanControllerProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      apiClient.responses['/study-plans'] = {
        'id': 'plan-new',
        'title': 'Single Submit Plan',
        'dailyMinutes': 60,
        'status': 'ACTIVE',
        'createdAt': '2026-10-13T10:00:00.000Z',
        'tasks': [],
      };

      // Launch first creation
      final future1 = controller.createPlan(
        title: 'Single Submit Plan',
        dailyMinutes: 60,
        subjects: ['Math'],
      );

      // Attempt second creation concurrently while first is in-flight
      final future2 = controller.createPlan(
        title: 'Duplicate Attempt',
        dailyMinutes: 60,
        subjects: ['Math'],
      );

      final results = await Future.wait([future1, future2]);
      expect(results[0], isNotNull);
      expect(results[1], isNull); // Blocked by _isCreating lock!
      expect(apiClient.postCallCount, 1);
    });

    test('regeneratePlan updates plan and preserves completed tasks', () async {
      final apiClient = FakeApiClient();
      final repository = StudyPlanRepository(apiClient: apiClient);

      apiClient.responses['/study-plans'] = [
        {
          'id': 'plan-reg',
          'title': 'Original Plan',
          'dailyMinutes': 30,
          'status': 'ACTIVE',
          'createdAt': '2026-10-10T10:00:00.000Z',
          'tasks': [
            {
              'id': 't-done',
              'planId': 'plan-reg',
              'title': 'Completed Task',
              'scheduledDate': '2026-10-10',
              'durationMinutes': 30,
              'status': 'COMPLETED',
            },
          ],
        },
      ];

      final container = ProviderContainer(
        overrides: [studyPlanRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final controller = container.read(studyPlanControllerProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      var state = container.read(studyPlanControllerProvider).value!;
      expect(state.first.completedTaskCount, 1);

      // Setup response for regeneration
      apiClient.responses['/study-plans/plan-reg/regenerate'] = {
        'id': 'plan-reg',
        'title': 'Original Plan',
        'dailyMinutes': 45,
        'status': 'ACTIVE',
        'createdAt': '2026-10-10T10:00:00.000Z',
        'tasks': [
          {
            'id': 't-done',
            'planId': 'plan-reg',
            'title': 'Completed Task',
            'scheduledDate': '2026-10-10',
            'durationMinutes': 30,
            'status': 'COMPLETED',
          },
          {
            'id': 't-new',
            'planId': 'plan-reg',
            'title': 'Newly Generated Task',
            'scheduledDate': '2026-10-14',
            'durationMinutes': 45,
            'status': 'TODO',
          },
        ],
      };

      final regenerated = await controller.regeneratePlan(
        planId: 'plan-reg',
        preserveCompleted: true,
      );

      expect(regenerated, isNotNull);
      expect(regenerated!.tasks.length, 2);
      expect(regenerated.completedTaskCount, 1); // Preserved!

      state = container.read(studyPlanControllerProvider).value!;
      expect(state.first.tasks.length, 2);
    });

    test(
      'updateTaskStatus optimistically updates task and rolls back on failure',
      () async {
        final apiClient = FakeApiClient();
        final repository = StudyPlanRepository(apiClient: apiClient);

        apiClient.responses['/study-plans'] = [
          {
            'id': 'plan-roll',
            'title': 'Rollback Plan',
            'dailyMinutes': 30,
            'status': 'ACTIVE',
            'createdAt': '2026-10-10T10:00:00.000Z',
            'tasks': [
              {
                'id': 'task-roll',
                'planId': 'plan-roll',
                'title': 'Target Task',
                'scheduledDate': '2026-10-10',
                'durationMinutes': 30,
                'status': 'TODO',
              },
            ],
          },
        ];

        final container = ProviderContainer(
          overrides: [
            studyPlanRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(studyPlanControllerProvider.notifier);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // Network error on PATCH
        apiClient.errors['/study-tasks/task-roll'] = ApiException(
          code: 'NETWORK_ERROR',
          message: 'Failed to reach server.',
        );

        final success = await controller.updateTaskStatus(
          planId: 'plan-roll',
          taskId: 'task-roll',
          newStatus: 'COMPLETED',
        );

        expect(success, isFalse);

        // Verify state was rolled back to TODO
        final state = container.read(studyPlanControllerProvider).value!;
        expect(state.first.tasks.first.isCompleted, isFalse);
        expect(state.first.tasks.first.status, 'TODO');
      },
    );

    test(
      'editTaskDetails, skipTask, and deleteTask update state properly',
      () async {
        final apiClient = FakeApiClient();
        final repository = StudyPlanRepository(apiClient: apiClient);

        apiClient.responses['/study-plans'] = [
          {
            'id': 'plan-crud',
            'title': 'CRUD Plan',
            'dailyMinutes': 30,
            'status': 'ACTIVE',
            'createdAt': '2026-10-10T10:00:00.000Z',
            'tasks': [
              {
                'id': 't1',
                'planId': 'plan-crud',
                'title': 'Initial Title',
                'scheduledDate': '2026-10-10',
                'durationMinutes': 30,
                'status': 'TODO',
              },
            ],
          },
        ];

        final container = ProviderContainer(
          overrides: [
            studyPlanRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(studyPlanControllerProvider.notifier);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // Edit task
        apiClient.responses['/study-tasks/t1'] = {
          'id': 't1',
          'planId': 'plan-crud',
          'title': 'Updated Title',
          'topic': 'New Topic',
          'scheduledDate': '2026-10-10',
          'durationMinutes': 45,
          'status': 'TODO',
        };

        final editOk = await controller.editTaskDetails(
          planId: 'plan-crud',
          taskId: 't1',
          title: 'Updated Title',
          topic: 'New Topic',
          durationMinutes: 45,
        );
        expect(editOk, isTrue);

        var state = container.read(studyPlanControllerProvider).value!;
        expect(state.first.tasks.first.title, 'Updated Title');
        expect(state.first.tasks.first.durationMinutes, 45);

        // Skip task
        apiClient.responses['/study-tasks/t1'] = {
          'id': 't1',
          'planId': 'plan-crud',
          'title': 'Updated Title',
          'scheduledDate': '2026-10-10',
          'durationMinutes': 45,
          'status': 'SKIPPED',
        };

        final skipOk = await controller.skipTask(
          planId: 'plan-crud',
          taskId: 't1',
        );
        expect(skipOk, isTrue);

        state = container.read(studyPlanControllerProvider).value!;
        expect(state.first.tasks.first.isSkipped, isTrue);

        // Delete task
        apiClient.responses['/study-tasks/t1'] = true;
        final delOk = await controller.deleteTask(
          planId: 'plan-crud',
          taskId: 't1',
        );
        expect(delOk, isTrue);

        state = container.read(studyPlanControllerProvider).value!;
        expect(state.first.tasks.isEmpty, isTrue);
      },
    );
  });
}
