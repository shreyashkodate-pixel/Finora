import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/sla_timer_widget.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../ai/providers/ai_provider.dart';
import '../../ai/widgets/ai_draft_dialog.dart';
import '../../ai/widgets/ai_triage_card.dart';
import '../../ai/widgets/living_summary_card.dart';
import '../../ai/widgets/sla_risk_card.dart';
import '../../approvals/providers/approval_provider.dart';
import '../../approvals/widgets/approval_panel_widget.dart';
import '../../autofix/widgets/autofix_panel_widget.dart';
import '../../auth/providers/auth_provider.dart';

import '../models/case_model.dart';
import '../providers/case_provider.dart';
import '../widgets/attachment_list_widget.dart';
import '../widgets/message_stream_widget.dart';

/// Multi-tab case detail workspace per SRS §4, §5 & §6.
/// Embeds real-time timeline, message composer, evidence attachments,
/// Gemini AI Living Summary/Triage/Risk cards, and Business Approvals panel.
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
          title: const Text('Update Ticket Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Current Status: ${currentCase.status.toUpperCase()} (Version: ${currentCase.version})',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
              ),
              const SizedBox(height: 16),
              ...transitions.map((targetStatus) {
                return ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  title: Text(
                    targetStatus.replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
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

  void _showReopenDialog(BuildContext context, CaseModel currentCase) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Reopen Case'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Cases can be reopened within 7 calendar days of resolution. Please state the justification:',
                style: TextStyle(fontSize: 13),
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
                }
              },
              child: const Text('Reopen Ticket'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final caseProv = context.watch<CaseProvider>();
    final auth = context.watch<AuthProvider>();
    final c = caseProv.selectedCase;
    final isStaff = auth.currentUser?.isStaff ?? false;

    if (caseProv.isLoading && c == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading Case...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (c == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Case Not Found')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Could not load case details.'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth >= 980;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              c.referenceNumber,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(width: 8),
            StatusBadge(status: c.status),
            const SizedBox(width: 6),
            PriorityBadge(priority: c.priority),
          ],
        ),
        actions: [
          // Reopen action if resolved
          if (c.status == 'resolved')
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                icon: const Icon(Icons.replay, size: 16),
                label: const Text('Reopen'),
                onPressed: () => _showReopenDialog(context, c),
              ),
            ),

          // Status transition button for staff
          if (isStaff && c.status != 'closed' && c.status != 'cancelled')
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.edit_note, size: 16),
                label: const Text('Update Status'),
                onPressed: () => _showStatusDialog(context, c),
              ),
            ),

          // AI Draft Assistant button for staff
          if (isStaff)
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
      body: caseProv.errorMessage != null
          ? Column(
              children: [
                Container(
                  width: double.infinity,
                  color: AppColors.priorityP1.withValues(alpha: 0.1),
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, size: 16, color: AppColors.priorityP1),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          caseProv.errorMessage!,
                          style: const TextStyle(fontSize: 12, color: AppColors.priorityP1),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 14),
                        onPressed: () => caseProv.clearError(),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildTabViews(c, isWideScreen)),
              ],
            )
          : _buildTabViews(c, isWideScreen),
    );
  }

  Widget _buildTabViews(CaseModel c, bool isWideScreen) {
    return TabBarView(
      controller: _tabController,
      children: [
        // Tab 1: Discussion & Message Stream
        Column(
          children: [
            LivingSummaryCard(
              caseId: c.id,
              summary: context.watch<AIProvider>().summary,
              isStaff: context.watch<AuthProvider>().currentUser?.isStaff ?? false,
            ),
            Expanded(
              child: MessageStreamWidget(caseId: c.id),
            ),
          ],
        ),

        // Tab 2: AI Copilot & Risk
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SLARiskCard(risk: context.watch<AIProvider>().risk),
              const SizedBox(height: 16),
              AITriageCard(
                currentCase: c,
                triage: context.watch<AIProvider>().triage,
                isStaff: context.watch<AuthProvider>().currentUser?.isStaff ?? false,
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.auto_awesome, color: AppColors.primaryBlue),
                          SizedBox(width: 8),
                          Text(
                            'AI Response Assistant',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Generate an automated, context-aware draft message addressing the user problem, triage findings, and knowledge base references.',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.edit),
                        label: const Text('Open Response Drafter'),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => AIDraftDialog(caseId: c.id),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (context.watch<AuthProvider>().currentUser?.isStaff ?? false)
                AutoFixPanelWidget(caseId: c.id),
            ],
          ),
        ),


        // Tab 3: Case Info & Evidence Attachments
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Case metadata card
              _buildCaseMetadataCard(c),
              const SizedBox(height: 16),

              // SLA Details Card
              _buildSlaDetailsCard(c),
              const SizedBox(height: 16),

              // Attachments
              AttachmentListWidget(caseId: c.id),
            ],
          ),
        ),

        // Tab 4: Approvals & Governance
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ApprovalPanelWidget(currentCase: c),
        ),
      ],
    );
  }

  Widget _buildCaseMetadataCard(CaseModel c) {
    final dateFormat = DateFormat('MMM d, yyyy h:mm a');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Case Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _buildMetaRow('Title', c.title),
            if (c.description != null && c.description!.isNotEmpty)
              _buildMetaRow('Description', c.description!),
            _buildMetaRow('Type', c.type.toUpperCase()),
            _buildMetaRow('Site / Campus', c.site ?? 'Not Specified'),
            _buildMetaRow('Reporter ID', c.requesterId),
            _buildMetaRow('Assigned Owner', c.ownerId ?? 'Unassigned'),
            _buildMetaRow('Created At', dateFormat.format(c.createdAt.toLocal())),
            if (c.resolvedAt != null)
              _buildMetaRow('Resolved At', dateFormat.format(c.resolvedAt!.toLocal())),
            if (c.closedAt != null)
              _buildMetaRow('Closed At', dateFormat.format(c.closedAt!.toLocal())),
            _buildMetaRow('Record Version', '${c.version} (Optimistic Locking)'),
          ],
        ),
      ),
    );
  }

  Widget _buildSlaDetailsCard(CaseModel c) {
    final sla = c.sla;
    if (sla == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No SLA contract active for this ticket.'),
        ),
      );
    }

    final dateFormat = DateFormat('MMM d, yyyy h:mm a');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('SLA Target Windows (24/7 Clock)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SlaTimerWidget(
                  targetTime: sla.targetResolveAt,
                  isBreached: sla.resolutionBreached,
                  completedAt: c.resolvedAt,
                  label: 'Resolution',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildMetaRow('Target Response By', dateFormat.format(sla.targetResponseAt.toLocal())),
            _buildMetaRow('Target Resolve By', dateFormat.format(sla.targetResolveAt.toLocal())),
            if (sla.respondedAt != null)
              _buildMetaRow('First Responded At', dateFormat.format(sla.respondedAt!.toLocal())),
            _buildMetaRow(
              'Response SLA Status',
              sla.responseBreached ? 'BREACHED' : 'Compliant',
              valueColor: sla.responseBreached ? AppColors.priorityP1 : AppColors.slaHealthy,
            ),
            _buildMetaRow(
              'Resolution SLA Status',
              sla.resolutionBreached ? 'BREACHED' : 'Compliant',
              valueColor: sla.resolutionBreached ? AppColors.priorityP1 : AppColors.slaHealthy,
            ),
          ],
        ),
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
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: valueColor != null ? FontWeight.bold : FontWeight.normal,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
