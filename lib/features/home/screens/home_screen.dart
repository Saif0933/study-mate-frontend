import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../tutor/controllers/conversation_list_controller.dart';
import '../../tutor/models/conversation_model.dart';
import '../../tutor/screens/chat_screen.dart';

/// Primary Home Dashboard showcasing real user profile summary,
/// quick navigation actions, recent AI Tutor conversations, and learning highlights.
class HomeScreen extends ConsumerWidget {
  final void Function(int index)? onTabSelected;

  const HomeScreen({super.key, this.onTabSelected});

  void _navigateToTab(BuildContext context, int tabIndex, String routeName) {
    if (onTabSelected != null) {
      onTabSelected!(tabIndex);
    } else {
      Navigator.of(context).pushNamed(routeName);
    }
  }

  void _startPromptConversation(
    BuildContext context,
    WidgetRef ref,
    String topic,
    String prompt,
  ) async {
    final newConv = await ref
        .read(conversationListControllerProvider.notifier)
        .createConversation(topic);
    if (newConv != null && context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatScreen(conversation: newConv)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final user = authState is Authenticated ? authState.user : null;
    final userName =
        user?.displayName ?? user?.email.split('@').first ?? 'Learner';
    final userEmail = user?.email ?? '';
    final userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : 'L';
    final userBadge = user != null
        ? (user.status == 'ACTIVE' ? 'STUDENT' : user.status)
        : 'STUDENT';

    final convAsync = ref.watch(conversationListControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xs + 2),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(
                Icons.auto_stories_rounded,
                color: AppTheme.primaryDark,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Text('AI StudyMate'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.settings);
            },
            tooltip: 'Settings & Account',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref
                .read(conversationListControllerProvider.notifier)
                .refresh();
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              // 1. Welcome & Profile Summary Card
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.white24,
                          child: Text(
                            userInitial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back, $userName!',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (userEmail.isNotEmpty)
                                Text(
                                  userEmail,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            userBadge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'Ready to master your coursework? Ask questions, study documents, or test your recall.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // 2. Quick Actions Section
              Text(
                'Quick Actions',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _buildQuickActionButton(
                      context,
                      label: 'AI Tutor',
                      icon: Icons.psychology_rounded,
                      color: AppTheme.primaryDark,
                      onTap: () => _navigateToTab(context, 1, AppRoutes.chat),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _buildQuickActionButton(
                      context,
                      label: 'PDF Chat',
                      icon: Icons.picture_as_pdf_rounded,
                      color: AppTheme.secondary,
                      onTap: () =>
                          _navigateToTab(context, 2, AppRoutes.documents),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _buildQuickActionButton(
                      context,
                      label: 'Quiz',
                      icon: Icons.quiz_rounded,
                      color: AppTheme.accent,
                      onTap: () => _navigateToTab(context, 3, AppRoutes.quiz),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _buildQuickActionButton(
                      context,
                      label: 'Planner',
                      icon: Icons.calendar_month_rounded,
                      color: AppTheme.success,
                      onTap: () =>
                          _navigateToTab(context, 4, AppRoutes.studyPlanner),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // 3. Recent AI Tutor Conversations Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Study Chats',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () => _navigateToTab(context, 1, AppRoutes.chat),
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),

              // Conversations Content (Loading, Error, Empty, or Data)
              if (convAsync.hasError && !convAsync.hasValue)
                _buildConversationsError(
                  context,
                  ref,
                  convAsync.error.toString(),
                )
              else
                convAsync.when(
                  loading: () => _buildConversationsLoading(),
                  error: (error, _) =>
                      _buildConversationsError(context, ref, error.toString()),
                  data: (conversations) {
                    if (conversations.isEmpty) {
                      return _buildConversationsEmpty(context, ref);
                    }
                    final recents = conversations.take(3).toList();
                    return Column(
                      children: recents
                          .map((conv) => _buildConversationTile(context, conv))
                          .toList(),
                    );
                  },
                ),
              const SizedBox(height: AppSpacing.lg),

              // 4. Learning Activity & Socratic Prompts
              Text(
                'Try a Study Prompt',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildPromptCard(
                context,
                ref,
                title: 'Explain with an Analogy',
                description:
                    'Explain the difference between RAM and ROM using a kitchen analogy.',
                topic: 'Computer Hardware - RAM vs ROM',
                icon: Icons.lightbulb_outline_rounded,
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildPromptCard(
                context,
                ref,
                title: 'Socratic Concept Breakdown',
                description:
                    'Break down Newton’s Third Law and test me with a conceptual puzzle.',
                topic: 'Physics - Newton’s Laws',
                icon: Icons.psychology_alt_rounded,
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildPromptCard(
                context,
                ref,
                title: 'Active Recall Check',
                description:
                    'Ask me 3 progressive questions about cellular respiration.',
                topic: 'Biology - Cellular Respiration',
                icon: Icons.quiz_outlined,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConversationsLoading() {
    return Column(
      children: List.generate(
        3,
        (i) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            title: Container(height: 12, width: 120, color: Colors.white10),
            subtitle: Container(height: 8, width: 60, color: Colors.white10),
          ),
        ),
      ),
    );
  }

  Widget _buildConversationsError(
    BuildContext context,
    WidgetRef ref,
    String errorMessage,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: Theme.of(context).colorScheme.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Unable to load recent chats',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                ref.read(conversationListControllerProvider.notifier).refresh();
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationsEmpty(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: AppTheme.primaryDark,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'No recent study chats',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              'Start a tutoring session to ask questions or review your study material.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _navigateToTab(context, 1, AppRoutes.chat),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Start Chat'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationTile(
    BuildContext context,
    ConversationModel conversation,
  ) {
    final dateStr = DateFormat(
      'MMM d • hh:mm a',
    ).format(conversation.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: const Icon(
            Icons.school_rounded,
            color: AppTheme.primaryDark,
            size: 20,
          ),
        ),
        title: Text(
          conversation.title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          dateStr,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatScreen(conversation: conversation),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPromptCard(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String description,
    required String topic,
    required IconData icon,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: InkWell(
        onTap: () => _startPromptConversation(context, ref, topic, description),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppTheme.secondary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}
