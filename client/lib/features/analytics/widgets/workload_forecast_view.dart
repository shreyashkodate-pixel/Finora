import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/dimensions.dart';
import '../../../shared/theme/typography.dart';
import '../models/analytics_model.dart';
import '../providers/predictive_analytics_provider.dart';

/// Workload Forecast tab presenting projected volume, confidence bounds,
/// priority/category breakdowns, and staffing sizing recommendations.
class WorkloadForecastView extends StatelessWidget {
  const WorkloadForecastView({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<PredictiveAnalyticsProvider>();

    if (prov.isLoadingWorkload && prov.workloadForecast == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppDimensions.spaceXl),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (prov.isForbiddenWorkload) {
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
                'Workload forecasting is restricted to Team Leads, Managers, and Administrators.',
                style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondaryLight),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (prov.workloadError != null && prov.workloadForecast == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.priorityP1),
              const SizedBox(height: AppDimensions.spaceMd),
              Text(
                'Unable to Load Workload Forecast',
                style: AppTypography.headlineSm,
              ),
              const SizedBox(height: AppDimensions.spaceSm),
              Text(
                prov.workloadError!,
                style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondaryLight),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spaceLg),
              FilledButton.icon(
                onPressed: () => prov.fetchWorkloadForecast(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final forecast = prov.workloadForecast;
    if (forecast == null) {
      return const Center(child: Text('No forecast data available.'));
    }

    final lower = forecast.confidenceInterval['lower_bound'] ?? forecast.predictedTotalCases;
    final upper = forecast.confidenceInterval['upper_bound'] ?? forecast.predictedTotalCases;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Horizon Selector Header (Responsive Wrap)
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
                    'Workload Demand Projection',
                    style: AppTypography.headlineSm,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Statistical arrival modeling across selected forecast horizon',
                    style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                  ),
                ],
              ),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 7, label: Text('7 Days')),
                  ButtonSegment(value: 14, label: Text('14 Days')),
                  ButtonSegment(value: 30, label: Text('30 Days')),
                ],
                selected: {prov.selectedHorizon},
                onSelectionChanged: (set) {
                  if (set.isNotEmpty) {
                    prov.setHorizon(set.first);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceLg),

          // KPI Summary Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              final cards = [
                _buildSummaryCard(
                  title: 'Projected Inflow',
                  value: '~${forecast.predictedTotalCases} Cases',
                  subtext: '95% Confidence: $lower – $upper cases',
                  icon: Icons.auto_graph,
                  color: AppColors.primaryBlue,
                ),
                _buildSummaryCard(
                  title: 'High Priority (P1/P2)',
                  value: '${forecast.predictedP1Cases + forecast.predictedP2Cases} Cases',
                  subtext: '${forecast.predictedP1Cases} P1 Critical • ${forecast.predictedP2Cases} P2 Major',
                  icon: Icons.warning_amber_rounded,
                  color: AppColors.priorityP1,
                ),
                _buildSummaryCard(
                  title: 'Standard Volume (P3/P4)',
                  value: '${forecast.predictedP3P4Cases} Cases',
                  subtext: 'Routine operational tickets',
                  icon: Icons.checklist_rtl_rounded,
                  color: AppColors.slaHealthy,
                ),
              ];

              if (isWide) {
                return Row(
                  children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c))).toList(),
                );
              }
              return Column(
                children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c)).toList(),
              );
            },
          ),
          const SizedBox(height: AppDimensions.spaceLg),

          // Staffing Recommendation Banner
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
              side: const BorderSide(color: AppColors.primaryBlue, width: 1.2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spaceMd),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.psychology_outlined, color: AppColors.primaryBlue, size: 28),
                  const SizedBox(width: AppDimensions.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Authoritative Staffing Advisory',
                          style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          forecast.recommendation,
                          style: AppTypography.bodyMd,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spaceXl),

          // Breakdown: Priority Distribution & Category Breakdown
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              final priorityCard = _buildPriorityDistributionCard(context, forecast);
              final categoryCard = _buildCategoryDistributionCard(context, forecast);

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: priorityCard),
                    const SizedBox(width: AppDimensions.spaceLg),
                    Expanded(child: categoryCard),
                  ],
                );
              }
              return Column(
                children: [
                  priorityCard,
                  const SizedBox(height: AppDimensions.spaceLg),
                  categoryCard,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              subtext,
              style: AppTypography.labelSm.copyWith(color: AppColors.textSecondaryLight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityDistributionCard(BuildContext context, WorkloadForecastResponse forecast) {
    final total = forecast.predictedTotalCases > 0 ? forecast.predictedTotalCases : 1;
    final p1Pct = (forecast.predictedP1Cases / total).clamp(0.0, 1.0);
    final p2Pct = (forecast.predictedP2Cases / total).clamp(0.0, 1.0);
    final p3p4Pct = (forecast.predictedP3P4Cases / total).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pie_chart_outline, size: 20, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Text('Priority Distribution', style: AppTypography.headlineSm.copyWith(fontSize: 16)),
              ],
            ),
            const SizedBox(height: AppDimensions.spaceLg),
            _buildProgressBarItem(
              label: 'P1 Critical',
              count: forecast.predictedP1Cases,
              pct: p1Pct,
              color: AppColors.priorityP1,
            ),
            const SizedBox(height: 12),
            _buildProgressBarItem(
              label: 'P2 High',
              count: forecast.predictedP2Cases,
              pct: p2Pct,
              color: AppColors.priorityP2,
            ),
            const SizedBox(height: 12),
            _buildProgressBarItem(
              label: 'P3/P4 Normal & Low',
              count: forecast.predictedP3P4Cases,
              pct: p3p4Pct,
              color: AppColors.slaHealthy,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDistributionCard(BuildContext context, WorkloadForecastResponse forecast) {
    final total = forecast.predictedTotalCases > 0 ? forecast.predictedTotalCases : 1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.category_outlined, size: 20, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Text('Category Breakdown', style: AppTypography.headlineSm.copyWith(fontSize: 16)),
              ],
            ),
            const SizedBox(height: AppDimensions.spaceLg),
            if (forecast.categoryBreakdown.isEmpty)
              const Text('No category breakdown available.')
            else
              ...forecast.categoryBreakdown.entries.map((entry) {
                final pct = (entry.value / total).clamp(0.0, 1.0);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildProgressBarItem(
                    label: entry.key,
                    count: entry.value,
                    pct: pct,
                    color: AppColors.primaryBlue,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBarItem({
    required String label,
    required int count,
    required double pct,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTypography.bodySm),
            Text(
              '$count cases (${(pct * 100).toStringAsFixed(0)}%)',
              style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
