import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_mate_frontend/core/network/api_client.dart';
import 'package:study_mate_frontend/core/theme/app_theme.dart';
import 'package:study_mate_frontend/features/study_plans/controllers/study_plan_controller.dart';
import 'package:study_mate_frontend/features/study_plans/models/study_plan_model.dart';
import 'package:study_mate_frontend/features/study_plans/repositories/study_plan_repository.dart';
import 'package:study_mate_frontend/features/study_plans/screens/study_plan_create_screen.dart';
import 'package:study_mate_frontend/features/study_plans/screens/study_plan_screen.dart';

class MockStudyPlanRepository implements StudyPlanRepository {
  @override
  ApiClient get apiClient => throw UnimplementedError();

  List<StudyPlanModel> plans;
  bool createCalled = false;
  bool regenerateCalled = false;
  bool updateStatusCalled = false;
  bool updateDetailsCalled = false;
  bool deleteTaskCalled = false;
  bool addTaskCalled = false;
  Object? errorToThrow;

  MockStudyPlanRepository({this.plans = const [], this.errorToThrow});

  @override
  Future<List<StudyPlanModel>> getStudyPlans() async {
    if (errorToThrow != null) throw errorToThrow!;
    return plans;
  }

  @override
  Future<StudyPlanModel> getStudyPlan(String planId) async {
    return plans.firstWhere((p) => p.id == planId);
  }

  @override
  Future<StudyPlanModel> createStudyPlan({
    required String title,
    DateTime? examDate,
    required int dailyMinutes,
    String timezone = 'Asia/Kolkata',
    required List<String> subjects,
    Map<String, dynamic>? preferences,
  }) async {
    createCalled = true;
    if (errorToThrow != null) throw errorToThrow!;
    final created = StudyPlanModel(
      id: 'plan-created-1',
      title: title,
      examDate: examDate,
      dailyMinutes: dailyMinutes,
      timezone: timezone,
      preferences: preferences,
      status: 'ACTIVE',
      createdAt: DateTime.now(),
      tasks: [
        StudyTaskModel(
          id: 'task-c1',
          planId: 'plan-created-1',
          title: 'Initial Concept Review',
          topic: subjects.isNotEmpty ? subjects.first : 'General',
          scheduledDate: DateTime.now(),
          durationMinutes: dailyMinutes,
          status: 'TODO',
        ),
      ],
    );
    plans = [created, ...plans];
    return created;
  }

  @override
  Future<StudyPlanModel> regenerateStudyPlan({
    required String planId,
    bool preserveCompleted = true,
    int? dailyMinutes,
    DateTime? examDate,
  }) async {
    regenerateCalled = true;
    if (errorToThrow != null) throw errorToThrow!;
    final current = plans.firstWhere((p) => p.id == planId);
    final preservedTasks = current.tasks.where((t) => t.isCompleted).toList();
    final newTasks = [
      ...preservedTasks,
      StudyTaskModel(
        id: 'task-regen-1',
        planId: planId,
        title: 'Recalculated Session',
        scheduledDate: DateTime.now().add(const Duration(days: 1)),
        durationMinutes: dailyMinutes ?? current.dailyMinutes,
        status: 'TODO',
      ),
    ];
    final updated = current.copyWith(
      dailyMinutes: dailyMinutes ?? current.dailyMinutes,
      tasks: newTasks,
    );
    plans = plans.map((p) => p.id == planId ? updated : p).toList();
    return updated;
  }

  @override
  Future<StudyTaskModel> updateTaskStatus({
    required String taskId,
    required String status,
  }) async {
    updateStatusCalled = true;
    if (errorToThrow != null) throw errorToThrow!;
    for (final plan in plans) {
      for (final task in plan.tasks) {
        if (task.id == taskId) {
          return task.copyWith(
            status: status,
            completedAt: status == 'COMPLETED' ? DateTime.now() : null,
          );
        }
      }
    }
    return StudyTaskModel(
      id: taskId,
      planId: 'p',
      title: 'Task',
      scheduledDate: DateTime.now(),
      durationMinutes: 30,
      status: status,
    );
  }

  @override
  Future<StudyTaskModel> updateTaskDetails({
    required String taskId,
    String? title,
    String? topic,
    int? durationMinutes,
    DateTime? scheduledDate,
  }) async {
    updateDetailsCalled = true;
    return StudyTaskModel(
      id: taskId,
      planId: 'p',
      title: title ?? 'Updated Title',
      topic: topic,
      scheduledDate: scheduledDate ?? DateTime.now(),
      durationMinutes: durationMinutes ?? 30,
      status: 'TODO',
    );
  }

  @override
  Future<StudyTaskModel> createTask({
    required String planId,
    required String title,
    String? topic,
    required DateTime scheduledDate,
    required int durationMinutes,
  }) async {
    addTaskCalled = true;
    return StudyTaskModel(
      id: 'task-added',
      planId: planId,
      title: title,
      topic: topic,
      scheduledDate: scheduledDate,
      durationMinutes: durationMinutes,
      status: 'TODO',
    );
  }

