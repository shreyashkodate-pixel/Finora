import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/dimensions.dart';
import '../theme/typography.dart';
import 'custom_buttons.dart';

/// Standard Loading State with accessible label and optional skeleton
class LoadingState extends StatelessWidget {
  final String message;

  const LoadingState({
    super.key,
    this.message = 'Loading data...',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: AppDimensions.spaceMd),
            Text(
              message,
              style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondaryLight),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Standard Error State with human-readable message and Retry action
class ErrorState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  const ErrorState({
    super.key,
    this.title = 'Unable to load content',
    required this.message,
    this.onRetry,
    this.retryLabel = 'Try Again',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(AppDimensions.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppDimensions.spaceMd),
              decoration: BoxDecoration(
                color: AppColors.priorityP1Background,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 36,
                color: AppColors.priorityP1,
              ),
            ),
            const SizedBox(height: AppDimensions.spaceMd),
            Text(
              title,
              style: AppTypography.headlineSm,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spaceSm),
            Text(
              message,
              style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondaryLight),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppDimensions.spaceLg),
              PrimaryButton(
                label: retryLabel,
                icon: Icons.refresh_rounded,
                onPressed: onRetry!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Standard Empty State with explanation and contextual action button
class EmptyState extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.title,
    this.description = 'No records found.',
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(AppDimensions.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppDimensions.spaceMd),
              decoration: const BoxDecoration(
                color: AppColors.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 36,
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: AppDimensions.spaceMd),
            Text(
              title,
              style: AppTypography.headlineSm,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spaceSm),
            Text(
              description,
              style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondaryLight),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppDimensions.spaceLg),
              PrimaryButton(
                label: actionLabel!,
                onPressed: onAction!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Standard Unauthorized State for restricted RBAC routes
class UnauthorizedState extends StatelessWidget {
  final String message;

  const UnauthorizedState({
    super.key,
    this.message = 'You do not have administrative permission to view this section.',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(AppDimensions.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppDimensions.spaceMd),
              decoration: BoxDecoration(
                color: AppColors.priorityP2Background,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                size: 36,
                color: AppColors.priorityP2,
              ),
            ),
            const SizedBox(height: AppDimensions.spaceMd),
            const Text(
              'Access Restricted',
              style: AppTypography.headlineSm,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spaceSm),
            Text(
              message,
              style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondaryLight),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Non-intrusive Offline Banner State
class OfflineBanner extends StatelessWidget {
  final VoidCallback? onReconnect;

  const OfflineBanner({
    super.key,
    this.onReconnect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.statusWarning.withValues(alpha: 0.15),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 18, color: AppColors.statusWarning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Operating in offline cached mode. Read-only records displayed.',
              style: AppTypography.bodySm.copyWith(color: AppColors.textPrimaryLight, fontWeight: FontWeight.w500),
            ),
          ),
          if (onReconnect != null)
            TextButton(
              onPressed: onReconnect,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(48, 32),
              ),
              child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}
