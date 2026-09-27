import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/dimensions.dart';
import '../../../shared/theme/typography.dart';
import '../../../shared/widgets/custom_buttons.dart';
import '../providers/major_incident_provider.dart';

class DeclareMajorIncidentDialog extends StatefulWidget {
  final String? initialCaseId;

  const DeclareMajorIncidentDialog({super.key, this.initialCaseId});

  @override
  State<DeclareMajorIncidentDialog> createState() => _DeclareMajorIncidentDialogState();
}

class _DeclareMajorIncidentDialogState extends State<DeclareMajorIncidentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _caseIdCtrl;
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _impactCtrl = TextEditingController();
  final TextEditingController _bridgeUrlCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _caseIdCtrl = TextEditingController(text: widget.initialCaseId ?? '');
  }

  @override
  void dispose() {
    _caseIdCtrl.dispose();
    _titleCtrl.dispose();
    _impactCtrl.dispose();
    _bridgeUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() => _isSubmitting = true);

    final provider = context.read<MajorIncidentProvider>();
    final success = await provider.declareMajorIncident(
      caseId: _caseIdCtrl.text.trim(),
      title: _titleCtrl.text.trim(),
      impactSummary: _impactCtrl.text.trim().isNotEmpty ? _impactCtrl.text.trim() : null,
      bridgeUrl: _bridgeUrlCtrl.text.trim().isNotEmpty ? _bridgeUrlCtrl.text.trim() : null,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success != null) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Major Incident Declared Successfully! War Room Active.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'Failed to declare Major Incident'),
            backgroundColor: AppColors.priorityP1,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.space2xs),
            decoration: BoxDecoration(
              color: AppColors.priorityP1.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.campaign_outlined, color: AppColors.priorityP1, size: 24),
          ),
          const SizedBox(width: AppDimensions.spaceSm),
          Text('Declare Major Incident (P1)', style: AppTypography.headlineSm),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppDimensions.spaceSm),
                  decoration: BoxDecoration(
                    color: AppColors.priorityP1.withValues(alpha: 0.08),
                    borderRadius: AppDimensions.cardBorderRadius,
                    border: Border.all(color: AppColors.priorityP1.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.priorityP1, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Declaring a Major Incident activates the Command Bridge, alerts incident commanders, and initiates emergency SLA tracking.',
                          style: AppTypography.bodySm.copyWith(color: AppColors.textPrimaryLight),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceMd),
                TextFormField(
                  key: const Key('majorIncidentCaseIdField'),
                  controller: _caseIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Root Case ID (UUID) *',
                    hintText: 'e.g. 550e8400-e29b-41d4-a716-446655440000',
                    prefixIcon: Icon(Icons.confirmation_number_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Root Case ID is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDimensions.spaceMd),
                TextFormField(
                  key: const Key('majorIncidentTitleField'),
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Incident Title / Summary *',
                    hintText: 'e.g. Core Payment Gateway Outage - High Latency & 500s',
                    prefixIcon: Icon(Icons.title_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Incident title is required';
                    }
                    if (val.trim().length < 3) {
                      return 'Title must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDimensions.spaceMd),
                TextFormField(
                  key: const Key('majorIncidentImpactField'),
                  controller: _impactCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Operational / Business Impact',
                    hintText: 'e.g. Impacting 100% of checkout transactions in EU region.',
                    prefixIcon: Icon(Icons.warning_amber_outlined),
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceMd),
                TextFormField(
                  key: const Key('majorIncidentBridgeUrlField'),
                  controller: _bridgeUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'War-Room / Bridge Video URL',
                    hintText: 'e.g. https://meet.google.com/fin-war-room',
                    prefixIcon: Icon(Icons.video_call_outlined),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        SecondaryButton(
          label: 'Cancel',
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: AppDimensions.spaceSm),
        PrimaryButton(
          key: const Key('declareIncidentSubmitBtn'),
          label: _isSubmitting ? 'Declaring...' : 'Declare Incident',
          icon: Icons.flash_on_outlined,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
    );
  }
}
