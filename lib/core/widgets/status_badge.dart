import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final String? label;

  const StatusBadge({super.key, required this.status, this.label});

  @override
  Widget build(BuildContext context) {
    final (color, icon, text) = _resolveStatus(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label ?? text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  (Color, IconData, String) _resolveStatus(String s) {
    switch (s.toUpperCase()) {
      case 'READY':
      case 'COMPLETED':
      case 'ACTIVE':
      case 'SUCCESS':
        return (AppTheme.success, Icons.check_circle_outline_rounded, 'Ready');
      case 'PROCESSING':
      case 'IN_PROGRESS':
        return (AppTheme.warning, Icons.sync_rounded, 'Processing');
      case 'UPLOADED':
      case 'TODO':
        return (AppTheme.secondary, Icons.schedule_rounded, 'Pending');
      case 'FAILED':
      case 'ERROR':
        return (AppTheme.error, Icons.error_outline_rounded, 'Failed');
      case 'DELETING':
        return (AppTheme.warning, Icons.delete_sweep_rounded, 'Deleting');
      case 'DELETED':
        return (
          AppTheme.textSecondaryLight,
          Icons.delete_outline_rounded,
          'Deleted',
        );
      case 'ARCHIVED':
      case 'SKIPPED':
        return (
          AppTheme.textSecondaryLight,
          Icons.archive_outlined,
          'Archived',
        );
      default:
        return (AppTheme.primary, Icons.info_outline_rounded, s);
    }
  }
}
