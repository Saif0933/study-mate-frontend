import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_exceptions.dart';
import '../models/document_model.dart';
import '../repositories/document_repository.dart';
import 'document_list_controller.dart';

class DocumentQAEntry {
  final String question;
  final String? answer;
  final List<DocumentCitation> sources;
  final bool hasSufficientEvidence;
  final bool isPending;
  final String? error;

  const DocumentQAEntry({
    required this.question,
    this.answer,
    this.sources = const [],
    this.hasSufficientEvidence = true,
    this.isPending = false,
    this.error,
  });

  DocumentQAEntry copyWith({
    String? answer,
    List<DocumentCitation>? sources,
    bool? hasSufficientEvidence,
    bool? isPending,
    String? error,
  }) {
    return DocumentQAEntry(
      question: question,
      answer: answer ?? this.answer,
      sources: sources ?? this.sources,
      hasSufficientEvidence:
          hasSufficientEvidence ?? this.hasSufficientEvidence,
      isPending: isPending ?? this.isPending,
      error: error,
    );
  }
}

class DocumentChatState {
  final List<DocumentQAEntry> entries;
  final bool isAsking;
  final String? generalError;
  final bool isDocumentDeleted;

  const DocumentChatState({
    this.entries = const [],
    this.isAsking = false,
    this.generalError,
    this.isDocumentDeleted = false,
  });

  DocumentChatState copyWith({
    List<DocumentQAEntry>? entries,
    bool? isAsking,
    String? generalError,
    bool? isDocumentDeleted,
    bool clearError = false,
  }) {
    return DocumentChatState(
      entries: entries ?? this.entries,
      isAsking: isAsking ?? this.isAsking,
      generalError: clearError ? null : (generalError ?? this.generalError),
      isDocumentDeleted: isDocumentDeleted ?? this.isDocumentDeleted,
    );
  }
}

final documentChatControllerProvider = NotifierProvider.autoDispose
    .family<DocumentChatController, DocumentChatState, String>(
      (arg) => DocumentChatController(arg),
    );

class DocumentChatController extends Notifier<DocumentChatState> {
  final String documentId;

  DocumentChatController(this.documentId);

  late final DocumentRepository _repository;

  @override
  DocumentChatState build() {
    _repository = ref.watch(documentRepositoryProvider);
    return const DocumentChatState();
  }

  void markDocumentDeleted() {
    state = state.copyWith(isDocumentDeleted: true);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Future<bool> askQuestion(String question) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty || state.isAsking || state.isDocumentDeleted) {
      return false;
    }

    final pendingEntry = DocumentQAEntry(
      question: trimmed,
      isPending: true,
      hasSufficientEvidence: true,
    );

    state = state.copyWith(
      entries: [...state.entries, pendingEntry],
      isAsking: true,
      clearError: true,
    );

    try {
      final response = await _repository.askQuestion(
        documentId: documentId,
        question: trimmed,
      );

      final updatedEntries = List<DocumentQAEntry>.from(state.entries);
      final lastIndex = updatedEntries.length - 1;
      if (lastIndex >= 0) {
        updatedEntries[lastIndex] = updatedEntries[lastIndex].copyWith(
          answer: response.answer,
          sources: response.sources,
          hasSufficientEvidence: response.hasSufficientEvidence,
          isPending: false,
        );
      }

      state = state.copyWith(entries: updatedEntries, isAsking: false);
      return true;
    } on ApiException catch (e) {
      final updatedEntries = List<DocumentQAEntry>.from(state.entries);
      final lastIndex = updatedEntries.length - 1;
      if (lastIndex >= 0) {
        updatedEntries[lastIndex] = updatedEntries[lastIndex].copyWith(
          isPending: false,
          error: e.message,
        );
      }
      state = state.copyWith(
        entries: updatedEntries,
        isAsking: false,
        generalError: e.message,
      );
      return false;
    } catch (e) {
      final updatedEntries = List<DocumentQAEntry>.from(state.entries);
      final lastIndex = updatedEntries.length - 1;
      if (lastIndex >= 0) {
        updatedEntries[lastIndex] = updatedEntries[lastIndex].copyWith(
          isPending: false,
          error: 'Failed to retrieve grounded answer: ${e.toString()}',
        );
      }
      state = state.copyWith(
        entries: updatedEntries,
        isAsking: false,
        generalError: 'Could not connect to document reasoning engine.',
      );
      return false;
    }
  }

  Future<bool> retryQuestion(int index) async {
    if (index < 0 ||
        index >= state.entries.length ||
        state.isAsking ||
        state.isDocumentDeleted) {
      return false;
    }

    final targetEntry = state.entries[index];
    final updatedEntries = List<DocumentQAEntry>.from(state.entries);
    updatedEntries[index] = targetEntry.copyWith(isPending: true, error: null);

    state = state.copyWith(
      entries: updatedEntries,
      isAsking: true,
      clearError: true,
    );

    try {
      final response = await _repository.askQuestion(
        documentId: documentId,
        question: targetEntry.question,
      );

      final current = List<DocumentQAEntry>.from(state.entries);
      current[index] = current[index].copyWith(
        answer: response.answer,
        sources: response.sources,
        hasSufficientEvidence: response.hasSufficientEvidence,
        isPending: false,
      );

      state = state.copyWith(entries: current, isAsking: false);
      return true;
    } on ApiException catch (e) {
      final current = List<DocumentQAEntry>.from(state.entries);
      current[index] = current[index].copyWith(
        isPending: false,
        error: e.message,
      );
      state = state.copyWith(
        entries: current,
        isAsking: false,
        generalError: e.message,
      );
      return false;
    } catch (e) {
      final current = List<DocumentQAEntry>.from(state.entries);
      current[index] = current[index].copyWith(
        isPending: false,
        error: 'Retry failed: ${e.toString()}',
      );
      state = state.copyWith(
        entries: current,
        isAsking: false,
        generalError: 'Could not retrieve response.',
      );
      return false;
    }
  }
}
