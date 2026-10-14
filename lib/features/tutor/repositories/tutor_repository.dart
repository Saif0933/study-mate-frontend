import '../../../core/network/api_client.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';

class TutorRepository {
  final ApiClient apiClient;

  TutorRepository({required this.apiClient});

  /// Fetch all conversations for the authenticated user
  Future<List<ConversationModel>> getConversations() async {
    final response = await apiClient.get('/conversations');
    if (response is List) {
      return response
          .map(
            (item) => ConversationModel.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    }
    return [];
  }

  /// Create a new conversation
  Future<ConversationModel> createConversation({String? title}) async {
    final response = await apiClient.post(
      '/conversations',
      data: {if (title != null && title.isNotEmpty) 'title': title},
    );
    return ConversationModel.fromJson(response as Map<String, dynamic>);
  }

  /// Fetch messages for a specific conversation
  Future<List<MessageModel>> getMessages(String conversationId) async {
    final response = await apiClient.get(
      '/conversations/$conversationId/messages',
    );
    if (response is List) {
      return response
          .map((item) => MessageModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Send message to AI tutor with optional explanation mode
  Future<MessageModel> sendMessage({
    required String conversationId,
    required String content,
    String? explanationMode, // 'simple', 'detailed', 'examples'
  }) async {
    final response = await apiClient.post(
      '/conversations/$conversationId/messages',
      data: {
        'content': content,
        if (explanationMode != null && explanationMode.isNotEmpty)
          'explanationMode': explanationMode,
      },
    );
    return MessageModel.fromJson(response as Map<String, dynamic>);
  }

  /// Rename a conversation title
  Future<ConversationModel> renameConversation({
    required String conversationId,
    required String newTitle,
  }) async {
    final response = await apiClient.patch(
      '/conversations/$conversationId',
      data: {'title': newTitle},
    );
    return ConversationModel.fromJson(response as Map<String, dynamic>);
  }

  /// Delete a conversation
  Future<void> deleteConversation(String conversationId) async {
    await apiClient.delete('/conversations/$conversationId');
  }
}
