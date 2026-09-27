import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/dimensions.dart';
import '../../../shared/theme/typography.dart';
import '../../../shared/widgets/custom_buttons.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/search_field.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/change_model.dart';
import '../providers/change_provider.dart';
import 'create_change_dialog.dart';

class ChangeManagementScreen extends StatefulWidget {
  const ChangeManagementScreen({super.key});

  @override
  State<ChangeManagementScreen> createState() => _ChangeManagementScreenState();
}

class _ChangeManagementScreenState extends State<ChangeManagementScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String? _selectedStatus;
  String? _selectedType;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChangeProvider>().fetchChanges();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openCreateDialog() {
    showDialog(
      context: context,
      builder: (_) => const CreateChangeDialog(),
    ).then((val) {
      if (val != null) {
        context.read<ChangeProvider>().fetchChanges();
      }
    });
  }

  void _openCABDialog(ChangeRequestModel change) {
    final feedbackCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('CAB Review: ${change.changeNumber}', style: AppTypography.headlineSm),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  change.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _buildTypeBadge(change.changeType),
                    _buildRiskBadge(change.riskLevel),
                    StatusBadge(status: change.status),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Justification: ${change.reason}', style: AppTypography.bodySm),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('cabFeedbackInput'),
                  controller: feedbackCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'CAB Assessment & Feedback *',
                    hintText: 'Enter approval conditions, test requirements, or rejection reasons...',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          SecondaryButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          const SizedBox(width: 8),
          DangerButton(
            key: const Key('cabRejectConfirmBtn'),
            label: 'Reject RFC',
            onPressed: () async {
              final ok = await context.read<ChangeProvider>().recordCABDecision(
                    change.id,
                    false,
                    feedbackCtrl.text.trim().isNotEmpty ? feedbackCtrl.text.trim() : null,
                  );
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Change Request Rejected by CAB')),
                  );
                }
              }
            },
          ),
          const SizedBox(width: 8),
          PrimaryButton(
            key: const Key('cabApproveConfirmBtn'),
            label: 'Approve RFC',
            onPressed: () async {
              final ok = await context.read<ChangeProvider>().recordCABDecision(
                    change.id,
                    true,
                    feedbackCtrl.text.trim().isNotEmpty ? feedbackCtrl.text.trim() : null,
                  );
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Change Request Approved by CAB')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _confirmTransition(ChangeRequestModel change, String targetStatus, String label, String message) {
    ConfirmationDialog.show(
      context: context,
      title: label,
      message: message,
      confirmLabel: 'Confirm',
    ).then((confirmed) {
      if (confirmed == true) {
        context.read<ChangeProvider>().updateStatus(change.id, targetStatus);
      }
    });
  }

  Widget _buildTypeBadge(String type) {
    Color bg;
    Color fg;
    switch (type.toLowerCase()) {
      case 'emergency':
        bg = AppColors.priorityP1.withValues(alpha: 0.12);
        fg = AppColors.priorityP1;
        break;
      case 'standard':
        bg = AppColors.slaHealthy.withValues(alpha: 0.12);
        fg = AppColors.slaHealthy;
        break;
      case 'normal':
      default:
        bg = AppColors.primaryBlue.withValues(alpha: 0.12);
        fg = AppColors.primaryBlue;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        type.toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _buildRiskBadge(String risk) {
    Color bg;
    Color fg;
    switch (risk.toLowerCase()) {
      case 'critical':
        bg = AppColors.priorityP1.withValues(alpha: 0.15);
        fg = AppColors.priorityP1;
        break;
      case 'high':
        bg = AppColors.priorityP2.withValues(alpha: 0.15);
        fg = AppColors.priorityP2;
        break;
      case 'moderate':
        bg = AppColors.priorityP3.withValues(alpha: 0.15);
        fg = AppColors.priorityP3;
        break;
      case 'low':
      default:
        bg = AppColors.slaHealthy.withValues(alpha: 0.15);
        fg = AppColors.slaHealthy;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        'RISK: ${risk.toUpperCase()}',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChangeProvider>();
    final auth = context.watch<AuthProvider>();
    final isWide = MediaQuery.of(context).size.width >= 900;
    final isStaff = auth.currentUser?.isStaff ?? false;
    final isManager = auth.currentUser?.role == 'manager' ||
        auth.currentUser?.role == 'team_lead' ||
        auth.currentUser?.role == 'administrator';

    // Metrics
    final totalChanges = provider.changes.length;
    final pendingCAB = provider.changes.where((c) => c.status.toLowerCase() == 'pending_cab').length;
    final approvedScheduled = provider.changes
        .where((c) => c.status.toLowerCase() == 'approved' || c.status.toLowerCase() == 'scheduled')
        .length;
    final implementingActive = provider.changes.where((c) => c.status.toLowerCase() == 'implementing').length;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(
        children: [
          // 1. Top Enterprise Metric Banner
          Container(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.borderLight)),
            ),
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final isCompact = constraints.maxWidth < 650;
                final cards = [
                  MetricCard(
                    label: 'Total Changes',
                    value: '$totalChanges',
                    icon: Icons.published_with_changes_outlined,
                  ),
                  MetricCard(
                    label: 'Pending CAB',
                    value: '$pendingCAB',
                    icon: Icons.gavel_outlined,
                    valueColor: AppColors.priorityP2,
                  ),
                  MetricCard(
                    label: 'Approved / Scheduled',
                    value: '$approvedScheduled',
                    icon: Icons.event_available_outlined,
                    valueColor: AppColors.priorityP3,
                  ),
                  MetricCard(
                    label: 'Implementing',
                    value: '$implementingActive',
                    icon: Icons.engineering_outlined,
                    valueColor: AppColors.primaryBlue,
                  ),
                ];

                if (isCompact) {
                  return GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.5,
                    children: cards,
                  );
                }

                return Row(
                  children: cards
                      .map((c) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: c,
                            ),
                          ))
                      .toList(),
                );
              },
            ),
          ),

          // 2. Responsive Filter & Action Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceMd, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.borderLight)),
            ),
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final isNarrow = constraints.maxWidth < 750;

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SearchField(
                        controller: _searchCtrl,
                        hintText: 'Search RFCs by CHG ID, title, justification...',
                        onChanged: (v) => provider.setSearchQuery(v),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButton<String?>(
                              isExpanded: true,
                              value: _selectedStatus,
                              hint: const Text('All Statuses'),
                              items: const [
                                DropdownMenuItem(value: null, child: Text('All Statuses')),
                                DropdownMenuItem(value: 'draft', child: Text('Draft')),
                                DropdownMenuItem(value: 'pending_cab', child: Text('Pending CAB')),
                                DropdownMenuItem(value: 'approved', child: Text('Approved')),
                                DropdownMenuItem(value: 'scheduled', child: Text('Scheduled')),
                                DropdownMenuItem(value: 'implementing', child: Text('Implementing')),
                                DropdownMenuItem(value: 'completed', child: Text('Completed')),
                                DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                              ],
                              onChanged: (v) {
                                setState(() => _selectedStatus = v);
                                provider.fetchChanges(status: _selectedStatus, type: _selectedType);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButton<String?>(
                              isExpanded: true,
                              value: _selectedType,
                              hint: const Text('All Types'),
                              items: const [
                                DropdownMenuItem(value: null, child: Text('All Types')),
                                DropdownMenuItem(value: 'standard', child: Text('Standard')),
                                DropdownMenuItem(value: 'normal', child: Text('Normal')),
                                DropdownMenuItem(value: 'emergency', child: Text('Emergency')),
                              ],
                              onChanged: (v) {
                                setState(() => _selectedType = v);
                                provider.fetchChanges(status: _selectedStatus, type: _selectedType);
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded),
                            tooltip: 'Refresh',
                            onPressed: () => provider.fetchChanges(status: _selectedStatus, type: _selectedType),
                          ),
                        ],
                      ),
                      if (isStaff) ...[
                        const SizedBox(height: 8),
                        PrimaryButton(
                          label: 'Submit RFC',
                          icon: Icons.add,
                          onPressed: _openCreateDialog,
                        ),
                      ],
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: SearchField(
                        controller: _searchCtrl,
                        hintText: 'Search RFCs by CHG ID, title, justification...',
                        onChanged: (v) => provider.setSearchQuery(v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String?>(
                      value: _selectedStatus,
                      hint: const Text('All Statuses'),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All Statuses')),
                        DropdownMenuItem(value: 'draft', child: Text('Draft')),
                        DropdownMenuItem(value: 'pending_cab', child: Text('Pending CAB')),
                        DropdownMenuItem(value: 'approved', child: Text('Approved')),
                        DropdownMenuItem(value: 'scheduled', child: Text('Scheduled')),
                        DropdownMenuItem(value: 'implementing', child: Text('Implementing')),
                        DropdownMenuItem(value: 'completed', child: Text('Completed')),
                        DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                      ],
                      onChanged: (v) {
                        setState(() => _selectedStatus = v);
                        provider.fetchChanges(status: _selectedStatus, type: _selectedType);
                      },
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String?>(
                      value: _selectedType,
                      hint: const Text('All Types'),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All Types')),
                        DropdownMenuItem(value: 'standard', child: Text('Standard')),
                        DropdownMenuItem(value: 'normal', child: Text('Normal')),
                        DropdownMenuItem(value: 'emergency', child: Text('Emergency')),
                      ],
                      onChanged: (v) {
                        setState(() => _selectedType = v);
                        provider.fetchChanges(status: _selectedStatus, type: _selectedType);
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Refresh',
                      onPressed: () => provider.fetchChanges(status: _selectedStatus, type: _selectedType),
                    ),
                    if (isStaff) ...[
                      const SizedBox(width: 12),
                      PrimaryButton(
                        label: 'Submit RFC',
                        icon: Icons.add,
                        onPressed: _openCreateDialog,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),

          // 3. Error Banner (if any)
          if (provider.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.priorityP1.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.priorityP1, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      provider.error!,
                      style: const TextStyle(color: AppColors.priorityP1, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

          // 4. Main Body: Master-Detail on Desktop, Stacked list on Mobile
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.changes.isEmpty
                    ? _buildEmptyState(isStaff)
                    : isWide
                        ? _buildMasterDetailLayout(provider, isStaff, isManager)
                        : _buildMobileListLayout(provider, isStaff, isManager),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isStaff) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.published_with_changes_outlined, size: 64, color: AppColors.textSecondaryLight),
          const SizedBox(height: 16),
          Text(
            'No Change Requests Found',
            style: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Submit RFCs and govern production deployments with CAB review.',
            style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondaryLight),
          ),
          if (isStaff) ...[
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Submit First RFC',
              onPressed: _openCreateDialog,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMasterDetailLayout(ChangeProvider provider, bool isStaff, bool isManager) {
    final selected = provider.selectedChange ?? (provider.changes.isNotEmpty ? provider.changes.first : null);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Master Pane
        SizedBox(
          width: 380,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: AppColors.borderLight)),
            ),
            child: ListView.separated(
              itemCount: provider.changes.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.borderLight),
              itemBuilder: (ctx, index) {
                final change = provider.changes[index];
                final isSelected = selected?.id == change.id;

                return InkWell(
                  onTap: () => provider.setSelectedChange(change),
                  child: Container(
                    color: isSelected ? AppColors.primaryBlue.withValues(alpha: 0.06) : Colors.transparent,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Text(
                              change.changeNumber,
                              style: AppTypography.bodyMd.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isSelected ? AppColors.primaryBlue : AppColors.textPrimaryLight,
                              ),
                            ),
                            _buildTypeBadge(change.changeType),
                            _buildRiskBadge(change.riskLevel),
                            StatusBadge(status: change.status),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          change.title,
                          style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          change.reason,
                          style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // Right Detail Pane
        Expanded(
          child: selected == null
              ? const Center(child: Text('Select a Change Request to inspect plans & CAB review'))
              : _buildDetailPane(selected, isStaff, isManager),
        ),
      ],
    );
  }

  Widget _buildMobileListLayout(ChangeProvider provider, bool isStaff, bool isManager) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      itemCount: provider.changes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, index) {
        final change = provider.changes[index];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppDimensions.cardBorderRadius,
            side: const BorderSide(color: AppColors.borderLight),
          ),
          child: InkWell(
            borderRadius: AppDimensions.cardBorderRadius,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: Text(change.changeNumber)),
                    body: _buildDetailPane(change, isStaff, isManager),
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        change.changeNumber,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      _buildTypeBadge(change.changeType),
                      _buildRiskBadge(change.riskLevel),
                      StatusBadge(status: change.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    change.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text('Reason: ${change.reason}', style: AppTypography.bodySm),
                  const SizedBox(height: 8),
                  Text(
                    'Created: ${dateFormat.format(change.createdAt.toLocal())}',
                    style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailPane(ChangeRequestModel change, bool isStaff, bool isManager) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(AppDimensions.spaceLg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppDimensions.cardBorderRadius,
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          change.changeNumber,
                          style: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.bold),
                        ),
                        _buildTypeBadge(change.changeType),
                        _buildRiskBadge(change.riskLevel),
                        StatusBadge(status: change.status),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (change.status.toLowerCase() == 'pending_cab' && isManager)
                          PrimaryButton(
                            label: 'CAB Review',
                            icon: Icons.gavel,
                            onPressed: () => _openCABDialog(change),
                          ),
                        if (change.status.toLowerCase() == 'approved' && isStaff)
                          PrimaryButton(
                            label: 'Start Implementation',
                            icon: Icons.play_arrow,
                            onPressed: () => _confirmTransition(
                              change,
                              'implementing',
                              'Start Implementation',
                              'Are you ready to transition Change ${change.changeNumber} into IMPLEMENTING state?',
                            ),
                          ),
                        if (change.status.toLowerCase() == 'implementing' && isStaff) ...[
                          DangerButton(
                            label: 'Trigger Rollback',
                            icon: Icons.undo,
                            onPressed: () => _confirmTransition(
                              change,
                              'rollback',
                              'Trigger Rollback Plan',
                              'Are you sure you want to trigger the rollback contingency plan for ${change.changeNumber}?',
                            ),
                          ),
                          const SizedBox(width: 8),
                          PrimaryButton(
                            label: 'Mark Completed',
                            icon: Icons.check_circle_outline,
                            onPressed: () => _confirmTransition(
                              change,
                              'completed',
                              'Mark Change Completed',
                              'Confirm that change implementation and validation have completed successfully.',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  change.title,
                  style: AppTypography.headlineSm.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  children: [
                    _buildMetaItem('Created', dateFormat.format(change.createdAt.toLocal())),
                    _buildMetaItem('Last Updated', dateFormat.format(change.updatedAt.toLocal())),
                    if (change.scheduledStart != null)
                      _buildMetaItem('Scheduled Start', dateFormat.format(change.scheduledStart!.toLocal())),
                    if (change.scheduledEnd != null)
                      _buildMetaItem('Scheduled End', dateFormat.format(change.scheduledEnd!.toLocal())),
                    if (change.problemId != null) _buildMetaItem('Linked Problem ID', change.problemId!),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section 1: Business Justification & Scope
          _buildInfoCard(
            title: 'Business Justification & Scope',
            icon: Icons.article_outlined,
            children: [
              Text('Justification / Problem Addressed:', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(change.reason, style: AppTypography.bodyMd),
              const SizedBox(height: 12),
              Text('Scope & Details:', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(change.description, style: AppTypography.bodyMd),
            ],
          ),
          const SizedBox(height: 20),

          // Section 2: Implementation Plan
          _buildInfoCard(
            title: 'Step-by-Step Implementation Plan',
            icon: Icons.checklist_rtl_outlined,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  change.implementationPlan,
                  style: AppTypography.bodyMd.copyWith(fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Section 3: Post-Implementation Test & Validation Plan
          _buildInfoCard(
            title: 'Post-Implementation Validation & Smoke Tests',
            icon: Icons.verified_outlined,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  change.testPlan,
                  style: AppTypography.bodyMd.copyWith(fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Section 4: Rollback & Backout Contingency Plan
          _buildInfoCard(
            title: 'Rollback & Backout Contingency Plan',
            icon: Icons.undo_outlined,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.priorityP1.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.priorityP1.withValues(alpha: 0.2)),
                ),
                child: Text(
                  change.rollbackPlan,
                  style: AppTypography.bodyMd.copyWith(
                    fontFamily: 'monospace',
                    color: AppColors.priorityP1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Section 5: CAB Governance & Assessment Feedback
          _buildInfoCard(
            title: 'Change Advisory Board (CAB) Governance',
            icon: Icons.account_balance_outlined,
            children: [
              if (change.cabFeedback != null && change.cabFeedback!.isNotEmpty) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.comment_bank_outlined, color: AppColors.primaryBlue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CAB Review Assessment & Feedback:',
                              style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(change.cabFeedback!, style: AppTypography.bodyMd),
                        ],
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  change.status.toLowerCase() == 'pending_cab'
                      ? 'RFC is awaiting review and formal authorization from designated CAB members.'
                      : 'No explicit CAB feedback recorded for this change record.',
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.textSecondaryLight,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.spaceLg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppDimensions.cardBorderRadius,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryBlue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: AppTypography.headlineSm.copyWith(fontSize: 16)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildMetaItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.labelSm.copyWith(color: AppColors.textSecondaryLight)),
        const SizedBox(height: 2),
        Text(value, style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
