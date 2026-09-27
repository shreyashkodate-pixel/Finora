import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/dimensions.dart';
import '../theme/typography.dart';

class FilterOption {
  final String key;
  final String label;
  final int? count;

  const FilterOption({
    required this.key,
    required this.label,
    this.count,
  });
}

/// Horizontal Filter Bar with selectable chips
class FilterBar extends StatelessWidget {
  final List<FilterOption> options;
  final String selectedKey;
  final ValueChanged<String> onSelected;

  const FilterBar({
    super.key,
    required this.options,
    required this.selectedKey,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((opt) {
          final isSelected = opt.key == selectedKey;
          return Padding(
            padding: const EdgeInsets.only(right: AppDimensions.spaceSm),
            child: FilterChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(opt.label),
                  if (opt.count != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.25)
                            : AppColors.borderLight,
                        borderRadius: AppDimensions.pillBorderRadius,
                      ),
                      child: Text(
                        '${opt.count}',
                        style: AppTypography.labelSm.copyWith(
                          fontSize: 10,
                          color: isSelected ? Colors.white : AppColors.textSecondaryLight,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              labelStyle: AppTypography.labelMd.copyWith(
                color: isSelected ? Colors.white : AppColors.textPrimaryLight,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              backgroundColor: Colors.white,
              selectedColor: AppColors.primaryBlue,
              checkmarkColor: Colors.white,
              showCheckmark: false,
              side: BorderSide(
                color: isSelected ? AppColors.primaryBlue : AppColors.borderLight,
                width: 1,
              ),
              shape: RoundedRectangleBorder(borderRadius: AppDimensions.buttonBorderRadius),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              onSelected: (_) => onSelected(opt.key),
            ),
          );
        }).toList(),
      ),
    );
  }
}
