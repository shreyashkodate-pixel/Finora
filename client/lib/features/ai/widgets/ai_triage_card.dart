import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/accessible_button.dart';
import '../../cases/models/case_model.dart';
import '../../cases/providers/case_provider.dart';
import '../models/ai_models.dart';
import '../providers/ai_provider.dart';

/// Gemini AI Triage Recommendation Card with Human-in-the-Loop approval per SRS §5.2 & §5.13.
class AITriageCard extends StatelessWidget {
  final CaseModel currentCase;
  final AITriageModel? triage;
  final bool isStaff;

  const AITriageCard({
    super.key,
    required this.currentCase,
    required this.triage,
    required this.isStaff,
  });

  Color _getConfidenceColor(String level) {
    switch (level.toLowerCase()) {
      case 'high':
        return AppColors.slaHealthy;
      case 'moderate':
        return AppColors.slaWarning;
      case 'low':
      default:
        return AppColors.priorityP1;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (triage == null) {
      return Card(
        color: AppColors.aiBackground,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.aiAccent),
              ),
              const SizedBox(width: 12),
              const Text(
                'Gemini AI analyzing case context and triage patterns...',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
              ),
            ],
          ),
        ),
      );
    }

    final confColor = _getConfidenceColor(triage!.confidenceLevel);

    return Card(
      color: AppColors.aiBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.aiBorder, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.auto_awesome, size: 20, color: AppColors.aiAccent),
                    SizedBox(width: 8),
                    Text(
                      'AI Triage Recommendation',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryDark),
                    ),
                  ],
                ),
                // Confidence badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: confColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: confColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined, size: 12, color: confColor),
                      const SizedBox(width: 4),
                      Text(
                        '${triage!.confidenceLevel.toUpperCase()} CONFIDENCE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: confColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Recommendations
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                if (triage!.suggestedCategory != null)
                  Text.rich(
                    TextSpan(
                      text: 'Category: ',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      children: [
                        TextSpan(
                          text: triage!.suggestedCategory,
                          style: const TextStyle(fontWeight: FontWeight.normal, color: AppColors.primaryBlue),
                        ),
                      ],
                    ),
                  ),
                if (triage!.suggestedPriority != null)
                  Text.rich(
                    TextSpan(
                      text: 'Priority: ',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      children: [
                        TextSpan(
                          text: triage!.suggestedPriority!.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: triage!.suggestedPriority!.toLowerCase() == 'p1'
                                ? AppColors.priorityP1
                                : AppColors.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            if (triage!.reasoning != null && triage!.reasoning!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                triage!.reasoning!,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight, height: 1.3),
              ),
            ],

            // Human in the Loop Action
            if (isStaff && currentCase.status == 'new') ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.aiBorder),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AccessibleButton(
                    onPressed: () async {
                      final aiProv = context.read<AIProvider>();
                      final caseProv = context.read<CaseProvider>();
                      final success = await aiProv.applyTriage(currentCase.id, currentCase.version);
                      if (success) {
                        await caseProv.fetchCaseDetails(currentCase.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('AI recommendation applied successfully.')),
                          );
                        }
                      }
                    },
                    icon: Icons.check,
                    semanticLabel: 'Apply AI triage recommendation button',
                    child: const Text('Apply Recommendation'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
