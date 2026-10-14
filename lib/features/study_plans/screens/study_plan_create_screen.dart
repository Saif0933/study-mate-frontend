import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../controllers/study_plan_controller.dart';

class StudyPlanCreateScreen extends ConsumerStatefulWidget {
  const StudyPlanCreateScreen({super.key});

  @override
  ConsumerState<StudyPlanCreateScreen> createState() =>
      _StudyPlanCreateScreenState();
}

class _StudyPlanCreateScreenState extends ConsumerState<StudyPlanCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _subjectsController = TextEditingController();
  DateTime? _selectedExamDate;
  int _dailyMinutes = 60;
  String _timezone = 'Asia/Kolkata';
  String _confidenceLevel = 'INTERMEDIATE';
  String _intensity = 'BALANCED';
  bool _isGenerating = false;
  String? _error;

  static const _supportedTimezones = [
    'Asia/Kolkata',
    'UTC',
    'America/New_York',
    'America/Los_Angeles',
    'America/Chicago',
    'Europe/London',
    'Europe/Paris',
    'Asia/Dubai',
    'Asia/Singapore',
    'Asia/Tokyo',
    'Australia/Sydney',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _subjectsController.dispose();
    super.dispose();
  }

  void _pickExamDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 14)),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedExamDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  void _handleSubmit() async {
    if (_isGenerating) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final subjects = _subjectsController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (subjects.isEmpty) {
      setState(() {
        _error = 'Please enter at least one subject or topic.';
      });
      return;
    }

    if (_dailyMinutes <= 0) {
      setState(() {
        _error = 'Daily study duration must be a positive number of minutes.';
      });
      return;
    }

    if (_selectedExamDate != null &&
        _selectedExamDate!.isBefore(DateTime.now())) {
      setState(() {
        _error = 'Exam date must be in the future.';
      });
      return;
    }

    // Check if user already has an active plan and confirm
    final currentPlans = ref.read(studyPlanControllerProvider).value ?? [];
    if (currentPlans.isNotEmpty) {
      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Existing Plan Detected'),
          content: Text(
            'You already have ${currentPlans.length} study plan(s). Generating this new plan will save alongside your existing schedule. Do you wish to continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Create Plan'),
            ),
          ],
        ),
      );

      if (shouldProceed != true) return;
    }

    setState(() {
      _isGenerating = true;
      _error = null;
    });

    final newPlan = await ref
        .read(studyPlanControllerProvider.notifier)
        .createPlan(
          title: _titleController.text.trim(),
          examDate: _selectedExamDate,
          dailyMinutes: _dailyMinutes,
          timezone: _timezone,
          subjects: subjects,
          preferences: {
            'confidenceLevel': _confidenceLevel,
            'intensity': _intensity,
          },
        );

    if (mounted) {
      setState(() {
        _isGenerating = false;
      });

      if (newPlan != null) {
        Navigator.of(context).pop();
      } else {
        setState(() {
          _error =
              'Failed to generate study plan. Please verify inputs or network connection.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(studyPlanControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Study Plan')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Plan Your Exam Prep',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Set realistic constraints. AI will schedule manageable daily tasks leading up to test day.',
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
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: theme.colorScheme.error,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: theme.colorScheme.error,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Title
                TextFormField(
                  controller: _titleController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Plan Name',
                    hintText: 'e.g. Midterms Prep 2026',
                    prefixIcon: Icon(Icons.edit_note_rounded, size: 20),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a name for your plan';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Subjects / Topics
                TextFormField(
                  controller: _subjectsController,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Subjects / Topics (comma-separated)',
                    hintText:
                        'e.g. Linear Algebra, Organic Chemistry, World History',
                    prefixIcon: Icon(Icons.menu_book_rounded, size: 20),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter subjects or topics to study';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Exam Date Picker
                InkWell(
                  onTap: _pickExamDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Target Exam Date (Optional)',
                      prefixIcon: const Icon(
                        Icons.calendar_today_rounded,
                        size: 20,
                      ),
                      suffixIcon: _selectedExamDate != null
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                setState(() {
                                  _selectedExamDate = null;
                                });
                              },
                            )
                          : null,
                    ),
                    child: Text(
                      _selectedExamDate != null
                          ? DateFormat(
                              'EEEE, MMMM d, y',
                            ).format(_selectedExamDate!)
                          : 'Tap to select exam date',
                      style: TextStyle(
                        color: _selectedExamDate != null
                            ? null
                            : theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Timezone Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _timezone,
                  decoration: const InputDecoration(
                    labelText: 'Timezone',
                    prefixIcon: Icon(Icons.language_rounded, size: 20),
                  ),
                  items: _supportedTimezones.map((tz) {
                    return DropdownMenuItem(value: tz, child: Text(tz));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _timezone = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 20),

                // Available Daily Study Time
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Daily Available Study Time:',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$_dailyMinutes minutes',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildTimeChip(30, '30 min')),
                    const SizedBox(width: 8),
                    Expanded(child: _buildTimeChip(60, '1 hour')),
                    const SizedBox(width: 8),
                    Expanded(child: _buildTimeChip(90, '1.5 hrs')),
                    const SizedBox(width: 8),
                    Expanded(child: _buildTimeChip(120, '2 hrs')),
                  ],
                ),
                const SizedBox(height: 10),
                Slider(
                  value: _dailyMinutes.toDouble(),
                  min: 15,
                  max: 240,
                  divisions: 15,
                  label: '$_dailyMinutes min',
                  onChanged: (val) {
                    setState(() {
                      _dailyMinutes = val.toInt();
                    });
                  },
                ),
                const SizedBox(height: 20),

                // Confidence / Familiarity Level
                Text(
                  'Current Familiarity Level:',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildPreferenceChip(
                        current: _confidenceLevel,
                        value: 'BEGINNER',
                        label: 'Beginner',
                        onSelect: (v) => setState(() => _confidenceLevel = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildPreferenceChip(
                        current: _confidenceLevel,
                        value: 'INTERMEDIATE',
                        label: 'Intermediate',
                        onSelect: (v) => setState(() => _confidenceLevel = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildPreferenceChip(
                        current: _confidenceLevel,
                        value: 'ADVANCED',
                        label: 'Advanced',
                        onSelect: (v) => setState(() => _confidenceLevel = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Study Intensity
                Text(
                  'Study Pace / Intensity:',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildPreferenceChip(
                        current: _intensity,
                        value: 'BALANCED',
                        label: 'Balanced',
                        onSelect: (v) => setState(() => _intensity = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildPreferenceChip(
                        current: _intensity,
                        value: 'CONSISTENT_DAILY',
                        label: 'Steady',
                        onSelect: (v) => setState(() => _intensity = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildPreferenceChip(
                        current: _intensity,
                        value: 'INTENSIVE',
                        label: 'Intensive',
                        onSelect: (v) => setState(() => _intensity = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                AppButton(
                  label: 'Generate Study Schedule',
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

  Widget _buildTimeChip(int minutes, String label) {
    final isSelected = _dailyMinutes == minutes;
    return InkWell(
      onTap: () {
        setState(() {
          _dailyMinutes = minutes;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withValues(alpha: 0.15) : null,
          border: Border.all(
            color: isSelected
                ? AppTheme.primary
                : Theme.of(context).dividerColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? AppTheme.primary : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreferenceChip({
    required String current,
    required String value,
    required String label,
    required ValueChanged<String> onSelect,
  }) {
    final isSelected = current == value;
    return InkWell(
      onTap: () => onSelect(value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.secondary.withValues(alpha: 0.15) : null,
          border: Border.all(
            color: isSelected
                ? AppTheme.secondary
                : Theme.of(context).dividerColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? AppTheme.secondary : null,
            ),
          ),
        ),
      ),
    );
  }
}
