import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/sla_timer_widget.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cases/models/case_model.dart';
import '../../cases/providers/case_provider.dart';
import '../../cases/screens/case_detail_screen.dart';

/// Operational Workstation for IT Operators (L1, L2, Leads) per SRS §4 & §7.
class OperatorWorkspaceScreen extends StatefulWidget {
  const OperatorWorkspaceScreen({super.key});

  @override
  State<OperatorWorkspaceScreen> createState() => _OperatorWorkspaceScreenState();
}

class _OperatorWorkspaceScreenState extends State<OperatorWorkspaceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CaseProvider>().fetchCases();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final caseProv = context.watch<CaseProvider>();
    final auth = context.watch<AuthProvider>();
    final cases = caseProv.cases;
    final currentUserId = auth.currentUser?.id;

    // Categorized queues
    final unassignedCases = cases.where((c) => c.ownerId == null && c.status != 'closed' && c.status != 'cancelled').toList();
    final myAssignedCases = cases.where((c) => c.ownerId == currentUserId && c.status != 'closed' && c.status != 'cancelled').toList();
    final p1Cases = cases.where((c) => c.priority.toLowerCase() == 'p1' && c.status != 'closed' && c.status != 'cancelled').toList();
    final activeCases = cases.where((c) => c.status != 'closed' && c.status != 'cancelled').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Operator Workstation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<CaseProvider>().fetchCases(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: 'Unassigned (${unassignedCases.length})',
              icon: const Icon(Icons.assignment_late_outlined),
            ),
            Tab(
              text: 'Assigned to Me (${myAssignedCases.length})',
              icon: const Icon(Icons.person_pin_outlined),
            ),
            Tab(
              text: 'All Active (${activeCases.length})',
              icon: const Icon(Icons.list_alt_outlined),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<CaseProvider>().fetchCases(),
        child: Column(
          children: [
            // KPI Summary Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Theme.of(context).cardTheme.color,
              child: Row(
                children: [
                  Expanded(
                    child: _buildBadgeMetric(
                      label: 'P1 Critical',
                      count: p1Cases.length.toString(),
                      color: AppColors.priorityP1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildBadgeMetric(
                      label: 'Triage Queue',
                      count: unassignedCases.length.toString(),
                      color: AppColors.statusAwaiting,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildBadgeMetric(
                      label: 'In Progress',
                      count: activeCases.where((c) => c.status == 'in_progress' || c.status == 'assigned').length.toString(),
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildBadgeMetric(
                      label: 'Total Active',
                      count: activeCases.length.toString(),
                      color: AppColors.slaHealthy,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.borderLight),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCaseListView(unassignedCases, 'No unassigned tickets in queue! Great job.'),
                  _buildCaseListView(myAssignedCases, 'You have no tickets currently assigned to you.'),
                  _buildCaseListView(activeCases, 'No active tickets found.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeMetric({required String label, required String count, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCaseListView(List<CaseModel> queue, String emptyMessage) {
    if (queue.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.done_all, size: 48, color: AppColors.slaHealthy),
            const SizedBox(height: 12),
            Text(
              emptyMessage,
              style: const TextStyle(color: AppColors.textSecondaryLight),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: queue.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final c = queue[index];
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => CaseDetailScreen(caseId: c.id)),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            c.referenceNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusBadge(status: c.status),
                          const SizedBox(width: 6),
                          PriorityBadge(priority: c.priority),
                        ],
                      ),
                      if (c.sla != null)
                        SlaTimerWidget(
                          targetTime: c.sla!.targetResolveAt,
                          isBreached: c.sla!.resolutionBreached,
                          completedAt: c.resolvedAt,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    c.title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  if (c.description != null && c.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      c.description!,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 14, color: AppColors.textSecondaryLight),
                      const SizedBox(width: 4),
                      Text(
                        'Owner: ${c.ownerId != null ? 'Assigned' : 'Unassigned'}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                      ),
                      const Spacer(),
                      if (c.site != null) ...[
                        const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondaryLight),
                        const SizedBox(width: 4),
                        Text(
                          c.site!,
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
