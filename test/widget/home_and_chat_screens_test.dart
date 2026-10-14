import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_mate_frontend/core/routing/app_router.dart';
import 'package:study_mate_frontend/core/theme/app_theme.dart';
import 'package:study_mate_frontend/features/auth/controllers/auth_controller.dart';
import 'package:study_mate_frontend/features/auth/models/user_model.dart';
import 'package:study_mate_frontend/features/home/screens/home_screen.dart';
import 'package:study_mate_frontend/features/tutor/controllers/chat_controller.dart';
import 'package:study_mate_frontend/features/tutor/controllers/conversation_list_controller.dart';
import 'package:study_mate_frontend/features/tutor/models/conversation_model.dart';
import 'package:study_mate_frontend/features/tutor/models/message_model.dart';
import 'package:study_mate_frontend/features/tutor/screens/chat_screen.dart';
import 'package:study_mate_frontend/features/tutor/screens/conversations_screen.dart';

class MockAuthController extends AuthController {
  final UserModel? user;
  MockAuthController([this.user]);

  @override
  AuthState build() {
    if (user != null) {
      return Authenticated(user!);
    }
    return const Unauthenticated();
  }
}

class MockConversationListController extends ConversationListController {
  final List<ConversationModel> initialData;
  final Object? errorToThrow;

  MockConversationListController({
    this.initialData = const [],
    this.errorToThrow,
  });

  @override
  Future<List<ConversationModel>> build() async {
    if (errorToThrow != null) {
      return Future.error(errorToThrow!, StackTrace.current);
    }
    return initialData;
  }

  @override
  Future<ConversationModel?> createConversation([String? title]) async {
    final created = ConversationModel(
      id: 'conv-new',
      title: title ?? 'New Session',
      createdAt: DateTime.now(),
    );
    final current = state.value ?? [];
    state = AsyncValue.data([created, ...current]);
    return created;
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    final current = state.value ?? [];
    state = AsyncValue.data(
      current.where((c) => c.id != conversationId).toList(),
    );
  }

  @override
  Future<bool> renameConversation({
    required String conversationId,
    required String newTitle,
  }) async {
    final current = state.value ?? [];
    state = AsyncValue.data(
      current
          .map((c) => c.id == conversationId ? c.copyWith(title: newTitle) : c)
          .toList(),
    );
    return true;
  }
}

class MockChatController extends ChatController {
  final ChatState customInitialState;
  bool sendMessageCalled = false;
  String? lastSentText;
  bool failNextSend = false;

  MockChatController(
    super.conversationId, {
    this.customInitialState = const ChatState(),
    this.failNextSend = false,
  });

  @override
  ChatState build() {
    return customInitialState;
  }

  @override
  Future<bool> sendMessage(String text) async {
    sendMessageCalled = true;
    lastSentText = text;
    if (failNextSend) {
      state = state.copyWith(
        isSending: false,
        errorMessage: 'Network timeout while contacting AI tutor.',
      );
      return false;
    }

    final userMsg = MessageModel(
      id: 'msg-u',
      conversationId: conversationId,
      role: 'user',
      content: text,
      createdAt: DateTime.now(),
    );
    final aiMsg = MessageModel(
      id: 'msg-ai',
      conversationId: conversationId,
      role: 'assistant',
      content: 'Here is your personalized Socratic explanation.',
      createdAt: DateTime.now(),
    );
    state = state.copyWith(
      messages: [...state.messages, userMsg, aiMsg],
      isSending: false,
    );
    return true;
  }

  @override
  void setExplanationMode(String mode) {
    state = state.copyWith(explanationMode: mode);
  }
}

Widget createWidgetWithOverrides({
  required Widget child,
  UserModel? user,
  List<ConversationModel>? conversations,
  Object? conversationsError,
  MockChatController? customChatController,
  String? chatConversationId,
}) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(() => MockAuthController(user)),
      conversationListControllerProvider.overrideWith(
        () => MockConversationListController(
          initialData: conversations ?? [],
          errorToThrow: conversationsError,
        ),
      ),
      if (customChatController != null && chatConversationId != null)
        chatControllerProvider(
          chatConversationId,
        ).overrideWith(() => customChatController),
    ],
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      onGenerateRoute: AppRouter.onGenerateRoute,
      home: child,
    ),
  );
}

