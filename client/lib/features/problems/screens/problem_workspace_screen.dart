import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/dimensions.dart';
import '../../../shared/theme/typography.dart';
import '../../../shared/widgets/accessible_button.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../../../shared/widgets/custom_buttons.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/priority_badge.dart';
import '../../../shared/widgets/search_field.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../knowledge/providers/knowledge_provider.dart';
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
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProblemProvider>().fetchProblems();
      context.read<KnowledgeProvider>().fetchArticles();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openCreateDialog() {
    showDialog(
      context: context,
      builder: (_) => const CreateProblemDialog(),
    ).then((val) {
      if (val != null) {
        context.read<ProblemProvider>().fetchProblems(
              status: _selectedStatus,
              priority: _selectedPriority,
            );
      }
    });
  }

  void _openEditDialog(ProblemModel problem) {
    final titleCtrl = TextEditingController(text: problem.title);
    final descCtrl = TextEditingController(text: problem.description);
    final rootCauseCtrl = TextEditingController(text: problem.rootCause ?? '');
    final workaroundCtrl = TextEditingController(text: problem.workaround ?? '');
    String priority = problem.priority.toLowerCase();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Problem Record (${problem.problemNumber})', style: AppTypography.headlineSm),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 550),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Problem Title *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description *'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: const InputDecoration(labelText: 'Priority Level'),
                  items: const [
                    DropdownMenuItem(value: 'p1', child: Text('P1 - Critical')),
                    DropdownMenuItem(value: 'p2', child: Text('P2 - High')),
                    DropdownMenuItem(value: 'p3', child: Text('P3 - Medium')),
                    DropdownMenuItem(value: 'p4', child: Text('P4 - Low')),
                  ],
                  onChanged: (v) {
                    if (v != null) priority = v;
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: rootCauseCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Root Cause Investigation'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: workaroundCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Workaround / Mitigation'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          SecondaryButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          const SizedBox(width: 8),
          PrimaryButton(
            label: 'Save Changes',
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty || descCtrl.text.trim().isEmpty) return;
              final ok = await context.read<ProblemProvider>().updateProblem(
                    problem.id,
                    title: titleCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                    priority: priority,
                    rootCause: rootCauseCtrl.text.trim().isNotEmpty ? rootCauseCtrl.text.trim() : null,
                    workaround: workaroundCtrl.text.trim().isNotEmpty ? workaroundCtrl.text.trim() : null,
                  );
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                if (ok != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Problem ${problem.problemNumber} updated successfully')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _openLinkCaseDialog(ProblemModel problem) {
    final caseIdCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Link Incident Case (${problem.problemNumber})', style: AppTypography.headlineSm),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450, maxHeight: 300),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter the UUID of the Incident / Case to link to this problem root cause investigation.',
                style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('caseIdInput'),
                controller: caseIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'Case UUID *',
                  hintText: 'e.g. 123e4567-e89b-12d3-a456-426614174000',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
              ),
            ],
          ),
        ),
        actions: [
          SecondaryButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          const SizedBox(width: 8),
          PrimaryButton(
            key: const Key('linkIncidentConfirmBtn'),
            label: 'Confirm Link',
            onPressed: () async {
              final caseId = caseIdCtrl.text.trim();
              if (caseId.isEmpty) return;
              final ok = await context.read<ProblemProvider>().linkCase(problem.id, caseId);
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Incident linked to problem successfully')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _openKnownErrorDialog(ProblemModel problem) {
    final titleCtrl = TextEditingController(text: 'KEDB: ${problem.title}');
    final symptomsCtrl = TextEditingController(text: problem.description);
    final workaroundCtrl = TextEditingController(text: problem.workaround ?? '');
    final fixCtrl = TextEditingController(text: problem.rootCause ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Publish Known Error Article (${problem.problemNumber})', style: AppTypography.headlineSm),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 400),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('kedbTitleInput'),
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Article Title *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('kedbSymptomsInput'),
                  controller: symptomsCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Symptoms *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('kedbWorkaroundInput'),
                  controller: workaroundCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Workaround / Temporary Fix *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('kedbFixInput'),
                  controller: fixCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Permanent Resolution Plan'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          SecondaryButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          const SizedBox(width: 8),
          PrimaryButton(
            key: const Key('publishKedbConfirmBtn'),
            label: 'Confirm KEDB Publication',
            onPressed: () async {
              if (workaroundCtrl.text.trim().isEmpty || titleCtrl.text.trim().isEmpty) return;
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
                    const SnackBar(content: Text('Known Error published to KEDB successfully')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _confirmUnlinkCase(ProblemModel problem, String caseId) {
    ConfirmationDialog.show(
      context: context,
      title: 'Unlink Incident Case',
      message: 'Are you sure you want to remove Case $caseId from this Problem record?',
      confirmLabel: 'Unlink',
      isDestructive: true,
    ).then((confirmed) {
      if (confirmed == true) {
        context.read<ProblemProvider>().unlinkCase(problem.id, caseId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProblemProvider>();
    final isWide = MediaQuery.of(context).size.width >= 900;

    // Metrics computation
    final totalProblems = provider.problems.length;
    final activeProblems = provider.problems
        .where((p) => p.status.toLowerCase() == 'open' || p.status.toLowerCase() == 'investigating')
        .length;
    final criticalProblems = provider.problems
        .where((p) => p.priority.toLowerCase() == 'p1' || p.priority.toLowerCase() == 'p2')
        .length;
    final publishedKEDB = provider.problems.fold<int>(0, (sum, p) => sum + p.knownErrors.length);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(
        children: [
          // 1. Top Enterprise Metric Banner
          Container(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.borderLight)),
            ),
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final isCompact = constraints.maxWidth < 650;
                final cards = [
                  MetricCard(
                    label: 'Total Problems',
                    value: '$totalProblems',
                    icon: Icons.fact_check_outlined,
                  ),
                  MetricCard(
                    label: 'Active Investigations',
                    value: '$activeProblems',
                    icon: Icons.biotech_outlined,
                    valueColor: AppColors.priorityP2,
                  ),
                  MetricCard(
                    label: 'Critical (P1/P2)',
                    value: '$criticalProblems',
                    icon: Icons.warning_amber_rounded,
                    valueColor: AppColors.priorityP1,
                  ),
                  MetricCard(
                    label: 'KEDB Articles',
                    value: '$publishedKEDB',
                    icon: Icons.menu_book_outlined,
                    valueColor: AppColors.priorityP3,
                  ),
                ];

                if (isCompact) {
                  return GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.2,
                    children: cards,
                  );
                }

                return Row(
                  children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c))).toList(),
                );
              },
            ),
          ),

          // 2. Filter & Action Toolbar (Responsive)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceMd, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.borderLight)),
            ),
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final isNarrow = constraints.maxWidth < 750;

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SearchField(
                        controller: _searchCtrl,
                        hintText: 'Search by PRB ID, title, root cause...',
                        onChanged: (v) => provider.setSearchQuery(v),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButton<String?>(
                              isExpanded: true,
                              value: _selectedStatus,
                              hint: const Text('All Statuses'),
                              items: const [
                                DropdownMenuItem(value: null, child: Text('All Statuses')),
                                DropdownMenuItem(value: 'open', child: Text('Open')),
                                DropdownMenuItem(value: 'investigating', child: Text('Investigating')),
                                DropdownMenuItem(value: 'workaround_found', child: Text('Workaround Found')),
                                DropdownMenuItem(value: 'known_error', child: Text('Known Error')),
                                DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                                DropdownMenuItem(value: 'closed', child: Text('Closed')),
                              ],
                              onChanged: (v) {
                                setState(() => _selectedStatus = v);
                                provider.fetchProblems(status: _selectedStatus, priority: _selectedPriority);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButton<String?>(
                              isExpanded: true,
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
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            tooltip: 'Refresh Problems',
                            onPressed: () => provider.fetchProblems(
                              status: _selectedStatus,
                              priority: _selectedPriority,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      AccessibleButton(
                        label: 'New Problem',
                        icon: Icons.add,
                        onPressed: _openCreateDialog,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: SearchField(
                        controller: _searchCtrl,
                        hintText: 'Search by PRB ID, title, root cause, workaround...',
                        onChanged: (v) => provider.setSearchQuery(v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String?>(
                      value: _selectedStatus,
                      hint: const Text('All Statuses'),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All Statuses')),
                        DropdownMenuItem(value: 'open', child: Text('Open')),
                        DropdownMenuItem(value: 'investigating', child: Text('Investigating')),
                        DropdownMenuItem(value: 'workaround_found', child: Text('Workaround Found')),
                        DropdownMenuItem(value: 'known_error', child: Text('Known Error')),
                        DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                        DropdownMenuItem(value: 'closed', child: Text('Closed')),
                      ],
                      onChanged: (v) {
                        setState(() => _selectedStatus = v);
                        provider.fetchProblems(status: _selectedStatus, priority: _selectedPriority);
                      },
                    ),
                    const SizedBox(width: 12),
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
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh Problems',
                      onPressed: () => provider.fetchProblems(
                        status: _selectedStatus,
                        priority: _selectedPriority,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AccessibleButton(
                      label: 'New Problem',
                      icon: Icons.add,
                      onPressed: _openCreateDialog,
                    ),
                  ],
                );
              },
            ),
          ),

          // 3. Error Banner if present
          if (provider.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.priorityP1.withValues(alpha: 0.12),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.priorityP1, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      provider.error!,
                      style: AppTypography.bodySm.copyWith(color: AppColors.priorityP1, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

          // 4. Main Body: Master-Detail on Wide Screen, Single Pane on Mobile
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.problems.isEmpty
                    ? _buildEmptyState()
                    : isWide
                        ? _buildMasterDetailLayout(provider)
                        : _buildMobileListLayout(provider),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.fact_check_outlined, size: 64, color: AppColors.textSecondaryLight),
          const SizedBox(height: 16),
          Text(
            'No Problem Records Found',
            style: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Track root causes, link recurring incidents, and publish to KEDB.',
            style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondaryLight),
          ),
          const SizedBox(height: 16),
          AccessibleButton(
            label: 'Create First Problem',
            onPressed: _openCreateDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildMasterDetailLayout(ProblemProvider provider) {
    final selected = provider.selectedProblem ?? (provider.problems.isNotEmpty ? provider.problems.first : null);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Master List Pane
        SizedBox(
          width: 380,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: AppColors.borderLight)),
            ),
            child: ListView.separated(
              itemCount: provider.problems.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.borderLight),
              itemBuilder: (ctx, index) {
                final prob = provider.problems[index];
                final isSelected = selected?.id == prob.id;

                return InkWell(
                  onTap: () => provider.setSelectedProblem(prob),
                  child: Container(
                    color: isSelected ? AppColors.primaryBlue.withValues(alpha: 0.06) : Colors.transparent,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Text(
                              prob.problemNumber,
                              style: AppTypography.bodyMd.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isSelected ? AppColors.primaryBlue : AppColors.textPrimaryLight,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PriorityBadge(priority: prob.priority),
                                const SizedBox(width: 4),
                                StatusBadge(status: prob.status),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          prob.title,
                          style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Linked Cases: ${prob.caseLinks.length}',
                              style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight, fontSize: 12),
                            ),
                            if (prob.knownErrors.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.priorityP3.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'KEDB: ${prob.knownErrors.length}',
                                  style: AppTypography.labelSm.copyWith(color: AppColors.priorityP3, fontWeight: FontWeight.bold),
                                ),
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
        ),

        // Detail Workspace Pane
        Expanded(
          child: selected == null
              ? const Center(child: Text('Select a problem to view workspace'))
              : _buildProblemDetailWorkspace(selected),
        ),
      ],
    );
  }

  Widget _buildMobileListLayout(ProblemProvider provider) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.problems.length,
      itemBuilder: (context, index) {
        final prob = provider.problems[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () {
              provider.setSelectedProblem(prob);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: Text(prob.problemNumber)),
                    body: _buildProblemDetailWorkspace(prob),
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(prob.problemNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      PriorityBadge(priority: prob.priority),
                      StatusBadge(status: prob.status),
                      Text(dateFormat.format(prob.createdAt.toLocal()), style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(prob.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(prob.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Linked Cases: ${prob.caseLinks.length} | KEDB: ${prob.knownErrors.length}',
                          style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondaryLight),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProblemDetailWorkspace(ProblemModel problem) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final knowledgeProvider = context.watch<KnowledgeProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Problem Header Card
          Container(
            padding: const EdgeInsets.all(AppDimensions.spaceLg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppDimensions.cardBorderRadius,
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          problem.problemNumber,
                          style: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.bold),
                        ),
                        PriorityBadge(priority: problem.priority),
                        StatusBadge(status: problem.status),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SecondaryButton(
                          label: 'Edit Details',
                          icon: Icons.edit_outlined,
                          onPressed: () => _openEditDialog(problem),
                        ),
                        PrimaryButton(
                          label: 'Publish KEDB',
                          icon: Icons.menu_book,
                          onPressed: () => _openKnownErrorDialog(problem),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  problem.title,
                  style: AppTypography.headlineSm.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  children: [
                    _buildMetaItem('Created', dateFormat.format(problem.createdAt.toLocal())),
                    _buildMetaItem('Last Updated', dateFormat.format(problem.updatedAt.toLocal())),
                    if (problem.resolvedAt != null)
                      _buildMetaItem('Resolved At', dateFormat.format(problem.resolvedAt!.toLocal())),
                    _buildMetaItem('Owner', problem.ownerId ?? 'Unassigned Operator'),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),

                // Status Lifecycle Transitions
                Text('Status Lifecycle Actions:', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (problem.status.toLowerCase() == 'open')
                      SecondaryButton(
                        label: 'Mark Investigating',
                        icon: Icons.biotech_outlined,
                        onPressed: () => context.read<ProblemProvider>().updateProblem(problem.id, status: 'investigating'),
                      ),
                    if (problem.status.toLowerCase() == 'open' || problem.status.toLowerCase() == 'investigating')
                      SecondaryButton(
                        label: 'Mark Workaround Found',
                        icon: Icons.lightbulb_outline,
                        onPressed: () => context.read<ProblemProvider>().updateProblem(problem.id, status: 'workaround_found'),
                      ),
                    if (problem.status.toLowerCase() != 'resolved' && problem.status.toLowerCase() != 'closed')
                      SecondaryButton(
                        label: 'Resolve Problem',
                        icon: Icons.check_circle_outline,
                        onPressed: () => context.read<ProblemProvider>().updateProblem(problem.id, status: 'resolved'),
                      ),
                    if (problem.status.toLowerCase() == 'resolved')
                      SecondaryButton(
                        label: 'Close Problem',
                        icon: Icons.lock_outline,
                        onPressed: () => context.read<ProblemProvider>().updateProblem(problem.id, status: 'closed'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Root Cause & Investigation Card
          Container(
            padding: const EdgeInsets.all(AppDimensions.spaceLg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppDimensions.cardBorderRadius,
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text('Investigation & Root Cause Analysis', style: AppTypography.headlineSm.copyWith(fontSize: 16)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Edit Investigation',
                      onPressed: () => _openEditDialog(problem),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Description', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(problem.description, style: AppTypography.bodyMd),
                const SizedBox(height: 16),
                Text('Root Cause Defect', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  problem.rootCause ?? 'No root cause documented yet. Mark status as Investigating to analyze.',
                  style: AppTypography.bodyMd.copyWith(
                    color: problem.rootCause != null ? AppColors.textPrimaryLight : AppColors.textSecondaryLight,
                    fontStyle: problem.rootCause != null ? FontStyle.normal : FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),
                Text('Workaround / Mitigation', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  problem.workaround ?? 'No temporary workaround documented yet.',
                  style: AppTypography.bodyMd.copyWith(
                    color: problem.workaround != null ? AppColors.priorityP2 : AppColors.textSecondaryLight,
                    fontStyle: problem.workaround != null ? FontStyle.normal : FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Problem ↔ Case Linking Section
          Container(
            padding: const EdgeInsets.all(AppDimensions.spaceLg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppDimensions.cardBorderRadius,
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Text(
                      'Linked Incidents (${problem.caseLinks.length})',
                      style: AppTypography.headlineSm.copyWith(fontSize: 16),
                    ),
                    AccessibleButton(
                      label: 'Link Incident Case',
                      icon: Icons.link,
                      onPressed: () => _openLinkCaseDialog(problem),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (problem.caseLinks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No incident cases linked yet. Link recurring incident tickets to consolidate root cause analysis.',
                      style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondaryLight, fontStyle: FontStyle.italic),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: problem.caseLinks.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (ctx, idx) {
                      final link = problem.caseLinks[idx];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.confirmation_number_outlined, color: AppColors.primaryBlue),
                        title: Text('Case ID: ${link.caseId}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Linked on: ${dateFormat.format(link.linkedAt.toLocal())}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.link_off_rounded, color: AppColors.priorityP1),
                          tooltip: 'Unlink Incident',
                          onPressed: () => _confirmUnlinkCase(problem, link.caseId),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 4. Known Error Database (KEDB) Section
          Container(
            padding: const EdgeInsets.all(AppDimensions.spaceLg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppDimensions.cardBorderRadius,
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Text(
                      'Known Error Database (KEDB) Articles (${problem.knownErrors.length})',
                      style: AppTypography.headlineSm.copyWith(fontSize: 16),
                    ),
                    SecondaryButton(
                      label: 'Publish to KEDB',
                      icon: Icons.add,
                      onPressed: () => _openKnownErrorDialog(problem),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (problem.knownErrors.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No Known Error articles published for this problem. Publish workarounds to enable automated operator suggestions.',
                      style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondaryLight, fontStyle: FontStyle.italic),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: problem.knownErrors.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (ctx, idx) {
                      final ke = problem.knownErrors[idx];
                      return Card(
                        elevation: 0,
                        color: AppColors.backgroundLight,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(ke.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: ke.published ? AppColors.priorityP3.withValues(alpha: 0.15) : AppColors.borderLight,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      ke.published ? 'PUBLISHED' : 'DRAFT',
                                      style: TextStyle(
                                        color: ke.published ? AppColors.priorityP3 : AppColors.textSecondaryLight,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('Symptoms: ${ke.symptoms}', style: AppTypography.bodySm),
                              const SizedBox(height: 4),
                              Text('💡 Workaround: ${ke.workaround}',
                                  style: AppTypography.bodySm.copyWith(color: AppColors.priorityP2, fontWeight: FontWeight.w600)),
                              if (ke.permanentFix != null) ...[
                                const SizedBox(height: 4),
                                Text('Permanent Fix: ${ke.permanentFix}', style: AppTypography.bodySm),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 5. Related Knowledge Base Integration
          Container(
            padding: const EdgeInsets.all(AppDimensions.spaceLg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppDimensions.cardBorderRadius,
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Related Knowledge Base Articles',
                  style: AppTypography.headlineSm.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 12),
                if (knowledgeProvider.articles.isEmpty)
                  Text(
                    'No knowledge base articles found.',
                    style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondaryLight, fontStyle: FontStyle.italic),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: knowledgeProvider.articles.take(4).map((art) {
                      return ActionChip(
                        avatar: const Icon(Icons.menu_book, size: 16, color: AppColors.primaryBlue),
                        label: Text(art.title),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(art.title),
                              content: Text(art.body),
                              actions: [
                                AccessibleButton(label: 'Close', onPressed: () => Navigator.of(ctx).pop()),
                              ],
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.labelSm.copyWith(color: AppColors.textSecondaryLight)),
        const SizedBox(height: 2),
        Text(value, style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
