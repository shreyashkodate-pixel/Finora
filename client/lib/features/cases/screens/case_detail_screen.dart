import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/dimensions.dart';
import '../../../shared/theme/typography.dart';
import '../../../shared/widgets/custom_buttons.dart';
import '../../../shared/widgets/priority_badge.dart';
import '../../../shared/widgets/sla_timer_widget.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../ai/providers/ai_provider.dart';
import '../../ai/widgets/ai_draft_dialog.dart';
import '../../ai/widgets/ai_triage_card.dart';
import '../../ai/widgets/living_summary_card.dart';
import '../../ai/widgets/sla_risk_card.dart';
import '../../approvals/providers/approval_provider.dart';
import '../../approvals/widgets/approval_panel_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../../autofix/widgets/autofix_panel_widget.dart';
import '../models/case_model.dart';
import '../providers/case_provider.dart';
import '../widgets/attachment_list_widget.dart';
import '../widgets/message_stream_widget.dart';

/// Role-aware Case Detail Workspace per SRS §4, §5, §6 & Stitch Screen 4.
/// Enforces 7-day reopen invariant, optimistic concurrency, and message confidentiality.
class CaseDetailScreen extends StatefulWidget {
  final String caseId;

  const CaseDetailScreen({super.key, required this.caseId});

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadData() {
    final caseProv = context.read<CaseProvider>();
    final aiProv = context.read<AIProvider>();
    final apprProv = context.read<ApprovalProvider>();

    caseProv.fetchCaseDetails(widget.caseId);
    aiProv.fetchTriage(widget.caseId);
    aiProv.fetchSummary(widget.caseId);
    aiProv.fetchRisk(widget.caseId);
    apprProv.fetchApprovalsForCase(widget.caseId);
  }

  bool _isReopenWindowExpired(CaseModel currentCase) {
    if (currentCase.resolvedAt == null) return false;
    final expiryTime = currentCase.resolvedAt!.add(const Duration(days: 7));
    return DateTime.now().toUtc().isAfter(expiryTime);
  }

