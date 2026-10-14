import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_exceptions.dart';
import '../models/message_model.dart';
import '../repositories/tutor_repository.dart';
import 'conversation_list_controller.dart';

class ChatState {
  final List<MessageModel> messages;
  final bool isLoading;
  final bool isSending;
  final String? errorMessage;
  final String? errorCode;
  final String explanationMode; // 'standard', 'simple', 'detailed', 'examples'

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.errorMessage,
    this.errorCode,
    this.explanationMode = 'standard',
  });

  ChatState copyWith({
    List<MessageModel>? messages,
    bool? isLoading,
    bool? isSending,
    String? errorMessage,
    String? errorCode,
    String? explanationMode,
    bool clearError = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      explanationMode: explanationMode ?? this.explanationMode,
    );
  }
}

final chatControllerProvider = NotifierProvider.autoDispose
    .family<ChatController, ChatState, String>((arg) => ChatController(arg));

class ChatController extends Notifier<ChatState> {
  final String conversationId;
  bool _isDisposed = false;

  ChatController(this.conversationId);

  late final TutorRepository _repository;

  @override
  ChatState build() {
    _repository = ref.watch(tutorRepositoryProvider);
    ref.onDispose(() {
      _isDisposed = true;
    });
    Future.microtask(() => _loadMessages());
    return const ChatState(isLoading: true);
  }

  Future<void> _loadMessages() async {
    if (_isDisposed) return;
    try {
      final msgs = await _repository.getMessages(conversationId);
      if (_isDisposed) return;
      state = state.copyWith(messages: msgs, isLoading: false);
    } on ApiException catch (e) {
      if (_isDisposed) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
        errorCode: e.code,
      );
    } catch (e) {
      if (_isDisposed) return;
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void setExplanationMode(String mode) {
    state = state.copyWith(explanationMode: mode);
  }

  Future<bool> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isSending) return false;

    // Create optimistic user message
    final optimisticMsg = MessageModel(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      role: 'user',
      content: trimmed,
      createdAt: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, optimisticMsg],
      isSending: true,
      clearError: true,
    );

    try {
      final mode = state.explanationMode == 'standard'
          ? null
          : state.explanationMode;
      final aiMsg = await _repository.sendMessage(
        conversationId: conversationId,
        content: trimmed,
        explanationMode: mode,
      );

      state = state.copyWith(
        messages: [...state.messages, aiMsg],
        isSending: false,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(
        messages: state.messages
            .where((m) => m.id != optimisticMsg.id)
            .toList(),
        isSending: false,
        errorMessage: e.message,
        errorCode: e.code,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        messages: state.messages
            .where((m) => m.id != optimisticMsg.id)
            .toList(),
        isSending: false,
        errorMessage: 'Failed to send message. Please try again.',
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void retry() {
    _loadMessages();
  }
}
