import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/document_chat_controller.dart';
import '../controllers/document_list_controller.dart';
import '../models/document_model.dart';

class DocumentChatScreen extends ConsumerStatefulWidget {
  final DocumentModel document;

  const DocumentChatScreen({super.key, required this.document});

  @override
  ConsumerState<DocumentChatScreen> createState() => _DocumentChatScreenState();
}

class _DocumentChatScreenState extends ConsumerState<DocumentChatScreen> {
  final _questionController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _submitQuestion([String? preset]) async {
    final text = preset ?? _questionController.text;
    if (text.trim().isEmpty) return;

    final controller = ref.read(
      documentChatControllerProvider(widget.document.id).notifier,
    );

    // Save previous text in case submission fails
    final drafted = _questionController.text;
    if (preset == null) {
      _questionController.clear();
    }

    final success = await controller.askQuestion(text);
    if (!success && preset == null && mounted) {
      // Restore draft text on submission failure
      if (_questionController.text.isEmpty) {
        _questionController.text = drafted;
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _confirmDeleteDocument() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Document?'),
        content: Text(
          'Are you sure you want to delete "${widget.document.originalName}"? You will be returned to the document library.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              ref
                  .read(
                    documentChatControllerProvider(widget.document.id).notifier,
                  )
                  .markDocumentDeleted();
              await ref
                  .read(documentListControllerProvider.notifier)
                  .deleteDocument(widget.document.id);
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(
      documentChatControllerProvider(widget.document.id),
    );
    final theme = Theme.of(context);

    // If document is not ready or has been deleted, show warning banner
    final isReady = widget.document.isReady && !chatState.isDocumentDeleted;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.document.originalName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Text(
              'Grounded PDF Assistant',
              style: TextStyle(fontSize: 12, color: AppTheme.secondary),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              if (val == 'delete') {
                _confirmDeleteDocument();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: AppTheme.error,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Delete Document',
                      style: TextStyle(color: AppTheme.error),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Grounding banner or Deleted notice
            if (chatState.isDocumentDeleted) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                color: AppTheme.error.withValues(alpha: 0.15),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppTheme.error,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'This document has been deleted. Questions cannot be answered.',
                        style: TextStyle(
                          color: AppTheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: AppTheme.secondary.withValues(alpha: 0.1),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      color: AppTheme.secondary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Answers are strictly extracted & grounded in this PDF.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // General Error Banner if present
            if (chatState.generalError != null &&
                !chatState.isDocumentDeleted) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: AppTheme.error.withValues(alpha: 0.12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppTheme.error,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        chatState.generalError!,
                        style: const TextStyle(
                          color: AppTheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 14,
                        color: AppTheme.error,
                      ),
                      onPressed: () => ref
                          .read(
                            documentChatControllerProvider(
                              widget.document.id,
                            ).notifier,
                          )
                          .clearError(),
                    ),
                  ],
                ),
              ),
            ],

            // Entries List
            Expanded(
              child: chatState.entries.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: chatState.entries.length,
                      itemBuilder: (context, index) {
                        final entry = chatState.entries[index];
                        return _buildQAItem(entry, index);
                      },
                    ),
            ),

            // Question Input Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.cardColor,
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _questionController,
                      enabled: isReady && !chatState.isAsking,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: isReady
                            ? 'Ask a question about this document...'
                            : 'Document not available for questioning',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: theme.scaffoldBackgroundColor,
                      ),
                      onSubmitted: (_) => isReady ? _submitQuestion() : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: isReady ? AppTheme.secondary : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: chatState.isAsking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.search_rounded,
                              color: Colors.white,
                            ),
                      onPressed: isReady && !chatState.isAsking
                          ? () => _submitQuestion()
                          : null,
                      tooltip: 'Search & Answer',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.secondary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.find_in_page_rounded,
                size: 40,
                color: AppTheme.secondary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ask anything about your notes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'AI StudyMate will search the vector chunks of this PDF and provide verified answers with page citations.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            _buildSamplePrompt('Summarize the primary thesis or objective'),
            const SizedBox(height: 8),
            _buildSamplePrompt(
              'What are the key formulas or definitions mentioned?',
            ),
            const SizedBox(height: 8),
            _buildSamplePrompt('What are the conclusions or summary points?'),
          ],
        ),
      ),
    );
  }

  Widget _buildSamplePrompt(String text) {
    return InkWell(
      onTap: widget.document.isReady ? () => _submitQuestion(text) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.help_outline_rounded,
              size: 18,
              color: AppTheme.secondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildQAItem(DocumentQAEntry entry, int index) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // User Question Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.help_outline_rounded,
                  color: AppTheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    entry.question,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Answer Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
            ),
            child: entry.isPending
                ? const Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.secondary,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Searching document chunks...',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  )
                : entry.error != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            color: theme.colorScheme.error,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              entry.error!,
                              style: TextStyle(
                                color: theme.colorScheme.error,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () {
                          ref
                              .read(
                                documentChatControllerProvider(
                                  widget.document.id,
                                ).notifier,
                              )
                              .retryQuestion(index);
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Retry Question'),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Insufficient Evidence Banner
                      if (!entry.hasSufficientEvidence) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.warning.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: AppTheme.warning,
                                size: 16,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Insufficient Evidence in Document: The uploaded PDF does not contain conclusive evidence for this question.',
                                  style: TextStyle(
                                    color: AppTheme.warning,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      SelectableText(
                        entry.answer ?? 'No answer provided.',
                        style: const TextStyle(fontSize: 15, height: 1.45),
                      ),

                      // Verified Citations
                      if (entry.sources.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          'Verified Sources & Citations:',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.secondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: entry.sources.map((src) {
                            final pageNum = src.page;
                            return Chip(
                              avatar: const Icon(
                                Icons.bookmark_border_rounded,
                                size: 14,
                                color: AppTheme.secondary,
                              ),
                              label: Text(
                                pageNum != null
                                    ? 'Page $pageNum'
                                    : (src.chunkId != null
                                          ? 'Passage #${src.chunkId}'
                                          : 'Passage Reference'),
                                style: const TextStyle(fontSize: 11),
                              ),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
