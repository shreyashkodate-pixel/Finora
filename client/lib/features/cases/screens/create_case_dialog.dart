import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/dimensions.dart';
import '../../../shared/theme/typography.dart';
import '../../../shared/widgets/custom_buttons.dart';
import '../../../shared/widgets/priority_badge.dart';
import '../providers/case_provider.dart';

/// Modal Wizard for submitting a new Incident or Service Request per SRS §4.1 & Stitch Screen 3.
class CreateCaseDialog extends StatefulWidget {
  final String initialType;
  final String? initialTitle;

  const CreateCaseDialog({
    super.key,
    this.initialType = 'incident',
    this.initialTitle,
  });

  @override
  State<CreateCaseDialog> createState() => _CreateCaseDialogState();
}

class _CreateCaseDialogState extends State<CreateCaseDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  final _descriptionController = TextEditingController();
  final _siteController = TextEditingController(text: 'Campus North');

  late String _selectedType;
  String _selectedPriority = 'p3';
  int _currentStep = 0;
  final List<String> _attachedFileNames = [];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _siteController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _currentStep = 0);
      return;
    }

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

  void _addMockAttachment() {
    if (_attachedFileNames.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 5 initial attachments allowed.')),
      );
      return;
    }
    setState(() {
      final idx = _attachedFileNames.length + 1;
      _attachedFileNames.add('system_log_evidence_$idx.log');
    });
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachedFileNames.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final caseProv = context.watch<CaseProvider>();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusCard)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceLg),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Block with Overline & Close Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'TRIAGE ORCHESTRATOR',
                                  style: AppTypography.labelSm.copyWith(
                                    color: AppColors.primaryBlue,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: const BoxDecoration(
                                    color: AppColors.borderDark,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'INTAKE-MOD-03',
                                  style: AppTypography.codeMd.copyWith(
                                    fontSize: 11,
                                    color: AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Submit a Support Case',
                              style: AppTypography.headlineMd,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Close dialog',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.spaceMd),

                  // Linear Step Progress Bar
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.spaceSm),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Row(
                      children: [
                        _buildStepIndicator(
                          stepIndex: 0,
                          stepNumber: '01',
                          title: 'Issue Context',
                          subtitle: 'Classify & Describe',
                          isActive: _currentStep == 0,
                          isCompleted: _currentStep > 0,
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right, size: 16, color: AppColors.textSecondaryLight),
                        const SizedBox(width: 8),
                        _buildStepIndicator(
                          stepIndex: 1,
                          stepNumber: '02',
                          title: 'Evidence',
                          subtitle: 'Logs & Files',
                          isActive: _currentStep == 1,
                          isCompleted: _currentStep > 1,
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right, size: 16, color: AppColors.textSecondaryLight),
                        const SizedBox(width: 8),
                        _buildStepIndicator(
                          stepIndex: 2,
                          stepNumber: '03',
                          title: 'Review',
                          subtitle: 'Confirm & Send',
                          isActive: _currentStep == 2,
                          isCompleted: false,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceMd),

                  // Error Banner
                  if (caseProv.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.spaceSm),
                      decoration: BoxDecoration(
                        color: AppColors.priorityP1.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                        border: Border.all(color: AppColors.priorityP1.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.priorityP1, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              caseProv.errorMessage!,
                              style: AppTypography.bodySm.copyWith(color: AppColors.priorityP1),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spaceMd),
                  ],

                  // STEP 0: Issue Context
                  if (_currentStep == 0) ...[
                    // Case Type Selector
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'incident',
                          label: Text('Report Incident'),
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
                    const SizedBox(height: AppDimensions.spaceMd),

                    // Title Field
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Case Title *',
                        hintText: 'e.g. VPN gateway connection timeout during peak hours',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Title is required.';
                        if (val.trim().length < 5) return 'Title must be at least 5 characters.';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppDimensions.spaceMd),

                    // Priority Selector
                    DropdownButtonFormField<String>(
                      initialValue: _selectedPriority,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Initial Priority Level *'),
                      items: const [
                        DropdownMenuItem(value: 'p1', child: Text('P1 - Critical (Outage / System Down)')),
                        DropdownMenuItem(value: 'p2', child: Text('P2 - High (Severe Degradation)')),
                        DropdownMenuItem(value: 'p3', child: Text('P3 - Medium (Normal Business Need)')),
                        DropdownMenuItem(value: 'p4', child: Text('P4 - Low (General Inquiry / Minor)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedPriority = val);
                      },
                    ),
                    const SizedBox(height: AppDimensions.spaceMd),

                    // Description Field
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      minLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Detailed Description *',
                        hintText: 'Provide error codes, affected systems, and steps to reproduce...',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Description is required.';
                        if (val.trim().length < 10) return 'Please provide more details (minimum 10 characters).';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppDimensions.spaceMd),

                    // Site Location
                    TextFormField(
                      controller: _siteController,
                      decoration: const InputDecoration(
                        labelText: 'Physical Site / Campus',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                  ],

                  // STEP 1: Evidence & Attachments
                  if (_currentStep == 1) ...[
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.spaceLg),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundLight,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                        border: Border.all(color: AppColors.borderLight, style: BorderStyle.solid),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.cloud_upload_outlined, size: 40, color: AppColors.primaryBlue),
                          const SizedBox(height: 8),
                          Text(
                            'Attach Diagnostic Evidence or Screenshots',
                            style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Accepted formats: .log, .txt, .png, .jpg, .pdf (Max 10MB/file, 50MB case total)',
                            style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          CustomButtons.secondary(
                            text: 'Select Evidence File',
                            icon: Icons.attach_file,
                            onPressed: _addMockAttachment,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spaceMd),

                    if (_attachedFileNames.isNotEmpty) ...[
                      Text(
                        'Attached Files (${_attachedFileNames.length})',
                        style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ..._attachedFileNames.asMap().entries.map((entry) {
                        final index = entry.key;
                        final name = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.insert_drive_file_outlined, size: 18, color: AppColors.primaryBlue),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(name, style: AppTypography.bodySm),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16, color: AppColors.textSecondaryLight),
                                onPressed: () => _removeAttachment(index),
                                tooltip: 'Remove file',
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],

                  // STEP 2: Review & Submit
                  if (_currentStep == 2) ...[
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.spaceMd),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundLight,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  _selectedType == 'incident' ? 'INCIDENT REPORT' : 'SERVICE REQUEST',
                                  style: AppTypography.labelSm.copyWith(
                                    color: _selectedType == 'incident' ? AppColors.priorityP1 : AppColors.primaryBlue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              PriorityBadge(priority: _selectedPriority),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _titleController.text.trim().isNotEmpty
                                ? _titleController.text.trim()
                                : 'No Title Entered',
                            style: AppTypography.headlineSm,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _descriptionController.text.trim().isNotEmpty
                                ? _descriptionController.text.trim()
                                : 'No description provided.',
                            style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                          ),
                          const Divider(height: 20),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondaryLight),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Site: ${_siteController.text.trim().isNotEmpty ? _siteController.text.trim() : "Campus North"}',
                                  style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.attach_file, size: 14, color: AppColors.textSecondaryLight),
                              const SizedBox(width: 4),
                              Text(
                                '${_attachedFileNames.length} file(s) attached',
                                style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: AppDimensions.spaceLg),

                  // Wizard Navigation & Submit Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentStep > 0)
                        CustomButtons.secondary(
                          text: 'Back',
                          icon: Icons.arrow_back,
                          onPressed: () => setState(() => _currentStep--),
                        )
                      else
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                      if (_currentStep < 2)
                        CustomButtons.primary(
                          text: 'Continue',
                          icon: Icons.arrow_forward,
                          onPressed: () {
                            if (_currentStep == 0 && !_formKey.currentState!.validate()) {
                              return;
                            }
                            setState(() => _currentStep++);
                          },
                        )
                      else
                        CustomButtons.primary(
                          text: 'Submit Ticket',
                          icon: Icons.send,
                          isLoading: caseProv.isActionLoading,
                          onPressed: _handleSubmit,
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

  Widget _buildStepIndicator({
    required int stepIndex,
    required String stepNumber,
    required String title,
    required String subtitle,
    required bool isActive,
    required bool isCompleted,
  }) {
    final bgColor = isActive
        ? AppColors.primaryBlue
        : isCompleted
            ? AppColors.slaHealthy
            : AppColors.borderLight;
    final fgColor = (isActive || isCompleted) ? Colors.white : AppColors.textSecondaryLight;

    return Expanded(
      child: InkWell(
        onTap: () {
          if (isCompleted || stepIndex < _currentStep) {
            setState(() => _currentStep = stepIndex);
          }
        },
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : Text(
                        stepNumber,
                        style: TextStyle(color: fgColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTypography.labelSm.copyWith(
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      color: isActive ? AppColors.textPrimaryLight : AppColors.textSecondaryLight,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
