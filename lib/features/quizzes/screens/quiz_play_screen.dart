import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../controllers/quiz_controller.dart';
import '../models/quiz_model.dart';
import 'quiz_result_screen.dart';

class QuizPlayScreen extends ConsumerWidget {
  final QuizModel quiz;

  const QuizPlayScreen({super.key, required this.quiz});

  void _confirmSubmit(
    BuildContext context,
    WidgetRef ref,
    QuizPlayState state,
  ) {
    if (state.isSubmitting) return;

    final total = state.attempt?.questions.length ?? 0;
    final answered = state.selectedAnswers.length;
    final unanswered = total - answered;

    if (unanswered > 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Unanswered Questions'),
          content: Text(
            'You have $unanswered unanswered question(s). Are you sure you want to submit your quiz now?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Go Back'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _executeSubmit(context, ref);
              },
              child: const Text('Submit Anyway'),
            ),
          ],
        ),
      );
    } else {
      _executeSubmit(context, ref);
    }
  }

  void _executeSubmit(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(quizPlayControllerProvider(quiz.id).notifier)
        .submit();
    if (result != null && context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              QuizResultScreen(result: result, quizTitle: quiz.title),
        ),
      );
    } else if (context.mounted) {
      final error = ref.read(quizPlayControllerProvider(quiz.id)).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error ??
                'Failed to submit quiz attempt. Answers are saved. Please retry.',
          ),
          backgroundColor: AppTheme.error,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playState = ref.watch(quizPlayControllerProvider(quiz.id));
    final theme = Theme.of(context);

    if (playState.isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(quiz.title)),
        body: const LoadingView(message: 'Preparing your quiz questions...'),
      );
    }

    if (playState.errorMessage != null && playState.attempt == null) {
      return Scaffold(
        appBar: AppBar(title: Text(quiz.title)),
        body: ErrorView(
          message: playState.errorMessage!,
          onRetry: () {
            ref.read(quizPlayControllerProvider(quiz.id).notifier).retryStart();
          },
        ),
      );
    }

    final questions = playState.attempt?.questions ?? [];
    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(quiz.title)),
        body: const Center(child: Text('No questions available in this quiz.')),
      );
    }

    final currentIndex = playState.currentQuestionIndex;
    final currentQuestion = questions[currentIndex];
    final selectedOption = playState.selectedAnswers[currentQuestion.id];
    final progress = (currentIndex + 1) / questions.length;
    final isLast = currentIndex == questions.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(quiz.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: theme.dividerColor,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Question Progress Header & Count
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Question ${currentIndex + 1} of ${questions.length}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppTheme.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${playState.selectedAnswers.length}/${questions.length} Answered',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Interactive Question Jump Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(questions.length, (idx) {
                    final q = questions[idx];
                    final isAnswered = playState.selectedAnswers.containsKey(
                      q.id,
                    );
                    final isCurrent = idx == currentIndex;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: InkWell(
                        onTap: () {
                          ref
                              .read(
                                quizPlayControllerProvider(quiz.id).notifier,
                              )
                              .setQuestionIndex(idx);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? AppTheme.accent
                                : (isAnswered
                                      ? AppTheme.accent.withValues(alpha: 0.2)
                                      : theme.cardColor),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isCurrent
                                  ? AppTheme.accent
                                  : (isAnswered
                                        ? AppTheme.accent.withValues(alpha: 0.5)
                                        : theme.dividerColor),
                              width: isCurrent ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${idx + 1}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isCurrent
                                    ? Colors.white
                                    : (isAnswered ? AppTheme.accent : null),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),

              // Recoverable Error Banner if Submission Failed
              if (playState.errorMessage != null &&
                  playState.attempt != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppTheme.error,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          playState.errorMessage!,
                          style: const TextStyle(
                            color: AppTheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: playState.isSubmitting
                            ? null
                            : () => _executeSubmit(context, ref),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ],

              // Question Prompt Card
              Card(
                elevation: 0,
                color: theme.cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Text(
                    currentQuestion.prompt,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Options with Accessible Radios
              Expanded(
                child: ListView.separated(
                  itemCount: currentQuestion.options.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final option = currentQuestion.options[idx];
                    final isSelected = selectedOption == option;
                    final optionLabel = String.fromCharCode(
                      65 + idx,
                    ); // A, B, C, D

                    return Semantics(
                      selected: isSelected,
                      label:
                          'Option $optionLabel: $option. ${isSelected ? "Selected" : "Not selected"}.',
                      child: InkWell(
                        onTap: playState.isSubmitting
                            ? null
                            : () {
                                ref
                                    .read(
                                      quizPlayControllerProvider(
                                        quiz.id,
                                      ).notifier,
                                    )
                                    .selectOption(currentQuestion.id, option);
                              },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.accent.withValues(alpha: 0.12)
                                : theme.cardColor,
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.accent
                                  : theme.dividerColor,
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                color: isSelected
                                    ? AppTheme.accent
                                    : theme.dividerColor,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? AppTheme.accent
                                      : theme.dividerColor.withValues(
                                          alpha: 0.3,
                                        ),
                                ),
                                child: Center(
                                  child: Text(
                                    optionLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.white : null,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  option,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Navigation Buttons
              Row(
                children: [
                  if (currentIndex > 0) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: playState.isSubmitting
                            ? null
                            : () {
                                ref
                                    .read(
                                      quizPlayControllerProvider(
                                        quiz.id,
                                      ).notifier,
                                    )
                                    .setQuestionIndex(currentIndex - 1);
                              },
                        child: const Text('Previous'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: AppButton(
                      label: isLast ? 'Submit Quiz' : 'Next Question',
                      isLoading: playState.isSubmitting,
                      onPressed: playState.isSubmitting
                          ? null
                          : () {
                              if (isLast) {
                                _confirmSubmit(context, ref, playState);
                              } else {
                                ref
                                    .read(
                                      quizPlayControllerProvider(
                                        quiz.id,
                                      ).notifier,
                                    )
                                    .setQuestionIndex(currentIndex + 1);
                              }
                            },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
