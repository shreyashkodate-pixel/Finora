import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/dimensions.dart';
import '../../../shared/theme/typography.dart';
import '../../../shared/widgets/custom_buttons.dart';
import '../providers/change_provider.dart';

class CreateChangeDialog extends StatefulWidget {
  final String? initialProblemId;

  const CreateChangeDialog({super.key, this.initialProblemId});

  @override
  State<CreateChangeDialog> createState() => _CreateChangeDialogState();
}

class _CreateChangeDialogState extends State<CreateChangeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _reasonController = TextEditingController();
  final _implPlanController = TextEditingController();
  final _testPlanController = TextEditingController();
  final _rollbackPlanController = TextEditingController();

  String _riskLevel = 'low';
  String _changeType = 'normal';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _reasonController.dispose();
    _implPlanController.dispose();
    _testPlanController.dispose();
    _rollbackPlanController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final provider = context.read<ChangeProvider>();

    final created = await provider.createChangeRequest(
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      reason: _reasonController.text.trim(),
      riskLevel: _riskLevel,
      changeType: _changeType,
      implementationPlan: _implPlanController.text.trim(),
      testPlan: _testPlanController.text.trim(),
      rollbackPlan: _rollbackPlanController.text.trim(),
      problemId: widget.initialProblemId,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (created != null) {
        Navigator.of(context).pop(created);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Change Request ${created.changeNumber} submitted successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'Failed to submit Change Request'),
            backgroundColor: AppColors.priorityP1,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusDialog)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650, maxHeight: 750),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceLg),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Request for Change (RFC)',
                          style: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Change Title *',
                      hintText: 'e.g. Upgrade PostgreSQL cluster to 16.4',
                    ),
                    validator: (v) => (v == null || v.trim().length < 3) ? 'Title required (min 3 chars)' : null,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _changeType,
                          decoration: const InputDecoration(labelText: 'Change Type *'),
                          items: const [
                            DropdownMenuItem(value: 'standard', child: Text('Standard (Pre-approved)', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'normal', child: Text('Normal (Requires CAB)', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'emergency', child: Text('Emergency (ECAB)', overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _changeType = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _riskLevel,
                          decoration: const InputDecoration(labelText: 'Risk Level *'),
                          items: const [
                            DropdownMenuItem(value: 'low', child: Text('Low Risk', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'moderate', child: Text('Moderate Risk', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'high', child: Text('High Risk', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'critical', child: Text('Critical Risk', overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _riskLevel = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _reasonController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Business / Technical Justification *',
                      hintText: 'Why is this change necessary? What risk does it mitigate?',
                    ),
                    validator: (v) => (v == null || v.trim().length < 5) ? 'Justification required (min 5 chars)' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _descController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Scope & Detailed Description *',
                      hintText: 'Systems, services, and components affected...',
                    ),
                    validator: (v) => (v == null || v.trim().length < 5) ? 'Scope description required (min 5 chars)' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _implPlanController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Implementation Plan (Step-by-Step) *',
                      hintText: '1. Drain connections\n2. Apply migration\n3. Restart workers',
                    ),
                    validator: (v) => (v == null || v.trim().length < 5) ? 'Implementation plan required' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _testPlanController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Post-Implementation Test & Validation Plan *',
                      hintText: 'Verification procedures, smoke tests, health check endpoints...',
                    ),
                    validator: (v) => (v == null || v.trim().length < 5) ? 'Test plan required' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _rollbackPlanController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Rollback & Backout Contingency Plan *',
                      hintText: 'Exact remediation steps if post-implementation validation fails...',
                    ),
                    validator: (v) => (v == null || v.trim().length < 5) ? 'Rollback plan required' : null,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SecondaryButton(
                        label: 'Cancel',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 12),
                      PrimaryButton(
                        label: 'Submit RFC',
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
      ),
    );
  }
}
