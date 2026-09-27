import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/dimensions.dart';
import '../theme/typography.dart';

/// Reusable Page Header with title, subtitle, and action buttons
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final String? breadcrumb;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.breadcrumb,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.marginDesktop,
        vertical: AppDimensions.spaceMd,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.borderLight, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppDimensions.spaceMd),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (breadcrumb != null) ...[
                  Text(
                    breadcrumb!,
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space2xs),
                ],
                Text(
                  title,
                  style: AppTypography.headlineMd.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppDimensions.space2xs),
                  Text(
                    subtitle!,
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actions != null && actions!.isNotEmpty) ...[
            const SizedBox(width: AppDimensions.spaceMd),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: actions!,
            ),
          ],
        ],
      ),
    );
  }
}
