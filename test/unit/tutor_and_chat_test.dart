import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_mate_frontend/core/network/api_client.dart';
import 'package:study_mate_frontend/core/network/api_exceptions.dart';
import 'package:study_mate_frontend/core/storage/secure_storage_service.dart';
import 'package:study_mate_frontend/features/tutor/controllers/chat_controller.dart';
import 'package:study_mate_frontend/features/tutor/controllers/conversation_list_controller.dart';
import 'package:study_mate_frontend/features/tutor/repositories/tutor_repository.dart';

class FakeSecureStorageService extends Fake implements SecureStorageService {
  @override
  Future<String?> getToken() async => 'test-valid-token';
  @override
  Future<bool> hasToken() async => true;
}

class FakeApiClient extends Fake implements ApiClient {
  final Map<String, dynamic> responses = {};
  final Map<String, ApiException> errors = {};
  int postCallCount = 0;
  dynamic lastPostData;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (errors.containsKey(path)) {
      throw errors[path]!;
    }
    return responses[path];
  }

  @override
  Future<dynamic> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    postCallCount++;
    lastPostData = data;
    if (errors.containsKey(path)) {
      throw errors[path]!;
    }
    return responses[path];
  }

  @override
  Future<dynamic> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (errors.containsKey(path)) {
      throw errors[path]!;
    }
    return responses[path];
  }

  @override
  Future<dynamic> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (errors.containsKey(path)) {
      throw errors[path]!;
    }
    return responses[path];
  }
}

