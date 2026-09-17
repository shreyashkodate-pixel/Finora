import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/accessible_button.dart';
import '../../../shared/widgets/status_badge.dart';
import '../models/problem_model.dart';
import '../providers/problem_provider.dart';
import 'create_problem_dialog.dart';

class ProblemWorkspaceScreen extends StatefulWidget {
  const ProblemWorkspaceScreen({super.key});

  @override
  State<ProblemWorkspaceScreen> createState() => _ProblemWorkspaceScreenState();
}

class _ProblemWorkspaceScreenState extends State<ProblemWorkspaceScreen> {
  String? _selectedStatus;
  String? _selectedPriority;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProblemProvider>().fetchProblems();
    });
  }

  void _openCreateDialog() {
    showDialog(
      context: context,
      builder: (_) => const CreateProblemDialog(),
    ).then((val) {
      if (val != null) {
        context.read<ProblemProvider>().fetchProblems();
      }
    });
  }

  void _openKnownErrorDialog(ProblemModel problem) {
    final titleCtrl = TextEditingController(text: 'KEDB: ${problem.title}');
    final symptomsCtrl = TextEditingController(text: problem.description);
    final workaroundCtrl = TextEditingController(text: problem.workaround ?? '');
    final fixCtrl = TextEditingController(text: problem.rootCause ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Publish Known Error (${problem.problemNumber})'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Article Title')),
                const SizedBox(height: 12),
                TextField(controller: symptomsCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Symptoms')),
                const SizedBox(height: 12),
                TextField(controller: workaroundCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Workaround *')),
                const SizedBox(height: 12),
                TextField(controller: fixCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Permanent Fix')),
              ],
            ),
          ),
        ),
        actions: [
          AccessibleButton(
            label: 'Cancel',
            isSecondary: true,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          AccessibleButton(
            label: 'Publish to KEDB',
            onPressed: () async {
              if (workaroundCtrl.text.trim().isEmpty) return;
              final ok = await context.read<ProblemProvider>().publishKnownError(
                    problemId: problem.id,
                    title: titleCtrl.text.trim(),
                    symptoms: symptomsCtrl.text.trim(),
                    workaround: workaroundCtrl.text.trim(),
                    permanentFix: fixCtrl.text.trim().isNotEmpty ? fixCtrl.text.trim() : null,
                  );
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Known Error published successfully')),
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
    final provider = context.watch<ProblemProvider>();
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Problem Management & KEDB'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Problems',
            onPressed: () => provider.fetchProblems(
              status: _selectedStatus,
              priority: _selectedPriority,
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: AccessibleButton(
              label: 'New Problem',
              icon: Icons.add,
              onPressed: _openCreateDialog,
            ),
          ),
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
                    DropdownMenuItem(value: 'open', child: Text('Open')),
                    DropdownMenuItem(value: 'investigating', child: Text('Investigating')),
                    DropdownMenuItem(value: 'known_error', child: Text('Known Error')),
                    DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                    DropdownMenuItem(value: 'closed', child: Text('Closed')),
                  ],
                  onChanged: (v) {
                    setState(() => _selectedStatus = v);
                    provider.fetchProblems(status: _selectedStatus, priority: _selectedPriority);
                  },
                ),
                const SizedBox(width: 16),
                DropdownButton<String?>(
                  value: _selectedPriority,
                  hint: const Text('All Priorities'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All Priorities')),
                    DropdownMenuItem(value: 'p1', child: Text('P1 - Critical')),
                    DropdownMenuItem(value: 'p2', child: Text('P2 - High')),
                    DropdownMenuItem(value: 'p3', child: Text('P3 - Medium')),
                    DropdownMenuItem(value: 'p4', child: Text('P4 - Low')),
                  ],
                  onChanged: (v) {
                    setState(() => _selectedPriority = v);
                    provider.fetchProblems(status: _selectedStatus, priority: _selectedPriority);
                  },
                ),
              ],
            ),
          ),

          // Content List
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.problems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.fact_check_outlined, size: 64, color: AppColors.textSecondaryLight),
                            const SizedBox(height: 16),
                            const Text(
                              'No Problem Records Found',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Track root causes and eliminate recurring incidents.',
                              style: TextStyle(color: AppColors.textSecondaryLight),
                            ),
                            const SizedBox(height: 16),
                            AccessibleButton(
                              label: 'Create First Problem',
                              onPressed: _openCreateDialog,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: provider.problems.length,
                        itemBuilder: (context, index) {
                          final prob = provider.problems[index];
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
                                            prob.problemNumber,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          const SizedBox(width: 8),
                                          PriorityBadge(priority: prob.priority),
                                          const SizedBox(width: 8),
                                          StatusBadge(status: prob.status),
                                        ],
                                      ),
                                      Text(
                                        dateFormat.format(prob.createdAt.toLocal()),
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    prob.title,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    prob.description,
                                    style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                                  ),
                                  if (prob.rootCause != null) ...[
                                    const SizedBox(height: 8),
                                    Text('🔍 Root Cause: ${prob.rootCause}',
                                        style: const TextStyle(fontWeight: FontWeight.w500)),
                                  ],
                                  if (prob.workaround != null) ...[
                                    const SizedBox(height: 4),
                                    Text('💡 Workaround: ${prob.workaround}',
                                        style: const TextStyle(color: AppColors.priorityP2, fontWeight: FontWeight.w500)),
                                  ],
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Linked Incidents: ${prob.caseLinks.length} | KEDB Articles: ${prob.knownErrors.length}',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                      AccessibleButton(
                                        label: 'Publish KEDB',
                                        icon: Icons.menu_book,
                                        isSecondary: true,
                                        onPressed: () => _openKnownErrorDialog(prob),
                                      ),
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
