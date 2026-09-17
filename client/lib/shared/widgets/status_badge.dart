import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Accessible visual badge indicating case status per SRS §4.1.
class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  Color _getStatusColor() {
    switch (status.toLowerCase()) {
      case 'new':
        return AppColors.statusNew;
      case 'in_assessment':
        return AppColors.statusInAssessment;
      case 'assigned':
        return AppColors.statusAssigned;
      case 'awaiting_requester':
      case 'awaiting_approval':
        return AppColors.statusAwaiting;
      case 'resolved':
        return AppColors.statusResolved;
      case 'closed':
        return AppColors.statusClosed;
      case 'cancelled':
        return AppColors.statusCancelled;
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Accessible priority badge (P1 Critical, P2 High, P3 Medium, P4 Low).
class PriorityBadge extends StatelessWidget {
  final String priority;

  const PriorityBadge({super.key, required this.priority});

  Color _getPriorityColor() {
    switch (priority.toLowerCase()) {
      case 'p1':
        return AppColors.priorityP1;
      case 'p2':
        return AppColors.priorityP2;
      case 'p3':
        return AppColors.priorityP3;
      case 'p4':
        return AppColors.priorityP4;
      default:
        return Colors.grey;
    }
  }

  String _getPriorityLabel() {
    switch (priority.toLowerCase()) {
      case 'p1':
        return 'P1 - Critical';
      case 'p2':
        return 'P2 - High';
      case 'p3':
        return 'P3 - Medium';
      case 'p4':
        return 'P4 - Low';
      default:
        return priority.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getPriorityColor();
    final label = _getPriorityLabel();

    return Semantics(
      label: 'Priority: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          priority.toUpperCase(),
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
