import 'package:flutter/material.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/dimensions.dart';
import '../../../shared/theme/typography.dart';
import '../models/search_model.dart';

class SearchResultCard extends StatelessWidget {
  final SemanticSearchResultItemModel item;
  final bool isSelected;
  final VoidCallback? onTap;

  const SearchResultCard({
    super.key,
    required this.item,
    this.isSelected = false,
    this.onTap,
  });

  IconData _getEntityIcon(String type) {
    switch (type.toLowerCase()) {
      case 'case':
        return Icons.confirmation_number_outlined;
      case 'knowledge_article':
      case 'article':
        return Icons.menu_book_outlined;
      case 'problem':
        return Icons.fact_check_outlined;
      case 'known_error':
        return Icons.bug_report_outlined;
      case 'audit_log':
        return Icons.history_outlined;
      default:
        return Icons.description_outlined;
    }
  }

  Color _getScoreColor(double score) {
    if (score >= 0.70) return AppColors.slaHealthy;
    if (score >= 0.40) return AppColors.primaryBlue;
    return AppColors.textSecondaryLight;
  }

  String _formatEntityType(String type) {
    switch (type.toLowerCase()) {
      case 'case':
        return 'CASE';
      case 'knowledge_article':
      case 'article':
        return 'ARTICLE';
      case 'problem':
        return 'PROBLEM';
      case 'known_error':
        return 'KNOWN ERROR';
      case 'audit_log':
        return 'AUDIT LOG';
      default:
        return type.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scorePercent = item.scorePercentage;
    final scoreColor = _getScoreColor(item.score);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppDimensions.cardBorderRadius,
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.spaceMd),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryContainer.withValues(alpha: 0.5) : AppColors.surfaceLight,
            borderRadius: AppDimensions.cardBorderRadius,
            border: Border.all(
              color: isSelected ? AppColors.primaryBlue : AppColors.borderLight,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Type badge + Score badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: AppDimensions.priorityBorderRadius,
                      border: Border.all(color: AppColors.borderLight, width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getEntityIcon(item.entityType),
                          size: 14,
                          color: AppColors.textSecondaryLight,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatEntityType(item.entityType),
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.textPrimaryLight,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Relevance Score Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.1),
                      borderRadius: AppDimensions.pillBorderRadius,
                      border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.insights_rounded,
                          size: 12,
                          color: scoreColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$scorePercent% match',
                          style: AppTypography.labelSm.copyWith(
                            color: scoreColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                item.title,
                style: AppTypography.headlineSm.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryLight,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),

              // Snippet Preview
              Text(
                item.contentSnippet,
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.textSecondaryLight,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),

              // Metadata Tags Row
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (item.status != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Status: ${item.status!.toUpperCase()}',
                        style: AppTypography.labelSm.copyWith(fontSize: 10),
                      ),
                    ),
                  if (item.category != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.category!,
                        style: AppTypography.labelSm.copyWith(fontSize: 10),
                      ),
                    ),
                  if (item.priority != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'P: ${item.priority!.toUpperCase()}',
                        style: AppTypography.labelSm.copyWith(fontSize: 10),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
