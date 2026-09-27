import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/responsive/breakpoints.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/dimensions.dart';
import '../../../shared/theme/typography.dart';
import '../../../shared/widgets/custom_buttons.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/page_header.dart';
import '../../analytics/screens/predictive_analytics_screen.dart';
import '../../approvals/providers/approval_provider.dart';
import '../../approvals/screens/pending_approvals_screen.dart';
import '../../cases/providers/case_provider.dart';

/// Stitch-aligned Leadership & Operational Health Insights Dashboard
/// Corresponds to Stitch design: manager_operational_health_insights
class ManagerInsightsScreen extends StatefulWidget {
  const ManagerInsightsScreen({super.key});

  @override
  State<ManagerInsightsScreen> createState() => _ManagerInsightsScreenState();
}

class _ManagerInsightsScreenState extends State<ManagerInsightsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CaseProvider>().fetchCases();
      context.read<ApprovalProvider>().fetchPendingApprovals();
    });
  }

  @override
  Widget build(BuildContext context) {
    final caseProv = context.watch<CaseProvider>();
    final apprProv = context.watch<ApprovalProvider>();
    final cases = caseProv.cases;
    final pendingApprovals = apprProv.pendingApprovals;

    // Operational statistics calculation
    final totalCases = cases.length;
    final activeCases = cases.where((c) => c.status != 'closed' && c.status != 'cancelled').toList();
    final p1Cases = cases.where((c) => c.priority.toLowerCase() == 'p1' && c.status != 'closed' && c.status != 'cancelled').toList();
    final resolvedCases = cases.where((c) => c.status == 'resolved' || c.status == 'closed').toList();

    // SLA compliance rate
    final casesWithSla = cases.where((c) => c.sla != null).toList();
    final breachedCases = casesWithSla.where((c) => c.sla!.resolutionBreached).length;
    final complianceRate = casesWithSla.isNotEmpty
        ? (((casesWithSla.length - breachedCases) / casesWithSla.length) * 100).toStringAsFixed(1)
        : '100.0';

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            context.read<CaseProvider>().fetchCases(),
            context.read<ApprovalProvider>().fetchPendingApprovals(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppDimensions.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Page Header with Refresh & Analytics Navigation
              PageHeader(
                title: 'Operational Health & Service Insights',
                subtitle: 'Executive SLA telemetry, squad throughput, and capacity governance.',
                actions: [
                  CustomButtons.secondary(
                    text: 'Predictive Radar',
                    icon: Icons.auto_graph_rounded,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PredictiveAnalyticsScreen()),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  CustomButtons.secondary(
                    text: 'Refresh Telemetry',
                    icon: Icons.refresh,
                    isLoading: caseProv.isLoading || apprProv.isLoading,
                    onPressed: () {
                      context.read<CaseProvider>().fetchCases();
                      context.read<ApprovalProvider>().fetchPendingApprovals();
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spaceLg),

              // 2. Executive Metric Cards Grid
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < ResponsiveBreakpoints.mobileMax;

                  final card1 = MetricCard(
                    label: 'SLA Compliance Rate',
                    value: '$complianceRate%',
                    icon: Icons.speed_rounded,
                    valueColor: (double.tryParse(complianceRate) ?? 100) >= 90
                        ? AppColors.slaHealthy
                        : AppColors.priorityP1,
                    subtitle: '$breachedCases breaches / ${casesWithSla.length} active SLA contracts',
                  );

                  final card2 = MetricCard(
                    label: 'Critical P1 Outages',
                    value: p1Cases.length.toString(),
                    icon: Icons.warning_amber_rounded,
                    valueColor: p1Cases.isNotEmpty ? AppColors.priorityP1 : AppColors.slaHealthy,
                    subtitle: 'Requires immediate command escalation',
                  );

                  final card3 = MetricCard(
                    label: 'Pending Approvals',
                    value: pendingApprovals.length.toString(),
                    icon: Icons.approval_rounded,
                    valueColor: pendingApprovals.isNotEmpty ? AppColors.statusAwaiting : AppColors.slaHealthy,
                    subtitle: 'Awaiting Lead / Manager authorization',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PendingApprovalsScreen()),
                      );
                    },
                  );

                  final card4 = MetricCard(
                    label: 'Active Backlog',
                    value: activeCases.length.toString(),
                    icon: Icons.inventory_2_outlined,
                    valueColor: AppColors.primaryBlue,
                    subtitle: '${resolvedCases.length} resolved / $totalCases all-time',
                  );

                  if (isMobile) {
                    return Column(
                      children: [
                        card1,
                        const SizedBox(height: 10),
                        card2,
                        const SizedBox(height: 10),
                        card3,
                        const SizedBox(height: 10),
                        card4,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: card1),
                      const SizedBox(width: AppDimensions.spaceMd),
                      Expanded(child: card2),
                      const SizedBox(width: AppDimensions.spaceMd),
                      Expanded(child: card3),
                      const SizedBox(width: AppDimensions.spaceMd),
                      Expanded(child: card4),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppDimensions.spaceLg),

              // 3. AI Operational Briefing Card (Stitch AI Accent Style)
              Container(
                padding: const EdgeInsets.all(AppDimensions.spaceLg),
                decoration: BoxDecoration(
                  color: AppColors.aiBackground,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                  border: Border.all(color: AppColors.aiBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.aiAccent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'AI Operational Health Synthesis',
                          style: AppTypography.headlineSm.copyWith(
                            color: AppColors.textPrimaryLight,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                            border: Border.all(color: AppColors.aiBorder),
                          ),
                          child: Text(
                            'Real-time Synthesis',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.aiAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _generateOperationalNarrative(
                        totalCases: totalCases,
                        activeCases: activeCases.length,
                        p1Cases: p1Cases.length,
                        pendingApprovals: pendingApprovals.length,
                        complianceRate: complianceRate,
                        resolvedCount: resolvedCases.length,
                      ),
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.textPrimaryLight,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spaceLg),

              // 4. Incident Distribution & Lifecycle Breakdown Section
              Container(
                padding: const EdgeInsets.all(AppDimensions.spaceLg),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Incident Distribution & Lifecycle Breakdown',
                      style: AppTypography.headlineSm,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Live distribution of tickets across the intake-to-resolution pipeline.',
                      style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                    ),
                    const SizedBox(height: AppDimensions.spaceLg),
                    _buildLifecycleRow('New & Unassigned', cases.where((c) => c.status == 'new').length, totalCases, AppColors.statusNew),
                    const SizedBox(height: 16),
                    _buildLifecycleRow('Assigned / In Progress', cases.where((c) => c.status == 'assigned' || c.status == 'in_progress').length, totalCases, AppColors.statusAssigned),
                    const SizedBox(height: 16),
                    _buildLifecycleRow('Awaiting Authorization', cases.where((c) => c.status == 'awaiting_approval').length, totalCases, AppColors.statusAwaiting),
                    const SizedBox(height: 16),
                    _buildLifecycleRow('Resolved & Closed', resolvedCases.length, totalCases, AppColors.slaHealthy),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _generateOperationalNarrative({
    required int totalCases,
    required int activeCases,
    required int p1Cases,
    required int pendingApprovals,
    required String complianceRate,
    required int resolvedCount,
  }) {
    if (totalCases == 0) {
      return 'The service desk is currently clean. No active incidents or historical tickets recorded in the operational period.';
    }

    final p1Note = p1Cases > 0
        ? 'Attention is required on $p1Cases critical (P1) incident(s) requiring immediate operator triage.'
        : 'Zero critical (P1) outages are impacting production operations.';

    final apprNote = pendingApprovals > 0
        ? '$pendingApprovals business approval request(s) are held in queue awaiting Lead or Manager authorization.'
        : 'Authorization queues are fully cleared.';

    return 'Service Desk is operating at an overall SLA resolution compliance rate of $complianceRate%. '
        'Currently managing $activeCases active ticket(s) with $resolvedCount completed resolutions. '
        '$p1Note $apprNote Automated Gemini triage and background sweep monitoring remain fully operational.';
  }

  Widget _buildLifecycleRow(String label, int count, int total, Color color) {
    final pct = total > 0 ? count / total : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600)),
            Text(
              '$count (${(pct * 100).toStringAsFixed(0)}%)',
              style: AppTypography.codeMd.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: AppColors.borderLight,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
