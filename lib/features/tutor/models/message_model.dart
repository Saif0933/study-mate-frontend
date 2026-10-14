class MessageModel {
  final String id;
  final String conversationId;
  final String role; // 'user' or 'assistant' or 'system'
  final String content;
  final DateTime createdAt;
  final String? modelId;
  final int? inputTokens;
  final int? outputTokens;
  final int? latencyMs;
  final List<SourceCitation>? citations;

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.modelId,
    this.inputTokens,
    this.outputTokens,
    this.latencyMs,
    this.citations,
  });

  bool get isUser => role.toLowerCase() == 'user';
  bool get isAssistant => role.toLowerCase() == 'assistant';

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      role: (json['role'] as String?)?.toLowerCase() ?? 'user',
      content: (json['content'] as String?) ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      modelId: json['modelId'] as String?,
      inputTokens: json['inputTokens'] as int?,
      outputTokens: json['outputTokens'] as int?,
      latencyMs: json['latencyMs'] as int?,
      citations: json['citations'] != null
          ? (json['citations'] as List)
                .map((c) => SourceCitation.fromJson(c as Map<String, dynamic>))
                .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'role': role,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      if (modelId != null) 'modelId': modelId,
      if (inputTokens != null) 'inputTokens': inputTokens,
      if (outputTokens != null) 'outputTokens': outputTokens,
    };
  }
}

class SourceCitation {
  final String documentId;
  final int? page;
  final String? chunkId;

  const SourceCitation({required this.documentId, this.page, this.chunkId});

  factory SourceCitation.fromJson(Map<String, dynamic> json) {
    return SourceCitation(
      documentId: (json['documentId'] ?? '') as String,
      page: json['page'] as int?,
      chunkId: json['chunkId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'documentId': documentId,
      if (page != null) 'page': page,
      if (chunkId != null) 'chunkId': chunkId,
    };
  }
}