  void _showReopenDialog(BuildContext context, CaseModel currentCase) {
    if (_isReopenWindowExpired(currentCase)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('7-day reopen window expired. Please submit a new ticket.'),
          backgroundColor: AppColors.priorityP1,
        ),
      );
      return;
    }

    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusCard)),
          title: Text('Reopen Case ${currentCase.referenceNumber}', style: AppTypography.headlineSm),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cases can be reopened within 7 calendar days of resolution. Please state the justification:',
                style: AppTypography.bodySm,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reopening Reason *',
                  hintText: 'e.g. Issue recurred after workstation restart...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) return;
                Navigator.of(ctx).pop();
                final ok = await context.read<CaseProvider>().reopenCase(
                      caseId: currentCase.id,
                      reason: reason,
                      currentVersion: currentCase.version,
                    );
                if (ok && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ticket successfully reopened.')),
                  );
                } else if (!ok && mounted) {
                  final err = context.read<CaseProvider>().errorMessage;
                  if (err != null && (err.contains('stale') || err.contains('conflict') || err.contains('409'))) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('This ticket was modified by another operator. Refreshing...'),
                      ),
                    );
                    _loadData();
                  }
                }
              },
              child: const Text('Reopen Ticket'),
            ),
          ],
        );
      },
    );
  }

  void _showStatusDialog(BuildContext context, CaseModel currentCase) {
    final transitions = <String>[];
    switch (currentCase.status) {
      case 'new':
        transitions.addAll(['assigned', 'cancelled']);
        break;
      case 'assigned':
        transitions.addAll(['in_progress', 'awaiting_approval', 'resolved', 'cancelled']);
        break;
      case 'in_progress':
        transitions.addAll(['awaiting_approval', 'resolved', 'cancelled']);
        break;
      case 'awaiting_approval':
        transitions.addAll(['assigned', 'cancelled']);
        break;
      case 'resolved':
        transitions.addAll(['closed']);
        break;
      default:
        break;
    }

    if (transitions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No status transitions available from "${currentCase.status}".')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusCard)),
          title: Text('Update Ticket Status', style: AppTypography.headlineSm),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Current Status: ${currentCase.status.toUpperCase()} (Version: ${currentCase.version})',
                style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
              ),
              const SizedBox(height: 16),
              ...transitions.map((targetStatus) {
                return ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusButton)),
                  title: Text(
                    targetStatus.replaceAll('_', ' ').toUpperCase(),
                    style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.bold),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    final ok = await context.read<CaseProvider>().updateStatus(
                          caseId: currentCase.id,
                          newStatus: targetStatus,
                          currentVersion: currentCase.version,
                        );
                    if (ok && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Status transitioned to ${targetStatus.toUpperCase()}')),
                      );
                    } else if (!ok && mounted) {
                      final err = context.read<CaseProvider>().errorMessage;
                      if (err != null && (err.contains('stale') || err.contains('conflict') || err.contains('409'))) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('This ticket was modified by another operator. Refreshing...'),
                          ),
                        );
                        _loadData();
                      }
                    }
                  },
                );
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showPriorityDialog(BuildContext context, CaseModel currentCase) {
    final priorities = [
      {'value': 'p1', 'label': 'P1 - Critical (Outage / System Down)'},
      {'value': 'p2', 'label': 'P2 - High (Severe Degradation)'},
      {'value': 'p3', 'label': 'P3 - Medium (Normal Business Need)'},
      {'value': 'p4', 'label': 'P4 - Low (General Inquiry / Minor)'},
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusCard)),
          title: Text('Update Ticket Priority', style: AppTypography.headlineSm),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Current Priority: ${currentCase.priority.toUpperCase()} (Version: ${currentCase.version})',
                style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
              ),
              const SizedBox(height: 16),
              ...priorities.map((item) {
                final val = item['value']!;
                final lbl = item['label']!;
                return ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusButton)),
                  title: Text(lbl, style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.bold)),
                  trailing: PriorityBadge(priority: val),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    final ok = await context.read<CaseProvider>().updatePriority(
                          caseId: currentCase.id,
                          priority: val,
                          currentVersion: currentCase.version,
                        );
                    if (ok && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Priority updated to ${val.toUpperCase()}')),
                      );
                    } else if (!ok && mounted) {
                      final err = context.read<CaseProvider>().errorMessage;
                      if (err != null && (err.contains('stale') || err.contains('conflict') || err.contains('409'))) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('This ticket was modified by another operator. Refreshing...'),
                          ),
                        );
                        _loadData();
                      }
                    }
                  },
                );
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _assignToMe(CaseModel currentCase, String currentUserId) async {
    final ok = await context.read<CaseProvider>().assignCase(
          caseId: currentCase.id,
          ownerId: currentUserId,
          currentVersion: currentCase.version,
        );
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Case ${currentCase.referenceNumber} assigned to you.')),
      );
    } else if (!ok && mounted) {
      final err = context.read<CaseProvider>().errorMessage;
      if (err != null && (err.contains('stale') || err.contains('conflict') || err.contains('409'))) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This ticket was modified by another operator. Refreshing...'),
          ),
        );
        _loadData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final caseProv = context.watch<CaseProvider>();
    final auth = context.watch<AuthProvider>();
    final c = caseProv.selectedCase;
    final isStaff = auth.currentUser?.isStaff ?? false;

    if (caseProv.isLoading && c == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading Ticket...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (c == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ticket Not Found')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Could not load ticket details.', style: AppTypography.bodyMd),
              const SizedBox(height: 12),
              CustomButtons.primary(
                text: 'Retry',
                icon: Icons.refresh,
                onPressed: _loadData,
              ),
            ],
          ),
        ),
      );
    }

    final isExpired = _isReopenWindowExpired(c);

    // If requester, render clean split / single workspace per Stitch Screen 4
    if (!isStaff) {
      return _buildRequesterDetailView(c, isExpired);
    }

    // If staff (Operator/Lead/Manager/Admin), render complete multi-tab workspace
    return _buildStaffDetailView(c, isExpired, auth.currentUser?.id);
  }

  Widget _buildRequesterDetailView(CaseModel c, bool isExpired) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              c.referenceNumber,
              style: AppTypography.codeMd.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 10),
            StatusBadge(status: c.status),
            const SizedBox(width: 8),
            PriorityBadge(priority: c.priority),
          ],
        ),
        actions: [
          if (c.status == 'resolved')
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: isExpired
                  ? Tooltip(
                      message: '7-day reopen window expired. Please submit a new ticket.',
                      child: TextButton.icon(
                        icon: const Icon(Icons.lock_clock, size: 16, color: AppColors.textSecondaryLight),
                        label: const Text('Reopen Expired', style: TextStyle(color: AppColors.textSecondaryLight)),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('7-day reopen window expired. Please submit a new ticket.'),
                              backgroundColor: AppColors.priorityP1,
                            ),
                          );
                        },
                      ),
                    )
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.replay, size: 16),
                      label: const Text('Reopen Ticket'),
                      onPressed: () => _showReopenDialog(context, c),
                    ),
            ),
          IconButton(
            tooltip: 'Refresh Ticket Data',
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Public Live Chat Stream (65% width)
                Expanded(
                  flex: 65,
                  child: MessageStreamWidget(caseId: c.id),
                ),
                const VerticalDivider(width: 1, color: AppColors.borderLight),
                // Right Column: Ticket Overview & Metadata (35% width)
                Expanded(
                  flex: 35,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppDimensions.spaceMd),
                    child: Column(
                      children: [
                        if (c.status == 'resolved' && isExpired) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.priorityP1.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                              border: Border.all(color: AppColors.priorityP1.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, size: 18, color: AppColors.priorityP1),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '7-day reopen window expired. Please submit a new ticket.',
                                    style: AppTypography.bodySm.copyWith(
                                      color: AppColors.priorityP1,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        _buildCaseOverviewCard(c),
                        const SizedBox(height: 16),
                        _buildSlaDetailsCard(c),
                        const SizedBox(height: 16),
                        AttachmentListWidget(caseId: c.id),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Discussion'),
                      Tab(icon: Icon(Icons.info_outline), text: 'Details & Files'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        MessageStreamWidget(caseId: c.id),
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(AppDimensions.spaceMd),
                          child: Column(
                            children: [
                              if (c.status == 'resolved' && isExpired) ...[
                                Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.priorityP1.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                                    border: Border.all(color: AppColors.priorityP1.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.info_outline, size: 18, color: AppColors.priorityP1),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '7-day reopen window expired. Please submit a new ticket.',
                                          style: AppTypography.bodySm.copyWith(
                                            color: AppColors.priorityP1,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              _buildCaseOverviewCard(c),
                              const SizedBox(height: 16),
                              _buildSlaDetailsCard(c),
                              const SizedBox(height: 16),
                              AttachmentListWidget(caseId: c.id),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStaffDetailView(CaseModel c, bool isExpired, String? currentUserId) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth >= 980;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              c.referenceNumber,
              style: AppTypography.codeMd.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(width: 8),
            StatusBadge(status: c.status),
            const SizedBox(width: 6),
            PriorityBadge(priority: c.priority),
          ],
        ),
        actions: [
          if (c.ownerId == null && currentUserId != null && c.status != 'closed' && c.status != 'cancelled')
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.person_add, size: 16),
                label: const Text('Assign to Me'),
                onPressed: () => _assignToMe(c, currentUserId),
              ),
            ),
          if (c.status != 'closed' && c.status != 'cancelled')
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.flag_outlined, size: 16),
                label: const Text('Priority'),
                onPressed: () => _showPriorityDialog(context, c),
              ),
            ),
          if (c.status == 'resolved')
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                icon: const Icon(Icons.replay, size: 16),
                label: const Text('Reopen'),
                onPressed: () => _showReopenDialog(context, c),
              ),
            ),
          if (c.status != 'closed' && c.status != 'cancelled')
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.edit_note, size: 16),
                label: const Text('Update Status'),
                onPressed: () => _showStatusDialog(context, c),
              ),
            ),
          IconButton(
            tooltip: 'Generate AI Reply Draft',
            icon: const Icon(Icons.auto_awesome, color: AppColors.primaryBlue),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AIDraftDialog(caseId: c.id),
              );
            },
          ),
          IconButton(
            tooltip: 'Refresh Case Data',
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: !isWideScreen,
          tabs: const [
            Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Discussion'),
            Tab(icon: Icon(Icons.psychology_outlined), text: 'AI Copilot'),
            Tab(icon: Icon(Icons.info_outline), text: 'Info & Evidence'),
            Tab(icon: Icon(Icons.approval_outlined), text: 'Approvals'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          Column(
            children: [
              LivingSummaryCard(
                caseId: c.id,
                summary: context.watch<AIProvider>().summary,
                isStaff: true,
              ),
              Expanded(
                child: MessageStreamWidget(caseId: c.id),
              ),
            ],
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SLARiskCard(risk: context.watch<AIProvider>().risk),
                const SizedBox(height: 16),
                AITriageCard(
                  currentCase: c,
                  triage: context.watch<AIProvider>().triage,
                  isStaff: true,
                ),
                const SizedBox(height: 16),
                AutoFixPanelWidget(caseId: c.id),
              ],
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCaseOverviewCard(c),
                const SizedBox(height: 16),
                _buildSlaDetailsCard(c),
                const SizedBox(height: 16),
                AttachmentListWidget(caseId: c.id),
              ],
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            child: ApprovalPanelWidget(currentCase: c),
          ),
        ],
      ),
    );
  }

  Widget _buildCaseOverviewCard(CaseModel c) {
    final dateFormat = DateFormat('MMM d, yyyy h:mm a');

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: AppColors.primaryBlue),
              const SizedBox(width: 8),
              Text('Ticket Overview', style: AppTypography.headlineSm.copyWith(fontSize: 15)),
            ],
          ),
          const SizedBox(height: 14),
          _buildMetaRow('Title', c.title),
          if (c.description != null && c.description!.isNotEmpty)
            _buildMetaRow('Description', c.description!),
          _buildMetaRow('Type', c.type == 'incident' ? 'Incident' : 'Service Request'),
          _buildMetaRow('Physical Site', c.site ?? 'Main Campus'),
          _buildMetaRow('Requester ID', c.requesterId),
          _buildMetaRow('Owner / Assignee', c.ownerId ?? 'Unassigned (In Triage Queue)'),
          _buildMetaRow('Created At', dateFormat.format(c.createdAt.toLocal())),
          if (c.resolvedAt != null)
            _buildMetaRow('Resolved At', dateFormat.format(c.resolvedAt!.toLocal())),
          if (c.closedAt != null)
            _buildMetaRow('Closed At', dateFormat.format(c.closedAt!.toLocal())),
          _buildMetaRow('Version Token', '${c.version} (Optimistic Concurrency)'),
        ],
      ),
    );
  }

  Widget _buildSlaDetailsCard(CaseModel c) {
    final sla = c.sla;
    if (sla == null) {
      return Container(
        padding: const EdgeInsets.all(AppDimensions.spaceMd),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Text('No active SLA policy assigned.', style: AppTypography.bodySm),
      );
    }

    final dateFormat = DateFormat('MMM d, yyyy h:mm a');

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 18, color: AppColors.primaryBlue),
                  const SizedBox(width: 8),
                  Text('SLA Target Telemetry', style: AppTypography.headlineSm.copyWith(fontSize: 15)),
                ],
              ),
              SlaTimerWidget(
                targetTime: sla.targetResolveAt,
                isBreached: sla.resolutionBreached,
                completedAt: c.resolvedAt,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildMetaRow('Target Response By', dateFormat.format(sla.targetResponseAt.toLocal())),
          _buildMetaRow('Target Resolve By', dateFormat.format(sla.targetResolveAt.toLocal())),
          if (sla.respondedAt != null)
            _buildMetaRow('First Response At', dateFormat.format(sla.respondedAt!.toLocal())),
          _buildMetaRow(
            'Response SLA',
            sla.responseBreached ? 'BREACHED' : 'Compliant',
            valueColor: sla.responseBreached ? AppColors.priorityP1 : AppColors.slaHealthy,
          ),
          _buildMetaRow(
            'Resolution SLA',
            sla.resolutionBreached ? 'BREACHED' : 'Compliant',
            valueColor: sla.resolutionBreached ? AppColors.priorityP1 : AppColors.slaHealthy,
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: AppTypography.labelSm.copyWith(
                color: AppColors.textSecondaryLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodySm.copyWith(
                fontWeight: valueColor != null ? FontWeight.bold : FontWeight.normal,
                color: valueColor ?? AppColors.textPrimaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
