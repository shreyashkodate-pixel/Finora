import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/accessible_button.dart';
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                      const Text(
                        'Request for Change (RFC)',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                    decoration: const InputDecoration(labelText: 'Change Title *', hintText: 'e.g. Upgrade PostgreSQL to 16.4'),
                    validator: (v) => (v == null || v.trim().length < 3) ? 'Title required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _changeType,
                          decoration: const InputDecoration(labelText: 'Change Type'),
                          items: const [
                            DropdownMenuItem(value: 'standard', child: Text('Standard (Pre-approved)')),
                            DropdownMenuItem(value: 'normal', child: Text('Normal (Requires CAB)')),
                            DropdownMenuItem(value: 'emergency', child: Text('Emergency (ECAB)')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _changeType = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _riskLevel,
                          decoration: const InputDecoration(labelText: 'Risk Level'),
                          items: const [
                            DropdownMenuItem(value: 'low', child: Text('Low Risk')),
                            DropdownMenuItem(value: 'moderate', child: Text('Moderate Risk')),
                            DropdownMenuItem(value: 'high', child: Text('High Risk')),
                            DropdownMenuItem(value: 'critical', child: Text('Critical Risk')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _riskLevel = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _reasonController,
                    decoration: const InputDecoration(labelText: 'Business / Technical Justification *'),
                    validator: (v) => (v == null || v.trim().length < 5) ? 'Justification required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Scope & Description *'),
                    validator: (v) => (v == null || v.trim().length < 5) ? 'Scope description required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _implPlanController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Implementation Plan (Step-by-step) *'),
                    validator: (v) => (v == null || v.trim().length < 5) ? 'Implementation plan required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _testPlanController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Post-Implementation Test Plan *'),
                    validator: (v) => (v == null || v.trim().length < 5) ? 'Test plan required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _rollbackPlanController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Rollback & Contingency Plan *'),
                    validator: (v) => (v == null || v.trim().length < 5) ? 'Rollback plan required' : null,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AccessibleButton(
                        label: 'Cancel',
                        isSecondary: true,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 12),
                      AccessibleButton(
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
