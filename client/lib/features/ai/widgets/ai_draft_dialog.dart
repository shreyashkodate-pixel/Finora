import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/accessible_button.dart';
import '../providers/ai_provider.dart';

/// Interactive AI Communication Draft Assistant with Human-in-the-Loop review per SRS §5.9.
class AIDraftDialog extends StatefulWidget {
  final String caseId;

  const AIDraftDialog({super.key, required this.caseId});

  @override
  State<AIDraftDialog> createState() => _AIDraftDialogState();
}

class _AIDraftDialogState extends State<AIDraftDialog> {
  String _selectedType = 'progress_update';
  final _draftController = TextEditingController();
  bool _hasGenerated = false;

  final List<Map<String, String>> _draftTypes = [
    {'value': 'progress_update', 'label': 'Progress Update to Requester'},
    {'value': 'info_request', 'label': 'Request Additional Information'},
    {'value': 'resolution', 'label': 'Resolution & Confirmation Message'},
    {'value': 'escalation_summary', 'label': 'Managerial Escalation Summary'},
  ];

  @override
  void dispose() {
    _draftController.dispose();
    super.dispose();
  }

  Future<void> _handleGenerate() async {
    final aiProv = context.read<AIProvider>();
    final draft = await aiProv.generateDraft(widget.caseId, _selectedType);
    if (draft != null && mounted) {
      setState(() {
        _draftController.text = draft.body;
        _hasGenerated = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final aiProv = context.watch<AIProvider>();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.auto_awesome, color: AppColors.aiAccent, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'AI Communication Assistant',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Draft type selector
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(labelText: 'Select Draft Intent'),
                items: _draftTypes.map((d) {
                  return DropdownMenuItem(value: d['value'], child: Text(d['label']!));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedType = val);
                },
              ),
              const SizedBox(height: 16),

              // Generate Button
              AccessibleButton(
                onPressed: _handleGenerate,
                isLoading: aiProv.isLoading,
                semanticLabel: 'Generate AI communication draft',
                icon: Icons.auto_awesome,
                child: const Text('Generate Draft with Gemini'),
              ),
              const SizedBox(height: 16),

              // Preview & Edit Area
              if (_hasGenerated) ...[
                const Text(
                  'Human Review & Edit (Changes will be inserted into reply):',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _draftController,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Edit generated draft before using...',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Discard'),
                    ),
                    const SizedBox(width: 12),
                    AccessibleButton(
                      onPressed: () {
                        Navigator.of(context).pop(_draftController.text);
                      },
                      semanticLabel: 'Use this draft in message composer',
                      child: const Text('Use in Message Composer'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
