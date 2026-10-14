import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_mate_frontend/core/routing/app_router.dart';
import 'package:study_mate_frontend/core/routing/app_shell.dart';
import 'package:study_mate_frontend/core/routing/route_names.dart';
import 'package:study_mate_frontend/core/widgets/app_placeholder_screen.dart';
import 'package:study_mate_frontend/features/auth/screens/forgot_password_screen.dart';
import 'package:study_mate_frontend/features/auth/screens/login_screen.dart';
import 'package:study_mate_frontend/features/auth/screens/register_screen.dart';
import 'package:study_mate_frontend/features/auth/screens/reset_password_screen.dart';
import 'package:study_mate_frontend/features/auth/screens/welcome_screen.dart';
import 'package:study_mate_frontend/features/documents/models/document_model.dart';
import 'package:study_mate_frontend/features/documents/screens/document_chat_screen.dart';
import 'package:study_mate_frontend/features/tutor/models/conversation_model.dart';
import 'package:study_mate_frontend/features/tutor/screens/chat_screen.dart';

class _FakeBuildContext extends Fake implements BuildContext {}

void main() {
  group('Route Names and AppRouter Tests (Phase 1)', () {
    final fakeContext = _FakeBuildContext();

    test('AppRoutes defines all required named routes', () {
      expect(AppRoutes.welcome, '/welcome');
      expect(AppRoutes.login, '/login');
      expect(AppRoutes.register, '/register');
      expect(AppRoutes.home, '/home');
      expect(AppRoutes.chat, '/chat');
      expect(AppRoutes.documents, '/documents');
      expect(AppRoutes.pdfChat, '/pdf-chat');
      expect(AppRoutes.quiz, '/quiz');
      expect(AppRoutes.studyPlanner, '/study-planner');
      expect(AppRoutes.settings, '/settings');
    });

    test('Generates route for Welcome screen', () {
      final route =
          AppRouter.onGenerateRoute(
                const RouteSettings(name: AppRoutes.welcome),
              )
              as MaterialPageRoute;

      expect(route.builder(fakeContext), isA<WelcomeScreen>());
    });

    test('Generates route for Login and Register screens', () {
      final loginRoute =
          AppRouter.onGenerateRoute(const RouteSettings(name: AppRoutes.login))
              as MaterialPageRoute;
      expect(loginRoute.builder(fakeContext), isA<LoginScreen>());

      final registerRoute =
          AppRouter.onGenerateRoute(
                const RouteSettings(name: AppRoutes.register),
              )
              as MaterialPageRoute;
      expect(registerRoute.builder(fakeContext), isA<RegisterScreen>());
    });

    test('Generates route for Forgot Password and Reset Password screens', () {
      final forgotRoute =
          AppRouter.onGenerateRoute(
                const RouteSettings(name: AppRoutes.forgotPassword),
              )
              as MaterialPageRoute;
      expect(forgotRoute.builder(fakeContext), isA<ForgotPasswordScreen>());

      final resetRoute =
          AppRouter.onGenerateRoute(
                const RouteSettings(
                  name: AppRoutes.resetPassword,
                  arguments: 'sample-token',
                ),
              )
              as MaterialPageRoute;
      final resetWidget =
          resetRoute.builder(fakeContext) as ResetPasswordScreen;
      expect(resetWidget.initialToken, 'sample-token');
    });

    test(
      'Generates shell routes for Home, Documents, Quiz, Planner, Settings',
      () {
        final homeRoute =
            AppRouter.onGenerateRoute(const RouteSettings(name: AppRoutes.home))
                as MaterialPageRoute;
        final homeShell = homeRoute.builder(fakeContext) as AppShell;
        expect(homeShell.initialTab, 0);

        final docRoute =
            AppRouter.onGenerateRoute(
                  const RouteSettings(name: AppRoutes.documents),
                )
                as MaterialPageRoute;
        final docShell = docRoute.builder(fakeContext) as AppShell;
        expect(docShell.initialTab, 2);

        final quizRoute =
            AppRouter.onGenerateRoute(const RouteSettings(name: AppRoutes.quiz))
                as MaterialPageRoute;
        final quizShell = quizRoute.builder(fakeContext) as AppShell;
        expect(quizShell.initialTab, 3);

        final plannerRoute =
            AppRouter.onGenerateRoute(
                  const RouteSettings(name: AppRoutes.studyPlanner),
                )
                as MaterialPageRoute;
        final plannerShell = plannerRoute.builder(fakeContext) as AppShell;
        expect(plannerShell.initialTab, 4);

        final settingsRoute =
            AppRouter.onGenerateRoute(
                  const RouteSettings(name: AppRoutes.settings),
                )
                as MaterialPageRoute;
        final settingsShell = settingsRoute.builder(fakeContext) as AppShell;
        expect(settingsShell.initialTab, 5);
      },
    );

    test('Generates Chat route with and without arguments', () {
      // Without argument -> AppShell on tab 1
      final generalRoute =
          AppRouter.onGenerateRoute(const RouteSettings(name: AppRoutes.chat))
              as MaterialPageRoute;
      final chatShell = generalRoute.builder(fakeContext) as AppShell;
      expect(chatShell.initialTab, 1);

      // With ConversationModel argument -> ChatScreen
      final convo = ConversationModel(
        id: 'c1',
        title: 'Physics',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final convoRoute =
          AppRouter.onGenerateRoute(
                RouteSettings(name: AppRoutes.chat, arguments: convo),
              )
              as MaterialPageRoute;
      expect(convoRoute.builder(fakeContext), isA<ChatScreen>());
    });

    test('Generates PDF Chat with and without document argument', () {
      // Without argument -> AppPlaceholderScreen
      final emptyRoute =
          AppRouter.onGenerateRoute(
                const RouteSettings(name: AppRoutes.pdfChat),
              )
              as MaterialPageRoute;
      expect(emptyRoute.builder(fakeContext), isA<AppPlaceholderScreen>());

      // With DocumentModel argument -> DocumentChatScreen
      final doc = DocumentModel(
        id: 'd1',
        originalName: 'notes.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 1024,
        status: 'READY',
        createdAt: DateTime.now(),
      );
      final docRoute =
          AppRouter.onGenerateRoute(
                RouteSettings(name: AppRoutes.pdfChat, arguments: doc),
              )
              as MaterialPageRoute;
      expect(docRoute.builder(fakeContext), isA<DocumentChatScreen>());
    });

    test('Generates 404 placeholder for unmapped route', () {
      final notFoundRoute =
          AppRouter.onGenerateRoute(
                const RouteSettings(name: '/non-existent-route'),
              )
              as MaterialPageRoute;
      final widget = notFoundRoute.builder(fakeContext) as AppPlaceholderScreen;
      expect(widget.title, 'Route Not Found');
      expect(widget.featureName, '404 - Not Found');
    });
  });
}
