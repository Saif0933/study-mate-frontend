class FeedbackModel {
  final String? id;
  final String rating; // 'POSITIVE', 'NEGATIVE', or '1'..'5'
  final String? category; // 'HELPFULNESS', 'ACCURACY', 'SUGGESTION', 'BUG'
  final String comment;
  final String? messageId;
  final DateTime? createdAt;

  const FeedbackModel({
    this.id,
    required this.rating,
    this.category,
    required this.comment,
    this.messageId,
    this.createdAt,
  });

  factory FeedbackModel.fromJson(Map<String, dynamic> json) {
    return FeedbackModel(
      id: json['id'] as String?,
      rating: (json['rating'] as String?) ?? 'POSITIVE',
      category: json['category'] as String?,
      comment: (json['comment'] as String?) ?? '',
      messageId: json['messageId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'rating': rating,
      'category': ?category,
      'comment': comment,
      'messageId': ?messageId,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }
}
