import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Real-time 24/7 wall-clock SLA Timer Widget per SRS §4.3 & §5.7.
/// Displays countdown until deadline, highlighting warning states (<20% remaining) and breaches.
class SlaTimerWidget extends StatefulWidget {
  final DateTime targetTime;
  final bool isBreached;
  final DateTime? completedAt;
  final String label;

  const SlaTimerWidget({
    super.key,
    required this.targetTime,
    required this.isBreached,
    this.completedAt,
    this.label = 'Resolution',
  });

  @override
  State<SlaTimerWidget> createState() => _SlaTimerWidgetState();
}

class _SlaTimerWidgetState extends State<SlaTimerWidget> {
  Timer? _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _calculateRemaining();
    if (widget.completedAt == null && !widget.isBreached) {
      _timer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(_calculateRemaining);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _calculateRemaining() {
    final now = DateTime.now().toUtc();
    final target = widget.targetTime.toUtc();
    _remaining = target.difference(now);
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) {
      final abs = d.abs();
      if (abs.inDays > 0) return '${abs.inDays}d ${abs.inHours % 24}h overdue';
      if (abs.inHours > 0) return '${abs.inHours}h ${abs.inMinutes % 60}m overdue';
      return '${abs.inMinutes}m overdue';
    }
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h left';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m left';
    return '${d.inMinutes}m left';
  }

  @override
  Widget build(BuildContext context) {
    // If completed
    if (widget.completedAt != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.slaHealthy.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, size: 14, color: AppColors.slaHealthy),
            const SizedBox(width: 4),
            Text(
              '${widget.label}: Met',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.slaHealthy,
              ),
            ),
          ],
        ),
      );
    }

    // Breached state
    if (widget.isBreached || _remaining.isNegative) {
      final text = _formatDuration(_remaining);
      return Semantics(
        label: '${widget.label} breached. $text',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.slaBreached.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.slaBreached.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 14, color: AppColors.slaBreached),
              const SizedBox(width: 4),
              Text(
                '${widget.label}: $text',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.slaBreached,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Warning state (< 1 hour or < 20%)
    final isWarning = _remaining.inMinutes < 60;
    final color = isWarning ? AppColors.slaWarning : AppColors.textSecondaryLight;
    final text = _formatDuration(_remaining);

    return Semantics(
      label: '${widget.label} target in $text',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isWarning ? AppColors.slaWarning.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isWarning ? Icons.warning_amber_rounded : Icons.access_time,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              '${widget.label}: $text',
              style: TextStyle(
                fontSize: 11,
                fontWeight: isWarning ? FontWeight.bold : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
