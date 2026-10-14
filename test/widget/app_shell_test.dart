import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_mate_frontend/core/routing/app_shell.dart';
import 'package:study_mate_frontend/core/theme/app_theme.dart';
import 'package:study_mate_frontend/features/auth/controllers/auth_controller.dart';
import 'package:study_mate_frontend/features/auth/models/user_model.dart';

class MockAuthController extends AuthController {
  @override
  AuthState build() {
    return Authenticated(
      UserModel(
        id: 'u1',
        email: 'test@example.com',
        displayName: 'Test Learner',
        createdAt: DateTime.now(),
      ),
    );
  }
}

void main() {
  group('AppShell Widget Tests (Phase 1)', () {
    testWidgets(
      'Renders all bottom navigation destinations and default home screen',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authControllerProvider.overrideWith(MockAuthController.new),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const AppShell(),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verify destinations in navigation shell
        expect(find.text('Home'), findsWidgets);
        expect(find.text('AI Tutor'), findsWidgets);
        expect(find.text('Docs'), findsOneWidget);
        expect(find.text('Quiz'), findsWidgets);
        expect(find.text('Planner'), findsWidgets);
        expect(find.text('Settings'), findsOneWidget);

        // Verify Home content is initially visible
        expect(find.text('Quick Actions'), findsOneWidget);
        expect(find.text('Welcome back, Test Learner!'), findsOneWidget);
      },
    );

    testWidgets('Tapping on a bottom navigation item switches tabs', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(MockAuthController.new),
          ],
          child: MaterialApp(theme: AppTheme.darkTheme, home: const AppShell()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap on Settings tab
      await tester.tap(find.text('Settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Settings tab is active
      expect(find.text('Settings & Account'), findsOneWidget);
    });

    testWidgets(
      'Android PopScope navigates back to Home when invoked from another tab',
      (WidgetTester tester) async {
        final key = GlobalKey<AppShellState>();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authControllerProvider.overrideWith(MockAuthController.new),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: AppShell(key: key, initialTab: 3),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verify PopScope widget is present
        final popScopeFinder = find.byType(PopScope);
        expect(popScopeFinder, findsOneWidget);

        final popScopeWidget = tester.widget<PopScope>(popScopeFinder);
        // Because we are on tab 3, canPop is false (cannot pop root app yet)
        expect(popScopeWidget.canPop, false);

        // Programmatically invoke pop invoked callback
        popScopeWidget.onPopInvokedWithResult?.call(false, null);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Now should have switched back to Home tab
        final updatedPopScope = tester.widget<PopScope>(popScopeFinder);
        expect(updatedPopScope.canPop, true);
        expect(find.text('Quick Actions'), findsOneWidget);
      },
    );
  });
}
