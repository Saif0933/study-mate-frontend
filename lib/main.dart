import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/app_config.dart';
import 'core/routing/app_router.dart';
import 'core/routing/app_shell.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/loading_view.dart';
import 'features/auth/controllers/auth_controller.dart';
import 'features/auth/screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: AiStudyMateApp()));
}

class AiStudyMateApp extends ConsumerWidget {
  const AiStudyMateApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      onGenerateRoute: AppRouter.onGenerateRoute,
      home: _buildHomeForState(authState),
    );
  }

  Widget _buildHomeForState(AuthState state) {
    switch (state) {
      case Authenticated():
        return const AppShell(initialTab: 0);
      case Unauthenticated():
      case AuthError():
        return const LoginScreen();
      case AuthInitial():
      case AuthLoading():
        return const Scaffold(
          body: LoadingView(message: 'Initializing AI StudyMate...'),
        );
    }
  }
}
