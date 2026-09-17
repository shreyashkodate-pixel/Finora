import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/accessible_button.dart';
import '../../../shared/widgets/status_badge.dart';
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
  String? _selectedStatus;
  String? _selectedType;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChangeProvider>().fetchChanges();
    });
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
        title: Text('CAB Review: ${change.changeNumber}'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Title: ${change.title}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Type: ${change.changeType.toUpperCase()} | Risk: ${change.riskLevel.toUpperCase()}'),
              const SizedBox(height: 8),
              Text('Reason: ${change.reason}'),
              const SizedBox(height: 12),
              TextField(
                controller: feedbackCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'CAB Assessment & Feedback',
                  hintText: 'Enter approval conditions or rejection reasons...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          AccessibleButton(
            label: 'Reject RFC',
            isSecondary: true,
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
                    const SnackBar(content: Text('Change Request Rejected')),
                  );
                }
              }
            },
          ),
          AccessibleButton(
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
                    const SnackBar(content: Text('Change Request Approved')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChangeProvider>();
    final auth = context.watch<AuthProvider>();
    final isStaff = auth.currentUser?.isStaff ?? false;
    final isManager = auth.currentUser?.role == 'manager' || auth.currentUser?.role == 'team_lead' || auth.currentUser?.role == 'administrator';
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Change Advisory Board (CAB) & RFCs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Changes',
            onPressed: () => provider.fetchChanges(status: _selectedStatus, type: _selectedType),
          ),
          if (isStaff) ...[
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: AccessibleButton(
                label: 'Submit RFC',
                icon: Icons.add,
                onPressed: _openCreateDialog,
              ),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Filter toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Row(
              children: [
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
                const SizedBox(width: 16),
                DropdownButton<String?>(
                  value: _selectedType,
                  hint: const Text('All Change Types'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All Change Types')),
                    DropdownMenuItem(value: 'standard', child: Text('Standard')),
                    DropdownMenuItem(value: 'normal', child: Text('Normal')),
                    DropdownMenuItem(value: 'emergency', child: Text('Emergency')),
                  ],
                  onChanged: (v) {
                    setState(() => _selectedType = v);
                    provider.fetchChanges(status: _selectedStatus, type: _selectedType);
                  },
                ),
              ],
            ),
          ),

          // Content List
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.changes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.published_with_changes_outlined, size: 64, color: AppColors.textSecondaryLight),
                            const SizedBox(height: 16),
                            const Text(
                              'No Change Requests Found',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Submit RFCs and govern production changes with CAB review.',
                              style: TextStyle(color: AppColors.textSecondaryLight),
                            ),
                            if (isStaff) ...[
                              const SizedBox(height: 16),
                              AccessibleButton(
                                label: 'Create First RFC',
                                onPressed: _openCreateDialog,
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: provider.changes.length,
                        itemBuilder: (context, index) {
                          final change = provider.changes[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
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
                                          Text(
                                            change.changeNumber,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          const SizedBox(width: 8),
                                          StatusBadge(status: change.status),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryLight.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              change.changeType.toUpperCase(),
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        dateFormat.format(change.createdAt.toLocal()),
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    change.title,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 6),
                                  Text('Reason: ${change.reason}'),
                                  const SizedBox(height: 8),
                                  Text('📋 Implementation: ${change.implementationPlan}', style: Theme.of(context).textTheme.bodySmall),
                                  const SizedBox(height: 4),
                                  Text('↩️ Rollback Plan: ${change.rollbackPlan}', style: Theme.of(context).textTheme.bodySmall),
                                  if (change.cabFeedback != null) ...[
                                    const SizedBox(height: 8),
                                    Text('🏛️ CAB Feedback: ${change.cabFeedback}', style: const TextStyle(fontStyle: FontStyle.italic)),
                                  ],
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (change.status == 'pending_cab' && isManager) ...[
                                        AccessibleButton(
                                          label: 'CAB Review',
                                          icon: Icons.gavel,
                                          onPressed: () => _openCABDialog(change),
                                        ),
                                      ] else if (change.status == 'approved' && isStaff) ...[
                                        AccessibleButton(
                                          label: 'Start Implementation',
                                          icon: Icons.play_arrow,
                                          onPressed: () => provider.updateStatus(change.id, 'implementing'),
                                        ),
                                      ] else if (change.status == 'implementing' && isStaff) ...[
                                        AccessibleButton(
                                          label: 'Mark Completed',
                                          icon: Icons.check,
                                          onPressed: () => provider.updateStatus(change.id, 'completed'),
                                        ),
                                      ],
                                    ],
                                  ),
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
