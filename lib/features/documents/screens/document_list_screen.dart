import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/status_badge.dart';
import '../controllers/document_list_controller.dart';
import '../models/document_model.dart';
import 'document_chat_screen.dart';

class DocumentListScreen extends ConsumerWidget {
  const DocumentListScreen({super.key});

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    DocumentModel document,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Document?'),
        content: Text(
          'Are you sure you want to delete "${document.originalName}" and all associated embeddings? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await ref
                  .read(documentListControllerProvider.notifier)
                  .deleteDocument(document.id);
              if (!success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to delete document from server.'),
                    backgroundColor: AppTheme.error,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showFailedDocumentDialog(
    BuildContext context,
    WidgetRef ref,
    DocumentModel doc,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppTheme.error),
            const SizedBox(width: 8),
            const Expanded(child: Text('Document Processing Failed')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Error Code: ${doc.errorCode ?? "PARSE_ERROR"}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 10),
            const Text(
              'Common reasons for processing failure:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text('• PDF is password-protected or encrypted.'),
            const Text('• Scanned image PDF without selectable text.'),
            const Text('• Corrupted PDF structure or unsupported PDF version.'),
            const SizedBox(height: 12),
            const Text(
              'Recovery Guidance:\nExport or print your notes as a standard unencrypted PDF and upload again.',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Dismiss'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _confirmDelete(context, ref, doc);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete & Re-upload'),
          ),
        ],
      ),
    );
  }

  void _handleUpload(BuildContext context, WidgetRef ref) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final error = await ref
        .read(documentListControllerProvider.notifier)
        .pickAndUploadDocument();

    if (error != null) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppTheme.error,
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('PDF uploaded! Processing chunks and embeddings...'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(documentListControllerProvider);
    final isUploading = ref.watch(isDocumentUploadingProvider);
    final uploadProgress = ref.watch(documentUploadProgressProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Study Materials'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.read(documentListControllerProvider.notifier).refresh();
            },
            tooltip: 'Refresh documents',
          ),
        ],
      ),
      body: Column(
        children: [
          // Active Uploading Banner
          if (isUploading) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primaryDark.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Uploading PDF to secure storage...',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      if (uploadProgress != null)
                        Text(
                          '${(uploadProgress * 100).toInt()}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: uploadProgress,
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation(
                        AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Document List / States
          Expanded(
            child: docsAsync.when(
              loading: () =>
                  const LoadingView(message: 'Loading uploaded documents...'),
              error: (err, _) => ErrorView(
                message: err.toString(),
                onRetry: () =>
                    ref.read(documentListControllerProvider.notifier).refresh(),
              ),
              data: (documents) {
                if (documents.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.upload_file_rounded,
                    title: 'No documents uploaded yet',
                    description:
                        'Upload lecture slides, chapters, or syllabus PDFs (up to 10 MB) to ask questions grounded directly in your materials.',
                    actionText: 'Upload PDF (max 10MB)',
                    onAction: () => _handleUpload(context, ref),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => ref
                      .read(documentListControllerProvider.notifier)
                      .refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: documents.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final doc = documents[index];
                      final dateStr = DateFormat(
                        'MMM d, y',
                      ).format(doc.createdAt);

                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: doc.isReady
                              ? () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          DocumentChatScreen(document: doc),
                                    ),
                                  );
                                }
                              : doc.isFailed
                              ? () =>
                                    _showFailedDocumentDialog(context, ref, doc)
                              : () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        doc.isDeleting
                                            ? 'Document is currently being deleted.'
                                            : 'Document is currently being processed. Text extraction & chunk embeddings in progress.',
                                      ),
                                    ),
                                  );
                                },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: doc.isReady
                                        ? AppTheme.primary.withValues(
                                            alpha: 0.1,
                                          )
                                        : doc.isFailed
                                        ? AppTheme.error.withValues(alpha: 0.1)
                                        : AppTheme.secondary.withValues(
                                            alpha: 0.1,
                                          ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    doc.isReady
                                        ? Icons.picture_as_pdf_rounded
                                        : doc.isFailed
                                        ? Icons.error_outline_rounded
                                        : Icons.sync_rounded,
                                    color: doc.isReady
                                        ? AppTheme.primary
                                        : doc.isFailed
                                        ? AppTheme.error
                                        : AppTheme.secondary,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        doc.originalName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            '${doc.formattedSize} • $dateStr',
                                            style: TextStyle(
                                              color: Theme.of(
                                                context,
                                              ).textTheme.bodySmall?.color,
                                              fontSize: 12,
                                            ),
                                          ),
                                          if (doc.pageCount != null) ...[
                                            Text(
                                              ' • ${doc.pageCount} pages',
                                              style: TextStyle(
                                                color: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall?.color,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      StatusBadge(status: doc.status),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 20,
                                  ),
                                  color: Theme.of(context).colorScheme.error,
                                  onPressed: doc.isDeleting
                                      ? null
                                      : () => _confirmDelete(context, ref, doc),
                                  tooltip: 'Delete document',
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isUploading ? null : () => _handleUpload(context, ref),
        icon: const Icon(Icons.upload_file_rounded),
        label: const Text('Upload PDF'),
      ),
    );
  }
}
