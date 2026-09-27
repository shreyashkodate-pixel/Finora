import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Accessible visual badge indicating case status per SRS §4.1.
class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  Color _getStatusColor() {
    switch (status.toLowerCase()) {
      case 'new':
      case 'open':
        return AppColors.statusNew;
      case 'in_assessment':
      case 'investigating':
        return AppColors.statusInAssessment;
      case 'assigned':
      case 'scheduled':
        return AppColors.statusAssigned;
      case 'awaiting_requester':
      case 'awaiting_approval':
      case 'pending_cab':
        return AppColors.statusAwaiting;
      case 'approved':
      case 'workaround_found':
        return AppColors.slaHealthy;
      case 'implementing':
      case 'mitigated':
        return AppColors.priorityP2;
      case 'declared':
      case 'active':
        return AppColors.priorityP1;
      case 'resolved':
      case 'completed':
        return AppColors.statusResolved;
      case 'closed':
        return AppColors.statusClosed;
      case 'cancelled':
      case 'rejected':
      case 'failed':
      case 'rollback':
        return AppColors.statusCancelled;
      case 'known_error':
        return AppColors.priorityP3;
      case 'draft':
      case 'post_mortem':
        return AppColors.primaryBlue;
      default:
        return Colors.grey;
    }
  }

  String _formatStatus() {
    return status.replaceAll('_', ' ').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor();
    final label = _formatStatus();

    return Semantics(
      label: 'Case status: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