void main() {
  group('TutorRepository Unit Tests (Phase 3)', () {
    late FakeApiClient apiClient;
    late TutorRepository repository;

    final sampleConvJson = {
      'id': 'conv-101',
      'title': 'Photosynthesis Deep Dive',
      'createdAt': '2026-10-12T10:00:00Z',
    };

    final sampleMsgJson = {
      'id': 'msg-201',
      'conversationId': 'conv-101',
      'role': 'assistant',
      'content': 'Photosynthesis converts light energy into chemical energy.',
      'createdAt': '2026-10-12T10:01:00Z',
    };

    setUp(() {
      apiClient = FakeApiClient();
      repository = TutorRepository(apiClient: apiClient);
    });

    test('getConversations parses list of conversations', () async {
      apiClient.responses['/conversations'] = [sampleConvJson];

      final result = await repository.getConversations();

      expect(result.length, 1);
      expect(result.first.id, 'conv-101');
      expect(result.first.title, 'Photosynthesis Deep Dive');
    });

    test('createConversation sends title and returns new model', () async {
      apiClient.responses['/conversations'] = sampleConvJson;

      final result = await repository.createConversation(
        title: 'Photosynthesis Deep Dive',
      );

      expect(result.id, 'conv-101');
      expect(apiClient.lastPostData?['title'], 'Photosynthesis Deep Dive');
    });

    test('getMessages returns list of messages for conversation', () async {
      apiClient.responses['/conversations/conv-101/messages'] = [sampleMsgJson];

      final result = await repository.getMessages('conv-101');

      expect(result.length, 1);
      expect(result.first.id, 'msg-201');
      expect(result.first.role, 'assistant');
    });

    test('sendMessage sends content and optional explanationMode', () async {
      apiClient.responses['/conversations/conv-101/messages'] = sampleMsgJson;

      final result = await repository.sendMessage(
        conversationId: 'conv-101',
        content: 'Explain the light reactions',
        explanationMode: 'simple',
      );

      expect(result.id, 'msg-201');
      expect(apiClient.lastPostData?['content'], 'Explain the light reactions');
      expect(apiClient.lastPostData?['explanationMode'], 'simple');
    });

    test(
      'renameConversation patches title and returns updated model',
      () async {
        final updatedJson = Map<String, dynamic>.from(sampleConvJson)
          ..['title'] = 'Photosynthesis & Calvin Cycle';
        apiClient.responses['/conversations/conv-101'] = updatedJson;

        final result = await repository.renameConversation(
          conversationId: 'conv-101',
          newTitle: 'Photosynthesis & Calvin Cycle',
        );

        expect(result.title, 'Photosynthesis & Calvin Cycle');
      },
    );

    test('deleteConversation calls delete endpoint', () async {
      apiClient.responses['/conversations/conv-101'] = {'deleted': true};

      await repository.deleteConversation('conv-101');

      expect(
        apiClient.responses.containsKey('/conversations/conv-101'),
        isTrue,
      );
    });
  });

  group('ChatController Unit Tests (Phase 3)', () {
    late FakeApiClient apiClient;
    late TutorRepository repository;

    final sampleMsgJson = {
      'id': 'msg-assistant-1',
      'conversationId': 'conv-1',
      'role': 'assistant',
      'content': 'Hello, I am your Socratic AI Tutor.',
      'createdAt': '2026-10-12T10:00:00Z',
    };

    setUp(() {
      apiClient = FakeApiClient();
      repository = TutorRepository(apiClient: apiClient);
      apiClient.responses['/conversations/conv-1/messages'] = [sampleMsgJson];
    });

    test('loads conversation messages on build', () async {
      final container = ProviderContainer(
        overrides: [tutorRepositoryProvider.overrideWithValue(repository)],
      );

      final sub = container.listen(chatControllerProvider('conv-1'), (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final state = container.read(chatControllerProvider('conv-1'));
      expect(state.isLoading, isFalse);
      expect(state.messages.length, 1);
      expect(
        state.messages.first.content,
        'Hello, I am your Socratic AI Tutor.',
      );
      sub.close();
      container.dispose();
    });

    test('sendMessage rejects empty or whitespace-only messages', () async {
      final container = ProviderContainer(
        overrides: [tutorRepositoryProvider.overrideWithValue(repository)],
      );

      final sub = container.listen(chatControllerProvider('conv-1'), (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final controller = container.read(
        chatControllerProvider('conv-1').notifier,
      );
      final result = await controller.sendMessage('   ');

      expect(result, isFalse);
      expect(apiClient.postCallCount, 0);
      sub.close();
      container.dispose();
    });

    test(
      'sendMessage prevents duplicate submissions while already sending',
      () async {
        final container = ProviderContainer(
          overrides: [tutorRepositoryProvider.overrideWithValue(repository)],
        );

        final sub = container.listen(
          chatControllerProvider('conv-1'),
          (_, _) {},
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));

        final controller = container.read(
          chatControllerProvider('conv-1').notifier,
        );

        // Delay response so isSending is true
        apiClient.responses['/conversations/conv-1/messages'] = {
          'id': 'msg-reply',
          'conversationId': 'conv-1',
          'role': 'assistant',
          'content': 'First response',
          'createdAt': '2026-10-12T10:01:00Z',
        };

        final f1 = controller.sendMessage('Question 1');
        // Immediate second call while f1 is pending
        final f2 = controller.sendMessage('Question 2 duplicate');

        expect(await f2, isFalse);
        expect(await f1, isTrue);
        sub.close();
        container.dispose();
      },
    );

    test('sendMessage cleans up optimistic message on failure', () async {
      final container = ProviderContainer(
        overrides: [tutorRepositoryProvider.overrideWithValue(repository)],
      );

      final sub = container.listen(chatControllerProvider('conv-1'), (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 30));

      apiClient.errors['/conversations/conv-1/messages'] = const ApiException(
        code: 'RATE_LIMITED',
        statusCode: 429,
        message: 'Rate limit reached, please slow down.',
      );

      final controller = container.read(
        chatControllerProvider('conv-1').notifier,
      );
      final success = await controller.sendMessage('What is gravity?');

      expect(success, isFalse);
      final state = container.read(chatControllerProvider('conv-1'));
      expect(state.isSending, isFalse);
      expect(state.errorMessage, 'Rate limit reached, please slow down.');
      // The optimistic message was rolled back
      expect(
        state.messages.any((m) => m.content == 'What is gravity?'),
        isFalse,
      );
      sub.close();
      container.dispose();
    });

    test('setExplanationMode updates mode in state', () async {
      final container = ProviderContainer(
        overrides: [tutorRepositoryProvider.overrideWithValue(repository)],
      );

      final sub = container.listen(chatControllerProvider('conv-1'), (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final controller = container.read(
        chatControllerProvider('conv-1').notifier,
      );
      controller.setExplanationMode('detailed');

      expect(
        container.read(chatControllerProvider('conv-1')).explanationMode,
        'detailed',
      );
      sub.close();
      container.dispose();
    });
  });

  group('ConversationListController Unit Tests (Phase 3)', () {
    late FakeApiClient apiClient;
    late TutorRepository repository;

    final conv1 = {
      'id': 'c-1',
      'title': 'Organic Chem',
      'createdAt': '2026-10-12T09:00:00Z',
    };

    setUp(() {
      apiClient = FakeApiClient();
      repository = TutorRepository(apiClient: apiClient);
      apiClient.responses['/conversations'] = [conv1];
    });

    test('loads list of conversations on build', () async {
      final container = ProviderContainer(
        overrides: [tutorRepositoryProvider.overrideWithValue(repository)],
      );

      container.read(conversationListControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final state = container.read(conversationListControllerProvider);
      expect(state.value?.length, 1);
      expect(state.value?.first.title, 'Organic Chem');
      container.dispose();
    });

    test('createConversation adds new conversation at the beginning', () async {
      final container = ProviderContainer(
        overrides: [tutorRepositoryProvider.overrideWithValue(repository)],
      );

      container.read(conversationListControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final conv2 = {
        'id': 'c-2',
        'title': 'Thermodynamics',
        'createdAt': '2026-10-12T10:00:00Z',
      };
      apiClient.responses['/conversations'] = conv2;

      final controller = container.read(
        conversationListControllerProvider.notifier,
      );
      final created = await controller.createConversation('Thermodynamics');

      expect(created?.id, 'c-2');
      final list = container.read(conversationListControllerProvider).value!;
      expect(list.length, 2);
      expect(list.first.id, 'c-2');
      container.dispose();
    });

    test('deleteConversation removes target conversation', () async {
      final container = ProviderContainer(
        overrides: [tutorRepositoryProvider.overrideWithValue(repository)],
      );

      container.read(conversationListControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      apiClient.responses['/conversations/c-1'] = {'deleted': true};

      final controller = container.read(
        conversationListControllerProvider.notifier,
      );
      await controller.deleteConversation('c-1');

      final list = container.read(conversationListControllerProvider).value!;
      expect(list.isEmpty, isTrue);
      container.dispose();
    });

    test('renameConversation updates title of target conversation', () async {
      final container = ProviderContainer(
        overrides: [tutorRepositoryProvider.overrideWithValue(repository)],
      );

      container.read(conversationListControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final renamedJson = Map<String, dynamic>.from(conv1)
        ..['title'] = 'Advanced Organic Chem';
      apiClient.responses['/conversations/c-1'] = renamedJson;

      final controller = container.read(
        conversationListControllerProvider.notifier,
      );
      final success = await controller.renameConversation(
        conversationId: 'c-1',
        newTitle: 'Advanced Organic Chem',
      );

      expect(success, isTrue);
      final list = container.read(conversationListControllerProvider).value!;
      expect(list.first.title, 'Advanced Organic Chem');
      container.dispose();
    });
  });
}
