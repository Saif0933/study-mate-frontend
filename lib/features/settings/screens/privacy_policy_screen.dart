import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Responsible AI')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy & AI Transparency',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Last updated: October 2026 • AI StudyMate v1.0',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
            const Divider(height: 32),

            _buildSection(
              context,
              title: '1. What Data We Process',
              content:
                  'AI StudyMate collects only the information necessary to provide your personalized learning experience: your email address, display name, conversational tutor messages, uploaded study documents (PDFs), practice quiz attempts, and study schedules.',
            ),

            _buildSection(
              context,
              title: '2. How AI & Your Documents Work',
              content:
                  'When you ask questions about an uploaded PDF, the document text is processed into chunks and semantic embeddings on our secure backend server. When querying your materials, relevant excerpts are retrieved and sent to our configured AI provider (OpenAI) to synthesize answers grounded in your notes.\n\nYour API keys are never required, and provider secrets never reside on your device.',
            ),

            _buildSection(
              context,
              title: '3. Responsible AI & Learning Disclaimer',
              content:
                  'AI StudyMate is designed as an educational productivity and study tool. AI-generated explanations, quiz questions, and study plans may contain inaccuracies and should always be verified against official course textbooks and instructors.\n\nAI StudyMate is not an exam-cheating service and does not guarantee academic performance.',
            ),

            _buildSection(
              context,
              title: '4. Data Ownership & Deletion Rights',
              content:
                  'You retain complete ownership of your study materials and personal notes. You can delete individual documents, quizzes, study plans, or conversations at any time. When you request Account Deletion from the Settings screen, your account, stored files, vector embeddings, and conversation histories are permanently deleted.',
            ),

            _buildSection(
              context,
              title: '5. Security & Protection',
              content:
                  'All client-server communications use encrypted TLS connections. Access to personal materials is secured using strict owner-scoped authorization checks to ensure other users cannot view your files.',
            ),

            _buildSection(
              context,
              title: '6. Contact & Support',
              content:
                  'If you have questions regarding data privacy or need technical support, you can reach out via email to ${AppConfig.supportEmail} or through the app settings.',
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}
