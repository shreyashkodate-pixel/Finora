import 'package:flutter/material.dart';
import '../../../shared/theme/colors.dart';
import '../models/ai_models.dart';

/// Displays proactive SLA and Escalation Risk Signals per SRS §5.7.
class SLARiskCard extends StatelessWidget {
  final RiskAssessmentModel? risk;

  const SLARiskCard({super.key, required this.risk});

  Color _getRiskColor(String level) {
    switch (level.toLowerCase()) {
      case 'critical':
      case 'high':
        return AppColors.priorityP1;
      case 'moderate':
        return AppColors.slaWarning;
      case 'low':
      default:
        return AppColors.slaHealthy;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (risk == null) return const SizedBox.shrink();

    final color = _getRiskColor(risk!.riskLevel);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield_alert_outlined, size: 18, color: color),
                    const SizedBox(width: 8),
                    const Text(
                      'SLA & Escalation Risk Assessment',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${risk!.riskLevel.toUpperCase()} RISK (${(risk!.riskScore * 100).toInt()}%)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            if (risk!.signals.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('Active Signals:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: risk!.signals.map((s) {
                  return Chip(
                    label: Text(s.toString(), style: const TextStyle(fontSize: 11)),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
            if (risk!.recommendedAction != null) ...[
              const SizedBox(height: 8),
              Text(
                'Recommended: ${risk!.recommendedAction}',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: color),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
