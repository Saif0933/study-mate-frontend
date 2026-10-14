import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_mate_frontend/main.dart';
import 'package:study_mate_frontend/features/auth/controllers/auth_controller.dart';
import 'package:study_mate_frontend/features/auth/screens/login_screen.dart';

class FakeAuthController extends AuthController {
  @override
  AuthState build() {
    return const Unauthenticated();
  }
}

void main() {
  testWidgets('App root loads and displays initial auth screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(FakeAuthController.new),
        ],
        child: const AiStudyMateApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify LoginScreen is shown when unauthenticated
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('AI StudyMate'), findsWidgets);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
