import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../auth/controllers/auth_controller.dart';
import '../repositories/feedback_repository.dart';
import '../repositories/usage_repository.dart';
import 'privacy_policy_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  void _showEditProfileDialog(String? currentName) {
    showDialog(
      context: context,
      builder: (ctx) => _EditProfileDialog(initialName: currentName),
    );
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out of AI StudyMate?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(authControllerProvider.notifier).logout();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account & All Data?'),
        content: const Text(
          'This action is permanent and irreversible. All your uploaded PDF documents, vector embeddings, chat history, practice quizzes, and study plans will be permanently removed from the server.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Permanently Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Show deletion progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Expanded(
                child: Text('Deleting account and clearing personal data...'),
              ),
            ],
          ),
        ),
      ),
    );

    final result = await ref
        .read(authControllerProvider.notifier)
        .deleteAccount();

    if (!mounted) return;

    // Dismiss the deletion progress dialog
    Navigator.of(context, rootNavigator: true).pop();

    if (!result.success) {
      // Requirement 11: Ensure errors do not falsely indicate that deletion succeeded.
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Account Deletion Failed'),
          content: Text(
            '${result.error ?? 'An unexpected server error occurred.'}\n\nYour account and study data were NOT deleted and remain secure.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _showFeedbackDialog() {
    showDialog(context: context, builder: (ctx) => const _FeedbackDialog());
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terms of Service'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '1. Educational Purpose',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'AI StudyMate is designed strictly as a personal study and revision companion. AI outputs should be validated against official course materials.',
              ),
              SizedBox(height: 12),
              Text(
                '2. Academic Integrity',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'This platform is not an exam-cheating service. Users agree not to use AI StudyMate for live test cheating, proctored exam compromise, or plagiarism.',
              ),
              SizedBox(height: 12),
              Text(
                '3. Data Ownership',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'You retain full ownership of your uploaded study materials. Materials are processed solely to deliver semantic search, tutoring, and practice quizzes for your account.',
              ),
              SizedBox(height: 12),
              Text(
                '4. Service Availability',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'We continuously improve the platform, but do not guarantee uninterrupted access or exact model uptime.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSupportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Help & Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Have questions, feedback, or need account assistance? Our support team is here to help.',
            ),
            const SizedBox(height: 16),
            const Text(
              'Support Email:',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryDark),
            ),
            const SizedBox(height: 4),
            SelectableText(
              AppConfig.supportEmail,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Typical response time: 24–48 hours on business days.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy Email'),
            onPressed: () {
              Clipboard.setData(
                const ClipboardData(text: AppConfig.supportEmail),
              );
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Support email copied to clipboard!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final usageAsync = ref.watch(usageControllerProvider);
    final theme = Theme.of(context);

    final user = authState is Authenticated ? authState.user : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // User Profile Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: const BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              (user?.displayName?.isNotEmpty ?? false)
                                  ? user!.displayName![0].toUpperCase()
                                  : (user?.email.isNotEmpty ?? false)
                                  ? user!.email[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      user?.displayName ?? 'Learner',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                      color: AppTheme.primary,
                                    ),
                                    tooltip: 'Edit Profile Name',
                                    onPressed: () => _showEditProfileDialog(
                                      user?.displayName,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user?.email ?? '',
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.success.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      user?.status ?? 'ACTIVE',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.success,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'VERIFIED',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.verified_user_outlined,
                          size: 14,
                          color: AppTheme.textSecondaryDark,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Account details synced with secure authentication service.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: AppTheme.textSecondaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // AI Usage Overview & Quotas
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.speed_rounded,
                                color: AppTheme.secondary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'AI Usage & Limits',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          tooltip: 'Refresh Usage',
                          onPressed: () => ref.refresh(usageControllerProvider),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    usageAsync.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text('Loading usage stats from server...'),
                        ),
                      ),
                      error: (err, _) => Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceDark,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: AppTheme.textSecondaryDark,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Usage accounting active. Monitored server-side.',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  ref.refresh(usageControllerProvider),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                      data: (usage) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildUsageStat(
                                  'Tokens Consumed',
                                  '${usage.totalTokens}',
                                ),
                              ),
                              Expanded(
                                child: _buildUsageStat(
                                  'AI Requests',
                                  usage.quotaLimit != null
                                      ? '${usage.requestCount} / ${usage.quotaLimit}'
                                      : '${usage.requestCount}',
                                ),
                              ),
                              if (usage.estimatedCost > 0)
                                Expanded(
                                  child: _buildUsageStat(
                                    'Est. Cost',
                                    '\$${usage.estimatedCost.toStringAsFixed(4)}',
                                  ),
                                ),
                            ],
                          ),
                          if (usage.quotaLimit != null &&
                              usage.quotaLimit! > 0) ...[
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (usage.requestCount / usage.quotaLimit!)
                                    .clamp(0.0, 1.0),
                                backgroundColor: AppTheme.surfaceDark,
                                color: usage.isExhausted
                                    ? AppTheme.error
                                    : AppTheme.primary,
                                minHeight: 6,
                              ),
                            ),
                            if (usage.requestsRemaining != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${usage.requestsRemaining} requests remaining in current quota',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondaryDark,
                                ),
                              ),
                            ],
                          ],
                          if (usage.featureBreakdown.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'Feature Breakdown:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textSecondaryDark,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: usage.featureBreakdown.entries.map((e) {
                                return Chip(
                                  padding: EdgeInsets.zero,
                                  labelPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 0,
                                  ),
                                  label: Text(
                                    '${_formatFeatureName(e.key)}: ${e.value}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  backgroundColor: AppTheme.surfaceDark,
                                );
                              }).toList(),
                            ),
                          ],
                          if (usage.isExhausted) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.error.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppTheme.error.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    color: AppTheme.error,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'AI Request Limit Reached',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: AppTheme.error,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          usage.quotaMessage ??
                                              'Your quota for AI requests has been exhausted.',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        if (usage.resetTime != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Quota resets: ${usage.resetTime!.toLocal().toString().split('.')[0]}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Feedback & Improvements Section
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.rate_review_outlined,
                  color: AppTheme.primary,
                ),
                title: const Text('Send Feedback & Report Issues'),
                subtitle: const Text(
                  'Report AI inaccuracies, bugs, or suggest features',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _showFeedbackDialog,
              ),
            ),
            const SizedBox(height: 16),

            // Legal, Support & Transparency Section
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: const Text('Privacy Policy & Responsible AI'),
                    subtitle: const Text(
                      'Data retention, AI disclosures & rights',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PrivacyPolicyScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Terms of Service'),
                    subtitle: const Text(
                      'Educational use & academic integrity',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _showTermsDialog,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.help_outline_rounded),
                    title: const Text('Help & Support'),
                    subtitle: const Text('Contact assistance and support team'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _showSupportDialog,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded),
                    title: const Text('App Version'),
                    subtitle: Text(
                      '${AppConfig.appName} v${AppConfig.appVersion}',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Sign Out Button
            AppButton(
              label: 'Sign Out',
              onPressed: _confirmSignOut,
              isOutlined: true,
              icon: Icons.logout_rounded,
            ),
            const SizedBox(height: 16),

            // Delete Account Button (PRD FR-AUTH-04 & Play Store requirement)
            TextButton.icon(
              onPressed: _confirmDeleteAccount,
              icon: const Icon(Icons.delete_forever_rounded, size: 20),
              label: const Text('Delete Account and Personal Data'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondaryDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  String _formatFeatureName(String key) {
    switch (key.toUpperCase()) {
      case 'TUTOR_CHAT':
        return 'Tutor Chat';
      case 'DOCUMENT_QA':
        return 'PDF Q&A';
      case 'QUIZ_GENERATION':
        return 'Quizzes';
      case 'STUDY_PLAN_GENERATION':
        return 'Study Plans';
      default:
        return key;
    }
  }
}

class _FeedbackDialog extends ConsumerStatefulWidget {
  const _FeedbackDialog();

  @override
  ConsumerState<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends ConsumerState<_FeedbackDialog> {
  final _commentController = TextEditingController();
  String _rating = 'POSITIVE';
  String _selectedCategory = 'HELPFULNESS';
  bool _isSubmitting = false;
  String? _errorMessage;

  final _categories = const [
    ('HELPFULNESS', 'Helpfulness'),
    ('ACCURACY', 'Accuracy'),
    ('SUGGESTION', 'Suggestion'),
    ('BUG', 'Bug / Issue'),
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) {
      setState(() {
        _errorMessage = 'Please provide details or comments.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(feedbackRepositoryProvider);
      await repo.submitFeedback(
        rating: _rating,
        category: _selectedCategory,
        comment: comment,
      );

      if (!mounted) return;

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thank you! Your feedback has been submitted.'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to submit feedback. Please try again.';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send Feedback'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How was your experience with AI StudyMate?',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _rating == 'POSITIVE'
                          ? AppTheme.primary.withValues(alpha: 0.15)
                          : null,
                      side: BorderSide(
                        color: _rating == 'POSITIVE'
                            ? AppTheme.primary
                            : Colors.grey,
                      ),
                    ),
                    onPressed: () => setState(() => _rating = 'POSITIVE'),
                    icon: const Icon(Icons.thumb_up_alt_rounded, size: 18),
                    label: const Text('Positive'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _rating == 'NEGATIVE'
                          ? AppTheme.error.withValues(alpha: 0.15)
                          : null,
                      side: BorderSide(
                        color: _rating == 'NEGATIVE'
                            ? AppTheme.error
                            : Colors.grey,
                      ),
                    ),
                    onPressed: () => setState(() => _rating = 'NEGATIVE'),
                    icon: const Icon(Icons.thumb_down_alt_rounded, size: 18),
                    label: const Text('Issue'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Category:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _categories.map((c) {
                final isSelected = _selectedCategory == c.$1;
                return ChoiceChip(
                  label: Text(c.$2),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) setState(() => _selectedCategory = c.$1);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Share what was helpful or what could be improved...',
                border: OutlineInputBorder(),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppTheme.error, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit Feedback'),
        ),
      ],
    );
  }
}

class _EditProfileDialog extends ConsumerStatefulWidget {
  final String? initialName;
  const _EditProfileDialog({this.initialName});

  @override
  ConsumerState<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<_EditProfileDialog> {
  late final TextEditingController _controller;
  String? _dialogError;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _dialogError = 'Display name cannot be empty';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _dialogError = null;
    });

    final result = await ref
        .read(authControllerProvider.notifier)
        .updateProfile(trimmed);

    if (!mounted) return;

    if (result.success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: AppTheme.success,
        ),
      );
    } else {
      setState(() {
        _isSaving = false;
        _dialogError = result.error ?? 'Failed to update profile';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Profile Name'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your display name is shown on your study dashboard and reports.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLength: 100,
            decoration: InputDecoration(
              labelText: 'Display Name',
              hintText: 'Enter your name',
              errorText: _dialogError,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
