import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/colors.dart';
import '../models/ai_models.dart';
import '../providers/ai_provider.dart';

/// Living Case Summary card automatically maintained per SRS §5.3.
class LivingSummaryCard extends StatelessWidget {
  final String caseId;
  final CaseSummaryModel? summary;
  final bool isStaff;

  const LivingSummaryCard({
    super.key,
    required this.caseId,
    required this.summary,
    required this.isStaff,
  });

  @override
  Widget build(BuildContext context) {
    if (summary == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: const [
              Icon(Icons.notes, size: 20, color: AppColors.textSecondaryLight),
              SizedBox(width: 8),
              Text(
                'No living summary generated yet.',
                style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final timeStr = DateFormat('h:mm a').format(summary!.updatedAt.toLocal());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.summarize_outlined, size: 18, color: AppColors.primaryBlue),
                    SizedBox(width: 8),
                    Text(
                      'Living Case Summary',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                Text(
                  'Updated $timeStr (${summary!.messageCount} notes)',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SelectableText(
              summary!.summary,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            if (isStaff) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => context.read<AIProvider>().refreshSummary(caseId),
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('Refresh Summary', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
