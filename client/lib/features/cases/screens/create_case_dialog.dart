import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/accessible_button.dart';
import '../providers/case_provider.dart';

/// Modal dialog for submitting a new Incident or Service Request per SRS §4.1.
class CreateCaseDialog extends StatefulWidget {
  const CreateCaseDialog({super.key});

  @override
  State<CreateCaseDialog> createState() => _CreateCaseDialogState();
}

class _CreateCaseDialogState extends State<CreateCaseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _siteController = TextEditingController(text: 'Campus North');

  String _selectedType = 'incident';
  String _selectedPriority = 'p3';

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _siteController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final caseProv = context.read<CaseProvider>();
    final newCase = await caseProv.createCase(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      type: _selectedType,
      priority: _selectedPriority,
      site: _siteController.text.trim().isNotEmpty ? _siteController.text.trim() : null,
    );

    if (newCase != null && mounted) {
      Navigator.of(context).pop(newCase);
    }
  }

  @override
  Widget build(BuildContext context) {
    final caseProv = context.watch<CaseProvider>();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title & Close Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Submit Support Ticket',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Close dialog',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Error Banner
                  if (caseProv.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.priorityP1.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        caseProv.errorMessage!,
                        style: const TextStyle(color: AppColors.priorityP1, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Case Type Selector
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'incident',
                        label: Text('Incident'),
                        icon: Icon(Icons.report_problem_outlined, size: 16),
                      ),
                      ButtonSegment(
                        value: 'service_request',
                        label: Text('Service Request'),
                        icon: Icon(Icons.build_outlined, size: 16),
                      ),
                    ],
                    selected: {_selectedType},
                    onSelectionChanged: (newSelection) {
                      setState(() => _selectedType = newSelection.first);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Title Field
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Case Title',
                      hintText: 'e.g. VPN connection drops every 10 minutes',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Title is required.';
                      if (val.trim().length < 5) return 'Title must be at least 5 characters.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Priority Selector
                  DropdownButtonFormField<String>(
                    value: _selectedPriority,
                    decoration: const InputDecoration(labelText: 'Initial Priority'),
                    items: const [
                      DropdownMenuItem(value: 'p1', child: Text('P1 - Critical (System Outage)')),
                      DropdownMenuItem(value: 'p2', child: Text('P2 - High (Significant Degradation)')),
                      DropdownMenuItem(value: 'p3', child: Text('P3 - Medium (Normal Business Need)')),
                      DropdownMenuItem(value: 'p4', child: Text('P4 - Low (General Inquiry / Minor)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedPriority = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Description Field
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    minLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Detailed Description',
                      hintText: 'Describe what happened, error messages, and reproduction steps...',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Description is required.';
                      if (val.trim().length < 10) return 'Please provide more details (min 10 characters).';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Site Location
                  TextFormField(
                    controller: _siteController,
                    decoration: const InputDecoration(
                      labelText: 'Physical Site / Campus',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      AccessibleButton(
                        onPressed: _handleSubmit,
                        isLoading: caseProv.isActionLoading,
                        semanticLabel: 'Submit ticket button',
                        child: const Text('Submit Ticket', style: TextStyle(fontWeight: FontWeight.bold)),
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
