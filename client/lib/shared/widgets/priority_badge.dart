import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/dimensions.dart';
import '../theme/typography.dart';

/// Priority Badge with WCAG 2.1 AA Contrast Ratios.
/// - P1: Critical (Red)
/// - P2: High (Amber/Orange)
/// - P3: Normal (Blue)
/// - P4: Low (Slate)
class PriorityBadge extends StatelessWidget {
  final String priority;

  const PriorityBadge({
    super.key,
    required this.priority,
  });

  @override
  Widget build(BuildContext context) {
    final p = priority.toUpperCase().trim();
    Color bg;
    Color fg;
    Color border;
    String label;

    switch (p) {
      case 'P1':
      case 'CRITICAL':
        bg = AppColors.priorityP1Background;
        fg = AppColors.priorityP1;
        border = AppColors.priorityP1Border;
        label = 'P1 Critical';
        break;
      case 'P2':
      case 'HIGH':
        bg = AppColors.priorityP2Background;
        fg = AppColors.priorityP2;
        border = AppColors.priorityP2Border;
        label = 'P2 High';
        break;
      case 'P3':
      case 'MEDIUM':
      case 'NORMAL':
        bg = AppColors.priorityP3Background;
        fg = AppColors.priorityP3;
        border = AppColors.priorityP3Border;
        label = 'P3 Normal';
        break;
      case 'P4':
      case 'LOW':
      default:
        bg = AppColors.priorityP4Background;
        fg = AppColors.priorityP4;
        border = AppColors.priorityP4Border;
        label = 'P4 Low';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppDimensions.priorityBorderRadius,
        border: Border.all(color: border, width: 1),
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
