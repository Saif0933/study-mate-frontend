import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../documents/controllers/document_list_controller.dart';
import '../controllers/quiz_controller.dart';
import 'quiz_play_screen.dart';

class QuizCreateScreen extends ConsumerStatefulWidget {
  final String? initialDocumentId;

  const QuizCreateScreen({super.key, this.initialDocumentId});

  @override
  ConsumerState<QuizCreateScreen> createState() => _QuizCreateScreenState();
}

class _QuizCreateScreenState extends ConsumerState<QuizCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _topicController = TextEditingController();
  String? _selectedDocumentId;
  String _difficulty = 'MEDIUM';
  int _questionCount = 5;
  bool _isGenerating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedDocumentId = widget.initialDocumentId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  void _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_topicController.text.trim().isEmpty && _selectedDocumentId == null) {
      setState(() {
        _error =
            'Please enter a topic or select an uploaded PDF notes document.';
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _error = null;
    });

    final newQuiz = await ref
        .read(quizListControllerProvider.notifier)
        .createQuiz(
          title: _titleController.text.trim(),
          topic: _topicController.text.trim().isNotEmpty
              ? _topicController.text.trim()
              : null,
          sourceDocumentId: _selectedDocumentId,
          difficulty: _difficulty,
          questionCount: _questionCount,
        );

    if (mounted) {
      setState(() {
        _isGenerating = false;
      });

      if (newQuiz != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => QuizPlayScreen(quiz: newQuiz)),
        );
      } else {
        setState(() {
          _error = 'Failed to generate quiz. Please check topic or connection.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(documentListControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Generate Practice Quiz')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Test Your Knowledge',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'The AI will craft multiple-choice questions with detailed answer explanations.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
                const SizedBox(height: 24),

                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: theme.colorScheme.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Quiz Title
                TextFormField(
                  controller: _titleController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Quiz Title',
                    hintText: 'e.g. Chapter 4 Practice or Photosynthesis Quiz',
                    prefixIcon: Icon(Icons.title_rounded, size: 20),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please provide a title for the quiz';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Topic Input
                TextFormField(
                  controller: _topicController,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Topic / Concept (Optional if PDF selected)',
                    hintText: 'e.g. Thermodynamics Laws, European History 1914',
                    prefixIcon: Icon(Icons.school_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 16),

                // Source PDF Selector
                docsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (docs) {
                    final readyDocs = docs.where((d) => d.isReady).toList();
                    if (readyDocs.isEmpty) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Or Generate from Uploaded PDF:',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String?>(
                          initialValue: _selectedDocumentId,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(
                              Icons.picture_as_pdf_outlined,
                              size: 20,
                            ),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('None (Use topic only)'),
                            ),
                            ...readyDocs.map(
                              (doc) => DropdownMenuItem(
                                value: doc.id,
                                child: Text(
                                  doc.originalName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedDocumentId = val;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),

                // Difficulty Selector
                Text(
                  'Difficulty Level:',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildDifficultyOption(
                        'EASY',
                        'Easy',
                        AppTheme.success,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildDifficultyOption(
                        'MEDIUM',
                        'Medium',
                        AppTheme.warning,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildDifficultyOption(
                        'HARD',
                        'Hard',
                        AppTheme.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Question Count Slider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Number of Questions:',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$_questionCount questions',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _questionCount.toDouble(),
                  min: 3,
                  max: 10,
                  divisions: 7,
                  label: '$_questionCount questions',
                  onChanged: (val) {
                    setState(() {
                      _questionCount = val.toInt();
                    });
                  },
                ),
                const SizedBox(height: 32),

                AppButton(
                  label: 'Generate Quiz with AI',
                  onPressed: _handleSubmit,
                  isLoading: _isGenerating,
                  icon: Icons.auto_awesome_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyOption(String value, String label, Color color) {
    final isSelected = _difficulty == value;
    return InkWell(
      onTap: () {
        setState(() {
          _difficulty = value;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : null,
          border: Border.all(
            color: isSelected ? color : Theme.of(context).dividerColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? color : null,
            ),
          ),
        ),
      ),
    );
  }
}
