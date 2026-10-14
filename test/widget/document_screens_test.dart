import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_mate_frontend/core/routing/app_router.dart';
import 'package:study_mate_frontend/core/theme/app_theme.dart';
import 'package:study_mate_frontend/features/documents/controllers/document_chat_controller.dart';
import 'package:study_mate_frontend/features/documents/controllers/document_list_controller.dart';
import 'package:study_mate_frontend/features/documents/models/document_model.dart';
import 'package:study_mate_frontend/features/documents/screens/document_chat_screen.dart';
import 'package:study_mate_frontend/features/documents/screens/document_list_screen.dart';

class MockDocumentListController extends DocumentListController {
  final List<DocumentModel> initialDocs;
  bool deleteCalled = false;
  String? lastDeletedId;

  MockDocumentListController({this.initialDocs = const []});

  @override
  Future<List<DocumentModel>> build() async {
    return initialDocs;
  }

  @override
  Future<bool> deleteDocument(String id) async {
    deleteCalled = true;
    lastDeletedId = id;
    final current = state.value ?? [];
    state = AsyncValue.data(current.where((d) => d.id != id).toList());
    return true;
  }
}

class MockDocumentChatController extends DocumentChatController {
  final DocumentChatState customInitialState;
  bool askQuestionCalled = false;
  String? lastQuestionAsked;
  bool failNextAsk = false;

  MockDocumentChatController(
    super.documentId, {
    this.customInitialState = const DocumentChatState(),
    this.failNextAsk = false,
  });

  @override
  DocumentChatState build() {
    return customInitialState;
  }

  @override
  Future<bool> askQuestion(String question) async {
    askQuestionCalled = true;
    lastQuestionAsked = question;

    if (failNextAsk) {
      state = state.copyWith(
        isAsking: false,
        generalError: 'Connection error while reasoning over document.',
        entries: [
          ...state.entries,
          DocumentQAEntry(
            question: question,
            error: 'Connection error while reasoning over document.',
            isPending: false,
          ),
        ],
      );
      return false;
    }

    final newEntry = DocumentQAEntry(
      question: question,
      answer: 'This is the verified grounded answer from page 4.',
      sources: [DocumentCitation(documentId: documentId, page: 4)],
      hasSufficientEvidence: true,
      isPending: false,
    );

    state = state.copyWith(
      entries: [...state.entries, newEntry],
      isAsking: false,
    );
    return true;
  }

  @override
  Future<bool> retryQuestion(int index) async {
    if (index >= 0 && index < state.entries.length) {
      final updated = List<DocumentQAEntry>.from(state.entries);
      updated[index] = updated[index].copyWith(
        answer: 'Recovered answer from document chunks.',
        sources: [DocumentCitation(documentId: documentId, page: 9)],
        error: null,
        isPending: false,
      );
      state = state.copyWith(
        entries: updated,
        isAsking: false,
        clearError: true,
      );
      return true;
    }
    return false;
  }
}

class MockIsDocumentUploadingNotifier extends IsDocumentUploadingNotifier {
  final bool initialValue;
  MockIsDocumentUploadingNotifier(this.initialValue);
  @override
  bool build() => initialValue;
}

class MockDocumentUploadProgressNotifier
    extends DocumentUploadProgressNotifier {
  final double? initialValue;
  MockDocumentUploadProgressNotifier(this.initialValue);
  @override
  double? build() => initialValue;
}

Widget createDocumentWidget({
  required Widget child,
  List<DocumentModel>? documents,
  bool isUploading = false,
  double? uploadProgress,
  MockDocumentChatController? customChatController,
  String? chatDocId,
}) {
  return ProviderScope(
    overrides: [
      documentListControllerProvider.overrideWith(
        () => MockDocumentListController(initialDocs: documents ?? []),
      ),
      isDocumentUploadingProvider.overrideWith(
        () => MockIsDocumentUploadingNotifier(isUploading),
      ),
      documentUploadProgressProvider.overrideWith(
        () => MockDocumentUploadProgressNotifier(uploadProgress),
      ),
      if (customChatController != null && chatDocId != null)
        documentChatControllerProvider(
          chatDocId,
        ).overrideWith(() => customChatController),
    ],
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      onGenerateRoute: AppRouter.onGenerateRoute,
      home: child,
    ),
  );
}

