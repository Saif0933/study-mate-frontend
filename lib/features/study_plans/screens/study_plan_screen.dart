import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../controllers/study_plan_controller.dart';
import '../models/study_plan_model.dart';
import 'study_plan_create_screen.dart';

class StudyPlanScreen extends ConsumerStatefulWidget {
  const StudyPlanScreen({super.key});

  @override
  ConsumerState<StudyPlanScreen> createState() => _StudyPlanScreenState();
}

class _StudyPlanScreenState extends ConsumerState<StudyPlanScreen> {
  String? _selectedPlanId;

  void _confirmRegeneratePlan(BuildContext context, StudyPlanModel plan) {
    final completedCount = plan.completedTaskCount;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regenerate Study Schedule?'),
        content: Text(
          'Regenerating will recalculate your upcoming study sessions according to your remaining time.\n\n'
          'Your $completedCount completed task(s) will be safely preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final messenger = ScaffoldMessenger.of(context);
              final updated = await ref
                  .read(studyPlanControllerProvider.notifier)
                  .regeneratePlan(planId: plan.id, preserveCompleted: true);

              if (updated != null) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Study plan regenerated successfully! Completed tasks were preserved.',
                    ),
                    backgroundColor: AppTheme.success,
                  ),
                );
              } else {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Failed to regenerate plan. Please check your connection.',
                    ),
                    backgroundColor: AppTheme.error,
                  ),
                );
              }
            },
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context, String planId) {
    final titleCtrl = TextEditingController();
    final topicCtrl = TextEditingController();
    int duration = 30;
    DateTime scheduledDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Add Study Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Task Title',
                    hintText: 'e.g. Review Chapter 5 Notes',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: topicCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Topic (optional)',
                    hintText: 'e.g. Molecular Biology',
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Scheduled Date'),
                  subtitle: Text(
                    DateFormat('EEE, MMM d, y').format(scheduledDate),
                  ),
                  trailing: const Icon(Icons.calendar_today_rounded, size: 20),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: scheduledDate,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 7),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDlgState(() {
                        scheduledDate = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                        );
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Duration:'),
                    Text(
                      '$duration min',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Slider(
                  value: duration.toDouble(),
                  min: 15,
                  max: 180,
                  divisions: 11,
                  label: '$duration min',
                  onChanged: (v) {
                    setDlgState(() {
                      duration = v.toInt();
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                Navigator.of(ctx).pop();
                await ref
                    .read(studyPlanControllerProvider.notifier)
                    .addTask(
                      planId: planId,
                      title: titleCtrl.text.trim(),
                      topic: topicCtrl.text.trim().isNotEmpty
                          ? topicCtrl.text.trim()
                          : null,
                      scheduledDate: scheduledDate,
                      durationMinutes: duration,
                    );
              },
              child: const Text('Add Task'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTaskDialog(
    BuildContext context,
    String planId,
    StudyTaskModel task,
  ) {
    final titleCtrl = TextEditingController(text: task.title);
    final topicCtrl = TextEditingController(text: task.topic ?? '');
    int duration = task.durationMinutes;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Edit Study Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Task Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: topicCtrl,
                  decoration: const InputDecoration(labelText: 'Topic'),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Duration:'),
                    Text(
                      '$duration min',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Slider(
                  value: duration.toDouble(),
                  min: 15,
                  max: 180,
                  divisions: 11,
                  label: '$duration min',
                  onChanged: (v) {
                    setDlgState(() {
                      duration = v.toInt();
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                Navigator.of(ctx).pop();
                await ref
                    .read(studyPlanControllerProvider.notifier)
                    .editTaskDetails(
                      planId: planId,
                      taskId: task.id,
                      title: titleCtrl.text.trim(),
                      topic: topicCtrl.text.trim().isNotEmpty
                          ? topicCtrl.text.trim()
                          : null,
                      durationMinutes: duration,
                    );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(studyPlanControllerProvider);
    final controller = ref.read(studyPlanControllerProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Schedules'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => controller.refresh(),
            tooltip: 'Refresh plans',
          ),
        ],
      ),
      body: plansAsync.when(
        loading: () =>
            const LoadingView(message: 'Loading your study schedules...'),
        error: (err, _) => ErrorView(
          message: err.toString(),
          onRetry: () => controller.refresh(),
        ),
        data: (plans) {
          if (plans.isEmpty) {
            return EmptyStateView(
              icon: Icons.calendar_month_rounded,
              title: 'No study plans generated yet',
              description:
                  'Set your upcoming exam date, daily available study hours, and subjects to get a realistic AI-crafted schedule.',
              actionText: 'Create Study Plan',
              onAction: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const StudyPlanCreateScreen(),
                  ),
                );
              },
            );
          }

          // Select plan
          final activePlan = plans.firstWhere(
            (p) => p.id == _selectedPlanId,
            orElse: () => plans.first,
          );

          final totalTasks = activePlan.tasks.length;
          final completedTasks = activePlan.completedTaskCount;
          final progress = activePlan.completionProgress;

          String daysRemainingText = '';
          if (activePlan.examDate != null) {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final examDay = DateTime(
              activePlan.examDate!.year,
              activePlan.examDate!.month,
              activePlan.examDate!.day,
            );
            final diff = examDay.difference(today).inDays;
            daysRemainingText = diff >= 0
                ? '$diff days until exam'
                : 'Exam date passed';
          }

          final groupedTasks = activePlan.tasksGroupedByDate;
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final tomorrow = today.add(const Duration(days: 1));

          return RefreshIndicator(
            onRefresh: () => controller.refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Multi-Plan Selector if multiple plans exist
                if (plans.length > 1) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: activePlan.id,
                        isExpanded: true,
                        items: plans.map((p) {
                          return DropdownMenuItem(
                            value: p.id,
                            child: Text(
                              p.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedPlanId = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],

                // Plan Summary Hero Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    activePlan.title,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary.withValues(
                                            alpha: 0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          '${activePlan.dailyMinutes} min/day',
                                          style: const TextStyle(
                                            color: AppTheme.primary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme.dividerColor.withValues(
                                            alpha: 0.25,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.language_rounded,
                                              size: 12,
                                              color: Colors.white70,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              activePlan.timezone,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded),
                              onSelected: (val) {
                                if (val == 'regenerate') {
                                  _confirmRegeneratePlan(context, activePlan);
                                } else if (val == 'add_task') {
                                  _showAddTaskDialog(context, activePlan.id);
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'regenerate',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 18,
                                      ),
                                      SizedBox(width: 8),
                                      Text('Regenerate Plan'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'add_task',
                                  child: Row(
                                    children: [
                                      Icon(Icons.add_task_rounded, size: 18),
                                      SizedBox(width: 8),
                                      Text('Add Custom Task'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        if (daysRemainingText.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(
                                Icons.event_available_rounded,
                                size: 16,
                                color: AppTheme.secondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                daysRemainingText,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Progress Bar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Progress ($completedTasks/$totalTasks completed)',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${(progress * 100).toInt()}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: theme.dividerColor,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppTheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Agenda Header & Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Study Agenda:',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          _confirmRegeneratePlan(context, activePlan),
                      icon: const Icon(Icons.sync_rounded, size: 16),
                      label: const Text('Regenerate'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Grouped Agenda List
                if (groupedTasks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Center(
                      child: Text(
                        'No tasks scheduled for this plan.',
                        style: TextStyle(
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ),
                  )
                else
                  ...groupedTasks.entries.map((entry) {
                    final date = entry.key;
                    final tasks = entry.value;

                    String dateLabel;
                    if (date == today) {
                      dateLabel =
                          'Today • ${DateFormat('EEE, MMM d').format(date)}';
                    } else if (date == tomorrow) {
                      dateLabel =
                          'Tomorrow • ${DateFormat('EEE, MMM d').format(date)}';
                    } else {
                      dateLabel = DateFormat('EEEE, MMM d').format(date);
                    }

                    final dayMinutes = tasks.fold<int>(
                      0,
                      (sum, t) => sum + t.durationMinutes,
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8.0,
                            horizontal: 4.0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                dateLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppTheme.secondary,
                                ),
                              ),
                              Text(
                                '${tasks.length} tasks • $dayMinutes min',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.textTheme.bodySmall?.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...tasks.map(
                          (task) => _buildTaskCard(
                            context: context,
                            planId: activePlan.id,
                            task: task,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  }),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const StudyPlanCreateScreen()),
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Plan'),
      ),
    );
  }

  Widget _buildTaskCard({
    required BuildContext context,
    required String planId,
    required StudyTaskModel task,
  }) {
    final theme = Theme.of(context);
    final isDone = task.isCompleted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox Toggle
              Checkbox(
                value: isDone,
                activeColor: AppTheme.primary,
                onChanged: (_) {
                  ref
                      .read(studyPlanControllerProvider.notifier)
                      .toggleTaskCompletion(
                        planId: planId,
                        taskId: task.id,
                        currentCompleted: isDone,
                      );
                },
              ),
              const SizedBox(width: 4),

              // Title, Topic, Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      task.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        color: isDone ? theme.textTheme.bodySmall?.color : null,
                      ),
                    ),
                    if (task.description != null &&
                        task.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        task.description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),

                    // Badges Row with Accessible Tags and Non-Colour-Only Indicators
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildStatusBadge(task.status),
                        Text(
                          '${task.durationMinutes} min',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textTheme.bodySmall?.color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (task.topic != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.dividerColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              task.topic!,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.textTheme.bodySmall?.color,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),

              // Task Actions Menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz_rounded, size: 20),
                onSelected: (action) {
                  if (action == 'in_progress') {
                    ref
                        .read(studyPlanControllerProvider.notifier)
                        .updateTaskStatus(
                          planId: planId,
                          taskId: task.id,
                          newStatus: 'IN_PROGRESS',
                        );
                  } else if (action == 'skip') {
                    ref
                        .read(studyPlanControllerProvider.notifier)
                        .skipTask(planId: planId, taskId: task.id);
                  } else if (action == 'edit') {
                    _showEditTaskDialog(context, planId, task);
                  } else if (action == 'delete') {
                    ref
                        .read(studyPlanControllerProvider.notifier)
                        .deleteTask(planId: planId, taskId: task.id);
                  }
                },
                itemBuilder: (ctx) => [
                  if (!task.isInProgress)
                    const PopupMenuItem(
                      value: 'in_progress',
                      child: Row(
                        children: [
                          Icon(Icons.timelapse_rounded, size: 16),
                          SizedBox(width: 8),
                          Text('Mark In Progress'),
                        ],
                      ),
                    ),
                  if (!task.isSkipped)
                    const PopupMenuItem(
                      value: 'skip',
                      child: Row(
                        children: [
                          Icon(Icons.skip_next_rounded, size: 16),
                          SizedBox(width: 8),
                          Text('Skip Task'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Edit Details'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                          color: AppTheme.error,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Delete Task',
                          style: TextStyle(color: AppTheme.error),
                        ),
                      ],
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

  Widget _buildStatusBadge(String status) {
    Color color;
    IconData icon;
    String label;

    switch (status.toUpperCase()) {
      case 'COMPLETED':
        color = AppTheme.success;
        icon = Icons.check_circle_rounded;
        label = 'Completed';
        break;
      case 'IN_PROGRESS':
        color = AppTheme.warning;
        icon = Icons.timelapse_rounded;
        label = 'In Progress';
        break;
      case 'SKIPPED':
        color = Colors.grey;
        icon = Icons.remove_circle_outline_rounded;
        label = 'Skipped';
        break;
      case 'TODO':
      default:
        color = AppTheme.primary;
        icon = Icons.radio_button_unchecked_rounded;
        label = 'To Do';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
