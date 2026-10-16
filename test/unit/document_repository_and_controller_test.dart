import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_mate_frontend/core/network/api_client.dart';
import 'package:study_mate_frontend/core/network/api_exceptions.dart';
import 'package:study_mate_frontend/features/documents/controllers/document_chat_controller.dart';
import 'package:study_mate_frontend/features/documents/controllers/document_list_controller.dart';
import 'package:study_mate_frontend/features/documents/models/document_model.dart';
import 'package:study_mate_frontend/features/documents/repositories/document_repository.dart';

class FakeApiClient extends Fake implements ApiClient {
  final Map<String, dynamic> responses = {};
  final Map<String, ApiException> errors = {};
  int uploadCallCount = 0;
  int deleteCallCount = 0;
  dynamic lastPostData;
  String? lastDeletePath;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (errors.containsKey(path)) {
      throw errors[path]!;
    }
    return responses[path];
  }

  @override
  Future<dynamic> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    lastPostData = data;
    if (errors.containsKey(path)) {
      throw errors[path]!;
    }
    return responses[path];
  }

  @override
  Future<dynamic> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    deleteCallCount++;
    lastDeletePath = path;
    if (errors.containsKey(path)) {
      throw errors[path]!;
    }
    return responses[path];
  }

  @override
  Future<dynamic> uploadFile(
    String path, {
    required File file,
    required String fileFieldName,
    String? customFileName,
    Map<String, dynamic>? extraFields,
    ProgressCallback? onSendProgress,
  }) async {
    uploadCallCount++;
    if (onSendProgress != null) {
      onSendProgress(500, 1000);
      onSendProgress(1000, 1000);
    }
    if (errors.containsKey(path)) {
      throw errors[path]!;
    }
    return responses[path];
  }
}

