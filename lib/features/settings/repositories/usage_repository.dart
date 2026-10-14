import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers/core_providers.dart';
import '../models/usage_model.dart';

class UsageRepository {
  final ApiClient apiClient;

  UsageRepository({required this.apiClient});

  Future<UsageModel> getUsage() async {
    final response = await apiClient.get('/usage');
    if (response is Map<String, dynamic>) {
      return UsageModel.fromJson(response);
    }
    return const UsageModel();
  }
}

final usageRepositoryProvider = Provider<UsageRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return UsageRepository(apiClient: apiClient);
});

final usageControllerProvider = FutureProvider<UsageModel>((ref) async {
  final repo = ref.watch(usageRepositoryProvider);
  return await repo.getUsage();
});
