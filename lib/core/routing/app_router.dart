import 'package:flutter/material.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/reset_password_screen.dart';
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/documents/models/document_model.dart';
import '../../features/documents/screens/document_chat_screen.dart';
import '../../features/tutor/models/conversation_model.dart';
import '../../features/tutor/screens/chat_screen.dart';
import '../widgets/app_placeholder_screen.dart';
import 'app_shell.dart';
import 'route_names.dart';

/// Central route generator for AI StudyMate.
class AppRouter {
  AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.welcome:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const WelcomeScreen(),
        );

      case AppRoutes.login:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const LoginScreen(),
        );

      case AppRoutes.register:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const RegisterScreen(),
        );

      case AppRoutes.forgotPassword:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const ForgotPasswordScreen(),
        );

      case AppRoutes.resetPassword:
        final token = settings.arguments is String
            ? settings.arguments as String
            : null;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => ResetPasswordScreen(initialToken: token),
        );

      case AppRoutes.home:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const AppShell(initialTab: 0),
        );

      case AppRoutes.chat:
        if (settings.arguments is ConversationModel) {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => ChatScreen(
              conversation: settings.arguments as ConversationModel,
            ),
          );
        }
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const AppShell(initialTab: 1),
        );

      case AppRoutes.documents:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const AppShell(initialTab: 2),
        );

      case AppRoutes.pdfChat:
        if (settings.arguments is DocumentModel) {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => DocumentChatScreen(
              document: settings.arguments as DocumentModel,
            ),
          );
        }
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const AppPlaceholderScreen(
            title: 'PDF Chat',
            featureName: 'Document Context Chat',
            description:
                'Select a document from the Documents library to chat with citations and extracted notes.',
            icon: Icons.picture_as_pdf_rounded,
            phaseTag: 'PDF Intelligence',
          ),
        );

      case AppRoutes.quiz:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const AppShell(initialTab: 3),
        );

      case AppRoutes.studyPlanner:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const AppShell(initialTab: 4),
        );

      case AppRoutes.settings:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const AppShell(initialTab: 5),
        );

      default:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => AppPlaceholderScreen(
            title: 'Route Not Found',
            featureName: '404 - Not Found',
            description:
                'The requested route "${settings.name}" does not exist.',
            icon: Icons.explore_off_rounded,
            phaseTag: 'Navigation',
          ),
        );
    }
  }
}
