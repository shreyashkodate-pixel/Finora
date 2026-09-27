import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/dimensions.dart';
import '../theme/typography.dart';

/// User Role Badge indicating authorization tier
class RoleBadge extends StatelessWidget {
  final String role;

  const RoleBadge({
    super.key,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final r = role.toLowerCase().trim();
    Color bg;
    Color fg;
    String label;

    switch (r) {
      case 'admin':
      case 'administrator':
        bg = AppColors.priorityP1Background;
        fg = AppColors.priorityP1;
        label = 'Administrator';
        break;
      case 'manager':
        bg = AppColors.aiBackground;
        fg = AppColors.aiAccent;
        label = 'Manager';
        break;
      case 'lead':
      case 'team_lead':
        bg = AppColors.priorityP2Background;
        fg = AppColors.priorityP2;
        label = 'Team Lead';
        break;
      case 'operator':
      case 'level1':
      case 'level2':
        bg = AppColors.primaryContainer;
        fg = AppColors.primaryBlue;
        label = 'Operator';
        break;
      case 'requester':
      default:
        bg = AppColors.surfaceMuted;
        fg = AppColors.textSecondaryLight;
        label = 'Requester';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppDimensions.pillBorderRadius,
        border: Border.all(color: fg.withValues(alpha: 0.25), width: 1),
      ),
      child: Text(
        label,
        style: AppTypography.labelSm.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
