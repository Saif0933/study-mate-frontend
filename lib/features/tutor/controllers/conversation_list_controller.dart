import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../models/conversation_model.dart';
import '../repositories/tutor_repository.dart';

final tutorRepositoryProvider = Provider<TutorRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return TutorRepository(apiClient: apiClient);
});

final conversationListControllerProvider =
    AsyncNotifierProvider<ConversationListController, List<ConversationModel>>(
      () {
        return ConversationListController();
      },
    );

class ConversationListController
    extends AsyncNotifier<List<ConversationModel>> {
  late final TutorRepository _repository;

  @override
  Future<List<ConversationModel>> build() async {
    _repository = ref.watch(tutorRepositoryProvider);
    return await _repository.getConversations();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.getConversations());
  }

  Future<ConversationModel?> createConversation([String? title]) async {
    try {
      final newConv = await _repository.createConversation(title: title);
      final currentList = state.value ?? [];
      state = AsyncValue.data([newConv, ...currentList]);
      return newConv;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> deleteConversation(String conversationId) async {
    try {
      await _repository.deleteConversation(conversationId);
      final currentList = state.value ?? [];
      state = AsyncValue.data(
        currentList.where((c) => c.id != conversationId).toList(),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> renameConversation({
    required String conversationId,
    required String newTitle,
  }) async {
    try {
      final updated = await _repository.renameConversation(
        conversationId: conversationId,
        newTitle: newTitle,
      );
      final currentList = state.value ?? [];
      state = AsyncValue.data(
        currentList.map((c) => c.id == conversationId ? updated : c).toList(),
      );
      return true;
    } catch (_) {
      // In case endpoint is unmounted or offline, apply local update so user experience is smooth
      final currentList = state.value ?? [];
      state = AsyncValue.data(
        currentList
            .map(
              (c) => c.id == conversationId ? c.copyWith(title: newTitle) : c,
            )
            .toList(),
      );
      return true;
    }
  }
}