void main() {
  final testUser = UserModel(
    id: 'user-42',
    email: 'sarah.connor@example.com',
    displayName: 'Sarah Connor',
    status: 'ACTIVE',
    createdAt: DateTime.now(),
  );

  final sampleConversations = [
    ConversationModel(
      id: 'c-1',
      title: 'Thermodynamics & Heat Capacity',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    ConversationModel(
      id: 'c-2',
      title: 'Linear Algebra Eigenvalues',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  group('HomeScreen Dashboard Widget Tests (Phase 3)', () {
    testWidgets('renders real user summary, greeting, and status badge', (
      tester,
    ) async {
      await tester.pumpWidget(
        createWidgetWithOverrides(
          child: const HomeScreen(),
          user: testUser,
          conversations: sampleConversations,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome back, Sarah Connor!'), findsOneWidget);
      expect(find.text('sarah.connor@example.com'), findsOneWidget);
      expect(find.text('STUDENT'), findsOneWidget);
      expect(find.text('S'), findsOneWidget); // User initial avatar
    });

    testWidgets('renders quick action buttons for all four learning pillars', (
      tester,
    ) async {
      int? selectedTab;
      await tester.pumpWidget(
        createWidgetWithOverrides(
          child: HomeScreen(onTabSelected: (idx) => selectedTab = idx),
          user: testUser,
          conversations: sampleConversations,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI Tutor'), findsOneWidget);
      expect(find.text('PDF Chat'), findsOneWidget);
      expect(find.text('Quiz'), findsOneWidget);
      expect(find.text('Planner'), findsOneWidget);

      // Tap AI Tutor quick action
      await tester.tap(find.text('AI Tutor'));
      await tester.pumpAndSettle();
      expect(selectedTab, 1);

      // Tap PDF Chat quick action
      await tester.tap(find.text('PDF Chat'));
      await tester.pumpAndSettle();
      expect(selectedTab, 2);
    });

    testWidgets('renders recent study conversations when data is present', (
      tester,
    ) async {
      await tester.pumpWidget(
        createWidgetWithOverrides(
          child: const HomeScreen(),
          user: testUser,
          conversations: sampleConversations,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Recent Study Chats'), findsOneWidget);
      expect(find.text('Thermodynamics & Heat Capacity'), findsOneWidget);
      expect(find.text('Linear Algebra Eigenvalues'), findsOneWidget);
    });

    testWidgets('renders empty state when no recent study chats exist', (
      tester,
    ) async {
      await tester.pumpWidget(
        createWidgetWithOverrides(
          child: const HomeScreen(),
          user: testUser,
          conversations: const [],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No recent study chats'), findsOneWidget);
      expect(find.text('Start Chat'), findsOneWidget);
    });

    testWidgets(
      'renders error view with retry when conversations fail to load',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          createWidgetWithOverrides(
            child: const HomeScreen(),
            user: testUser,
            conversationsError: 'Network connection timeout',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Unable to load recent chats'), findsOneWidget);
        expect(find.text('Try Again'), findsOneWidget);
      },
    );

    testWidgets('renders study prompt suggestions', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createWidgetWithOverrides(
          child: const HomeScreen(),
          user: testUser,
          conversations: sampleConversations,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Try a Study Prompt'), findsOneWidget);
      expect(find.text('Explain with an Analogy'), findsOneWidget);
      expect(find.text('Socratic Concept Breakdown'), findsOneWidget);
      expect(find.text('Active Recall Check'), findsOneWidget);
    });
  });

  group('ConversationsScreen Widget Tests (Phase 3)', () {
    testWidgets('renders list of sessions and opens new session dialog', (
      tester,
    ) async {
      await tester.pumpWidget(
        createWidgetWithOverrides(
          child: const ConversationsScreen(),
          conversations: sampleConversations,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI Tutor Sessions'), findsOneWidget);
      expect(find.text('Thermodynamics & Heat Capacity'), findsOneWidget);
      expect(find.text('Linear Algebra Eigenvalues'), findsOneWidget);
      expect(find.text('New Session'), findsOneWidget);

      // Tap FAB to open new chat dialog
      await tester.tap(find.text('New Session'));
      await tester.pumpAndSettle();

      expect(find.text('Start New Conversation'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Start Chat'), findsOneWidget);
    });

    testWidgets('popup menu provides rename and delete options', (
      tester,
    ) async {
      await tester.pumpWidget(
        createWidgetWithOverrides(
          child: const ConversationsScreen(),
          conversations: sampleConversations,
        ),
      );
      await tester.pumpAndSettle();

      // Tap more options on first conversation
      final moreButtons = find.byIcon(Icons.more_vert_rounded);
      await tester.tap(moreButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('Rename'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      // Tap Rename
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      expect(find.text('Rename Conversation'), findsOneWidget);
    });
  });

  group('ChatScreen Widget Tests (Phase 3)', () {
    final activeConv = ConversationModel(
      id: 'active-conv-1',
      title: 'Quantum Physics Intro',
      createdAt: DateTime.now(),
    );

    testWidgets(
      'renders header, style selector chips, and empty prompt suggestions',
      (tester) async {
        final mockChat = MockChatController(
          'active-conv-1',
          customInitialState: const ChatState(messages: []),
        );

        await tester.pumpWidget(
          createWidgetWithOverrides(
            child: ChatScreen(conversation: activeConv),
            customChatController: mockChat,
            chatConversationId: 'active-conv-1',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Quantum Physics Intro'), findsOneWidget);
        expect(find.text('Normal'), findsOneWidget);
        expect(find.text('Simpler'), findsOneWidget);
        expect(find.text('Deep Dive'), findsOneWidget);
        expect(find.text('With Examples'), findsOneWidget);
        expect(find.text('How can I help you study today?'), findsOneWidget);
      },
    );

    testWidgets('renders existing messages with timestamps and role badges', (
      tester,
    ) async {
      final userMessage = MessageModel(
        id: 'm-1',
        conversationId: 'active-conv-1',
        role: 'user',
        content: 'What is wave-particle duality?',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      final aiMessage = MessageModel(
        id: 'm-2',
        conversationId: 'active-conv-1',
        role: 'assistant',
        content:
            'Matter and light exhibit behaviors of both waves and particles.',
        createdAt: DateTime.now(),
      );

      final mockChat = MockChatController(
        'active-conv-1',
        customInitialState: ChatState(messages: [userMessage, aiMessage]),
      );

      await tester.pumpWidget(
        createWidgetWithOverrides(
          child: ChatScreen(conversation: activeConv),
          customChatController: mockChat,
          chatConversationId: 'active-conv-1',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('What is wave-particle duality?'), findsOneWidget);
      expect(
        find.text(
          'Matter and light exhibit behaviors of both waves and particles.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.smart_toy_rounded), findsOneWidget);
    });

    testWidgets('sends message and clears input on success', (tester) async {
      final mockChat = MockChatController(
        'active-conv-1',
        customInitialState: const ChatState(messages: []),
      );

      await tester.pumpWidget(
        createWidgetWithOverrides(
          child: ChatScreen(conversation: activeConv),
          customChatController: mockChat,
          chatConversationId: 'active-conv-1',
        ),
      );
      await tester.pumpAndSettle();

      final inputField = find.byType(TextField);
      await tester.enterText(inputField, 'Explain Schrodinger equation');
      await tester.pumpAndSettle();

      final sendButton = find.byTooltip('Send message');
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      expect(mockChat.sendMessageCalled, isTrue);
      expect(mockChat.lastSentText, 'Explain Schrodinger equation');
      expect(find.text('Explain Schrodinger equation'), findsWidgets);
    });

    testWidgets('preserves draft text in input on failed request', (
      tester,
    ) async {
      final mockChat = MockChatController(
        'active-conv-1',
        customInitialState: const ChatState(messages: []),
        failNextSend: true,
      );

      await tester.pumpWidget(
        createWidgetWithOverrides(
          child: ChatScreen(conversation: activeConv),
          customChatController: mockChat,
          chatConversationId: 'active-conv-1',
        ),
      );
      await tester.pumpAndSettle();

      final inputField = find.byType(TextField);
      await tester.enterText(inputField, 'Draft that fails to send');
      await tester.pumpAndSettle();

      final sendButton = find.byTooltip('Send message');
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      // Input retains the unsent draft
      expect(
        find.widgetWithText(TextField, 'Draft that fails to send'),
        findsOneWidget,
      );
      // Error banner is displayed with Retry action
      expect(
        find.text('Network timeout while contacting AI tutor.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('popup menu allows rename and delete of conversation', (
      tester,
    ) async {
      final mockChat = MockChatController(
        'active-conv-1',
        customInitialState: const ChatState(messages: []),
      );

      await tester.pumpWidget(
        createWidgetWithOverrides(
          child: ChatScreen(conversation: activeConv),
          customChatController: mockChat,
          chatConversationId: 'active-conv-1',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Rename Title'), findsOneWidget);
      expect(find.text('Delete Chat'), findsOneWidget);

      await tester.tap(find.text('Rename Title'));
      await tester.pumpAndSettle();

      expect(find.text('Rename Conversation'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Save'), findsOneWidget);
    });
  });
}
