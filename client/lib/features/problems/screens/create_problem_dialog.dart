import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/accessible_button.dart';
import '../providers/problem_provider.dart';

class CreateProblemDialog extends StatefulWidget {
  final String? initialCaseId;

  const CreateProblemDialog({super.key, this.initialCaseId});

  @override
  State<CreateProblemDialog> createState() => _CreateProblemDialogState();
}

class _CreateProblemDialogState extends State<CreateProblemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _rootCauseController = TextEditingController();
  final _workaroundController = TextEditingController();
  String _priority = 'p3';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _rootCauseController.dispose();
    _workaroundController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final provider = context.read<ProblemProvider>();

    final created = await provider.createProblem(
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      priority: _priority,
      rootCause: _rootCauseController.text.trim().isNotEmpty
          ? _rootCauseController.text.trim()
          : null,
      workaround: _workaroundController.text.trim().isNotEmpty
          ? _workaroundController.text.trim()
          : null,
      caseIds: widget.initialCaseId != null ? [widget.initialCaseId!] : null,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (created != null) {
        Navigator.of(context).pop(created);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Problem ${created.problemNumber} created successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'Failed to create problem'),
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
        constraints: const BoxConstraints(maxWidth: 550),
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
                        'Create ITIL Problem Record',
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
                    decoration: const InputDecoration(
                      labelText: 'Problem Title *',
                      hintText: 'e.g. Recurrent Gateway Timeout on Checkout',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().length < 3) ? 'Title must be at least 3 characters' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Detailed Problem Description *',
                      hintText: 'Describe recurring incident patterns and impact',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().length < 5) ? 'Description must be at least 5 characters' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _priority,
                    decoration: const InputDecoration(labelText: 'Priority Level'),
                    items: const [
                      DropdownMenuItem(value: 'p1', child: Text('P1 - Critical')),
                      DropdownMenuItem(value: 'p2', child: Text('P2 - High')),
                      DropdownMenuItem(value: 'p3', child: Text('P3 - Medium')),
                      DropdownMenuItem(value: 'p4', child: Text('P4 - Low')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _priority = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _rootCauseController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Known Root Cause (Optional)',
                      hintText: 'Underlying hardware, software, or network defect',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _workaroundController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Workaround (Optional)',
                      hintText: 'Temporary workaround to mitigate recurrence',
                    ),
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
                        label: 'Create Problem',
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
