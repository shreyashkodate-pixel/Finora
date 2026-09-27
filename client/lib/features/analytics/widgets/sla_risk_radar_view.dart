import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/dimensions.dart';
import '../../../shared/theme/typography.dart';
import '../../../shared/widgets/priority_badge.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../cases/screens/case_detail_screen.dart';
import '../models/analytics_model.dart';
import '../providers/predictive_analytics_provider.dart';

/// SLA Risk Radar view presenting tickets with statistically high likelihood
/// of SLA breach, highlighting risk scores, time to breach, and causal drivers.
class SlaRiskRadarView extends StatelessWidget {
  const SlaRiskRadarView({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<PredictiveAnalyticsProvider>();

    if (prov.isLoadingRisk && prov.riskForecast == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppDimensions.spaceXl),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (prov.isForbiddenRisk) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48, color: AppColors.textSecondaryLight),
              const SizedBox(height: AppDimensions.spaceMd),
              Text(
                'Access Restricted',
                style: AppTypography.headlineSm,
              ),
              const SizedBox(height: AppDimensions.spaceSm),
              Text(
                'You do not have permission to access SLA risk forecasts.',
                style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondaryLight),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (prov.riskError != null && prov.riskForecast == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.priorityP1),
              const SizedBox(height: AppDimensions.spaceMd),
              Text(
                'Unable to Load SLA Risk Radar',
                style: AppTypography.headlineSm,
              ),
              const SizedBox(height: AppDimensions.spaceSm),
              Text(
                prov.riskError!,
                style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondaryLight),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spaceLg),
              FilledButton.icon(
                onPressed: () => prov.fetchRiskForecast(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final riskResponse = prov.riskForecast;
    final cases = prov.filteredRiskCases;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Risk Filter Bar (Responsive Wrap)
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SLA Risk Radar',
                    style: AppTypography.headlineSm,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Active cases prioritized by statistical breach risk score',
                    style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildFilterChip(context, prov, 'all', 'All (${riskResponse?.totalAtRiskCases ?? 0})'),
                  _buildFilterChip(context, prov, 'critical', 'Critical (≥0.80)'),
                  _buildFilterChip(context, prov, 'high', 'High (≥0.60)'),
                  _buildFilterChip(context, prov, 'moderate', 'Moderate (≥0.40)'),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceLg),

          // Operational Advisory Banner
          if (riskResponse != null && riskResponse.aiSummary.isNotEmpty)
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                side: BorderSide(
                  color: cases.isNotEmpty ? AppColors.priorityP1.withValues(alpha: 0.6) : AppColors.slaHealthy,
                  width: 1.2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spaceMd),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      cases.isNotEmpty ? Icons.radar_rounded : Icons.check_circle_outline_rounded,
                      color: cases.isNotEmpty ? AppColors.priorityP1 : AppColors.slaHealthy,
                      size: 26,
                    ),
                    const SizedBox(width: AppDimensions.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Operational SLA Assessment',
                            style: AppTypography.labelMd.copyWith(
                              fontWeight: FontWeight.bold,
                              color: cases.isNotEmpty ? AppColors.priorityP1 : AppColors.slaHealthy,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            riskResponse.aiSummary,
                            style: AppTypography.bodyMd,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppDimensions.spaceLg),

          // List of At-Risk Tickets
          if (cases.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.task_alt_rounded, size: 48, color: AppColors.slaHealthy),
                      const SizedBox(height: AppDimensions.spaceMd),
                      Text(
                        'No Cases At Risk',
                        style: AppTypography.headlineSm.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'All active tickets in the current filter are tracking comfortably within SLA thresholds.',
                        style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cases.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = cases[index];
                return _buildRiskCard(context, item);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    PredictiveAnalyticsProvider prov,
    String filterValue,
    String label,
  ) {
    final isSelected = prov.selectedRiskFilter == filterValue;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => prov.setRiskFilter(filterValue),
    );
  }

  Widget _buildRiskCard(BuildContext context, PredictiveRiskItem item) {
    final breachHours = (item.timeToBreachMinutes / 60).toStringAsFixed(1);
    final timeStr = item.timeToBreachMinutes <= 60
        ? '${item.timeToBreachMinutes} mins remaining'
        : '$breachHours hrs remaining';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        side: BorderSide(color: item.riskColor.withValues(alpha: 0.5), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Ref, Priority, Status, and Risk Score Badge (Responsive Wrap)
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.referenceNumber,
                      style: AppTypography.codeMd.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    PriorityBadge(priority: item.priority),
                    const SizedBox(width: 8),
                    StatusBadge(status: item.currentStatus),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.riskColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                    border: Border.all(color: item.riskColor, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 14, color: item.riskColor),
                      const SizedBox(width: 4),
                      Text(
                        'Risk Score: ${(item.riskScore).toStringAsFixed(2)} (${item.riskLevel.toUpperCase()})',
                        style: AppTypography.labelSm.copyWith(
                          color: item.riskColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Title
            Text(
              item.title,
              style: AppTypography.headlineSm.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),

            // Time to breach and Risk Drivers
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.timer_outlined, size: 16, color: AppColors.textSecondaryLight),
                const SizedBox(width: 6),
                Text(
                  'Estimated Time to Breach: ',
                  style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                ),
                Text(
                  timeStr,
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.bold,
                    color: item.timeToBreachMinutes <= 60 ? AppColors.priorityP1 : AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Risk Drivers Tags
            if (item.riskDrivers.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: item.riskDrivers.map((driver) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '• $driver',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.textSecondaryLight,
                        fontSize: 11,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Action: View Ticket
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CaseDetailScreen(caseId: item.caseId),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('Investigate Ticket'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
