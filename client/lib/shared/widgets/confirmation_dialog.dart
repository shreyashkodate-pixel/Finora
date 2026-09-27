import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'custom_buttons.dart';

/// Reusable Confirmation Dialog for Consequential Actions
class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.isDestructive = false,
    required this.onConfirm,
    this.onCancel,
  });

  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmationDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
        onConfirm: () => Navigator.of(ctx).pop(true),
        onCancel: () => Navigator.of(ctx).pop(false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        title,
        style: AppTypography.headlineSm.copyWith(
          color: isDestructive ? AppColors.priorityP1 : AppColors.textPrimaryLight,
        ),
      ),
      content: Text(
        message,
        style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondaryLight),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        SecondaryButton(
          label: cancelLabel,
          onPressed: () {
            if (onCancel != null) {
              onCancel!();
            } else {
              Navigator.of(context).pop(false);
            }
          },
        ),
        const SizedBox(width: 8),
        if (isDestructive)
          DangerButton(
            label: confirmLabel,
            onPressed: onConfirm,
          )
        else
          PrimaryButton(
            label: confirmLabel,
            onPressed: onConfirm,
          ),
      ],
    );
  }
}
