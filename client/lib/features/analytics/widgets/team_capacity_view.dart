import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/dimensions.dart';
import '../../../shared/theme/typography.dart';
import '../models/analytics_model.dart';
import '../providers/predictive_analytics_provider.dart';

/// Team Capacity & Burnout Risk tab presenting operator loads, queue depths,
/// capacity utilization percentages, and daily throughput velocity.
class TeamCapacityView extends StatelessWidget {
  const TeamCapacityView({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<PredictiveAnalyticsProvider>();

    if (prov.isLoadingCapacity && prov.teamCapacity == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppDimensions.spaceXl),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (prov.isForbiddenCapacity) {
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
                'Team capacity and burnout metrics are restricted to Team Leads, Managers, and Administrators.',
                style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondaryLight),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (prov.capacityError != null && prov.teamCapacity == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.priorityP1),
              const SizedBox(height: AppDimensions.spaceMd),
              Text(
                'Unable to Load Team Capacity',
                style: AppTypography.headlineSm,
              ),
              const SizedBox(height: AppDimensions.spaceSm),
              Text(
                prov.capacityError!,
                style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondaryLight),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spaceLg),
              FilledButton.icon(
                onPressed: () => prov.fetchTeamCapacity(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final cap = prov.teamCapacity;
    if (cap == null || cap.teams.isEmpty) {
      return Card(
        margin: const EdgeInsets.all(AppDimensions.spaceLg),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          child: Center(
            child: Column(
              children: [
                const Icon(Icons.group_off_outlined, size: 48, color: AppColors.textSecondaryLight),
                const SizedBox(height: AppDimensions.spaceMd),
                Text(
                  'No Teams Configured',
                  style: AppTypography.headlineSm.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  'No active operational teams found in the current organization.',
                  style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final criticalTeams = cap.teams.where((t) => t.burnoutRisk.toLowerCase() == 'critical').length;
    final highTeams = cap.teams.where((t) => t.burnoutRisk.toLowerCase() == 'high').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (Responsive Wrap)
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
                    'Team Capacity & Utilization Overview',
                    style: AppTypography.headlineSm,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Real-time staffing load, queue depth, and burnout velocity indexing',
                    style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                  ),
                ],
              ),
              FilledButton.tonalIcon(
                onPressed: () => prov.fetchTeamCapacity(),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceLg),

          // Overview KPI Card
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spaceLg),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Overall Capacity Utilization',
                          style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${cap.overallUtilizationPct.toStringAsFixed(1)}%',
                          style: AppTypography.headlineSm.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: cap.overallUtilizationPct > 90 ? AppColors.priorityP1 : AppColors.slaHealthy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Across ${cap.totalTeams} operational squads',
                          style: AppTypography.labelSm.copyWith(color: AppColors.textSecondaryLight),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 50,
                    color: Theme.of(context).dividerColor,
                  ),
                  const SizedBox(width: AppDimensions.spaceLg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Squad Health Status',
                          style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          criticalTeams > 0
                              ? '$criticalTeams Critical Overload'
                              : highTeams > 0
                                  ? '$highTeams High Load'
                                  : 'All Squads Balanced',
                          style: AppTypography.headlineSm.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: criticalTeams > 0
                                ? AppColors.priorityP1
                                : highTeams > 0
                                    ? AppColors.priorityP2
                                    : AppColors.slaHealthy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Standard threshold: 5 open cases/operator',
                          style: AppTypography.labelSm.copyWith(color: AppColors.textSecondaryLight),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spaceLg),

          // Team Grid / List
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              if (isWide) {
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    mainAxisExtent: 220,
                  ),
                  itemCount: cap.teams.length,
                  itemBuilder: (context, index) {
                    return _buildTeamCard(context, cap.teams[index]);
                  },
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cap.teams.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _buildTeamCard(context, cap.teams[index]);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTeamCard(BuildContext context, TeamCapacityMetricItem team) {
    final utilNormalized = (team.capacityUtilizationPct / 100.0).clamp(0.0, 1.0);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        side: BorderSide(color: team.burnoutColor.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Row 1: Team Name & Burnout Status Pill (Responsive Wrap)
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  team.teamName,
                  style: AppTypography.headlineSm.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: team.burnoutColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                    border: Border.all(color: team.burnoutColor, width: 1),
                  ),
                  child: Text(
                    '${team.burnoutRisk.toUpperCase()} LOAD',
                    style: AppTypography.labelSm.copyWith(
                      color: team.burnoutColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Row 2: Operator Count, Open Cases, Caseload Ratio
            Row(
              children: [
                _buildStatColumn('Active Staff', '${team.activeOperators} ops'),
                _buildStatColumn('Open Queue', '${team.openCases} tickets'),
                _buildStatColumn('Load Ratio', '${team.avgCasesPerOperator.toStringAsFixed(1)} / op'),
              ],
            ),
            const SizedBox(height: 8),

            // Row 3: Utilization Progress Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Capacity Utilization',
                      style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                    ),
                    Text(
                      '${team.capacityUtilizationPct.toStringAsFixed(1)}%',
                      style: AppTypography.bodySm.copyWith(
                        fontWeight: FontWeight.bold,
                        color: team.burnoutColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: utilNormalized,
                    minHeight: 8,
                    backgroundColor: team.burnoutColor.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(team.burnoutColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Row 4: Daily Closure Velocity
            Row(
              children: [
                const Icon(Icons.speed, size: 14, color: AppColors.textSecondaryLight),
                const SizedBox(width: 4),
                Text(
                  'Daily Throughput Velocity: ~${team.estimatedClosureVelocityPerDay.toStringAsFixed(1)} cases/day',
                  style: AppTypography.labelSm.copyWith(color: AppColors.textSecondaryLight, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.labelSm.copyWith(color: AppColors.textSecondaryLight)),
          const SizedBox(height: 2),
          Text(value, style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
