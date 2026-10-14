import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../controllers/quiz_controller.dart';
import 'quiz_create_screen.dart';
import 'quiz_play_screen.dart';

class QuizListScreen extends ConsumerWidget {
  const QuizListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizzesAsync = ref.watch(quizListControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Practice Quizzes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.read(quizListControllerProvider.notifier).refresh();
            },
            tooltip: 'Refresh quizzes',
          ),
        ],
      ),
      body: quizzesAsync.when(
        loading: () =>
            const LoadingView(message: 'Loading practice quizzes...'),
        error: (err, _) => ErrorView(
          message: err.toString(),
          onRetry: () =>
              ref.read(quizListControllerProvider.notifier).refresh(),
        ),
        data: (quizzes) {
          if (quizzes.isEmpty) {
            return EmptyStateView(
              icon: Icons.quiz_outlined,
              title: 'No quizzes generated yet',
              description:
                  'Generate multiple-choice practice quizzes from any topic or your uploaded PDF notes to test your understanding.',
              actionText: 'Generate Practice Quiz',
              onAction: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const QuizCreateScreen()),
                );
              },
            );
          }

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(quizListControllerProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: quizzes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final quiz = quizzes[index];
                final dateStr = DateFormat('MMM d, y').format(quiz.createdAt);

                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => QuizPlayScreen(quiz: quiz),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.accent.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.assignment_rounded,
                                  color: AppTheme.accent,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      quiz.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (quiz.topic != null)
                                      Text(
                                        quiz.topic!,
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodySmall?.color,
                                          fontSize: 13,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 16,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildDifficultyChip(quiz.difficulty),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).dividerColor.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${quiz.questionCount} Questions',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                dateStr,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.color,
                                ),
                              ),
                            ],
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const QuizCreateScreen()));
        },
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('New Quiz'),
      ),
    );
  }

  Widget _buildDifficultyChip(String difficulty) {
    Color color;
    switch (difficulty.toUpperCase()) {
      case 'EASY':
        color = AppTheme.success;
        break;
      case 'HARD':
        color = AppTheme.error;
        break;
      case 'MEDIUM':
      default:
        color = AppTheme.warning;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        difficulty.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
