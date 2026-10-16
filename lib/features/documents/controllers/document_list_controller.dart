import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/providers/core_providers.dart';
import '../models/document_model.dart';
import '../repositories/document_repository.dart';

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DocumentRepository(apiClient: apiClient);
});

class DocumentUploadProgressNotifier extends Notifier<double?> {
  @override
  double? build() => null;
  void setProgress(double? p) => state = p;
}

/// Exposes the upload progress (0.0 to 1.0) or null when not uploading
final documentUploadProgressProvider =
    NotifierProvider<DocumentUploadProgressNotifier, double?>(
      DocumentUploadProgressNotifier.new,
    );

class IsDocumentUploadingNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void setUploading(bool u) => state = u;
}

/// Exposes whether a document upload is currently in flight
final isDocumentUploadingProvider =
    NotifierProvider<IsDocumentUploadingNotifier, bool>(
      IsDocumentUploadingNotifier.new,
    );

final documentListControllerProvider =
    AsyncNotifierProvider<DocumentListController, List<DocumentModel>>(() {
      return DocumentListController();
    });

class DocumentListController extends AsyncNotifier<List<DocumentModel>> {
  late final DocumentRepository _repository;
  Timer? _pollingTimer;
  int _pollingAttempts = 0;
  static const int maxPollingAttempts = 15;
  static const Duration pollingInterval = Duration(seconds: 3);

  @override
  Future<List<DocumentModel>> build() async {
    _repository = ref.watch(documentRepositoryProvider);
    ref.onDispose(() {
      _stopPolling();
    });

    final docs = await _repository.getDocuments();
    _checkAndStartPolling(docs);
    return docs;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final docs = await _repository.getDocuments();
      _checkAndStartPolling(docs);
      return docs;
    });
  }

  /// Client-side validation for files before upload
  static String? validateFile({required String name, required int size}) {
    final lowerName = name.toLowerCase();
    if (!lowerName.endsWith('.pdf')) {
      return 'Unsupported file format. Please upload a standard PDF document (.pdf).';
    }
    if (size <= 0) {
      return 'Selected file is empty (0 bytes). Please select a valid PDF.';
    }
    if (size > AppConfig.maxUploadSizeBytes) {
      final sizeMb = (size / (1024 * 1024)).toStringAsFixed(1);
      return 'File exceeds the 10 MB limit ($sizeMb MB). Please select a smaller PDF.';
    }
    return null;
  }

  /// Pick a PDF using system file picker and upload to backend
  Future<String?> pickAndUploadDocument() async {
    Directory? tempDirToDelete;
    try {
      final pickedFile = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (pickedFile == null) {
        return null; // User cancelled
      }

      // Check preliminary size if available without I/O
      final initialSize = pickedFile.lengthSync() ?? await pickedFile.length();
      if (initialSize != null) {
        final preValidation =
            validateFile(name: pickedFile.name, size: initialSize);
        if (preValidation != null) {
          return preValidation;
        }
      }

      File file;
      if (pickedFile.path != null &&
          pickedFile.path!.isNotEmpty &&
          await File(pickedFile.path!).exists()) {
        file = File(pickedFile.path!);
      } else {
        // Fallback for Android (content:// URIs) and Web where path is null
        final bytes = await pickedFile.readAsBytes();
        if (bytes.isEmpty) {
          return 'Selected file is empty (0 bytes). Please select a valid PDF.';
        }
        final tempDir = Directory(
          '${Directory.systemTemp.path}/study_mate_${DateTime.now().millisecondsSinceEpoch}',
        );
        await tempDir.create(recursive: true);
        tempDirToDelete = tempDir;
        final safeFileName =
            pickedFile.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        final tempFile = File('${tempDir.path}/$safeFileName');
        await tempFile.writeAsBytes(bytes, flush: true);
        file = tempFile;
      }

      final size = await file.length();
      final validationError = validateFile(name: pickedFile.name, size: size);
      if (validationError != null) {
        return validationError;
      }

      return await uploadFile(file, customFileName: pickedFile.name);
    } catch (e) {
      return 'Error selecting document: ${e.toString()}';
    } finally {
      if (tempDirToDelete != null) {
        try {
          if (await tempDirToDelete.exists()) {
            await tempDirToDelete.delete(recursive: true);
          }
        } catch (_) {}
      }
    }
  }

  /// Directly upload a PDF file with progress updates
  Future<String?> uploadFile(File file, {String? customFileName}) async {
    final fileName = customFileName ?? file.path.split(RegExp(r'[/\\]')).last;
    final size = await file.length();
    final validationError = validateFile(name: fileName, size: size);
    if (validationError != null) {
      return validationError;
    }

    ref.read(isDocumentUploadingProvider.notifier).setUploading(true);
    ref.read(documentUploadProgressProvider.notifier).setProgress(0.0);

    try {
      final newDoc = await _repository.uploadDocument(
        file,
        customFileName: fileName,
        onSendProgress: (sent, total) {
          if (total > 0) {
            ref
                .read(documentUploadProgressProvider.notifier)
                .setProgress(sent / total);
          }
        },
      );

      final currentList = state.value ?? [];
      final updatedList = [newDoc, ...currentList];
      state = AsyncValue.data(updatedList);
      _checkAndStartPolling(updatedList);
      return null; // Success
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return 'Failed to upload document: ${e.toString()}';
    } finally {
      ref.read(isDocumentUploadingProvider.notifier).setUploading(false);
      ref.read(documentUploadProgressProvider.notifier).setProgress(null);
    }
  }

  /// Delete document on server and remove from state
  Future<bool> deleteDocument(String id) async {
    final currentList = state.value ?? [];
    // Mark optimistically as deleting
    state = AsyncValue.data(
      currentList
          .map((d) => d.id == id ? d.copyWith(status: 'DELETING') : d)
          .toList(),
    );

    try {
      await _repository.deleteDocument(id);
      final remaining = (state.value ?? []).where((d) => d.id != id).toList();
      state = AsyncValue.data(remaining);
      _checkAndStartPolling(remaining);
      return true;
    } on ApiException catch (e) {
      // Revert previous state
      state = AsyncValue.data(currentList);
      state = AsyncValue.error(e.message, StackTrace.current);
      return false;
    } catch (e, st) {
      state = AsyncValue.data(currentList);
      state = AsyncValue.error('Failed to delete document: $e', st);
      return false;
    }
  }

  void _checkAndStartPolling(List<DocumentModel> docs) {
    final hasProcessing = docs.any((d) => d.isProcessing);
    if (hasProcessing && (_pollingTimer == null || !_pollingTimer!.isActive)) {
      _startPolling();
    } else if (!hasProcessing && _pollingTimer != null) {
      _stopPolling();
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingAttempts = 0;
    _pollingTimer = Timer.periodic(pollingInterval, (timer) async {
      _pollingAttempts++;
      if (_pollingAttempts > maxPollingAttempts) {
        _stopPolling();
        return;
      }

      try {
        final updatedDocs = await _repository.getDocuments();
        state = AsyncValue.data(updatedDocs);
        if (!updatedDocs.any((d) => d.isProcessing)) {
          _stopPolling();
        }
      } catch (_) {
        // Continue polling on transient network hitch
      }
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _pollingAttempts = 0;
  }
}
