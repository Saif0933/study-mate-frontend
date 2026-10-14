class UsageModel {
  final int totalTokens;
  final int requestCount;
  final double estimatedCost;
  final Map<String, int> featureBreakdown;
  final int? quotaLimit;
  final int? requestsRemaining;
  final bool isExhausted;
  final String? quotaMessage;
  final DateTime? resetTime;

  const UsageModel({
    this.totalTokens = 0,
    this.requestCount = 0,
    this.estimatedCost = 0.0,
    this.featureBreakdown = const {},
    this.quotaLimit,
    this.requestsRemaining,
    this.isExhausted = false,
    this.quotaMessage,
    this.resetTime,
  });

  factory UsageModel.fromJson(Map<String, dynamic> json) {
    final breakdownRaw = json['featureBreakdown'];
    final breakdownMap = <String, int>{};
    if (breakdownRaw is Map) {
      breakdownRaw.forEach((k, v) {
        breakdownMap[k.toString()] = (v is int)
            ? v
            : int.tryParse(v.toString()) ?? 0;
      });
    }

    // Support both top-level quota fields and nested 'quota' map
    final quotaMap = json['quota'] is Map<String, dynamic>
        ? json['quota'] as Map<String, dynamic>
        : null;

    final quotaLimit =
        (json['quotaLimit'] as int?) ??
        (quotaMap != null ? (quotaMap['limit'] as int?) : null);

    final requestsRemaining =
        (json['requestsRemaining'] as int?) ??
        (quotaMap != null ? (quotaMap['remaining'] as int?) : null);

    final rawIsExhausted =
        json['isExhausted'] ??
        (quotaMap != null ? quotaMap['isExhausted'] : null);
    final isExhausted =
        rawIsExhausted == true ||
        (requestsRemaining != null && requestsRemaining <= 0) ||
        (quotaLimit != null &&
            (json['requestCount'] as int? ?? 0) >= quotaLimit);

    final quotaMessage =
        (json['quotaMessage'] as String?) ??
        (quotaMap != null ? (quotaMap['message'] as String?) : null);

    final resetTimeRaw =
        json['resetTime'] ??
        (quotaMap != null
            ? (quotaMap['resetTime'] ?? quotaMap['resetsAt'])
            : null);
    DateTime? resetTime;
    if (resetTimeRaw is String) {
      resetTime = DateTime.tryParse(resetTimeRaw);
    }

    return UsageModel(
      totalTokens: (json['totalTokens'] as int?) ?? 0,
      requestCount: (json['requestCount'] as int?) ?? 0,
      estimatedCost: (json['estimatedCost'] is num)
          ? (json['estimatedCost'] as num).toDouble()
          : 0.0,
      featureBreakdown: breakdownMap,
      quotaLimit: quotaLimit,
      requestsRemaining: requestsRemaining,
      isExhausted: isExhausted,
      quotaMessage: quotaMessage,
      resetTime: resetTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalTokens': totalTokens,
      'requestCount': requestCount,
      'estimatedCost': estimatedCost,
      'featureBreakdown': featureBreakdown,
      if (quotaLimit != null) 'quotaLimit': quotaLimit,
      if (requestsRemaining != null) 'requestsRemaining': requestsRemaining,
      'isExhausted': isExhausted,
      if (quotaMessage != null) 'quotaMessage': quotaMessage,
      if (resetTime != null) 'resetTime': resetTime!.toIso8601String(),
    };
  }
}
