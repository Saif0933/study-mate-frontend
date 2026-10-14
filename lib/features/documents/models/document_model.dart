class DocumentModel {
  final String id;
  final String originalName;
  final String mimeType;
  final int sizeBytes;
  final String status; // UPLOADED, PROCESSING, READY, FAILED, DELETING, DELETED
  final int? pageCount;
  final String? errorCode;
  final DateTime createdAt;
  final DateTime? processedAt;

  const DocumentModel({
    required this.id,
    required this.originalName,
    required this.mimeType,
    required this.sizeBytes,
    required this.status,
    this.pageCount,
    this.errorCode,
    required this.createdAt,
    this.processedAt,
  });

  bool get isReady => status.toUpperCase() == 'READY';
  bool get isProcessing =>
      status.toUpperCase() == 'PROCESSING' ||
      status.toUpperCase() == 'UPLOADED';
  bool get isFailed => status.toUpperCase() == 'FAILED';
  bool get isDeleting => status.toUpperCase() == 'DELETING';
  bool get isDeleted => status.toUpperCase() == 'DELETED';

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  DocumentModel copyWith({
    String? id,
    String? originalName,
    String? mimeType,
    int? sizeBytes,
    String? status,
    int? pageCount,
    String? errorCode,
    DateTime? createdAt,
    DateTime? processedAt,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      originalName: originalName ?? this.originalName,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      status: status ?? this.status,
      pageCount: pageCount ?? this.pageCount,
      errorCode: errorCode ?? this.errorCode,
      createdAt: createdAt ?? this.createdAt,
      processedAt: processedAt ?? this.processedAt,
    );
  }

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'] as String,
      originalName: (json['originalName'] as String?) ?? 'Document.pdf',
      mimeType: (json['mimeType'] as String?) ?? 'application/pdf',
      sizeBytes: (json['sizeBytes'] is int)
          ? json['sizeBytes'] as int
          : int.tryParse(json['sizeBytes']?.toString() ?? '0') ?? 0,
      status: (json['status'] as String?) ?? 'UPLOADED',
      pageCount: json['pageCount'] as int?,
      errorCode: json['errorCode'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      processedAt: json['processedAt'] != null
          ? DateTime.parse(json['processedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'originalName': originalName,
      'mimeType': mimeType,
      'sizeBytes': sizeBytes,
      'status': status,
      if (pageCount != null) 'pageCount': pageCount,
      if (errorCode != null) 'errorCode': errorCode,
      'createdAt': createdAt.toIso8601String(),
      if (processedAt != null) 'processedAt': processedAt!.toIso8601String(),
    };
  }
}

class DocumentQAResponse {
  final String answer;
  final List<DocumentCitation> sources;
  final bool hasSufficientEvidence;
  final String? confidence;

  const DocumentQAResponse({
    required this.answer,
    this.sources = const [],
    this.hasSufficientEvidence = true,
    this.confidence,
  });

  factory DocumentQAResponse.fromJson(Map<String, dynamic> json) {
    final sourcesRaw = json['sources'];
    final sourcesList = <DocumentCitation>[];

    if (sourcesRaw is List) {
      for (final s in sourcesRaw) {
        if (s is Map<String, dynamic>) {
          sourcesList.add(DocumentCitation.fromJson(s));
        }
      }
    }

    // Check insufficient evidence flags from backend
    final insufficientFlag =
        json['insufficientEvidence'] == true ||
        json['hasSufficientEvidence'] == false;

    return DocumentQAResponse(
      answer: (json['answer'] as String?) ?? '',
      sources: sourcesList,
      hasSufficientEvidence: !insufficientFlag,
      confidence: json['confidence'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'answer': answer,
      'sources': sources.map((s) => s.toJson()).toList(),
      'hasSufficientEvidence': hasSufficientEvidence,
      if (confidence != null) 'confidence': confidence,
    };
  }
}

class DocumentCitation {
  final String? documentId;
  final int? page;
  final String? chunkId;
  final String? excerpt;

  const DocumentCitation({
    this.documentId,
    this.page,
    this.chunkId,
    this.excerpt,
  });

  factory DocumentCitation.fromJson(Map<String, dynamic> json) {
    return DocumentCitation(
      documentId: json['documentId'] as String?,
      page: json['page'] as int?,
      chunkId: json['chunkId'] as String?,
      excerpt: json['excerpt'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (documentId != null) 'documentId': documentId,
      if (page != null) 'page': page,
      if (chunkId != null) 'chunkId': chunkId,
      if (excerpt != null) 'excerpt': excerpt,
    };
  }
}
