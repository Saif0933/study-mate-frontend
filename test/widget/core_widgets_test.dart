import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_mate_frontend/core/widgets/app_button.dart';
import 'package:study_mate_frontend/core/widgets/empty_state_view.dart';
import 'package:study_mate_frontend/core/widgets/error_view.dart';
import 'package:study_mate_frontend/core/widgets/loading_view.dart';
import 'package:study_mate_frontend/core/widgets/status_badge.dart';

void main() {
  group('Core Reusable Widgets Tests', () {
    testWidgets('LoadingView displays custom message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingView(message: 'Generating study plan...'),
          ),
        ),
      );

      expect(find.text('Generating study plan...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets(
      'ErrorView displays message, code, and triggers retry callback',
      (tester) async {
        bool retried = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ErrorView(
                message: 'Rate limit reached. Please wait.',
                code: 'RATE_LIMITED',
                onRetry: () {
                  retried = true;
                },
              ),
            ),
          ),
        );

        expect(find.text('Rate limit reached. Please wait.'), findsOneWidget);
        expect(find.text('Code: RATE_LIMITED'), findsOneWidget);

        await tester.tap(find.text('Try Again'));
        expect(retried, isTrue);
      },
    );

    testWidgets(
      'EmptyStateView renders title, description, and action button',
      (tester) async {
        bool actionTapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EmptyStateView(
                icon: Icons.quiz_outlined,
                title: 'No quizzes yet',
                description: 'Create your first practice quiz.',
                actionText: 'Generate Quiz',
                onAction: () {
                  actionTapped = true;
                },
              ),
            ),
          ),
        );

        expect(find.text('No quizzes yet'), findsOneWidget);
        expect(find.text('Create your first practice quiz.'), findsOneWidget);

        await tester.tap(find.text('Generate Quiz'));
        expect(actionTapped, isTrue);
      },
    );

    testWidgets(
      'AppButton displays loading indicator and disables taps when loading',
      (tester) async {
        int tapCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AppButton(
                label: 'Submit',
                isLoading: true,
                onPressed: () {
                  tapCount++;
                },
              ),
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Submit'), findsNothing);

        await tester.tap(find.byType(AppButton));
        expect(tapCount, equals(0)); // Should not fire when loading
      },
    );

    testWidgets('StatusBadge renders accessible status and icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatusBadge(status: 'READY'),
                StatusBadge(status: 'PROCESSING'),
                StatusBadge(status: 'FAILED'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Ready'), findsOneWidget);
      expect(find.text('Processing'), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);
    });
  });
}