void main() {
  final readyDoc = DocumentModel(
    id: 'doc-ready',
    originalName: 'Cell_Biology_Notes.pdf',
    mimeType: 'application/pdf',
    sizeBytes: 1572864, // 1.5 MB
    status: 'READY',
    pageCount: 14,
    createdAt: DateTime.now(),
  );

  final processingDoc = DocumentModel(
    id: 'doc-proc',
    originalName: 'Organic_Chemistry_Vol1.pdf',
    mimeType: 'application/pdf',
    sizeBytes: 5242880, // 5.0 MB
    status: 'PROCESSING',
    createdAt: DateTime.now(),
  );

  final failedDoc = DocumentModel(
    id: 'doc-fail',
    originalName: 'Corrupted_Syllabus.pdf',
    mimeType: 'application/pdf',
    sizeBytes: 819200,
    status: 'FAILED',
    errorCode: 'ENCRYPTED_PDF_NOT_SUPPORTED',
    createdAt: DateTime.now(),
  );

  group('DocumentListScreen Widget Tests (Phase 4)', () {
    testWidgets('renders empty state when no documents exist', (tester) async {
      await tester.pumpWidget(
        createDocumentWidget(child: const DocumentListScreen(), documents: []),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Study Materials'), findsOneWidget);
      expect(find.text('No documents uploaded yet'), findsOneWidget);
      expect(find.text('Upload PDF (max 10MB)'), findsOneWidget);
    });

    testWidgets(
      'renders document list with items, size, pages, and status badges',
      (tester) async {
        await tester.pumpWidget(
          createDocumentWidget(
            child: const DocumentListScreen(),
            documents: [readyDoc, processingDoc, failedDoc],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Cell_Biology_Notes.pdf'), findsOneWidget);
        expect(find.text('Organic_Chemistry_Vol1.pdf'), findsOneWidget);
        expect(find.text('Corrupted_Syllabus.pdf'), findsOneWidget);

        expect(find.text('Ready'), findsOneWidget);
        expect(find.text('Processing'), findsOneWidget);
        expect(find.text('Failed'), findsOneWidget);
        expect(find.textContaining('14 pages'), findsOneWidget);
      },
    );

    testWidgets(
      'displays active upload progress banner when uploading is in flight',
      (tester) async {
        await tester.pumpWidget(
          createDocumentWidget(
            child: const DocumentListScreen(),
            documents: [readyDoc],
            isUploading: true,
            uploadProgress: 0.65,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Uploading PDF to secure storage...'), findsOneWidget);
        expect(find.text('65%'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
      },
    );

    testWidgets(
      'tapping processing document shows informative processing notice',
      (tester) async {
        await tester.pumpWidget(
          createDocumentWidget(
            child: const DocumentListScreen(),
            documents: [processingDoc],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Organic_Chemistry_Vol1.pdf'));
        await tester.pump();

        expect(
          find.textContaining('Document is currently being processed'),
          findsOneWidget,
        );
        // Ensure chat screen did not open
        expect(find.byType(DocumentChatScreen), findsNothing);
      },
    );

    testWidgets('tapping failed document displays recovery guidance dialog', (
      tester,
    ) async {
      await tester.pumpWidget(
        createDocumentWidget(
          child: const DocumentListScreen(),
          documents: [failedDoc],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Corrupted_Syllabus.pdf'));
      await tester.pumpAndSettle();

      expect(find.text('Document Processing Failed'), findsOneWidget);
      expect(
        find.textContaining('ENCRYPTED_PDF_NOT_SUPPORTED'),
        findsOneWidget,
      );
      expect(find.textContaining('Recovery Guidance:'), findsOneWidget);
      expect(find.text('Delete & Re-upload'), findsOneWidget);
    });

    testWidgets(
      'delete button prompts confirmation dialog and deletes document',
      (tester) async {
        await tester.pumpWidget(
          createDocumentWidget(
            child: const DocumentListScreen(),
            documents: [readyDoc],
          ),
        );
        await tester.pumpAndSettle();

        final deleteBtn = find.byIcon(Icons.delete_outline_rounded);
        expect(deleteBtn, findsOneWidget);
        await tester.tap(deleteBtn);
        await tester.pumpAndSettle();

        expect(find.text('Delete Document?'), findsOneWidget);
        expect(
          find.textContaining(
            'Are you sure you want to delete "Cell_Biology_Notes.pdf"',
          ),
          findsOneWidget,
        );

        // Confirm delete
        await tester.tap(find.widgetWithText(TextButton, 'Delete'));
        await tester.pumpAndSettle();

        // Document is removed, empty state shown
        expect(find.text('No documents uploaded yet'), findsOneWidget);
      },
    );
  });

  group('DocumentChatScreen Widget Tests (Phase 4)', () {
    testWidgets(
      'renders document header, grounding banner, and prompt suggestions',
      (tester) async {
        await tester.pumpWidget(
          createDocumentWidget(
            child: DocumentChatScreen(document: readyDoc),
            customChatController: MockDocumentChatController(readyDoc.id),
            chatDocId: readyDoc.id,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Cell_Biology_Notes.pdf'), findsOneWidget);
        expect(find.text('Grounded PDF Assistant'), findsOneWidget);
        expect(
          find.text('Answers are strictly extracted & grounded in this PDF.'),
          findsOneWidget,
        );
        expect(find.text('Ask anything about your notes'), findsOneWidget);
        expect(
          find.text('Summarize the primary thesis or objective'),
          findsOneWidget,
        );
      },
    );

    testWidgets('renders QA entry with verified page citation chip', (
      tester,
    ) async {
      final initialEntry = DocumentQAEntry(
        question: 'What is the function of the Golgi apparatus?',
        answer: 'The Golgi apparatus modifies, sorts, and packages proteins.',
        sources: [const DocumentCitation(documentId: 'doc-ready', page: 8)],
        hasSufficientEvidence: true,
      );

      final mockChat = MockDocumentChatController(
        readyDoc.id,
        customInitialState: DocumentChatState(entries: [initialEntry]),
      );

      await tester.pumpWidget(
        createDocumentWidget(
          child: DocumentChatScreen(document: readyDoc),
          customChatController: mockChat,
          chatDocId: readyDoc.id,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('What is the function of the Golgi apparatus?'),
        findsOneWidget,
      );
      expect(
        find.text(
          'The Golgi apparatus modifies, sorts, and packages proteins.',
        ),
        findsOneWidget,
      );
      expect(find.text('Verified Sources & Citations:'), findsOneWidget);
      expect(find.text('Page 8'), findsOneWidget);
    });

    testWidgets(
      'displays insufficient evidence notice when reported by backend',
      (tester) async {
        final insufficientEntry = DocumentQAEntry(
          question: 'What is the date of the midterm exam?',
          answer: 'The notes do not mention an exam schedule.',
          sources: const [],
          hasSufficientEvidence: false,
        );

        final mockChat = MockDocumentChatController(
          readyDoc.id,
          customInitialState: DocumentChatState(entries: [insufficientEntry]),
        );

        await tester.pumpWidget(
          createDocumentWidget(
            child: DocumentChatScreen(document: readyDoc),
            customChatController: mockChat,
            chatDocId: readyDoc.id,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Insufficient Evidence in Document:'),
          findsOneWidget,
        );
        expect(
          find.text('The notes do not mention an exam schedule.'),
          findsOneWidget,
        );
        // No fabricated citations
        expect(find.text('Verified Sources & Citations:'), findsNothing);
      },
    );

    testWidgets(
      'sends question, clears input, and renders answer with citation',
      (tester) async {
        final mockChat = MockDocumentChatController(readyDoc.id);

        await tester.pumpWidget(
          createDocumentWidget(
            child: DocumentChatScreen(document: readyDoc),
            customChatController: mockChat,
            chatDocId: readyDoc.id,
          ),
        );
        await tester.pumpAndSettle();

        final inputFinder = find.byType(TextField);
        await tester.enterText(inputFinder, 'Explain cellular respiration');
        await tester.tap(find.byIcon(Icons.search_rounded));
        await tester.pumpAndSettle();

        expect(mockChat.askQuestionCalled, isTrue);
        expect(mockChat.lastQuestionAsked, 'Explain cellular respiration');
        expect(find.text('Explain cellular respiration'), findsOneWidget);
        expect(
          find.text('This is the verified grounded answer from page 4.'),
          findsOneWidget,
        );
        expect(find.text('Page 4'), findsOneWidget);
      },
    );

    testWidgets('preserves draft input on send failure and allows retry', (
      tester,
    ) async {
      final mockChat = MockDocumentChatController(
        readyDoc.id,
        failNextAsk: true,
      );

      await tester.pumpWidget(
        createDocumentWidget(
          child: DocumentChatScreen(document: readyDoc),
          customChatController: mockChat,
          chatDocId: readyDoc.id,
        ),
      );
      await tester.pumpAndSettle();

      final inputFinder = find.byType(TextField);
      await tester.enterText(inputFinder, 'Why do leaves change color?');
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();

      expect(
        find.text('Connection error while reasoning over document.'),
        findsWidgets,
      );
      // Retry button is available
      final retryBtn = find.text('Retry Question');
      expect(retryBtn, findsOneWidget);

      // Draft question was restored into the textfield
      final textField = tester.widget<TextField>(inputFinder);
      expect(textField.controller?.text, 'Why do leaves change color?');

      // Tapping retry resolves answer
      await tester.tap(retryBtn);
      await tester.pumpAndSettle();

      expect(
        find.text('Recovered answer from document chunks.'),
        findsOneWidget,
      );
      expect(find.text('Page 9'), findsOneWidget);
    });

    testWidgets('app bar menu allows deleting document and navigates back', (
      tester,
    ) async {
      final mockChat = MockDocumentChatController(readyDoc.id);

      await tester.pumpWidget(
        createDocumentWidget(
          child: DocumentChatScreen(document: readyDoc),
          customChatController: mockChat,
          chatDocId: readyDoc.id,
        ),
      );
      await tester.pumpAndSettle();

      final moreBtn = find.byIcon(Icons.more_vert_rounded);
      expect(moreBtn, findsOneWidget);
      await tester.tap(moreBtn);
      await tester.pumpAndSettle();

      expect(find.text('Delete Document'), findsOneWidget);
      await tester.tap(find.text('Delete Document'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Document?'), findsOneWidget);
      expect(
        find.textContaining('You will be returned to the document library.'),
        findsOneWidget,
      );
    });
  });
}
