import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/colors.dart';
import '../../approvals/providers/approval_provider.dart';
import '../../approvals/screens/pending_approvals_screen.dart';
import '../../cases/providers/case_provider.dart';

/// Operational & Leadership Insights dashboard per SRS §4 & §7.
/// Displays SLA compliance rates, high-priority incident volume,
/// pending business authorizations, and plain-language operational summaries.
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
      appBar: AppBar(
        title: const Text('Leadership & Service Insights'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<CaseProvider>().fetchCases();
              context.read<ApprovalProvider>().fetchPendingApprovals();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<CaseProvider>().fetchCases();
          await context.read<ApprovalProvider>().fetchPendingApprovals();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Executive KPI Grid
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      label: 'SLA Compliance',
                      value: '$complianceRate%',
                      subtext: '$breachedCases breached / ${casesWithSla.length} contracts',
                      color: double.tryParse(complianceRate) != null && double.parse(complianceRate) >= 90
                          ? AppColors.slaHealthy
                          : AppColors.priorityP1,
                      icon: Icons.speed,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'P1 Escalations',
                      value: p1Cases.length.toString(),
                      subtext: 'Critical priority tickets',
                      color: p1Cases.isNotEmpty ? AppColors.priorityP1 : AppColors.slaHealthy,
                      icon: Icons.warning_amber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Pending Approvals',
                      value: pendingApprovals.length.toString(),
                      subtext: 'Awaiting Lead/Manager sign-off',
                      color: pendingApprovals.isNotEmpty ? AppColors.statusAwaiting : AppColors.slaHealthy,
                      icon: Icons.approval,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PendingApprovalsScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Active Backlog',
                      value: activeCases.length.toString(),
                      subtext: 'Across all sites & teams',
                      color: AppColors.primaryBlue,
                      icon: Icons.inventory_2_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // AI Operational Synthesis Narrative Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.borderLight),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.auto_awesome, color: AppColors.primaryBlue, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'AI Operational Briefing',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Pending Approvals Action Banner
              if (pendingApprovals.isNotEmpty) ...[
                Card(
                  color: AppColors.statusAwaiting.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.statusAwaiting),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.statusAwaiting,
                      child: Icon(Icons.notification_important, color: Colors.white, size: 20),
                    ),
                    title: Text(
                      '${pendingApprovals.length} Authorization Requests Pending',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    subtitle: const Text('Review and decide on case tier escalations, role grants, and purchases.'),
                    trailing: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PendingApprovalsScreen()),
                        );
                      },
                      child: const Text('Review Inbox'),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Queue Health breakdown
              const Text(
                'Incident Distribution & Lifecycle Breakdown',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildLifecycleRow('New & Unassigned', cases.where((c) => c.status == 'new').length, totalCases, AppColors.statusNew),
                      const SizedBox(height: 12),
                      _buildLifecycleRow('Assigned / In Progress', cases.where((c) => c.status == 'assigned' || c.status == 'in_progress').length, totalCases, AppColors.statusAssigned),
                      const SizedBox(height: 12),
                      _buildLifecycleRow('Awaiting Authorization', cases.where((c) => c.status == 'awaiting_approval').length, totalCases, AppColors.statusAwaiting),
                      const SizedBox(height: 12),
                      _buildLifecycleRow('Resolved & Closed', resolvedCases.length, totalCases, AppColors.slaHealthy),
                    ],
                  ),
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

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String subtext,
    required Color color,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                  Icon(icon, color: color, size: 20),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 4),
              Text(
                subtext,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLifecycleRow(String label, int count, int total, Color color) {
    final pct = total > 0 ? count / total : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            Text('$count (${(pct * 100).toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: pct,
          backgroundColor: AppColors.borderLight,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }
}
