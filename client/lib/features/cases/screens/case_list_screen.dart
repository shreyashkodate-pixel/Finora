import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../shared/responsive/responsive_card_list.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/dimensions.dart';
import '../../../shared/theme/typography.dart';
import '../../../shared/widgets/custom_buttons.dart';
import '../../../shared/widgets/filter_bar.dart';
import '../../../shared/widgets/global_states.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/priority_badge.dart';
import '../../../shared/widgets/search_field.dart';
import '../../../shared/widgets/sla_timer_widget.dart';
import '../../../shared/widgets/status_badge.dart';
import '../models/case_model.dart';
import '../providers/case_provider.dart';
import 'case_detail_screen.dart';
import 'create_case_dialog.dart';

/// Real-time case feed with keyword search and status/priority filters per SRS §4.1 & Locked Invariant 5.
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

  void _openCreateDialog() async {
    final created = await showDialog<CaseModel>(
      context: context,
      builder: (_) => const CreateCaseDialog(),
    );
    if (created != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CaseDetailScreen(caseId: created.id)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final caseProv = context.watch<CaseProvider>();
    final cases = caseProv.cases;

    final statusOptions = [
      FilterOption(key: 'all', label: 'All Statuses', count: cases.length),
      FilterOption(key: 'new', label: 'New', count: cases.where((c) => c.status == 'new').length),
      FilterOption(key: 'assigned', label: 'Assigned', count: cases.where((c) => c.status == 'assigned').length),
      FilterOption(key: 'in_progress', label: 'In Progress', count: cases.where((c) => c.status == 'in_progress').length),
      FilterOption(key: 'awaiting_approval', label: 'Awaiting', count: cases.where((c) => c.status == 'awaiting_approval').length),
      FilterOption(key: 'resolved', label: 'Resolved', count: cases.where((c) => c.status == 'resolved').length),
      FilterOption(key: 'closed', label: 'Closed', count: cases.where((c) => c.status == 'closed').length),
    ];

    final priorityOptions = [
      const FilterOption(key: 'all', label: 'All Priorities'),
      const FilterOption(key: 'p1', label: 'P1 Critical'),
      const FilterOption(key: 'p2', label: 'P2 High'),
      const FilterOption(key: 'p3', label: 'P3 Medium'),
      const FilterOption(key: 'p4', label: 'P4 Low'),
    ];

    return Scaffold(
      body: Column(
        children: [
          // 1. Page Header
          PageHeader(
            title: 'Support Tickets',
            subtitle: 'Real-time incident & service request feed with 24/7 SLA telemetry',
            breadcrumb: 'HOME > TICKETS',
            actions: [
              CustomButtons.primary(
                text: 'New Ticket',
                icon: Icons.add,
                onPressed: _openCreateDialog,
              ),
            ],
          ),

          // 2. Search & Filter Bar
          Container(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.borderLight)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SearchField(
                  controller: _searchController,
                  hintText: 'Search cases by keyword or reference number (e.g. INC-2026-000001)...',
                  onSubmitted: (_) => _applyFilter(),
                  onClear: () {
                    _searchController.clear();
                    _applyFilter();
                  },
                ),
                const SizedBox(height: 12),
                FilterBar(
                  options: statusOptions,
                  selectedKey: _selectedStatus,
                  onSelected: (key) {
                    setState(() => _selectedStatus = key);
                    _applyFilter();
                  },
                ),
                const SizedBox(height: 8),
                FilterBar(
                  options: priorityOptions,
                  selectedKey: _selectedPriority,
                  onSelected: (key) {
                    setState(() => _selectedPriority = key);
                    _applyFilter();
                  },
                ),
              ],
            ),
          ),

          // 3. Ticket List Area
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => caseProv.fetchCases(
                status: _selectedStatus,
                priority: _selectedPriority,
                search: _searchController.text,
              ),
              child: caseProv.isLoading && cases.isEmpty
                  ? const LoadingState(message: 'Loading support tickets...')
                  : caseProv.errorMessage != null && cases.isEmpty
                      ? ErrorState(
                          message: caseProv.errorMessage!,
                          onRetry: _applyFilter,
                        )
                      : cases.isEmpty
                          ? EmptyState(
                              icon: Icons.inbox_outlined,
                              title: 'No tickets found',
                              description: 'No cases match the selected status, priority, or search keyword.',
                              actionLabel: 'Reset Filters',
                              onAction: () {
                                _searchController.clear();
                                setState(() {
                                  _selectedStatus = 'all';
                                  _selectedPriority = 'all';
                                });
                                _applyFilter();
                              },
                            )
                          : Container(
                              color: AppColors.backgroundLight,
                              padding: const EdgeInsets.all(AppDimensions.spaceMd),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                                  border: Border.all(color: AppColors.borderLight),
                                ),
                                child: ResponsiveDataView<CaseModel>(
                                  items: cases,
                                  loadingState: const LoadingState(message: 'Filtering tickets...'),
                                  emptyState: const EmptyState(
                                    title: 'No tickets found',
                                    description: 'No cases match the active filter criteria.',
                                  ),
                                  desktopTableBuilder: (ctx, items) => _buildDesktopCaseTable(items),
                                  mobileCardBuilder: (ctx, item, idx) => _buildMobileCaseCard(item),
                                ),
                              ),
                            ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateDialog,
        tooltip: 'Create New Support Ticket',
        backgroundColor: AppColors.primaryBlue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildDesktopCaseTable(List<CaseModel> items) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1.6),
        1: FlexColumnWidth(2.8),
        2: FlexColumnWidth(1.1),
        3: FlexColumnWidth(1.3),
        4: FlexColumnWidth(1.8),
        5: FlexColumnWidth(1.4),
        6: FlexColumnWidth(1.2),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: const BoxDecoration(
            color: AppColors.backgroundLight,
            border: Border(bottom: BorderSide(color: AppColors.borderLight)),
          ),
          children: [
            _buildTableHeader('Ticket ID'),
            _buildTableHeader('Subject / Summary'),
            _buildTableHeader('Priority'),
            _buildTableHeader('Status'),
            _buildTableHeader('SLA Countdown'),
            _buildTableHeader('Created Date'),
            _buildTableHeader('Action', alignRight: true),
          ],
        ),
        ...items.map((c) {
          final timeStr = DateFormat('MMM d, h:mm a').format(c.createdAt.toLocal());

          return TableRow(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.borderLight, width: 0.5)),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Text(
                  c.referenceNumber,
                  style: AppTypography.codeMd.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.title,
                      style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (c.site != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Site: ${c.site}',
                        style: AppTypography.bodySm.copyWith(
                          fontSize: 11,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: PriorityBadge(priority: c.priority),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: StatusBadge(status: c.status),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: c.sla != null
                    ? SlaTimerWidget(
                        targetTime: c.sla!.targetResolveAt,
                        isBreached: c.sla!.resolutionBreached,
                        completedAt: c.resolvedAt,
                      )
                    : Text('No SLA', style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Text(
                  timeStr,
                  style: AppTypography.bodySm.copyWith(fontSize: 12, color: AppColors.textSecondaryLight),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => CaseDetailScreen(caseId: c.id)),
                      );
                    },
                    child: const Text('View Ticket'),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildTableHeader(String text, {bool alignRight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        text,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: AppTypography.labelSm.copyWith(
          color: AppColors.textSecondaryLight,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildMobileCaseCard(CaseModel c) {
    final timeStr = DateFormat('MMM d, h:mm a').format(c.createdAt.toLocal());

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => CaseDetailScreen(caseId: c.id)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        c.referenceNumber,
                        style: AppTypography.codeMd.copyWith(
                          fontWeight: FontWeight.bold,
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
                    style: AppTypography.bodySm.copyWith(fontSize: 11, color: AppColors.textSecondaryLight),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                c.title,
                style: AppTypography.headlineSm.copyWith(fontSize: 15),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (c.description != null && c.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  c.description!,
                  style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (c.sla != null)
                    SlaTimerWidget(
                      targetTime: c.sla!.targetResolveAt,
                      isBreached: c.sla!.resolutionBreached,
                      completedAt: c.resolvedAt,
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
                          style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
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
