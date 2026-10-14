class QuizModel {
  final String id;
  final String title;
  final String? topic;
  final String difficulty; // EASY, MEDIUM, HARD
  final int questionCount;
  final String status;
  final String? sourceDocumentId;
  final DateTime createdAt;

  const QuizModel({
    required this.id,
    required this.title,
    this.topic,
    required this.difficulty,
    required this.questionCount,
    required this.status,
    this.sourceDocumentId,
    required this.createdAt,
  });

  String get formattedDifficulty {
    switch (difficulty.toUpperCase()) {
      case 'EASY':
        return 'Easy';
      case 'HARD':
        return 'Hard';
      case 'MEDIUM':
      default:
        return 'Medium';
    }
  }

  QuizModel copyWith({
    String? id,
    String? title,
    String? topic,
    String? difficulty,
    int? questionCount,
    String? status,
    String? sourceDocumentId,
    DateTime? createdAt,
  }) {
    return QuizModel(
      id: id ?? this.id,
      title: title ?? this.title,
      topic: topic ?? this.topic,
      difficulty: difficulty ?? this.difficulty,
      questionCount: questionCount ?? this.questionCount,
      status: status ?? this.status,
      sourceDocumentId: sourceDocumentId ?? this.sourceDocumentId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory QuizModel.fromJson(Map<String, dynamic> json) {
    return QuizModel(
      id: (json['id'] ?? '') as String,
      title: (json['title'] as String?) ?? 'Practice Quiz',
      topic: json['topic'] as String?,
      difficulty: (json['difficulty'] as String?) ?? 'MEDIUM',
      questionCount: (json['questionCount'] as int?) ?? 5,
      status: (json['status'] as String?) ?? 'READY',
      sourceDocumentId: json['sourceDocumentId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      if (topic != null) 'topic': topic,
      'difficulty': difficulty,
      'questionCount': questionCount,
      'status': status,
      if (sourceDocumentId != null) 'sourceDocumentId': sourceDocumentId,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class QuizQuestionModel {
  final String id;
  final int orderIndex;
  final String prompt;
  final List<String> options;
  final String? correctAnswer; // Nullable during active attempt
  final String? explanation;

  const QuizQuestionModel({
    required this.id,
    required this.orderIndex,
    required this.prompt,
    required this.options,
    this.correctAnswer,
    this.explanation,
  });

  bool get isValid =>
      id.isNotEmpty &&
      prompt.trim().isNotEmpty &&
      options.length >= 2 &&
      options.every((opt) => opt.trim().isNotEmpty);

  factory QuizQuestionModel.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    List<String> parsedOptions = [];
    if (rawOptions is List) {
      parsedOptions = rawOptions
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } else if (rawOptions is Map) {
      parsedOptions = rawOptions.values
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return QuizQuestionModel(
      id: (json['id'] ?? '') as String,
      orderIndex: (json['orderIndex'] as int?) ?? 0,
      prompt: (json['prompt'] as String?) ?? '',
      options: parsedOptions,
      correctAnswer: json['correctAnswer'] as String?,
      explanation: json['explanation'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderIndex': orderIndex,
      'prompt': prompt,
      'options': options,
      if (correctAnswer != null) 'correctAnswer': correctAnswer,
      if (explanation != null) 'explanation': explanation,
    };
  }
}

class QuizAttemptModel {
  final String id;
  final String quizId;
  final String status; // IN_PROGRESS, SUBMITTED, ABANDONED
  final int? score;
  final int totalQuestions;
  final DateTime startedAt;
  final DateTime? submittedAt;
  final List<QuizQuestionModel> questions;

  const QuizAttemptModel({
    required this.id,
    required this.quizId,
    required this.status,
    this.score,
    required this.totalQuestions,
    required this.startedAt,
    this.submittedAt,
    this.questions = const [],
  });

  bool get isValid =>
      id.isNotEmpty &&
      questions.isNotEmpty &&
      questions.every((q) => q.isValid);

  factory QuizAttemptModel.fromJson(Map<String, dynamic> json) {
    final questionsRaw = json['questions'] ?? json['quiz']?['questions'];
    final questionList = <QuizQuestionModel>[];
    if (questionsRaw is List) {
      for (final q in questionsRaw) {
        if (q is Map<String, dynamic>) {
          final parsed = QuizQuestionModel.fromJson(q);
          if (parsed.isValid) {
            questionList.add(parsed);
          }
        }
      }
    }

    return QuizAttemptModel(
      id: (json['id'] ?? '') as String,
      quizId: (json['quizId'] ?? '') as String,
      status: (json['status'] as String?) ?? 'IN_PROGRESS',
      score: json['score'] as int?,
      totalQuestions: (json['totalQuestions'] as int?) ?? questionList.length,
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : DateTime.now(),
      submittedAt: json['submittedAt'] != null
          ? DateTime.tryParse(json['submittedAt'] as String)
          : null,
      questions: questionList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quizId': quizId,
      'status': status,
      if (score != null) 'score': score,
      'totalQuestions': totalQuestions,
      'startedAt': startedAt.toIso8601String(),
      if (submittedAt != null) 'submittedAt': submittedAt!.toIso8601String(),
      'questions': questions.map((q) => q.toJson()).toList(),
    };
  }
}

class QuizSubmissionResult {
  final String attemptId;
  final int score;
  final int totalQuestions;
  final List<QuestionReviewItem> review;

  const QuizSubmissionResult({
    required this.attemptId,
    required this.score,
    required this.totalQuestions,
    required this.review,
  });

  double get percentage =>
      totalQuestions > 0 ? (score / totalQuestions) * 100 : 0.0;

  bool get isPassed => percentage >= 60.0;

  factory QuizSubmissionResult.fromJson(Map<String, dynamic> json) {
    final reviewRaw = json['review'] ?? json['responses'];
    final reviewList = <QuestionReviewItem>[];
    if (reviewRaw is List) {
      for (final r in reviewRaw) {
        if (r is Map<String, dynamic>) {
          reviewList.add(QuestionReviewItem.fromJson(r));
        }
      }
    }

    return QuizSubmissionResult(
      attemptId: (json['attemptId'] ?? json['id'] ?? '') as String,
      score: (json['score'] as int?) ?? 0,
      totalQuestions: (json['totalQuestions'] as int?) ?? reviewList.length,
      review: reviewList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'attemptId': attemptId,
      'score': score,
      'totalQuestions': totalQuestions,
      'review': review.map((r) => r.toJson()).toList(),
    };
  }
}

class QuestionReviewItem {
  final String questionId;
  final String prompt;
  final String? selectedAnswer;
  final String correctAnswer;
  final bool isCorrect;
  final String? explanation;

  const QuestionReviewItem({
    required this.questionId,
    required this.prompt,
    this.selectedAnswer,
    required this.correctAnswer,
    required this.isCorrect,
    this.explanation,
  });

  factory QuestionReviewItem.fromJson(Map<String, dynamic> json) {
    return QuestionReviewItem(
      questionId: (json['questionId'] ?? '') as String,
      prompt: (json['prompt'] ?? json['question']?['prompt'] ?? '') as String,
      selectedAnswer: json['selectedAnswer'] as String?,
      correctAnswer:
          (json['correctAnswer'] ?? json['question']?['correctAnswer'] ?? '')
              as String,
      isCorrect: (json['isCorrect'] as bool?) ?? false,
      explanation:
          (json['explanation'] ?? json['question']?['explanation']) as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'questionId': questionId,
      'prompt': prompt,
      if (selectedAnswer != null) 'selectedAnswer': selectedAnswer,
      'correctAnswer': correctAnswer,
      'isCorrect': isCorrect,
      if (explanation != null) 'explanation': explanation,
    };
  }
}
