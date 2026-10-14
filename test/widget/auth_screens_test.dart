import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_mate_frontend/core/routing/app_router.dart';
import 'package:study_mate_frontend/core/routing/app_shell.dart';
import 'package:study_mate_frontend/core/theme/app_theme.dart';
import 'package:study_mate_frontend/core/widgets/app_button.dart';
import 'package:study_mate_frontend/features/auth/controllers/auth_controller.dart';
import 'package:study_mate_frontend/features/auth/models/user_model.dart';
import 'package:study_mate_frontend/features/auth/screens/forgot_password_screen.dart';
import 'package:study_mate_frontend/features/auth/screens/login_screen.dart';
import 'package:study_mate_frontend/features/auth/screens/register_screen.dart';
import 'package:study_mate_frontend/features/auth/screens/reset_password_screen.dart';
import 'package:study_mate_frontend/features/auth/screens/welcome_screen.dart';
import 'package:study_mate_frontend/main.dart';

class TestAuthController extends AuthController {
  final AuthState initialState;
  bool loginCalled = false;
  bool registerCalled = false;
  bool forgotPasswordCalled = false;
  bool resetPasswordCalled = false;
  String? lastEmail;
  String? lastPassword;

  TestAuthController([this.initialState = const Unauthenticated()]);

  @override
  AuthState build() => initialState;

  @override
  Future<bool> login(String email, String password) async {
    loginCalled = true;
    lastEmail = email;
    lastPassword = password;
    return true;
  }

  @override
  Future<bool> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    registerCalled = true;
    lastEmail = email;
    lastPassword = password;
    return true;
  }

  @override
  Future<String?> forgotPassword(String email) async {
    forgotPasswordCalled = true;
    lastEmail = email;
    return 'Password reset is not yet supported by the server API (POST /api/v1/auth/forgot-password).';
  }

  @override
  Future<String?> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    resetPasswordCalled = true;
    return 'Password reset is not yet supported by the server API (POST /api/v1/auth/reset-password).';
  }
}

Widget createTestWidget({
  required Widget child,
  AuthState initialState = const Unauthenticated(),
  TestAuthController? customController,
}) {
  final controller = customController ?? TestAuthController(initialState);
  return ProviderScope(
    overrides: [authControllerProvider.overrideWith(() => controller)],
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      onGenerateRoute: AppRouter.onGenerateRoute,
      home: child,
    ),
  );
}

