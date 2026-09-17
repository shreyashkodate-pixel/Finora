import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/accessible_button.dart';
import '../../../shared/widgets/status_badge.dart';
import '../providers/autofix_provider.dart';

class AutoFixPanelWidget extends StatefulWidget {
  final String caseId;

  const AutoFixPanelWidget({super.key, required this.caseId});

  @override
  State<AutoFixPanelWidget> createState() => _AutoFixPanelWidgetState();
}

class _AutoFixPanelWidgetState extends State<AutoFixPanelWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AutoFixProvider>().fetchActionsForCase(widget.caseId);
    });
  }

  void _openProposeDialog() {
    String actionType = 'service_restart';
    final paramCtrl = TextEditingController(text: 'nginx');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Propose Auto-Fix Remediation'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: actionType,
                  decoration: const InputDecoration(labelText: 'Action Type'),
                  items: const [
                    DropdownMenuItem(value: 'service_restart', child: Text('Service Restart')),
                    DropdownMenuItem(value: 'dns_flush', child: Text('DNS Cache Flush')),
                    DropdownMenuItem(value: 'account_unlock', child: Text('Account Unlock (LDAP)')),
                    DropdownMenuItem(value: 'cache_clear', child: Text('Cache Clear')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() {
                        actionType = v;
                        if (v == 'service_restart') paramCtrl.text = 'nginx';
                        if (v == 'account_unlock') paramCtrl.text = 'user.name';
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                if (actionType == 'service_restart')
                  TextField(
                    controller: paramCtrl,
                    decoration: const InputDecoration(labelText: 'Target Service Name', hintText: 'nginx, postgresql, etc.'),
                  )
                else if (actionType == 'account_unlock')
                  TextField(
                    controller: paramCtrl,
                    decoration: const InputDecoration(labelText: 'Target Username', hintText: 'e.g. john.doe'),
                  ),
              ],
            ),
          ),
          actions: [
            AccessibleButton(
              label: 'Cancel',
              isSecondary: true,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            AccessibleButton(
              label: 'Propose Action',
              onPressed: () async {
                Map<String, dynamic> params = {};
                if (actionType == 'service_restart') params['service_name'] = paramCtrl.text.trim();
                if (actionType == 'account_unlock') params['username'] = paramCtrl.text.trim();

                final created = await context.read<AutoFixProvider>().proposeAutoFix(
                      caseId: widget.caseId,
                      actionType: actionType,
                      parameters: params,
                    );
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  if (created != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Auto-fix action proposed')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AutoFixProvider>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_fix_high, color: AppColors.primaryLight),
                    SizedBox(width: 8),
                    Text(
                      'Controlled Auto-Fix Remediation',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                AccessibleButton(
                  label: 'Propose Fix',
                  icon: Icons.add,
                  isSecondary: true,
                  onPressed: _openProposeDialog,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (provider.isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
            else if (provider.actions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No remediation actions recorded for this case.', style: TextStyle(color: AppColors.textSecondaryLight)),
              )
            else
              ...provider.actions.map((act) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              act.actionType.toUpperCase().replaceAll('_', ' '),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            StatusBadge(status: act.status),
                          ],
                        ),
                        if (act.parameters.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('Parameters: ${act.parameters}', style: const TextStyle(fontSize: 12)),
                        ],
                        if (act.executionOutput != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              act.executionOutput!,
                              style: const TextStyle(color: Colors.lightGreenAccent, fontFamily: 'monospace', fontSize: 11),
                            ),
                          ),
                        ],
                        if (act.rollbackOutput != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              act.rollbackOutput!,
                              style: const TextStyle(color: Colors.orangeAccent, fontFamily: 'monospace', fontSize: 11),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (act.status == 'pending') ...[
                              AccessibleButton(
                                label: 'Dry Run',
                                isSecondary: true,
                                onPressed: () => provider.executeAutoFix(act.id, dryRun: true),
                              ),
                              const SizedBox(width: 8),
                              AccessibleButton(
                                label: 'Execute Action',
                                icon: Icons.play_arrow,
                                onPressed: () => provider.executeAutoFix(act.id, dryRun: false),
                              ),
                            ] else if (act.status == 'success') ...[
                              AccessibleButton(
                                label: 'Rollback',
                                icon: Icons.undo,
                                isSecondary: true,
                                onPressed: () => provider.rollbackAutoFix(act.id),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
