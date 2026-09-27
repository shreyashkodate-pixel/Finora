import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/responsive/breakpoints.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/dimensions.dart';
import '../../../shared/theme/typography.dart';
import '../../../shared/widgets/global_states.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/priority_badge.dart';
import '../../../shared/widgets/search_field.dart';
import '../../../shared/widgets/sla_timer_widget.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../analytics/screens/predictive_analytics_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cases/models/case_model.dart';
import '../../cases/providers/case_provider.dart';
import '../../cases/screens/case_detail_screen.dart';

/// Authoritative Stitch Operator Queue Workstation Screen
/// Directly implements design/stitch/stitch_ai_it_helpdesk_1/operator_queue_workstation/code.html
class OperatorWorkspaceScreen extends StatefulWidget {
  const OperatorWorkspaceScreen({super.key});

  @override
  State<OperatorWorkspaceScreen> createState() => _OperatorWorkspaceScreenState();
}

class _OperatorWorkspaceScreenState extends State<OperatorWorkspaceScreen> {
  String _searchQuery = '';
  String _selectedPriority = '';
  String _selectedStatus = '';
  String _selectedSegment = 'all'; // all, healthy, warning, breached

  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshQueue();
    });
    // Auto-refresh every 15s per Stitch specs
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _refreshQueue();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _refreshQueue() {
    context.read<CaseProvider>().fetchCases(
          status: _selectedStatus.isNotEmpty ? _selectedStatus : null,
          priority: _selectedPriority.isNotEmpty ? _selectedPriority : null,
          search: _searchQuery.isNotEmpty ? _searchQuery : null,
        );
  }

  List<CaseModel> _filterCases(List<CaseModel> baseList) {
    return baseList.where((c) {
      if (c.status == 'closed' || c.status == 'cancelled') return false;

      // Segment filter
      if (_selectedSegment == 'healthy') {
        if (c.sla?.resolutionBreached == true || c.priority.toLowerCase() == 'p1') {
          return false;
        }
      } else if (_selectedSegment == 'warning') {
        if (c.priority.toLowerCase() != 'p1' && c.priority.toLowerCase() != 'p2') {
          return false;
        }
      } else if (_selectedSegment == 'breached') {
        if (c.sla?.resolutionBreached != true) {
          return false;
        }
      }

      // Priority filter
      if (_selectedPriority.isNotEmpty && c.priority.toLowerCase() != _selectedPriority.toLowerCase()) {
        return false;
      }

      // Status filter
      if (_selectedStatus.isNotEmpty && c.status.toLowerCase() != _selectedStatus.toLowerCase()) {
        return false;
      }

      // Search Query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchRef = c.referenceNumber.toLowerCase().contains(q);
        final matchTitle = c.title.toLowerCase().contains(q);
        final matchDesc = c.description?.toLowerCase().contains(q) ?? false;
        if (!matchRef && !matchTitle && !matchDesc) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final caseProv = context.watch<CaseProvider>();
    final auth = context.watch<AuthProvider>();
    final allCases = caseProv.cases;
    final currentUserId = auth.currentUser?.id;

    final activeCases = allCases.where((c) => c.status != 'closed' && c.status != 'cancelled').toList();
    final myAssignedCases = activeCases.where((c) => c.ownerId == currentUserId).toList();
    final unassignedCases = activeCases.where((c) => c.ownerId == null).toList();
    final p1Cases = activeCases.where((c) => c.priority.toLowerCase() == 'p1').toList();
    final breachedCases = activeCases.where((c) => c.sla?.resolutionBreached == true).toList();
    final healthyCases = activeCases.where((c) => c.sla?.resolutionBreached != true && c.priority.toLowerCase() != 'p1').toList();

    final filteredCases = _filterCases(activeCases);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: RefreshIndicator(
        onRefresh: () async => _refreshQueue(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppDimensions.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Stitch Header Banner
              _buildHeaderBanner(context, caseProv.isLoading),
              const SizedBox(height: AppDimensions.spaceMd),

              // 2. Stitch 4-Card KPI Grid
              _buildKpiMetricsGrid(
                myCount: myAssignedCases.length,
                unassignedCount: unassignedCases.length,
                riskCount: p1Cases.length,
                breachedCount: breachedCases.length,
              ),
              const SizedBox(height: AppDimensions.spaceMd),

              // 3. Main Workstation Queue Container
              _buildWorkstationQueueContainer(
                context: context,
                filteredCases: filteredCases,
                totalActiveCount: activeCases.length,
                healthyCount: healthyCases.length,
                warningCount: p1Cases.length,
                breachedCount: breachedCases.length,
                currentUserId: currentUserId,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 1. Stitch Header Banner
  Widget _buildHeaderBanner(BuildContext context, bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.borderLight, width: 1),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 720;
          final titleColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    'Operator Triage Workstation',
                    style: AppTypography.headlineSm.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryFixed,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 6, color: AppColors.secondaryIndigo),
                        SizedBox(width: 4),
                        Text(
                          'Live Stream',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSecondaryFixed,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'L1/L2 Incident orchestration & telemetry monitoring console',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ],
          );

          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: const Text('SLA Risk Radar'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PredictiveAnalyticsScreen()),
                  );
                },
              ),
              ElevatedButton.icon(
                icon: isLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.sync_rounded, size: 16),
                label: const Text('Auto-Refresh: 15s'),
                onPressed: _refreshQueue,
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.terminal_rounded, size: 24, color: AppColors.primaryBlue),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: titleColumn),
                  ],
                ),
                const SizedBox(height: 12),
                actions,
              ],
            );
          }

          return Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.terminal_rounded, size: 24, color: AppColors.primaryBlue),
              ),
              const SizedBox(width: 12),
              Expanded(child: titleColumn),
              const SizedBox(width: 12),
              actions,
            ],
          );
        },
      ),
    );
  }

  // 2. Stitch 4-Card KPI Grid
  Widget _buildKpiMetricsGrid({
    required int myCount,
    required int unassignedCount,
    required int riskCount,
    required int breachedCount,
  }) {
    final cards = [
      MetricCard(
        label: 'Triage Queue',
        value: '$unassignedCount',
        valueColor: AppColors.textPrimaryLight,
        icon: Icons.inbox_outlined,
        subtitle: 'Avg triage dispatch: 6m',
        subtitleIcon: Icons.hourglass_empty_rounded,
      ),
      MetricCard(
        label: 'Assigned to Me',
        value: '$myCount',
        valueColor: AppColors.primaryBlue,
        icon: Icons.assignment_ind_outlined,
        subtitle: 'Approaching SLA limits monitored',
        subtitleIcon: Icons.info_outline,
      ),
      MetricCard(
        label: 'P1 Critical',
        value: '$riskCount',
        valueColor: riskCount > 0 ? AppColors.priorityP1 : AppColors.textPrimaryLight,
        icon: Icons.warning_amber_rounded,
        pillText: riskCount > 0 ? 'Critical Attention' : 'Stable',
        pillBgColor: riskCount > 0 ? const Color(0xFFFFDAD6) : const Color(0xFFEFF4FF),
        pillTextColor: riskCount > 0 ? AppColors.priorityP1 : AppColors.primaryBlue,
        subtitle: 'Requires immediate operator touch',
        subtitleIcon: Icons.crisis_alert_rounded,
      ),
      MetricCard(
        label: 'Breached Cases',
        value: '$breachedCount',
        valueColor: breachedCount > 0 ? AppColors.priorityP1 : AppColors.primaryBlue,
        icon: Icons.verified_outlined,
        pillText: breachedCount == 0 ? '100% On-Target' : 'Attention Needed',
        pillBgColor: breachedCount == 0 ? const Color(0xFFE5EEFF) : const Color(0xFFFFDAD6),
        pillTextColor: breachedCount == 0 ? AppColors.primaryBlue : AppColors.priorityP1,
        subtitle: '100% 24/7 SLA compliance today',
        subtitleIcon: Icons.check_circle_outline,
      ),
    ];

    return ResponsiveBreakpoints.isDesktop(context)
        ? Row(
            children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4.0), child: c))).toList(),
          )
        : GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: cards,
          );
  }

  // 3. Main Workstation Queue Container
  Widget _buildWorkstationQueueContainer({
    required BuildContext context,
    required List<CaseModel> filteredCases,
    required int totalActiveCount,
    required int healthyCount,
    required int warningCount,
    required int breachedCount,
    required String? currentUserId,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.borderLight, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: Search & Filter Toolbar
          Padding(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 680) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SearchField(
                        hintText: 'Filter by Case ID, Requester, Keyword, or Hostname...',
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdownFilter(
                              label: 'Priority',
                              value: _selectedPriority,
                              items: const [
                                DropdownMenuItem(value: '', child: Text('Priority: All')),
                                DropdownMenuItem(value: 'p1', child: Text('P1 Critical')),
                                DropdownMenuItem(value: 'p2', child: Text('P2 High')),
                                DropdownMenuItem(value: 'p3', child: Text('P3 Medium')),
                                DropdownMenuItem(value: 'p4', child: Text('P4 Low')),
                              ],
                              onChanged: (val) => setState(() => _selectedPriority = val ?? ''),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDropdownFilter(
                              label: 'Status',
                              value: _selectedStatus,
                              items: const [
                                DropdownMenuItem(value: '', child: Text('Status: All Active')),
                                DropdownMenuItem(value: 'new', child: Text('New')),
                                DropdownMenuItem(value: 'in_assessment', child: Text('In Assessment')),
                                DropdownMenuItem(value: 'assigned', child: Text('Assigned')),
                                DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
                                DropdownMenuItem(value: 'awaiting_approval', child: Text('Awaiting Approval')),
                              ],
                              onChanged: (val) => setState(() => _selectedStatus = val ?? ''),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: SearchField(
                        hintText: 'Filter by Case ID, Requester, Keyword, or Hostname...',
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildDropdownFilter(
                      label: 'Priority',
                      value: _selectedPriority,
                      items: const [
                        DropdownMenuItem(value: '', child: Text('Priority: All')),
                        DropdownMenuItem(value: 'p1', child: Text('P1 Critical')),
                        DropdownMenuItem(value: 'p2', child: Text('P2 High')),
                        DropdownMenuItem(value: 'p3', child: Text('P3 Medium')),
                        DropdownMenuItem(value: 'p4', child: Text('P4 Low')),
                      ],
                      onChanged: (val) => setState(() => _selectedPriority = val ?? ''),
                    ),
                    const SizedBox(width: 8),
                    _buildDropdownFilter(
                      label: 'Status',
                      value: _selectedStatus,
                      items: const [
                        DropdownMenuItem(value: '', child: Text('Status: All Active')),
                        DropdownMenuItem(value: 'new', child: Text('New')),
                        DropdownMenuItem(value: 'in_assessment', child: Text('In Assessment')),
                        DropdownMenuItem(value: 'assigned', child: Text('Assigned')),
                        DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
                        DropdownMenuItem(value: 'awaiting_approval', child: Text('Awaiting Approval')),
                      ],
                      onChanged: (val) => setState(() => _selectedStatus = val ?? ''),
                    ),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1, color: AppColors.borderLight),

          // Row 2: Queue Segment Tabs & Count Indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceMd, vertical: 10),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSegmentPill('All ($totalActiveCount)', 'all'),
                        _buildSegmentPill('Healthy ($healthyCount)', 'healthy'),
                        _buildSegmentPill('Warning <20% ($warningCount)', 'warning', isWarning: true),
                        _buildSegmentPill('Breached ($breachedCount)', 'breached'),
                      ],
                    ),
                  ),
                ),
                Text(
                  'Displaying ${filteredCases.length} of $totalActiveCount prioritized tickets',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderLight),

          // Row 3: Dense Case Workstation Table
          if (filteredCases.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40.0),
              child: EmptyState(
                title: 'Queue Clear',
                description: 'No active incident tickets matching the selected filters.',
                icon: Icons.done_all_rounded,
                actionLabel: 'Refresh Queue',
                onAction: _refreshQueue,
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppColors.surfaceContainerLow),
                headingRowHeight: 40,
                dataRowMinHeight: 48,
                dataRowMaxHeight: 56,
                columnSpacing: 20,
                horizontalMargin: 16,
                columns: const [
                  DataColumn(label: Text('Case / Ref ID', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textPrimaryLight))),
                  DataColumn(label: Text('Customer & Org', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textPrimaryLight))),
                  DataColumn(label: Text('Subject / Summary', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textPrimaryLight))),
                  DataColumn(label: Text('Priority', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textPrimaryLight))),
                  DataColumn(label: Text('SLA Countdown', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textPrimaryLight))),
                  DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textPrimaryLight))),
                  DataColumn(label: Text('Assignee / Queue', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textPrimaryLight))),
                  DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textPrimaryLight))),
                ],
                rows: filteredCases.map((c) {
                  return DataRow(
                    cells: [
                      // Ref ID
                      DataCell(
                        InkWell(
                          onTap: () => _openCaseDetail(c.id),
                          child: Text(
                            c.referenceNumber,
                            style: AppTypography.codeMd.copyWith(
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ),
                      // Customer & Org
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              c.requesterId.isNotEmpty
                                  ? (c.requesterId.length > 8 ? '${c.requesterId.substring(0, 8)}...' : c.requesterId)
                                  : 'Requester',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: AppColors.textPrimaryLight),
                            ),
                            Text(
                              c.site ?? 'Acme Enterprise Corp',
                              style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondaryLight),
                            ),
                          ],
                        ),
                      ),
                      // Title
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 240),
                          child: Text(
                            c.title,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.textPrimaryLight),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      // Priority
                      DataCell(PriorityBadge(priority: c.priority)),
                      // SLA Countdown
                      DataCell(
                        c.sla != null
                            ? SlaTimerWidget(
                                targetTime: c.sla!.targetResolveAt,
                                isBreached: c.sla!.resolutionBreached,
                                completedAt: c.resolvedAt,
                              )
                            : const Text('—', style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 12)),
                      ),
                      // Status
                      DataCell(StatusBadge(status: c.status)),
                      // Assignee
                      DataCell(
                        Text(
                          c.ownerId == currentUserId ? 'You' : (c.ownerId != null ? 'Assigned' : 'Unassigned'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: c.ownerId == currentUserId ? FontWeight.w700 : FontWeight.w500,
                            color: c.ownerId == null ? AppColors.priorityP1 : AppColors.textPrimaryLight,
                          ),
                        ),
                      ),
                      // Quick Actions
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (c.ownerId == null && currentUserId != null)
                              TextButton.icon(
                                icon: const Icon(Icons.person_add_outlined, size: 14),
                                label: const Text('Take', style: TextStyle(fontSize: 11.5)),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () => _assignToMe(c, currentUserId),
                              ),
                            IconButton(
                              icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.primaryBlue),
                              tooltip: 'Open Case Detail',
                              onPressed: () => _openCaseDetail(c.id),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDropdownFilter({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: AppDimensions.inputHeight,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: items,
          onChanged: onChanged,
          icon: const Icon(Icons.expand_more_rounded, size: 16, color: AppColors.outline),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimaryLight,
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentPill(String title, String key, {bool isWarning = false}) {
    final isSelected = _selectedSegment == key;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: InkWell(
        onTap: () => setState(() => _selectedSegment = key),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isWarning) ...[
                const Icon(Icons.circle, size: 6, color: AppColors.priorityP1),
                const SizedBox(width: 4),
              ],
              Text(
                title,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.primaryBlue : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCaseDetail(String caseId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CaseDetailScreen(caseId: caseId)),
    );
  }

  Future<void> _assignToMe(CaseModel c, String currentUserId) async {
    final ok = await context.read<CaseProvider>().assignCase(
          caseId: c.id,
          ownerId: currentUserId,
          currentVersion: c.version,
        );
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Case ${c.referenceNumber} assigned to you.')),
      );
    } else if (!ok && mounted) {
      final err = context.read<CaseProvider>().errorMessage;
      if (err != null && (err.contains('stale') || err.contains('conflict') || err.contains('409'))) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This ticket was modified by another operator. Refreshing...'),
          ),
        );
        _refreshQueue();
      }
    }
  }
}