  @override
  Future<bool> deleteTask({required String taskId}) async {
    deleteTaskCalled = true;
    return true;
  }
}

Widget createTestApp({
  required Widget child,
  required MockStudyPlanRepository repository,
}) {
  return ProviderScope(
    overrides: [studyPlanRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(theme: AppTheme.darkTheme, home: child),
  );
}

void main() {
  group('StudyPlanScreen Widget Tests', () {
    testWidgets(
      'renders empty state when no plans exist and navigates to create screen',
      (tester) async {
        final repository = MockStudyPlanRepository(plans: []);

        await tester.pumpWidget(
          createTestApp(child: const StudyPlanScreen(), repository: repository),
        );
        await tester.pumpAndSettle();

        expect(find.text('Study Schedules'), findsOneWidget);
        expect(find.text('No study plans generated yet'), findsOneWidget);
        expect(find.text('Create Study Plan'), findsOneWidget);

        await tester.tap(find.text('Create Study Plan'));
        await tester.pumpAndSettle();

        expect(find.byType(StudyPlanCreateScreen), findsOneWidget);
      },
    );

    testWidgets(
      'renders active plan with progress bar, daily minutes, timezone, and tasks agenda',
      (tester) async {
        final now = DateTime.now();
        final samplePlan = StudyPlanModel(
          id: 'plan-main',
          title: 'Physics & Chemistry Finals',
          dailyMinutes: 60,
          timezone: 'Asia/Kolkata',
          examDate: DateTime(
            now.year,
            now.month,
            now.day,
          ).add(const Duration(days: 10)),
          status: 'ACTIVE',
          createdAt: now,
          tasks: [
            StudyTaskModel(
              id: 't1',
              planId: 'plan-main',
              title: 'Thermodynamics Laws',
              topic: 'Physics',
              scheduledDate: DateTime(now.year, now.month, now.day),
              durationMinutes: 45,
              status: 'TODO',
            ),
            StudyTaskModel(
              id: 't2',
              planId: 'plan-main',
              title: 'Organic Chemistry Reactions',
              topic: 'Chemistry',
              scheduledDate: DateTime(now.year, now.month, now.day),
              durationMinutes: 45,
              status: 'COMPLETED',
            ),
          ],
        );

        final repository = MockStudyPlanRepository(plans: [samplePlan]);

        await tester.pumpWidget(
          createTestApp(child: const StudyPlanScreen(), repository: repository),
        );
        await tester.pumpAndSettle();

        expect(find.text('Physics & Chemistry Finals'), findsOneWidget);
        expect(find.text('60 min/day'), findsOneWidget);
        expect(find.text('Asia/Kolkata'), findsOneWidget);
        expect(find.text('10 days until exam'), findsOneWidget);
        expect(find.text('Progress (1/2 completed)'), findsOneWidget);
        expect(find.text('50%'), findsOneWidget);

        // Verify tasks rendered with accessible status badges
        expect(find.text('Thermodynamics Laws'), findsOneWidget);
        expect(find.text('Organic Chemistry Reactions'), findsOneWidget);
        expect(find.text('To Do'), findsOneWidget);
        expect(find.text('Completed'), findsOneWidget);
        expect(
          find.byIcon(Icons.radio_button_unchecked_rounded),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      },
    );

    testWidgets('toggling task checkbox updates completion status', (
      tester,
    ) async {
      final now = DateTime.now();
      final samplePlan = StudyPlanModel(
        id: 'plan-toggle',
        title: 'Daily Action Test',
        dailyMinutes: 30,
        status: 'ACTIVE',
        createdAt: now,
        tasks: [
          StudyTaskModel(
            id: 't-toggle',
            planId: 'plan-toggle',
            title: 'Review Vocabulary List',
            scheduledDate: DateTime(now.year, now.month, now.day),
            durationMinutes: 30,
            status: 'TODO',
          ),
        ],
      );

      final repository = MockStudyPlanRepository(plans: [samplePlan]);

      await tester.pumpWidget(
        createTestApp(child: const StudyPlanScreen(), repository: repository),
      );
      await tester.pumpAndSettle();

      expect(find.text('To Do'), findsOneWidget);

      // Tap checkbox
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      expect(repository.updateStatusCalled, isTrue);
      expect(find.text('Completed'), findsOneWidget);
    });

    testWidgets(
      'regenerate button displays warning dialog protecting completed tasks',
      (tester) async {
        final now = DateTime.now();
        final samplePlan = StudyPlanModel(
          id: 'plan-regen-test',
          title: 'Regeneration Plan',
          dailyMinutes: 45,
          status: 'ACTIVE',
          createdAt: now,
          tasks: [
            StudyTaskModel(
              id: 't-done',
              planId: 'plan-regen-test',
              title: 'Finished Session',
              scheduledDate: DateTime(now.year, now.month, now.day),
              durationMinutes: 30,
              status: 'COMPLETED',
            ),
          ],
        );

        final repository = MockStudyPlanRepository(plans: [samplePlan]);

        await tester.pumpWidget(
          createTestApp(child: const StudyPlanScreen(), repository: repository),
        );
        await tester.pumpAndSettle();

        // Tap Regenerate text button in agenda header
        await tester.tap(find.text('Regenerate'));
        await tester.pumpAndSettle();

        // Verify warning dialog content
        expect(find.text('Regenerate Study Schedule?'), findsOneWidget);
        expect(
          find.text(
            'Regenerating will recalculate your upcoming study sessions according to your remaining time.\n\n'
            'Your 1 completed task(s) will be safely preserved.',
          ),
          findsOneWidget,
        );

        // Confirm regeneration
        await tester.tap(find.widgetWithText(ElevatedButton, 'Regenerate'));
        await tester.pumpAndSettle();

        expect(repository.regenerateCalled, isTrue);
        expect(
          find.text(
            'Study plan regenerated successfully! Completed tasks were preserved.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('supports switching active plan when multiple plans exist', (
      tester,
    ) async {
      final now = DateTime.now();
      final planA = StudyPlanModel(
        id: 'plan-a',
        title: 'Plan Alpha',
        dailyMinutes: 30,
        status: 'ACTIVE',
        createdAt: now,
        tasks: [],
      );
      final planB = StudyPlanModel(
        id: 'plan-b',
        title: 'Plan Beta',
        dailyMinutes: 60,
        status: 'ACTIVE',
        createdAt: now,
        tasks: [],
      );

      final repository = MockStudyPlanRepository(plans: [planA, planB]);

      await tester.pumpWidget(
        createTestApp(child: const StudyPlanScreen(), repository: repository),
      );
      await tester.pumpAndSettle();

      expect(find.text('Plan Alpha'), findsWidgets);

      // Select Plan Beta from dropdown
      await tester.tap(find.text('Plan Alpha').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Plan Beta').last);
      await tester.pumpAndSettle();

      expect(find.text('Plan Beta'), findsWidgets);
      expect(find.text('60 min/day'), findsOneWidget);
    });
  });

  group('StudyPlanCreateScreen Widget Tests', () {
    testWidgets('validates required plan title and subjects', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repository = MockStudyPlanRepository();

      await tester.pumpWidget(
        createTestApp(
          child: const StudyPlanCreateScreen(),
          repository: repository,
        ),
      );
      await tester.pumpAndSettle();

      // Submit with empty fields
      await tester.tap(find.text('Generate Study Schedule'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a name for your plan'), findsOneWidget);

      // Enter title, but empty subjects
      await tester.enterText(
        find.byType(TextFormField).first,
        'Midterms Study Schedule',
      );
      await tester.tap(find.text('Generate Study Schedule'));
      await tester.pumpAndSettle();

      expect(
        find.text('Please enter subjects or topics to study'),
        findsOneWidget,
      );
      expect(repository.createCalled, isFalse);
    });

    testWidgets(
      'creates study plan with title, subjects, timezone, daily minutes, and navigates back',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final repository = MockStudyPlanRepository();

        await tester.pumpWidget(
          createTestApp(
            child: const StudyPlanCreateScreen(),
            repository: repository,
          ),
        );
        await tester.pumpAndSettle();

        // Enter title
        await tester.enterText(
          find.byType(TextFormField).first,
          'Computer Science Midterms',
        );
        // Enter subjects
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'Data Structures, Algorithms, Databases',
        );

        // Select 1.5 hrs
        await tester.tap(find.text('1.5 hrs'));
        await tester.pumpAndSettle();

        // Select Advanced familiarity
        await tester.tap(find.text('Advanced'));
        await tester.pumpAndSettle();

        // Submit form
        await tester.tap(find.text('Generate Study Schedule'));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(repository.createCalled, isTrue);
      },
    );

    testWidgets('warns user before creating when an active plan already exists', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final existingPlan = StudyPlanModel(
        id: 'plan-existing',
        title: 'Current Active Plan',
        dailyMinutes: 60,
        status: 'ACTIVE',
        createdAt: DateTime.now(),
      );

      final repository = MockStudyPlanRepository(plans: [existingPlan]);

      await tester.pumpWidget(
        createTestApp(
          child: const StudyPlanCreateScreen(),
          repository: repository,
        ),
      );
      await tester.pumpAndSettle();

      // Fill in valid details
      await tester.enterText(
        find.byType(TextFormField).first,
        'Second Semester Schedule',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Physics, Chemistry',
      );

      // Tap generate
      await tester.tap(find.text('Generate Study Schedule'));
      await tester.pumpAndSettle();

      // Warning dialog appears
      expect(find.text('Existing Plan Detected'), findsOneWidget);
      expect(
        find.text(
          'You already have 1 study plan(s). Generating this new plan will save alongside your existing schedule. Do you wish to continue?',
        ),
        findsOneWidget,
      );

      // Cancel button rejects
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repository.createCalled, isFalse);

      // Tap generate again and confirm
      await tester.tap(find.text('Generate Study Schedule'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Plan'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(repository.createCalled, isTrue);
    });
  });
}
