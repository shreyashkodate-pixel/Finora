import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/dimensions.dart';
import '../../../shared/theme/typography.dart';
import '../../../shared/widgets/custom_buttons.dart';
import '../models/alert_model.dart';
import '../providers/alert_provider.dart';

/// Modal dialog for creating automated Alert Transformation & Routing rules
class CreateRuleDialog extends StatefulWidget {
  const CreateRuleDialog({super.key});

  @override
  State<CreateRuleDialog> createState() => _CreateRuleDialogState();
}

class _CreateRuleDialogState extends State<CreateRuleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _keywordCtrl = TextEditingController();

  AlertProviderEnum _selectedProvider = AlertProviderEnum.generic;
  String _selectedSeverity = 'critical';
  bool _autoCreateIncident = true;
  String _selectedPriority = 'p2';
  bool _isSubmitting = false;

  final List<String> _severityOptions = ['critical', 'high', 'warning', 'info'];
  final List<String> _priorityOptions = ['p1', 'p2', 'p3', 'p4'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _keywordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() => _isSubmitting = true);

    final payload = AlertRuleCreatePayload(
      name: _nameCtrl.text.trim(),
      provider: _selectedProvider,
      matchSeverity: _selectedSeverity.isNotEmpty ? _selectedSeverity : null,
      matchKeyword: _keywordCtrl.text.trim().isNotEmpty ? _keywordCtrl.text.trim() : null,
      autoCreateIncident: _autoCreateIncident,
      incidentPriority: _selectedPriority,
    );

    final provider = context.read<AlertProvider>();
    final success = await provider.createRule(payload);

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alert rule created successfully.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Failed to create rule.'),
            backgroundColor: AppColors.priorityP1,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: AppDimensions.cardBorderRadius,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.spaceLg),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dialog Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.12),
                        borderRadius: AppDimensions.priorityBorderRadius,
                      ),
                      child: const Icon(Icons.tune_rounded, color: AppColors.primaryBlue, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create Alert Rule',
                            style: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Automate priority routing and incident auto-creation',
                            style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),

                const Divider(height: 24),

                // Rule Name
                Text('Rule Name', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    hintText: 'e.g., PostgreSQL Connection Pool Exhaustion',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length < 2) {
                      return 'Rule name must be at least 2 characters.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppDimensions.spaceMd),

                // Provider & Severity Row
                Row(
                  children: [
                    // Provider Dropdown
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Provider', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<AlertProviderEnum>(
                            isExpanded: true,
                            initialValue: _selectedProvider,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            items: AlertProviderEnum.values
                                .where((p) => p != AlertProviderEnum.all)
                                .map((p) => DropdownMenuItem(
                                      value: p,
                                      child: Text(p.displayName, overflow: TextOverflow.ellipsis),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedProvider = val);
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Severity Dropdown
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Match Severity', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _selectedSeverity,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            items: _severityOptions
                                .map((s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(s.toUpperCase(), overflow: TextOverflow.ellipsis),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedSeverity = val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppDimensions.spaceMd),

                // Match Keyword
                Text('Match Keyword (Optional)', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _keywordCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Keyword in alert title/description (e.g., Redis, OOM)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),

                const SizedBox(height: AppDimensions.spaceMd),

                // Auto-create Incident Switch & Priority
                Container(
                  padding: const EdgeInsets.all(AppDimensions.spaceMd),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: AppDimensions.cardBorderRadius,
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Auto-Create Incident Case', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          subtitle: const Text('Automatically generate an authoritative Case with SLA targets upon alert arrival.', style: TextStyle(fontSize: 11)),
                          value: _autoCreateIncident,
                          onChanged: (val) => setState(() => _autoCreateIncident = val),
                        ),
                      ),
                      if (_autoCreateIncident) ...[
                        const Divider(height: 16),
                        Row(
                          children: [
                            const Text('Incident Priority: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                            const Spacer(),
                            DropdownButton<String>(
                              value: _selectedPriority,
                              items: _priorityOptions
                                  .map((p) => DropdownMenuItem(
                                        value: p,
                                        child: Text(p.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                      ))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedPriority = val);
                              },
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: AppDimensions.spaceLg),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SecondaryButton(
                      label: 'Cancel',
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    const SizedBox(width: 12),
                    PrimaryButton(
                      label: 'Create Rule',
                      isLoading: _isSubmitting,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
