import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/accessible_button.dart';
import '../../ai/models/ai_models.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cases/models/case_model.dart';
import '../../cases/providers/case_provider.dart';
import '../providers/approval_provider.dart';

/// Interactive Approval Panel on Case Workspace per SRS §4 & §6.1.
class ApprovalPanelWidget extends StatelessWidget {
  final CaseModel currentCase;

  const ApprovalPanelWidget({super.key, required this.currentCase});

  Color _getDecisionColor(String decision) {
    switch (decision.toLowerCase()) {
      case 'approved':
        return AppColors.slaHealthy;
      case 'rejected':
        return AppColors.priorityP1;
      case 'pending':
      default:
        return AppColors.statusAwaiting;
    }
  }

  void _showRequestDialog(BuildContext context) {
    final approverController = TextEditingController();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Request Business Authorization'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: approverController,
                decoration: const InputDecoration(
                  labelText: 'Approver User ID (Lead / Manager UUID)',
                  hintText: 'e.g. 00000000-0000-0000-0000-000000000000',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Business Justification',
                  hintText: 'Explain why approval is required for this action...',
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
                final approverId = approverController.text.trim();
                if (approverId.isEmpty) return;

                final apprProv = context.read<ApprovalProvider>();
                final caseProv = context.read<CaseProvider>();
                final ok = await apprProv.requestApproval(
                  caseId: currentCase.id,
                  approverId: approverId,
                  reason: reasonController.text.trim(),
                );
                if (ok) {
                  await caseProv.fetchCaseDetails(currentCase.id);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                }
              },
              child: const Text('Submit Request'),
            ),
          ],
        );
      },
    );
  }

  void _showDecisionDialog(BuildContext context, ApprovalModel approval, String decision) {
    final reasonController = TextEditingController();
    final isApprove = decision == 'approved';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(isApprove ? 'Confirm Approval' : 'Reject Authorization Request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isApprove
                    ? 'Are you sure you want to approve this request? The case will return to Assigned status for work to proceed.'
                    : 'Please provide the rejection reason for the requester and operator:',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: isApprove ? 'Notes (Optional)' : 'Rejection Reason *',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isApprove ? AppColors.slaHealthy : AppColors.priorityP1,
              ),
              onPressed: () async {
                if (!isApprove && reasonController.text.trim().isEmpty) return;

                final apprProv = context.read<ApprovalProvider>();
                final caseProv = context.read<CaseProvider>();
                final ok = await apprProv.decideApproval(
                  approvalId: approval.id,
                  decision: decision,
                  reason: reasonController.text.trim(),
                );
                if (ok) {
                  await caseProv.fetchCaseDetails(currentCase.id);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                }
              },
              child: Text(isApprove ? 'Approve' : 'Reject'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final apprProv = context.watch<ApprovalProvider>();
    final auth = context.watch<AuthProvider>();
    final approvals = apprProv.caseApprovals;
    final currentUser = auth.currentUser;
    final isStaff = currentUser?.isStaff ?? false;
    final canDecide = currentUser?.canApprove ?? false;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header & Request Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Approval Requests (${approvals.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (isStaff && currentCase.status == 'assigned')
                AccessibleButton(
                  onPressed: () => _showRequestDialog(context),
                  icon: Icons.approval,
                  semanticLabel: 'Request approval button',
                  child: const Text('Request Approval'),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Approvals List
          if (approvals.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'No approval requests recorded for this case.',
                  style: TextStyle(color: AppColors.textSecondaryLight),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: approvals.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final appr = approvals[index];
                  final decColor = _getDecisionColor(appr.decision);
                  final timeStr = DateFormat('MMM d, h:mm a').format(appr.createdAt.toLocal());
                  final isMyDecision = canDecide && appr.isPending;

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: decColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  appr.decision.toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: decColor,
                                  ),
                                ),
                              ),
                              Text(timeStr, style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (appr.reason != null && appr.reason!.isNotEmpty)
                            Text(
                              'Justification: ${appr.reason!}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          if (appr.decidedAt != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Decided on: ${DateFormat('MMM d, h:mm a').format(appr.decidedAt!.toLocal())}',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                            ),
                          ],

                          // Decision Actions (for Approver)
                          if (isMyDecision) ...[
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton(
                                  onPressed: () => _showDecisionDialog(context, appr, 'rejected'),
                                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.priorityP1),
                                  child: const Text('Reject'),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: () => _showDecisionDialog(context, appr, 'approved'),
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.slaHealthy),
                                  child: const Text('Approve'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
