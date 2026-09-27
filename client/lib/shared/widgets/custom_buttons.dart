import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/dimensions.dart';
import '../theme/typography.dart';

/// Primary Action Button (Deep Enterprise Blue)
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final btn = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.textSecondaryLight.withValues(alpha: 0.4),
        disabledForegroundColor: Colors.white,
        minimumSize: const Size(AppDimensions.minTouchTargetSize, AppDimensions.buttonHeight),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: AppDimensions.buttonBorderRadius),
        elevation: 0,
      ),
      child: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Row(
              mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: AppTypography.bodyMd.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: btn);
    }
    return btn;
  }
}

/// Secondary / Outlined Button
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;

  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final btn = OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimaryLight,
        backgroundColor: Colors.white,
        minimumSize: const Size(AppDimensions.minTouchTargetSize, AppDimensions.buttonHeight),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        side: const BorderSide(color: AppColors.borderLight, width: 1),
        shape: RoundedRectangleBorder(borderRadius: AppDimensions.buttonBorderRadius),
      ),
      child: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: AppColors.textSecondaryLight),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: AppTypography.bodyMd.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimaryLight,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: btn);
    }
    return btn;
  }
}

/// Danger / Destructive Action Button
class DangerButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  const DangerButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.priorityP1,
        foregroundColor: Colors.white,
        minimumSize: const Size(AppDimensions.minTouchTargetSize, AppDimensions.buttonHeight),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: AppDimensions.buttonBorderRadius),
        elevation: 0,
      ),
      child: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: AppTypography.bodyMd.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );
  }
}

/// Namespace helper for consistent button invocation
class CustomButtons {
  static Widget primary({
    required String text,
    required VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    bool fullWidth = false,
  }) {
    return PrimaryButton(
      label: text,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      fullWidth: fullWidth,
    );
  }

  static Widget secondary({
    required String text,
    required VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    bool fullWidth = false,
  }) {
    return SecondaryButton(
      label: text,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      fullWidth: fullWidth,
    );
  }

  static Widget danger({
    required String text,
    required VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
  }) {
    return DangerButton(
      label: text,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
    );
  }
}
