import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers/core_providers.dart';
import '../models/feedback_model.dart';

class FeedbackRepository {
  final ApiClient apiClient;

  FeedbackRepository({required this.apiClient});

  Future<FeedbackModel> submitFeedback({
    required String rating,
    String? category,
    required String comment,
    String? messageId,
  }) async {
    final response = await apiClient.post(
      '/feedback',
      data: {
        'rating': rating,
        if (category != null && category.isNotEmpty) 'category': category,
        'comment': comment.trim(),
        if (messageId != null && messageId.isNotEmpty) 'messageId': messageId,
      },
    );

    if (response is Map<String, dynamic>) {
      return FeedbackModel.fromJson(response);
    }
    return FeedbackModel(
      rating: rating,
      category: category,
      comment: comment,
      messageId: messageId,
      createdAt: DateTime.now(),
    );
  }
}

final feedbackRepositoryProvider = Provider<FeedbackRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return FeedbackRepository(apiClient: apiClient);
});