void main() {
  group('DocumentModel and QAResponse Tests', () {
    test('parses DocumentModel from JSON correctly', () {
      final json = {
        'id': 'doc-101',
        'originalName': 'Biology_Chapter_4.pdf',
        'mimeType': 'application/pdf',
        'sizeBytes': 2048576,
        'status': 'READY',
        'pageCount': 12,
        'createdAt': '2026-10-12T10:00:00.000Z',
      };

      final doc = DocumentModel.fromJson(json);
      expect(doc.id, 'doc-101');
      expect(doc.originalName, 'Biology_Chapter_4.pdf');
      expect(doc.isReady, isTrue);
      expect(doc.isProcessing, isFalse);
      expect(doc.isFailed, isFalse);
      expect(doc.pageCount, 12);
      expect(doc.formattedSize, '2.0 MB');
    });

    test(
      'supports statuses UPLOADED, PROCESSING, FAILED, DELETING, DELETED',
      () {
        final docBase = DocumentModel(
          id: 'doc-1',
          originalName: 'test.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 500,
          status: 'UPLOADED',
          createdAt: DateTime.now(),
        );

        expect(docBase.isProcessing, isTrue);
        expect(docBase.isReady, isFalse);

        final processingDoc = docBase.copyWith(status: 'PROCESSING');
        expect(processingDoc.isProcessing, isTrue);

        final failedDoc = docBase.copyWith(
          status: 'FAILED',
          errorCode: 'CORRUPT_PDF',
        );
        expect(failedDoc.isFailed, isTrue);
        expect(failedDoc.errorCode, 'CORRUPT_PDF');

        final deletingDoc = docBase.copyWith(status: 'DELETING');
        expect(deletingDoc.isDeleting, isTrue);

        final deletedDoc = docBase.copyWith(status: 'DELETED');
        expect(deletedDoc.isDeleted, isTrue);
      },
    );

    test(
      'parses DocumentQAResponse with citations and insufficient evidence flag',
      () {
        final jsonWithEvidence = {
          'answer':
              'Mitochondria generates ATP through oxidative phosphorylation.',
          'sources': [
            {'documentId': 'doc-1', 'page': 4, 'chunkId': 'chunk-9'},
            {'documentId': 'doc-1', 'page': 5},
          ],
          'hasSufficientEvidence': true,
        };

        final res1 = DocumentQAResponse.fromJson(jsonWithEvidence);
        expect(res1.hasSufficientEvidence, isTrue);
        expect(res1.sources.length, 2);
        expect(res1.sources[0].page, 4);
        expect(res1.sources[0].chunkId, 'chunk-9');
        expect(res1.sources[1].page, 5);

        final jsonInsufficient = {
          'answer': 'The uploaded syllabus does not specify the exam date.',
          'sources': [],
          'insufficientEvidence': true,
        };

        final res2 = DocumentQAResponse.fromJson(jsonInsufficient);
        expect(res2.hasSufficientEvidence, isFalse);
        expect(res2.sources.isEmpty, isTrue);
      },
    );
  });

  group('DocumentRepository Unit Tests', () {
    late FakeApiClient apiClient;
    late DocumentRepository repository;

    final sampleDocJson = {
      'id': 'doc-101',
      'originalName': 'Physics_Notes.pdf',
      'mimeType': 'application/pdf',
      'sizeBytes': 102400,
      'status': 'READY',
      'createdAt': '2026-10-12T10:00:00.000Z',
    };

    setUp(() {
      apiClient = FakeApiClient();
      repository = DocumentRepository(apiClient: apiClient);
    });

    test('getDocuments returns parsed documents list', () async {
      apiClient.responses['/documents'] = [sampleDocJson];

      final docs = await repository.getDocuments();
      expect(docs.length, 1);
      expect(docs.first.id, 'doc-101');
      expect(docs.first.originalName, 'Physics_Notes.pdf');
    });

    test('getDocument fetches single document metadata', () async {
      apiClient.responses['/documents/doc-101'] = sampleDocJson;

      final doc = await repository.getDocument('doc-101');
      expect(doc.id, 'doc-101');
      expect(doc.isReady, isTrue);
    });

    test('askQuestion sends payload to /documents/:id/questions', () async {
      apiClient.responses['/documents/doc-101/questions'] = {
        'answer': 'Newton’s second law states F=ma.',
        'sources': [
          {'documentId': 'doc-101', 'page': 3},
        ],
        'hasSufficientEvidence': true,
      };

      final response = await repository.askQuestion(
        documentId: 'doc-101',
        question: 'State Newton’s second law',
      );

      expect(apiClient.lastPostData, {'question': 'State Newton’s second law'});
      expect(response.answer, contains('F=ma'));
      expect(response.sources.first.page, 3);
      expect(response.hasSufficientEvidence, isTrue);
    });

    test('deleteDocument calls DELETE /documents/:id', () async {
      apiClient.responses['/documents/doc-101'] = {'deleted': true};

      await repository.deleteDocument('doc-101');
      expect(apiClient.deleteCallCount, 1);
      expect(apiClient.lastDeletePath, '/documents/doc-101');
    });
  });

  group('DocumentListController Unit Tests', () {
    test('validateFile rejects unsupported format and oversized files', () {
      expect(
        DocumentListController.validateFile(name: 'photo.jpg', size: 1024),
        contains('Unsupported file format'),
      );

      expect(
        DocumentListController.validateFile(name: 'notes.pdf', size: 0),
        contains('empty (0 bytes)'),
      );

      expect(
        DocumentListController.validateFile(
          name: 'huge_book.pdf',
          size: 15 * 1024 * 1024,
        ),
        contains('exceeds the 10 MB limit'),
      );

      expect(
        DocumentListController.validateFile(
          name: 'chapter1.pdf',
          size: 2 * 1024 * 1024,
        ),
        isNull,
      );
    });

    test(
      'uploadFile updates progress and adds new document to state',
      () async {
        final apiClient = FakeApiClient();
        final repository = DocumentRepository(apiClient: apiClient);

        final uploadedDocJson = {
          'id': 'doc-new',
          'originalName': 'Lecture1.pdf',
          'mimeType': 'application/pdf',
          'sizeBytes': 5000,
          'status': 'UPLOADED',
          'createdAt': '2026-10-12T10:00:00.000Z',
        };
        apiClient.responses['/documents'] = <dynamic>[];

        final container = ProviderContainer(
          overrides: [documentRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);

        // Read initial state
        container.read(documentListControllerProvider);
        await Future<void>.delayed(const Duration(milliseconds: 30));

        final tempFile = File('${Directory.systemTemp.path}/Lecture1.pdf');
        await tempFile.writeAsString('Dummy PDF content for testing');
        addTearDown(() async {
          if (await tempFile.exists()) await tempFile.delete();
        });

        apiClient.responses['/documents'] = uploadedDocJson;

        final controller = container.read(
          documentListControllerProvider.notifier,
        );
        final error = await controller.uploadFile(tempFile);

        expect(error, isNull);
        expect(apiClient.uploadCallCount, 1);
        final list = container.read(documentListControllerProvider).value!;
        expect(list.length, 1);
        expect(list.first.id, 'doc-new');
        expect(list.first.status, 'UPLOADED');
      },
    );

    test(
      'deleteDocument removes document from state upon server confirmation',
      () async {
        final apiClient = FakeApiClient();
        final repository = DocumentRepository(apiClient: apiClient);

        final initialDocs = [
          {
            'id': 'doc-1',
            'originalName': 'Doc1.pdf',
            'mimeType': 'application/pdf',
            'sizeBytes': 1000,
            'status': 'READY',
            'createdAt': '2026-10-12T10:00:00.000Z',
          },
        ];
        apiClient.responses['/documents'] = initialDocs;
        apiClient.responses['/documents/doc-1'] = {'deleted': true};

        final container = ProviderContainer(
          overrides: [documentRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);

        container.read(documentListControllerProvider);
        await Future<void>.delayed(const Duration(milliseconds: 30));

        final controller = container.read(
          documentListControllerProvider.notifier,
        );
        final success = await controller.deleteDocument('doc-1');

        expect(success, isTrue);
        expect(apiClient.deleteCallCount, 1);
        final list = container.read(documentListControllerProvider).value!;
        expect(list.isEmpty, isTrue);
      },
    );
  });

  group('DocumentChatController Unit Tests', () {
    test('askQuestion updates entry with answer and citations', () async {
      final apiClient = FakeApiClient();
      final repository = DocumentRepository(apiClient: apiClient);

      apiClient.responses['/documents/doc-101/questions'] = {
        'answer': 'Mitosis results in two identical daughter cells.',
        'sources': [
          {'documentId': 'doc-101', 'page': 7},
        ],
        'hasSufficientEvidence': true,
      };

      final container = ProviderContainer(
        overrides: [documentRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        documentChatControllerProvider('doc-101').notifier,
      );
      final success = await controller.askQuestion('What is mitosis?');

      expect(success, isTrue);
      final state = container.read(documentChatControllerProvider('doc-101'));
      expect(state.entries.length, 1);
      final entry = state.entries.first;
      expect(entry.question, 'What is mitosis?');
      expect(entry.answer, contains('two identical daughter cells'));
      expect(entry.sources.first.page, 7);
      expect(entry.hasSufficientEvidence, isTrue);
      expect(entry.isPending, isFalse);
    });

    test('handles insufficient evidence state from backend response', () async {
      final apiClient = FakeApiClient();
      final repository = DocumentRepository(apiClient: apiClient);

      apiClient.responses['/documents/doc-101/questions'] = {
        'answer': 'The document does not state the author’s birthplace.',
        'sources': [],
        'hasSufficientEvidence': false,
      };

      final container = ProviderContainer(
        overrides: [documentRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        documentChatControllerProvider('doc-101').notifier,
      );
      final success = await controller.askQuestion(
        'Where was the author born?',
      );

      expect(success, isTrue);
      final state = container.read(documentChatControllerProvider('doc-101'));
      final entry = state.entries.first;
      expect(entry.hasSufficientEvidence, isFalse);
      expect(entry.sources.isEmpty, isTrue);
    });

    test('retryQuestion resends failed question and resolves answer', () async {
      final apiClient = FakeApiClient();
      final repository = DocumentRepository(apiClient: apiClient);

      // First call fails
      apiClient.errors['/documents/doc-101/questions'] = ApiException(
        code: 'TIMEOUT',
        message: 'Network request timed out.',
      );

      final container = ProviderContainer(
        overrides: [documentRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        documentChatControllerProvider('doc-101').notifier,
      );
      final firstAttempt = await controller.askQuestion('Define entropy.');

      expect(firstAttempt, isFalse);
      var state = container.read(documentChatControllerProvider('doc-101'));
      expect(state.entries.first.error, 'Network request timed out.');

      // Second call succeeds
      apiClient.errors.remove('/documents/doc-101/questions');
      apiClient.responses['/documents/doc-101/questions'] = {
        'answer': 'Entropy is a measure of randomness or disorder in a system.',
        'sources': [
          {'documentId': 'doc-101', 'page': 14},
        ],
        'hasSufficientEvidence': true,
      };

      final retryAttempt = await controller.retryQuestion(0);
      expect(retryAttempt, isTrue);
      state = container.read(documentChatControllerProvider('doc-101'));
      expect(state.entries.first.error, isNull);
      expect(state.entries.first.answer, contains('randomness or disorder'));
      expect(state.entries.first.sources.first.page, 14);
    });

    test(
      'markDocumentDeleted prevents new questions from being sent',
      () async {
        final apiClient = FakeApiClient();
        final repository = DocumentRepository(apiClient: apiClient);

        final container = ProviderContainer(
          overrides: [documentRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);

        final controller = container.read(
          documentChatControllerProvider('doc-101').notifier,
        );
        controller.markDocumentDeleted();

        final state = container.read(documentChatControllerProvider('doc-101'));
        expect(state.isDocumentDeleted, isTrue);

        final success = await controller.askQuestion('Are you there?');
        expect(success, isFalse);
        expect(apiClient.lastPostData, isNull);
      },
    );
  });
}
