import 'package:flutter/material.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/dimensions.dart';
import '../../../shared/theme/typography.dart';
import '../models/alert_model.dart';

/// Card item representing an Inbound Alert in the list view
class AlertListCard extends StatelessWidget {
  final InboundAlertModel alert;
  final bool isSelected;
  final VoidCallback onTap;

  const AlertListCard({
    super.key,
    required this.alert,
    this.isSelected = false,
    required this.onTap,
  });

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = alert.provider;
    final sevEnum = AlertSeverityExtension.fromApiValue(alert.severity);
    final status = alert.status;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppDimensions.cardBorderRadius,
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.spaceMd),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryContainer.withValues(alpha: 0.5)
                : AppColors.surfaceLight,
            borderRadius: AppDimensions.cardBorderRadius,
            border: Border.all(
              color: isSelected ? AppColors.primaryBlue : AppColors.borderLight,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Provider Badge + Severity Tag + Timestamp
              Row(
                children: [
                  // Provider Chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: provider.brandColor.withValues(alpha: 0.12),
                      borderRadius: AppDimensions.priorityBorderRadius,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(provider.icon, size: 13, color: provider.brandColor),
                        const SizedBox(width: 4),
                        Text(
                          provider.displayName,
                          style: AppTypography.labelSm.copyWith(
                            color: provider.brandColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Severity Tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: sevEnum.color.withValues(alpha: 0.12),
                      borderRadius: AppDimensions.priorityBorderRadius,
                    ),
                    child: Text(
                      alert.severity.toUpperCase(),
                      style: AppTypography.labelSm.copyWith(
                        color: sevEnum.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Timestamp
                  Text(
                    _formatTimestamp(alert.createdAt),
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.textSecondaryLight,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppDimensions.spaceSm),

              // Title
              Text(
                alert.title,
                style: AppTypography.headlineSm.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              if (alert.description != null && alert.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  alert.description!,
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.textSecondaryLight,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: AppDimensions.spaceSm),

              // Footer Row: Status Badge + Linked Incident Tag
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: status.color.withValues(alpha: 0.1),
                      borderRadius: AppDimensions.pillBorderRadius,
                      border: Border.all(
                        color: status.color.withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(status.icon, size: 12, color: status.color),
                        const SizedBox(width: 4),
                        Text(
                          status.displayName,
                          style: AppTypography.labelSm.copyWith(
                            color: status.color,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Linked Case / Incident Indicator
                  if (alert.hasLinkedCase)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: AppDimensions.priorityBorderRadius,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.confirmation_number_outlined, size: 11, color: AppColors.primaryBlue),
                          const SizedBox(width: 3),
                          Text(
                            'INCIDENT LINKED',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (alert.isAcknowledged)
                    Text(
                      'Ack by Staff',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.statusAssigned,
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
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
