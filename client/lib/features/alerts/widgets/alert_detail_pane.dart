import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/dimensions.dart';
import '../../../shared/theme/typography.dart';
import '../../../shared/widgets/custom_buttons.dart';
import '../../cases/screens/case_detail_screen.dart';
import '../models/alert_model.dart';
import '../providers/alert_provider.dart';

/// Detailed inspection pane for an Inbound Monitoring Alert
class AlertDetailPane extends StatelessWidget {
  final InboundAlertModel alert;
  final VoidCallback? onClose;

  const AlertDetailPane({
    super.key,
    required this.alert,
    this.onClose,
  });

  void _navigateToCase(BuildContext context, String caseId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CaseDetailScreen(caseId: caseId),
      ),
    );
  }

  Future<void> _acknowledge(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Acknowledge Inbound Alert'),
        content: Text('Are you sure you want to acknowledge "${alert.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Acknowledge'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final provider = context.read<AlertProvider>();
      final success = await provider.acknowledgeAlert(alert.id);
      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Alert acknowledged successfully.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(provider.errorMessage ?? 'Failed to acknowledge alert.'),
              backgroundColor: AppColors.priorityP1,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = alert.provider;
    final sevEnum = AlertSeverityExtension.fromApiValue(alert.severity);
    final status = alert.status;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Provider Badge + Close Button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: provider.brandColor.withValues(alpha: 0.12),
                  borderRadius: AppDimensions.priorityBorderRadius,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(provider.icon, size: 16, color: provider.brandColor),
                    const SizedBox(width: 6),
                    Text(
                      provider.displayName,
                      style: AppTypography.labelMd.copyWith(
                        color: provider.brandColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (onClose != null)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: onClose,
                  tooltip: 'Close details',
                ),
            ],
          ),

          const SizedBox(height: AppDimensions.spaceMd),

          // Title
          Text(
            alert.title,
            style: AppTypography.headlineMd.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: AppDimensions.spaceSm),

          // Status & Severity Chips Row
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              // Severity Tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: sevEnum.color.withValues(alpha: 0.15),
                  borderRadius: AppDimensions.priorityBorderRadius,
                ),
                child: Text(
                  'SEVERITY: ${alert.severity.toUpperCase()}',
                  style: AppTypography.labelSm.copyWith(
                    color: sevEnum.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: 0.12),
                  borderRadius: AppDimensions.pillBorderRadius,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(status.icon, size: 13, color: status.color),
                    const SizedBox(width: 4),
                    Text(
                      status.displayName,
                      style: AppTypography.labelSm.copyWith(
                        color: status.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.spaceLg),

          // Primary Actions Card
          Container(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              borderRadius: AppDimensions.cardBorderRadius,
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Operational Actions',
                  style: AppTypography.headlineSm.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceSm),

                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    if (!alert.isAcknowledged)
                      Consumer<AlertProvider>(
                        builder: (ctx, alertProv, _) {
                          return PrimaryButton(
                            label: 'Acknowledge Alert',
                            icon: Icons.check_circle_outline_rounded,
                            isLoading: alertProv.isAcknowledging,
                            onPressed: () => _acknowledge(context),
                          );
                        },
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.statusAssigned.withValues(alpha: 0.15),
                          borderRadius: AppDimensions.priorityBorderRadius,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_rounded, size: 16, color: AppColors.statusAssigned),
                            const SizedBox(width: 6),
                            Text(
                              'Acknowledged ${alert.acknowledgedAt != null ? "at ${alert.acknowledgedAt!.hour.toString().padLeft(2, '0')}:${alert.acknowledgedAt!.minute.toString().padLeft(2, '0')}" : ""}',
                              style: AppTypography.bodySm.copyWith(
                                color: AppColors.statusAssigned,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (alert.hasLinkedCase)
                      SecondaryButton(
                        label: 'Open Linked Incident',
                        icon: Icons.confirmation_number_outlined,
                        onPressed: () => _navigateToCase(context, alert.caseId!),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppDimensions.spaceLg),

          // Alert Description Section
          Text(
            'Description & Summary',
            style: AppTypography.headlineSm.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimensions.spaceXs),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: AppDimensions.cardBorderRadius,
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Text(
              alert.description?.isNotEmpty == true
                  ? alert.description!
                  : 'No detailed description provided with this inbound alert payload.',
              style: AppTypography.bodyMd.copyWith(
                height: 1.5,
              ),
            ),
          ),

          const SizedBox(height: AppDimensions.spaceLg),

          // Metadata Grid
          Text(
            'Telemetry & Ingestion Metadata',
            style: AppTypography.headlineSm.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimensions.spaceSm),

          _buildMetadataRow('External Alert ID', alert.externalAlertId ?? 'N/A'),
          _buildMetadataRow('Fingerprint Hash', alert.fingerprint),
          _buildMetadataRow('Ingested At', alert.createdAt.toIso8601String()),
          _buildMetadataRow('Last Updated', alert.updatedAt.toIso8601String()),
          if (alert.caseId != null)
            _buildMetadataRow('Linked Case UUID', alert.caseId!),
          if (alert.acknowledgedById != null)
            _buildMetadataRow('Acknowledged By UUID', alert.acknowledgedById!),

          const SizedBox(height: AppDimensions.spaceLg),

          // Raw JSON Payload Inspector
          Material(
            color: Colors.transparent,
            child: ExpansionTile(
              title: Text(
                'Raw Ingested Payload',
                style: AppTypography.headlineSm.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Exact payload stored at ingestion time', style: TextStyle(fontSize: 11)),
              leading: const Icon(Icons.data_object_rounded, size: 20),
              childrenPadding: const EdgeInsets.all(AppDimensions.spaceSm),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppDimensions.spaceMd),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: AppDimensions.priorityBorderRadius,
                  ),
                  child: SelectableText(
                    const JsonEncoder.withIndent('  ').convert(alert.rawPayload),
                    style: const TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 12,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.textSecondaryLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: AppTypography.bodySm.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
