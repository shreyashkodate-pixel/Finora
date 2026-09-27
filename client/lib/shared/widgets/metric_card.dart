import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/dimensions.dart';
import '../theme/typography.dart';

/// Minimalist Metric Card for Dashboards and KPI Rows aligned with Stitch precision ops
class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;
  final String? subtitle;
  final IconData? subtitleIcon;
  final String? pillText;
  final Color? pillBgColor;
  final Color? pillTextColor;
  final VoidCallback? onTap;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
    this.subtitle,
    this.subtitleIcon,
    this.pillText,
    this.pillBgColor,
    this.pillTextColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.spaceMd),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(color: AppColors.borderLight, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 12,
                          letterSpacing: 0.2,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondaryLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          Text(
                            value,
                            style: AppTypography.headlineLg.copyWith(
                              color: valueColor ?? AppColors.textPrimaryLight,
                              fontWeight: FontWeight.w700,
                              fontSize: 26,
                            ),
                          ),
                          if (pillText != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: pillBgColor ?? AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                pillText!,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: pillTextColor ?? AppColors.primaryBlue,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 20, color: valueColor ?? AppColors.primaryBlue),
                  ),
                ],
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    if (subtitleIcon != null) ...[
                      Icon(subtitleIcon, size: 14, color: AppColors.textSecondaryLight),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        subtitle!,
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.textSecondaryLight,
                          fontSize: 11.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
