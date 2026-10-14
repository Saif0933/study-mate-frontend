import 'package:flutter_test/flutter_test.dart';
import 'package:study_mate_frontend/features/auth/models/user_model.dart';
import 'package:study_mate_frontend/features/tutor/models/conversation_model.dart';
import 'package:study_mate_frontend/features/tutor/models/message_model.dart';
import 'package:study_mate_frontend/features/documents/models/document_model.dart';
import 'package:study_mate_frontend/features/quizzes/models/quiz_model.dart';
import 'package:study_mate_frontend/features/study_plans/models/study_plan_model.dart';

void main() {
  group('Domain Models Unit Tests', () {
    test('UserModel serialization and deserialization', () {
      final json = {
        'id': 'usr-123',
        'email': 'student@university.edu',
        'displayName': 'Alex Learner',
        'status': 'ACTIVE',
      };
      final user = UserModel.fromJson(json);
      expect(user.id, equals('usr-123'));
      expect(user.email, equals('student@university.edu'));
      expect(user.displayName, equals('Alex Learner'));
      expect(user.status, equals('ACTIVE'));
    });

    test('ConversationModel serialization and deserialization', () {
      final json = {
        'id': 'conv-123',
        'title': 'Organic Chemistry Exam Review',
        'createdAt': '2026-10-12T10:00:00.000Z',
      };
      final conv = ConversationModel.fromJson(json);
      expect(conv.id, equals('conv-123'));
      expect(conv.title, equals('Organic Chemistry Exam Review'));
    });

    test('MessageModel serialization with citations', () {
      final json = {
        'id': 'msg-1',
        'conversationId': 'conv-123',
        'role': 'assistant',
        'content': 'Photosynthesis occurs in chloroplasts.',
        'createdAt': '2026-10-12T10:01:00.000Z',
        'citations': [
          {'documentId': 'doc-1', 'page': 4, 'chunkId': 'chk-4'},
        ],
      };
      final msg = MessageModel.fromJson(json);
      expect(msg.isAssistant, isTrue);
      expect(msg.isUser, isFalse);
      expect(msg.citations, isNotNull);
      expect(msg.citations!.first.page, equals(4));
    });

    test('DocumentModel size and status checks', () {
      final json = {
        'id': 'doc-99',
        'originalName': 'biology_ch3.pdf',
        'mimeType': 'application/pdf',
        'sizeBytes': 2097152, // 2 MB
        'status': 'READY',
        'pageCount': 18,
        'createdAt': '2026-10-12T08:00:00.000Z',
      };
      final doc = DocumentModel.fromJson(json);
      expect(doc.isReady, isTrue);
      expect(doc.isProcessing, isFalse);
      expect(doc.formattedSize, equals('2.0 MB'));
    });

    test('QuizModel and Submission scoring', () {
      final resultJson = {
        'attemptId': 'att-1',
        'score': 4,
        'totalQuestions': 5,
        'review': [
          {
            'questionId': 'q1',
            'prompt': 'What is ATP?',
            'selectedAnswer': 'Energy currency',
            'correctAnswer': 'Energy currency',
            'isCorrect': true,
            'explanation': 'ATP stores and transfers chemical energy.',
          },
        ],
      };
      final result = QuizSubmissionResult.fromJson(resultJson);
      expect(result.score, equals(4));
      expect(result.totalQuestions, equals(5));
      expect(result.review.first.isCorrect, isTrue);
    });

    test('StudyPlanModel task progress calculation', () {
      final planJson = {
        'id': 'plan-1',
        'title': 'Midterm Plan',
        'dailyMinutes': 90,
        'status': 'ACTIVE',
        'createdAt': '2026-10-12T09:00:00.000Z',
        'tasks': [
          {
            'id': 't1',
            'planId': 'plan-1',
            'title': 'Read Chapter 1',
            'scheduledDate': '2026-10-13T09:00:00.000Z',
            'durationMinutes': 45,
            'status': 'COMPLETED',
          },
          {
            'id': 't2',
            'planId': 'plan-1',
            'title': 'Practice Problems 1-10',
            'scheduledDate': '2026-10-13T10:00:00.000Z',
            'durationMinutes': 45,
            'status': 'TODO',
          },
        ],
      };
      final plan = StudyPlanModel.fromJson(planJson);
      expect(plan.tasks.length, equals(2));
      expect(plan.completedTaskCount, equals(1));
      expect(plan.completionProgress, equals(0.5));
    });
  });
}
