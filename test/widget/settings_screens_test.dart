import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_mate_frontend/core/config/app_config.dart';
import 'package:study_mate_frontend/core/theme/app_theme.dart';
import 'package:study_mate_frontend/features/auth/controllers/auth_controller.dart';
import 'package:study_mate_frontend/features/auth/models/user_model.dart';
import 'package:study_mate_frontend/features/settings/models/feedback_model.dart';
import 'package:study_mate_frontend/features/settings/models/usage_model.dart';
import 'package:study_mate_frontend/features/settings/repositories/feedback_repository.dart';
import 'package:study_mate_frontend/features/settings/repositories/usage_repository.dart';
import 'package:study_mate_frontend/features/settings/screens/privacy_policy_screen.dart';
import 'package:study_mate_frontend/features/settings/screens/settings_screen.dart';

class MockAuthController extends AuthController {
  final UserModel currentUser;
  bool logoutCalled = false;
  bool deleteCalled = false;
  bool shouldDeleteSucceed;
  String? deleteError;

  MockAuthController({
    required this.currentUser,
    this.shouldDeleteSucceed = true,
    this.deleteError,
  });

  @override
  AuthState build() => Authenticated(currentUser);

  @override
  Future<void> logout() async {
    logoutCalled = true;
    state = const Unauthenticated();
  }

  @override
  Future<({bool success, String? error})> deleteAccount() async {
    deleteCalled = true;
    if (shouldDeleteSucceed) {
      state = const Unauthenticated();
      return (success: true, error: null);
    } else {
      return (
        success: false,
        error: deleteError ?? 'Server rejected deletion request.',
      );
    }
  }

  bool updateProfileCalled = false;
  String? updatedDisplayName;

  @override
  Future<({bool success, String? error, UserModel? user})> updateProfile(
    String displayName,
  ) async {
    updateProfileCalled = true;
    updatedDisplayName = displayName;
    final updated = currentUser.copyWith(displayName: displayName);
    state = Authenticated(updated);
    return (success: true, error: null, user: updated);
  }
}

class FakeFeedbackRepository extends Fake implements FeedbackRepository {
  final List<Map<String, dynamic>> submissions = [];
  bool shouldFail = false;

  @override
  Future<FeedbackModel> submitFeedback({
    required String rating,
    String? category,
    required String comment,
    String? messageId,
  }) async {
    if (shouldFail) {
      throw Exception('Server unreachable');
    }
    submissions.add({
      'rating': rating,
      'category': category,
      'comment': comment,
      'messageId': messageId,
    });
    return FeedbackModel(
      id: 'fb-test-1',
      rating: rating,
      category: category,
      comment: comment,
      messageId: messageId,
      createdAt: DateTime.now(),
    );
  }
}

