import 'api_client.dart';

/// Represents health status returned by the AI StudyMate backend /health endpoint.
class HealthStatusModel {
  final String status;
  final String timestamp;
  final int uptimeSeconds;
  final String environment;
  final String databaseStatus;
  final int? databaseLatencyMs;

  const HealthStatusModel({
    required this.status,
    required this.timestamp,
    required this.uptimeSeconds,
    required this.environment,
    required this.databaseStatus,
    this.databaseLatencyMs,
  });

  bool get isHealthy => status == 'ok' && databaseStatus == 'connected';

  factory HealthStatusModel.fromJson(Map<String, dynamic> json) {
    final services = json['services'] as Map<String, dynamic>? ?? {};
    final db = services['database'] as Map<String, dynamic>? ?? {};

    return HealthStatusModel(
      status: (json['status'] as String?) ?? 'unknown',
      timestamp: (json['timestamp'] as String?) ?? DateTime.now().toIso8601String(),
      uptimeSeconds: (json['uptimeSeconds'] as int?) ?? 0,
      environment: (json['environment'] as String?) ?? 'unknown',
      databaseStatus: (db['status'] as String?) ?? 'disconnected',
      databaseLatencyMs: db['latencyMs'] as int?,
    );
  }
}

/// Repository responsible for checking backend liveness, readiness, and connectivity.
class HealthRepository {
  final ApiClient _apiClient;

  const HealthRepository(this._apiClient);

  /// Hits GET /health on the configured backend API to confirm connectivity and database status.
  Future<HealthStatusModel> checkHealth() async {
    final response = await _apiClient.get('/health');
    if (response is Map<String, dynamic>) {
      return HealthStatusModel.fromJson(response);
    }
    throw const FormatException('Unexpected response format from /health');
  }

  /// Convenience method returning true if backend is reachable and healthy.
  Future<bool> isBackendReachable() async {
    try {
      final health = await checkHealth();
      return health.isHealthy;
    } catch (_) {
      return false;
    }
  }
}
