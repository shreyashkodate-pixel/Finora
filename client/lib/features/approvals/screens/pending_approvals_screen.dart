import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/colors.dart';
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

  @override
  Widget build(BuildContext context) {
    final apprProv = context.watch<ApprovalProvider>();
    final pending = apprProv.pendingApprovals;

    return Scaffold(
      body: apprProv.isLoading
          ? const Center(child: CircularProgressIndicator())
          : pending.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.check_circle_outline, size: 48, color: AppColors.slaHealthy),
                      SizedBox(height: 12),
                      Text('All caught up!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text(
                        'No pending business authorization requests requiring your decision.',
                        style: TextStyle(color: AppColors.textSecondaryLight),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => apprProv.fetchPendingApprovals(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: pending.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final appr = pending[index];
                      final timeStr = DateFormat('MMM d, h:mm a').format(appr.createdAt.toLocal());

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.pending_actions, color: AppColors.statusAwaiting, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Approval Request',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                  Text(timeStr, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (appr.reason != null)
                                Text(
                                  'Justification: ${appr.reason!}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                    children: [
                                      OutlinedButton(
                                        onPressed: () async {
                                          await apprProv.decideApproval(
                                            approvalId: appr.id,
                                            decision: 'rejected',
                                            reason: 'Rejected from Pending Approvals Inbox',
                                          );
                                          if (context.mounted) {
                                            context.read<CaseProvider>().fetchCases();
                                          }
                                        },
                                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.priorityP1),
                                        child: const Text('Reject'),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: () async {
                                          await apprProv.decideApproval(
                                            approvalId: appr.id,
                                            decision: 'approved',
                                            reason: 'Approved from Pending Approvals Inbox',
                                          );
                                          if (context.mounted) {
                                            context.read<CaseProvider>().fetchCases();
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.slaHealthy),
                                        child: const Text('Approve'),
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
    );
  }
}