void main() {
  final testUser = const UserModel(
    id: 'usr-alice',
    email: 'alice@example.com',
    displayName: 'Alice Learner',
    status: 'ACTIVE',
  );

  Widget createTestWidget({
    required MockAuthController authController,
    required UsageModel usage,
    required FakeFeedbackRepository feedbackRepo,
  }) {
    return ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => authController),
        usageControllerProvider.overrideWith((ref) async => usage),
        feedbackRepositoryProvider.overrideWithValue(feedbackRepo),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const SettingsScreen(),
      ),
    );
  }

  group('SettingsScreen Widget Tests', () {
    testWidgets(
      'renders user profile and read-only account details accurately',
      (tester) async {
        final mockAuth = MockAuthController(currentUser: testUser);
        final fakeFeedback = FakeFeedbackRepository();
        const usage = UsageModel(totalTokens: 100, requestCount: 2);

        await tester.pumpWidget(
          createTestWidget(
            authController: mockAuth,
            usage: usage,
            feedbackRepo: fakeFeedback,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Settings & Account'), findsOneWidget);
        expect(find.text('Alice Learner'), findsOneWidget);
        expect(find.text('alice@example.com'), findsOneWidget);
        expect(find.text('ACTIVE'), findsOneWidget);
        expect(find.text('VERIFIED'), findsOneWidget);
        expect(
          find.text(
            'Account details synced with secure authentication service.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'displays real AI usage, request quota, and feature breakdown',
      (tester) async {
        final mockAuth = MockAuthController(currentUser: testUser);
        final fakeFeedback = FakeFeedbackRepository();
        final usage = UsageModel(
          totalTokens: 4200,
          requestCount: 25,
          quotaLimit: 50,
          requestsRemaining: 25,
          estimatedCost: 0.042,
          featureBreakdown: const {'TUTOR_CHAT': 15, 'DOCUMENT_QA': 10},
        );

        await tester.pumpWidget(
          createTestWidget(
            authController: mockAuth,
            usage: usage,
            feedbackRepo: fakeFeedback,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('AI Usage & Limits'), findsOneWidget);
        expect(find.text('4200'), findsOneWidget);
        expect(find.text('25 / 50'), findsOneWidget);
        expect(find.text('\$0.0420'), findsOneWidget);
        expect(
          find.text('25 requests remaining in current quota'),
          findsOneWidget,
        );
        expect(find.text('Tutor Chat: 15'), findsOneWidget);
        expect(find.text('PDF Q&A: 10'), findsOneWidget);
      },
    );

    testWidgets(
      'displays quota exhaustion alert using server message and reset time',
      (tester) async {
        final mockAuth = MockAuthController(currentUser: testUser);
        final fakeFeedback = FakeFeedbackRepository();
        final usage = UsageModel(
          totalTokens: 100000,
          requestCount: 50,
          quotaLimit: 50,
          requestsRemaining: 0,
          isExhausted: true,
          quotaMessage: 'Daily token limit exceeded.',
          resetTime: DateTime.parse('2026-10-14T00:00:00.000Z'),
        );

        await tester.pumpWidget(
          createTestWidget(
            authController: mockAuth,
            usage: usage,
            feedbackRepo: fakeFeedback,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('AI Request Limit Reached'), findsOneWidget);
        expect(find.text('Daily token limit exceeded.'), findsOneWidget);
        expect(find.textContaining('Quota resets:'), findsOneWidget);
      },
    );

    testWidgets('submits user feedback via FeedbackDialog', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockAuth = MockAuthController(currentUser: testUser);
      final fakeFeedback = FakeFeedbackRepository();
      const usage = UsageModel();

      await tester.pumpWidget(
        createTestWidget(
          authController: mockAuth,
          usage: usage,
          feedbackRepo: fakeFeedback,
        ),
      );
      await tester.pumpAndSettle();

      // Tap Send Feedback tile
      await tester.tap(find.text('Send Feedback & Report Issues'));
      await tester.pumpAndSettle();

      expect(find.text('Send Feedback'), findsOneWidget);

      // Select category 'Accuracy'
      await tester.tap(find.text('Accuracy'));
      await tester.pumpAndSettle();

      // Enter comment
      await tester.enterText(
        find.byType(TextField),
        'Physics definition on thermodynamics was exceptionally clear!',
      );
      await tester.pumpAndSettle();

      // Submit feedback
      await tester.tap(find.text('Submit Feedback'));
      await tester.pumpAndSettle();

      // Verify submission
      expect(fakeFeedback.submissions.length, 1);
      expect(fakeFeedback.submissions.first['category'], 'ACCURACY');
      expect(
        fakeFeedback.submissions.first['comment'],
        contains('thermodynamics'),
      );
      expect(
        find.text('Thank you! Your feedback has been submitted.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'displays Terms of Service dialog with educational disclaimer',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final mockAuth = MockAuthController(currentUser: testUser);
        final fakeFeedback = FakeFeedbackRepository();
        const usage = UsageModel();

        await tester.pumpWidget(
          createTestWidget(
            authController: mockAuth,
            usage: usage,
            feedbackRepo: fakeFeedback,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Terms of Service'));
        await tester.pumpAndSettle();

        expect(find.text('1. Educational Purpose'), findsOneWidget);
        expect(find.text('2. Academic Integrity'), findsOneWidget);

        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();

        expect(find.text('1. Educational Purpose'), findsNothing);
      },
    );

    testWidgets('displays Help & Support dialog with valid contact details', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockAuth = MockAuthController(currentUser: testUser);
      final fakeFeedback = FakeFeedbackRepository();
      const usage = UsageModel();

      await tester.pumpWidget(
        createTestWidget(
          authController: mockAuth,
          usage: usage,
          feedbackRepo: fakeFeedback,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Help & Support'));
      await tester.pumpAndSettle();

      expect(find.text(AppConfig.supportEmail), findsOneWidget);
      expect(find.text('Copy Email'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.text(AppConfig.supportEmail), findsNothing);
    });

    testWidgets(
      'sign out flow triggers AuthController.logout() on confirmation',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final mockAuth = MockAuthController(currentUser: testUser);
        final fakeFeedback = FakeFeedbackRepository();
        const usage = UsageModel();

        await tester.pumpWidget(
          createTestWidget(
            authController: mockAuth,
            usage: usage,
            feedbackRepo: fakeFeedback,
          ),
        );
        await tester.pumpAndSettle();

        // Tap Sign Out
        await tester.tap(find.text('Sign Out'));
        await tester.pumpAndSettle();

        expect(
          find.text('Are you sure you want to sign out of AI StudyMate?'),
          findsOneWidget,
        );

        // Cancel first
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(mockAuth.logoutCalled, isFalse);

        // Tap Sign Out again and confirm
        await tester.tap(find.text('Sign Out'));
        await tester.pumpAndSettle();

        final dialogSignOutButton = find.widgetWithText(
          ElevatedButton,
          'Sign Out',
        );
        await tester.tap(dialogSignOutButton);
        await tester.pumpAndSettle();

        expect(mockAuth.logoutCalled, isTrue);
      },
    );

    testWidgets(
      'account deletion flow confirms and accurately handles failure without false logout',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final mockAuth = MockAuthController(
          currentUser: testUser,
          shouldDeleteSucceed: false,
          deleteError:
              'Unable to purge vector embeddings due to database lock.',
        );
        final fakeFeedback = FakeFeedbackRepository();
        const usage = UsageModel();

        await tester.pumpWidget(
          createTestWidget(
            authController: mockAuth,
            usage: usage,
            feedbackRepo: fakeFeedback,
          ),
        );
        await tester.pumpAndSettle();

        // Tap Delete Account
        await tester.tap(find.text('Delete Account and Personal Data'));
        await tester.pumpAndSettle();

        expect(find.text('Delete Account & All Data?'), findsOneWidget);
        expect(
          find.textContaining('This action is permanent and irreversible.'),
          findsOneWidget,
        );

        // Tap Cancel first
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(mockAuth.deleteCalled, isFalse);

        // Tap Delete Account again and confirm
        await tester.tap(find.text('Delete Account and Personal Data'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Permanently Delete'));
        await tester.pumpAndSettle();

        expect(mockAuth.deleteCalled, isTrue);

        // Check that error dialog is shown and states data was NOT deleted
        expect(find.text('Account Deletion Failed'), findsOneWidget);
        expect(
          find.textContaining('Your account and study data were NOT deleted'),
          findsOneWidget,
        );

        // User remains logged in on Settings screen
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(find.text('Alice Learner'), findsOneWidget);
      },
    );

    testWidgets(
      'account deletion successfully deletes account on backend confirmation',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final mockAuth = MockAuthController(
          currentUser: testUser,
          shouldDeleteSucceed: true,
        );
        final fakeFeedback = FakeFeedbackRepository();
        const usage = UsageModel();

        await tester.pumpWidget(
          createTestWidget(
            authController: mockAuth,
            usage: usage,
            feedbackRepo: fakeFeedback,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Delete Account and Personal Data'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Permanently Delete'));
        await tester.pumpAndSettle();

        expect(mockAuth.deleteCalled, isTrue);
        expect(mockAuth.state, isA<Unauthenticated>());
      },
    );

    testWidgets(
      'tapping edit profile icon opens edit dialog, updates display name, and shows confirmation',
      (tester) async {
        final mockAuth = MockAuthController(currentUser: testUser);
        final fakeFeedback = FakeFeedbackRepository();
        const usage = UsageModel();

        await tester.pumpWidget(
          createTestWidget(
            authController: mockAuth,
            usage: usage,
            feedbackRepo: fakeFeedback,
          ),
        );
        await tester.pumpAndSettle();

        // Find edit profile icon button
        final editButtonFinder = find.byTooltip('Edit Profile Name');
        expect(editButtonFinder, findsOneWidget);
        await tester.tap(editButtonFinder);
        await tester.pumpAndSettle();

        // Verify dialog opens
        expect(find.text('Edit Profile Name'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller?.text,
          'Alice Learner',
        );

        // Enter new display name
        final textFieldFinder = find.byType(TextField);
        await tester.enterText(textFieldFinder, 'Alice Wonder');
        await tester.pumpAndSettle();

        // Tap Save
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        // Verify update was called with new name
        expect(mockAuth.updateProfileCalled, isTrue);
        expect(mockAuth.updatedDisplayName, 'Alice Wonder');

        // Verify SnackBar confirmation appears
        expect(find.text('Profile updated successfully!'), findsOneWidget);
      },
    );
  });

  group('PrivacyPolicyScreen Widget Tests', () {
    testWidgets('renders all privacy policy sections and support email', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const PrivacyPolicyScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Privacy Policy & AI Transparency'), findsOneWidget);
      expect(find.text('1. What Data We Process'), findsOneWidget);
      expect(find.text('2. How AI & Your Documents Work'), findsOneWidget);
      expect(
        find.text('3. Responsible AI & Learning Disclaimer'),
        findsOneWidget,
      );
      expect(find.text('4. Data Ownership & Deletion Rights'), findsOneWidget);
      expect(find.text('5. Security & Protection'), findsOneWidget);
      expect(find.text('6. Contact & Support'), findsOneWidget);
      expect(find.textContaining(AppConfig.supportEmail), findsOneWidget);
    });
  });
}
