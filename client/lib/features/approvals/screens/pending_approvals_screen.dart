import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/dimensions.dart';
import '../../../shared/theme/typography.dart';
import '../../../shared/widgets/custom_buttons.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../cases/providers/case_provider.dart';
import '../../cases/screens/case_detail_screen.dart';
import '../providers/approval_provider.dart';

/// Pending Approvals Inbox for Team Leads and Managers per SRS §4 & §5.8.
class PendingApprovalsScreen extends StatefulWidget {
  const PendingApprovalsScreen({super.key});

  @override
  State<PendingApprovalsScreen> createState() => _PendingApprovalsScreenState();
}

class _PendingApprovalsScreenState extends State<PendingApprovalsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ApprovalProvider>().fetchPendingApprovals();
    });
  }

  void _showDecisionDialog(BuildContext context, String approvalId, String decision) {
    final reasonController = TextEditingController();
    final isApprove = decision == 'approved';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isApprove ? 'Approve Authorization' : 'Reject Authorization',
          style: AppTypography.headlineSm.copyWith(
            color: isApprove ? AppColors.slaHealthy : AppColors.priorityP1,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isApprove
                  ? 'Please confirm that you want to approve this request.'
                  : 'Please provide a reason or feedback for rejecting this authorization request.',
              style: AppTypography.bodyMd,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: isApprove ? 'Optional Notes' : 'Rejection Reason *',
                hintText: isApprove ? 'e.g. Budget approved for Q3' : 'e.g. Insufficient justification provided',
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          SecondaryButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          const SizedBox(width: 8),
          if (isApprove)
            PrimaryButton(
              label: 'Confirm Approval',
              onPressed: () async {
                Navigator.of(ctx).pop();
                final reason = reasonController.text.trim().isNotEmpty ? reasonController.text.trim() : 'Approved';
                final success = await context.read<ApprovalProvider>().decideApproval(
                  approvalId: approvalId,
                  decision: 'approved',
                  reason: reason,
                );
                if (mounted && success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Approval granted successfully.')),
                  );
                  context.read<CaseProvider>().fetchCases();
                }
              },
            )
          else
            DangerButton(
              label: 'Confirm Rejection',
              onPressed: () async {
                Navigator.of(ctx).pop();
                final reason = reasonController.text.trim().isNotEmpty ? reasonController.text.trim() : 'Rejected';
                final success = await context.read<ApprovalProvider>().decideApproval(
                  approvalId: approvalId,
                  decision: 'rejected',
                  reason: reason,
                );
                if (mounted && success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Request rejected.')),
                  );
                  context.read<CaseProvider>().fetchCases();
                }
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final apprProv = context.watch<ApprovalProvider>();
    final pending = apprProv.pendingApprovals;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Pending Approvals',
            subtitle: 'Business authorization and manager approvals awaiting your governance decision.',
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Pending Approvals',
                onPressed: () => apprProv.fetchPendingApprovals(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: apprProv.isLoading
                ? const Center(child: CircularProgressIndicator())
                : pending.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_outline, size: 56, color: AppColors.slaHealthy),
                            const SizedBox(height: 16),
                            Text('All caught up!', style: AppTypography.headlineMd),
                            const SizedBox(height: 6),
                            Text(
                              'No pending business authorization requests requiring your decision.',
                              style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondaryLight),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => apprProv.fetchPendingApprovals(),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(AppDimensions.spaceLg),
                          itemCount: pending.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final appr = pending[index];
                            final timeStr = DateFormat('MMM d, yyyy · h:mm a').format(appr.createdAt.toLocal());

                            return Card(
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                                side: const BorderSide(color: AppColors.borderLight),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(AppDimensions.spaceLg),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      alignment: WrapAlignment.spaceBetween,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        Wrap(
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          spacing: 8,
                                          runSpacing: 4,
                                          children: [
                                            const Icon(Icons.pending_actions, color: AppColors.statusAwaiting, size: 22),
                                            Text(
                                              'Authorization Request',
                                              style: AppTypography.headlineSm.copyWith(fontSize: 16),
                                            ),
                                            StatusBadge(status: appr.decision),
                                          ],
                                        ),
                                        Text(
                                          timeStr,
                                          style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    if (appr.reason != null && appr.reason!.isNotEmpty)
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.backgroundLight,
                                          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                                          border: Border.all(color: AppColors.borderLight),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Business Justification / Request Scope:',
                                              style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              appr.reason!,
                                              style: AppTypography.bodyMd,
                                            ),
                                          ],
                                        ),
                                      ),
                                    const SizedBox(height: 16),
                                    Wrap(
                                      alignment: WrapAlignment.spaceBetween,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        TextButton.icon(
                                          onPressed: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => CaseDetailScreen(caseId: appr.caseId),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.launch, size: 16),
                                          label: const Text('View Case Workspace'),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SecondaryButton(
                                              label: 'Reject',
                                              onPressed: () => _showDecisionDialog(context, appr.id, 'rejected'),
                                            ),
                                            const SizedBox(width: 8),
                                            PrimaryButton(
                                              label: 'Approve',
                                              onPressed: () => _showDecisionDialog(context, appr.id, 'approved'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
