import 'dart:io';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../models/document_model.dart';

class DocumentRepository {
  final ApiClient apiClient;

  DocumentRepository({required this.apiClient});

  /// Fetch all documents uploaded by user
  Future<List<DocumentModel>> getDocuments() async {
    final response = await apiClient.get('/documents');
    if (response is List) {
      return response
          .map((item) => DocumentModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } else if (response is Map<String, dynamic>) {
      // In case backend wraps in { documents: [...] } or { items: [...] }
      final list =
          response['documents'] ?? response['items'] ?? response['data'];
      if (list is List) {
        return list
            .map((item) => DocumentModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    }
    return [];
  }

  /// Get status of specific document
  Future<DocumentModel> getDocument(String id) async {
    final response = await apiClient.get('/documents/$id');
    return DocumentModel.fromJson(response as Map<String, dynamic>);
  }

  /// Upload a PDF document with progress tracking
  Future<DocumentModel> uploadDocument(
    File file, {
    ProgressCallback? onSendProgress,
  }) async {
    final response = await apiClient.uploadFile(
      '/documents',
      file: file,
      fileFieldName: 'file',
      onSendProgress: onSendProgress,
    );
    return DocumentModel.fromJson(response as Map<String, dynamic>);
  }

  /// Ask a grounded question against a processed document
  Future<DocumentQAResponse> askQuestion({
    required String documentId,
    required String question,
  }) async {
    final response = await apiClient.post(
      '/documents/$documentId/questions',
      data: {'question': question},
    );
    return DocumentQAResponse.fromJson(response as Map<String, dynamic>);
  }

  /// Delete document and its embeddings
  Future<void> deleteDocument(String id) async {
    await apiClient.delete('/documents/$id');
  }
}