void main() {
  group('WelcomeScreen Widget Tests (Phase 2)', () {
    testWidgets('renders brand title, feature badges and action buttons', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(child: const WelcomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('AI StudyMate'), findsOneWidget);
      expect(find.text('24/7 AI Tutor'), findsOneWidget);
      expect(find.text('Smart PDF Chat'), findsOneWidget);
      expect(find.text('Active Recall & Quizzes'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('I already have an account'), findsOneWidget);
    });
  });

  group('LoginScreen Widget Tests (Phase 2)', () {
    testWidgets('renders input fields, toggle button, and links', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(child: const LoginScreen()));
      await tester.pumpAndSettle();

      expect(find.text('AI StudyMate'), findsWidgets);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
    });

    testWidgets('shows validation errors when submitted empty', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const LoginScreen()));
      await tester.pumpAndSettle();

      // Tap Sign In button
      await tester.tap(find.widgetWithText(AppButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('shows invalid email format validation', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const LoginScreen()));
      await tester.pumpAndSettle();

      // Enter invalid email
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email Address'),
        'invalid-format',
      );
      await tester.tap(find.widgetWithText(AppButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address'), findsOneWidget);
    });

    testWidgets('password visibility toggle changes obscureText', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(child: const LoginScreen()));
      await tester.pumpAndSettle();

      final passwordFieldFinder = find.widgetWithText(
        TextFormField,
        'Password',
      );
      final initialField = tester.widget<EditableText>(
        find.descendant(
          of: passwordFieldFinder,
          matching: find.byType(EditableText),
        ),
      );
      expect(initialField.obscureText, isTrue);

      // Tap the eye icon to reveal
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pumpAndSettle();

      final updatedField = tester.widget<EditableText>(
        find.descendant(
          of: passwordFieldFinder,
          matching: find.byType(EditableText),
        ),
      );
      expect(updatedField.obscureText, isFalse);
    });

    testWidgets('displays AuthError banner when error state is active', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const LoginScreen(),
          initialState: const AuthError(
            'Invalid email or password',
            'AUTH_FAILED',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Invalid email or password'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });
  });

  group('RegisterScreen Widget Tests (Phase 2)', () {
    testWidgets('renders register fields and terms agreement', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(child: const RegisterScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Create Account'), findsWidgets);
      expect(find.text('Display Name (optional)'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);
    });

    testWidgets('enforces password minimum length of 8 characters', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(child: const RegisterScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email Address'),
        'valid@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'short',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm Password'),
        'short',
      );

      // Check terms box
      final checkboxFinder = find.byType(Checkbox);
      await tester.ensureVisible(checkboxFinder);
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();

      final buttonFinder = find.widgetWithText(AppButton, 'Create Account');
      await tester.ensureVisible(buttonFinder);
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(
        find.text('Password must be at least 8 characters'),
        findsOneWidget,
      );
    });

    testWidgets('enforces confirm password matching', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(child: const RegisterScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email Address'),
        'valid@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'ValidPassword123!',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm Password'),
        'DifferentPassword123!',
      );

      final checkboxFinder = find.byType(Checkbox);
      await tester.ensureVisible(checkboxFinder);
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();

      final buttonFinder = find.widgetWithText(AppButton, 'Create Account');
      await tester.ensureVisible(buttonFinder);
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('warns when terms checkbox is not selected', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(child: const RegisterScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email Address'),
        'valid@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'ValidPassword123!',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm Password'),
        'ValidPassword123!',
      );

      final buttonFinder = find.widgetWithText(AppButton, 'Create Account');
      await tester.ensureVisible(buttonFinder);
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(
        find.text('Please agree to the privacy terms to continue.'),
        findsOneWidget,
      );
    });
  });

  group('ForgotPasswordScreen Widget Tests (Phase 2)', () {
    testWidgets('renders reset instructions and email input', (tester) async {
      await tester.pumpWidget(
        createTestWidget(child: const ForgotPasswordScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reset Your Password'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Send Reset Link'), findsOneWidget);
      expect(
        find.text('Already have a reset token? Enter it here'),
        findsOneWidget,
      );
    });

    testWidgets(
      'submitting email triggers controller and shows feedback banner',
      (tester) async {
        final mockController = TestAuthController();
        await tester.pumpWidget(
          createTestWidget(
            child: const ForgotPasswordScreen(),
            customController: mockController,
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Email Address'),
          'student@example.com',
        );
        await tester.tap(find.widgetWithText(AppButton, 'Send Reset Link'));
        await tester.pumpAndSettle();

        expect(mockController.forgotPasswordCalled, isTrue);
        expect(
          find.textContaining('Password reset is not yet supported'),
          findsOneWidget,
        );
      },
    );
  });

  group('ResetPasswordScreen Widget Tests (Phase 2)', () {
    testWidgets('pre-populates token and renders input fields', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const ResetPasswordScreen(initialToken: 'test-token-777'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create New Password'), findsOneWidget);
      expect(find.text('test-token-777'), findsOneWidget);
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Confirm New Password'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Reset Password'), findsOneWidget);
    });

    testWidgets('submitting invokes resetPassword and displays result', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockController = TestAuthController();
      await tester.pumpWidget(
        createTestWidget(
          child: const ResetPasswordScreen(),
          customController: mockController,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Reset Token'),
        'abc-token-123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'New Password'),
        'BrandNewPassword123!',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm New Password'),
        'BrandNewPassword123!',
      );

      final buttonFinder = find.widgetWithText(AppButton, 'Reset Password');
      await tester.ensureVisible(buttonFinder);
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(mockController.resetPasswordCalled, isTrue);
      expect(
        find.textContaining('Password reset is not yet supported'),
        findsOneWidget,
      );
    });
  });

  group('App Navigation Guard and Auth State Tests (Phase 2)', () {
    testWidgets('displays LoginScreen when unauthenticated', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => TestAuthController(const Unauthenticated()),
            ),
          ],
          child: const AiStudyMateApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
    });

    testWidgets('displays AppShell when authenticated', (tester) async {
      final testUser = UserModel(
        id: 'usr-1',
        email: 'user@example.com',
        displayName: 'Test User',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => TestAuthController(Authenticated(testUser)),
            ),
          ],
          child: const AiStudyMateApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });
  });
}
