import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/sla_timer_widget.dart';
import '../../../shared/widgets/status_badge.dart';
import '../models/case_model.dart';
import '../providers/case_provider.dart';
import 'case_detail_screen.dart';
import 'create_case_dialog.dart';

/// Real-time case feed with keyword search and status/priority filters per SRS §4.1.
class CaseListScreen extends StatefulWidget {
  const CaseListScreen({super.key});

  @override
  State<CaseListScreen> createState() => _CaseListScreenState();
}

class _CaseListScreenState extends State<CaseListScreen> {
  final _searchController = TextEditingController();
  String _selectedStatus = 'all';
  String _selectedPriority = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CaseProvider>().fetchCases();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    context.read<CaseProvider>().fetchCases(
          status: _selectedStatus,
          priority: _selectedPriority,
          search: _searchController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final caseProv = context.watch<CaseProvider>();
    final cases = caseProv.cases;

    return Scaffold(
      body: Column(
        children: [
          // Filter & Search Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).cardTheme.color,
            child: Column(
              children: [
                // Search field
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search cases by keyword or reference number (e.g. INC-2026-000001)...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _applyFilter();
                            },
                          )
                        : null,
                  ),
                  onSubmitted: (_) => _applyFilter(),
                ),
                const SizedBox(height: 12),

                // Filter row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Status Filters
                      _buildFilterChip('All Statuses', 'all', _selectedStatus, (val) {
                        setState(() => _selectedStatus = val);
                        _applyFilter();
                      }),
                      const SizedBox(width: 8),
                      _buildFilterChip('New', 'new', _selectedStatus, (val) {
                        setState(() => _selectedStatus = val);
                        _applyFilter();
                      }),
                      const SizedBox(width: 8),
                      _buildFilterChip('Assigned', 'assigned', _selectedStatus, (val) {
                        setState(() => _selectedStatus = val);
                        _applyFilter();
                      }),
                      const SizedBox(width: 8),
                      _buildFilterChip('Awaiting', 'awaiting_approval', _selectedStatus, (val) {
                        setState(() => _selectedStatus = val);
                        _applyFilter();
                      }),
                      const SizedBox(width: 8),
                      _buildFilterChip('Resolved', 'resolved', _selectedStatus, (val) {
                        setState(() => _selectedStatus = val);
                        _applyFilter();
                      }),
                      const SizedBox(width: 16),

                      // Priority Filters
                      _buildFilterChip('All Priorities', 'all', _selectedPriority, (val) {
                        setState(() => _selectedPriority = val);
                        _applyFilter();
                      }),
                      const SizedBox(width: 8),
                      _buildFilterChip('P1 Critical', 'p1', _selectedPriority, (val) {
                        setState(() => _selectedPriority = val);
                        _applyFilter();
                      }),
                      const SizedBox(width: 8),
                      _buildFilterChip('P2 High', 'p2', _selectedPriority, (val) {
                        setState(() => _selectedPriority = val);
                        _applyFilter();
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderLight),

          // Case List
          Expanded(
            child: caseProv.isLoading
                ? const Center(child: CircularProgressIndicator())
                : cases.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.inbox_outlined, size: 48, color: AppColors.textSecondaryLight),
                            const SizedBox(height: 12),
                            const Text('No cases found matching criteria', style: TextStyle(fontSize: 16)),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _selectedStatus = 'all';
                                  _selectedPriority = 'all';
                                });
                                _applyFilter();
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reset filters'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => caseProv.fetchCases(
                          status: _selectedStatus,
                          priority: _selectedPriority,
                          search: _searchController.text,
                        ),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: cases.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return _buildCaseCard(cases[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await showDialog<CaseModel>(
            context: context,
            builder: (_) => const CreateCaseDialog(),
          );
          if (created != null && mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => CaseDetailScreen(caseId: created.id)),
            );
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('New Ticket'),
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    String currentValue,
    ValueChanged<String> onSelected,
  ) {
    final isSelected = value == currentValue;
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (_) => onSelected(value),
      selectedColor: AppColors.primaryBlue.withValues(alpha: 0.15),
      checkmarkColor: AppColors.primaryBlue,
    );
  }

  Widget _buildCaseCard(CaseModel c) {
    final timeStr = DateFormat('MMM d, h:mm a').format(c.createdAt.toLocal());

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => CaseDetailScreen(caseId: c.id)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header badges & Reference number
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        c.referenceNumber,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusBadge(status: c.status),
                      const SizedBox(width: 6),
                      PriorityBadge(priority: c.priority),
                    ],
                  ),
                  Text(
                    timeStr,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                c.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (c.description != null && c.description!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  c.description!,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),

              // SLA Timer & Site Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (c.sla != null)
                    SlaTimerWidget(
                      targetTime: c.sla!.targetResolveAt,
                      isBreached: c.sla!.resolutionBreached,
                      completedAt: c.resolvedAt,
                      label: 'Resolution SLA',
                    )
                  else
                    const SizedBox.shrink(),
                  if (c.site != null)
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondaryLight),
                        const SizedBox(width: 4),
                        Text(
                          c.site!,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
