import 'package:flutter/material.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/typography.dart';
import '../models/search_model.dart';

class CitationCard extends StatelessWidget {
  final CitationModel citation;
  final VoidCallback? onTap;

  const CitationCard({
    super.key,
    required this.citation,
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
      default:
        return Icons.link_rounded;
    }
  }

  String _formatEntityType(String type) {
    switch (type.toLowerCase()) {
      case 'case':
        return 'CASE';
      case 'knowledge_article':
      case 'article':
        return 'KNOWLEDGE';
      case 'problem':
        return 'PROBLEM';
      case 'known_error':
        return 'KNOWN ERROR';
      default:
        return type.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.borderLight, width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _getEntityIcon(citation.entityType),
                size: 16,
                color: AppColors.primaryBlue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _formatEntityType(citation.entityType),
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            citation.title,
                            style: AppTypography.bodySm.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimaryLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (citation.snippet.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        citation.snippet,
                        style: AppTypography.bodySm.copyWith(
                          fontSize: 11,
                          color: AppColors.textSecondaryLight,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.open_in_new_rounded,
                size: 14,
                color: AppColors.textSecondaryLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
