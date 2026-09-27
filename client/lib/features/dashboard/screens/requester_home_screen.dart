import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../shared/responsive/breakpoints.dart';
import '../../../shared/responsive/responsive_card_list.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/dimensions.dart';
import '../../../shared/theme/typography.dart';
import '../../../shared/widgets/custom_buttons.dart';
import '../../../shared/widgets/global_states.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/priority_badge.dart';
import '../../../shared/widgets/sla_timer_widget.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cases/models/case_model.dart';
import '../../cases/providers/case_provider.dart';
import '../../cases/screens/case_detail_screen.dart';
import '../../cases/screens/create_case_dialog.dart';
import '../../knowledge/providers/knowledge_provider.dart';
import '../../knowledge/screens/knowledge_browser_screen.dart';

/// Stitch-aligned Self-Service Hub & Requester Home per SRS §4, §7 & Stitch Screen 2.
class RequesterHomeScreen extends StatefulWidget {
  const RequesterHomeScreen({super.key});

  @override
  State<RequesterHomeScreen> createState() => _RequesterHomeScreenState();
}

class _RequesterHomeScreenState extends State<RequesterHomeScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CaseProvider>().fetchCases();
      context.read<KnowledgeProvider>().fetchArticles();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openIntakeDialog({String initialType = 'incident', String? initialTitle}) async {
    final created = await showDialog<CaseModel>(
      context: context,
      builder: (_) => CreateCaseDialog(
        initialType: initialType,
        initialTitle: initialTitle,
      ),
    );
    if (created != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CaseDetailScreen(caseId: created.id)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final caseProv = context.watch<CaseProvider>();
    final kbProv = context.watch<KnowledgeProvider>();
    final user = auth.currentUser;
    final cases = caseProv.cases;

    final activeCases = cases.where((c) => c.status != 'closed' && c.status != 'cancelled').toList();
    final resolvedCases = cases.where((c) => c.status == 'resolved').toList();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            context.read<CaseProvider>().fetchCases(),
            context.read<KnowledgeProvider>().fetchArticles(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spaceLg,
            vertical: AppDimensions.spaceLg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Hero & Plain-Language Smart Search Unit
              _buildHeroSearchUnit(user?.displayName ?? 'there'),
              const SizedBox(height: AppDimensions.spaceXl),

              // 2. Quick Action Cards (3-column grid / responsive stack)
              _buildQuickActionCards(),
              const SizedBox(height: AppDimensions.spaceXl),

              // 3. Telemetry KPI Metric Row
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < ResponsiveBreakpoints.mobileMax;
                  if (isMobile) {
                    return Column(
                      children: [
                        MetricCard(
                          label: 'Active Tickets',
                          value: activeCases.length.toString(),
                          icon: Icons.pending_actions,
                          valueColor: AppColors.primaryBlue,
                          subtitle: 'Incidents & requests in flight',
                        ),
                        const SizedBox(height: 8),
                        MetricCard(
                          label: 'Resolved',
                          value: resolvedCases.length.toString(),
                          icon: Icons.check_circle_outline,
                          valueColor: AppColors.slaHealthy,
                          subtitle: 'Within 7-day reopen window',
                        ),
                        const SizedBox(height: 8),
                        MetricCard(
                          label: 'Total Submitted',
                          value: cases.length.toString(),
                          icon: Icons.folder_open,
                          valueColor: AppColors.textPrimaryLight,
                          subtitle: 'All-time history',
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(
                        child: MetricCard(
                          label: 'Active Tickets',
                          value: activeCases.length.toString(),
                          icon: Icons.pending_actions,
                          valueColor: AppColors.primaryBlue,
                          subtitle: 'Incidents & requests in flight',
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spaceMd),
                      Expanded(
                        child: MetricCard(
                          label: 'Resolved',
                          value: resolvedCases.length.toString(),
                          icon: Icons.check_circle_outline,
                          valueColor: AppColors.slaHealthy,
                          subtitle: 'Within 7-day reopen window',
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spaceMd),
                      Expanded(
                        child: MetricCard(
                          label: 'Total Submitted',
                          value: cases.length.toString(),
                          icon: Icons.folder_open,
                          valueColor: AppColors.textPrimaryLight,
                          subtitle: 'All-time history',
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppDimensions.spaceXl),

              // 4. Active Requests Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'My Active Requests',
                        style: AppTypography.headlineMd,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                        ),
                        child: Text(
                          '${activeCases.length} open',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spaceMd),

              // Active Requests Data Presentation
              if (caseProv.isLoading && cases.isEmpty)
                const LoadingState(message: 'Loading your active support tickets...')
              else if (caseProv.errorMessage != null && cases.isEmpty)
                ErrorState(
                  message: caseProv.errorMessage!,
                  onRetry: () => context.read<CaseProvider>().fetchCases(),
                )
              else if (activeCases.isEmpty)
                EmptyState(
                  icon: Icons.task_alt_rounded,
                  title: 'All caught up!',
                  description: 'You currently have no open IT incidents or service requests.',
                  actionLabel: 'Submit New Ticket',
                  onAction: () => _openIntakeDialog(),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: ResponsiveDataView<CaseModel>(
                    items: activeCases,
                    loadingState: const LoadingState(message: 'Loading active tickets...'),
                    emptyState: const EmptyState(
                      title: 'All caught up!',
                      description: 'You currently have no open IT incidents or service requests.',
                    ),
                    desktopTableBuilder: (ctx, items) => _buildDesktopActiveCasesTable(items),
                    mobileCardBuilder: (ctx, item, idx) => _buildMobileActiveCaseCard(item),
                  ),
                ),
              const SizedBox(height: AppDimensions.spaceXl),

              // 5. Suggested Knowledge Base Section
              _buildSuggestedKnowledgeSection(kbProv),
              const SizedBox(height: AppDimensions.spaceXl),

              // 6. Registered Workstation Diagnostic Panel (Stitch Screen lines 567-638)
              _buildWorkstationDiagnosticPanel(user?.site ?? 'MBP-M3-VANCE-09'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSearchUnit(String userName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.spaceLg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, size: 14, color: AppColors.primaryBlue),
                    const SizedBox(width: 6),
                    Text(
                      'AI Nexus Intelligence Assist Active',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Welcome back, $userName. How can we help you today?',
            style: AppTypography.headlineLg,
          ),
          const SizedBox(height: 4),
          Text(
            'Describe technical friction or search catalog resources in plain language.',
            style: AppTypography.bodyLg.copyWith(color: AppColors.textSecondaryLight),
          ),
          const SizedBox(height: 18),

          // Smart Natural Language Search Input
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Describe what you need help with... (e.g. 'Can't connect to VPN' or 'Request Figma license')",
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondaryLight),
              suffixIcon: Container(
                margin: const EdgeInsets.only(right: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundLight,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Text(
                        '⌘K',
                        style: AppTypography.codeMd.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            onSubmitted: (query) {
              if (query.trim().isNotEmpty) {
                _openIntakeDialog(initialTitle: query.trim());
              }
            },
          ),
          const SizedBox(height: 12),

          // Fast Assist Filter Prompts
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Common requests:',
                style: AppTypography.labelSm.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondaryLight,
                ),
              ),
              _buildPromptChip('Reset MFA token'),
              _buildPromptChip('Request AWS Dev Account'),
              _buildPromptChip('Guest Wi-Fi pass'),
              _buildPromptChip('Hardware upgrade'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPromptChip(String label) {
    return InkWell(
      onTap: () => _openIntakeDialog(initialTitle: label),
      borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Text(
          label,
          style: AppTypography.labelSm.copyWith(color: AppColors.textPrimaryLight),
        ),
      ),
    );
  }

  Widget _buildQuickActionCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < ResponsiveBreakpoints.mobileMax;

        final card1 = _buildActionCard(
          icon: Icons.report_problem_outlined,
          iconColor: AppColors.priorityP1,
          iconBgColor: AppColors.priorityP1.withValues(alpha: 0.1),
          badgeText: 'High SLA',
          badgeColor: AppColors.priorityP1.withValues(alpha: 0.1),
          badgeTextColor: AppColors.priorityP1,
          title: 'Report an Incident',
          description: 'Something is broken or not working as expected. Alert our on-call triage teams instantly.',
          buttonText: 'Create Incident',
          onTap: () => _openIntakeDialog(initialType: 'incident'),
        );

        final card2 = _buildActionCard(
          icon: Icons.laptop_mac_outlined,
          iconColor: AppColors.primaryBlue,
          iconBgColor: AppColors.primaryLight.withValues(alpha: 0.1),
          badgeText: 'Pre-approved',
          badgeColor: AppColors.aiAccent.withValues(alpha: 0.1),
          badgeTextColor: AppColors.aiAccent,
          title: 'Request Software/Hardware',
          description: 'Order equipment, peripheral devices, or request app licenses and cloud environment access.',
          buttonText: 'Browse Catalog',
          onTap: () => _openIntakeDialog(initialType: 'service_request'),
        );

        final card3 = _buildActionCard(
          icon: Icons.menu_book_outlined,
          iconColor: AppColors.textPrimaryLight,
          iconBgColor: AppColors.backgroundLight,
          badgeText: 'Self-Service',
          badgeColor: AppColors.statusAssigned.withValues(alpha: 0.1),
          badgeTextColor: AppColors.statusAssigned,
          title: 'Browse Knowledge Base',
          description: 'Search vetted SOPs, setup guides, and quick self-service script repairs with zero waiting.',
          buttonText: 'View Guides',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const KnowledgeBrowserScreen()),
            );
          },
        );

        if (isMobile) {
          return Column(
            children: [
              card1,
              const SizedBox(height: 12),
              card2,
              const SizedBox(height: 12),
              card3,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: card1),
            const SizedBox(width: AppDimensions.spaceMd),
            Expanded(child: card2),
            const SizedBox(width: AppDimensions.spaceMd),
            Expanded(child: card3),
          ],
        );
      },
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String badgeText,
    required Color badgeColor,
    required Color badgeTextColor,
    required String title,
    required String description,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceLg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badgeText,
                  style: AppTypography.labelSm.copyWith(
                    color: badgeTextColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppTypography.headlineSm,
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          CustomButtons.secondary(
            text: buttonText,
            icon: Icons.arrow_forward,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopActiveCasesTable(List<CaseModel> items) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1.8),
        1: FlexColumnWidth(3.0),
        2: FlexColumnWidth(1.2),
        3: FlexColumnWidth(1.4),
        4: FlexColumnWidth(1.8),
        5: FlexColumnWidth(1.8),
        6: FlexColumnWidth(1.3),
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
            _buildTableHeader('Assignment'),
            _buildTableHeader('Action', alignRight: true),
          ],
        ),
        ...items.map((c) {
          final isIncident = c.type == 'incident';
          final assigneeText = c.ownerId != null ? 'L2 Triage Assigned' : 'Unassigned Pool';
          final assigneeTag = isIncident ? 'L2' : 'SA';

          return TableRow(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.borderLight, width: 0.5)),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isIncident ? Icons.report_problem_outlined : Icons.inventory_2_outlined,
                      size: 16,
                      color: isIncident ? AppColors.priorityP1 : AppColors.secondaryIndigo,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        c.referenceNumber,
                        style: AppTypography.codeMd.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                  ],
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
                    const SizedBox(height: 2),
                    Text(
                      'Created ${DateFormat('MMM d, h:mm a').format(c.createdAt.toLocal())}',
                      style: AppTypography.bodySm.copyWith(
                        fontSize: 11,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: isIncident ? AppColors.primaryLight.withValues(alpha: 0.2) : AppColors.secondaryIndigo.withValues(alpha: 0.15),
                      child: Text(
                        assigneeTag,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isIncident ? AppColors.primaryBlue : AppColors.secondaryIndigo,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        assigneeText,
                        style: AppTypography.bodySm.copyWith(fontSize: 12, color: AppColors.textSecondaryLight),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
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

  Widget _buildMobileActiveCaseCard(CaseModel c) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        title: Row(
          children: [
            Text(
              c.referenceNumber,
              style: AppTypography.codeMd.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge(status: c.status),
            const SizedBox(width: 6),
            PriorityBadge(priority: c.priority),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.title,
                style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (c.sla != null) ...[
                const SizedBox(height: 8),
                SlaTimerWidget(
                  targetTime: c.sla!.targetResolveAt,
                  isBreached: c.sla!.resolutionBreached,
                  completedAt: c.resolvedAt,
                ),
              ],
            ],
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondaryLight),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => CaseDetailScreen(caseId: c.id)),
          );
        },
      ),
    );
  }

  Widget _buildSuggestedKnowledgeSection(KnowledgeProvider kbProv) {
    final articles = kbProv.articles.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Suggested Knowledge Articles',
                  style: AppTypography.headlineMd,
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.aiAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                  ),
                  child: Text(
                    'AI Recommended',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.aiAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const KnowledgeBrowserScreen()),
                );
              },
              child: const Text('View All Articles'),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spaceMd),

        if (articles.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                const Icon(Icons.menu_book, color: AppColors.textSecondaryLight),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Browse enterprise IT troubleshooting guides and standard operating procedures in the Knowledge Base.',
                    style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                  ),
                ),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < ResponsiveBreakpoints.mobileMax;
              if (isMobile) {
                return Column(
                  children: articles.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: _buildKnowledgeCard(a),
                  )).toList(),
                );
              }
              return Row(
                children: articles.map((a) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: _buildKnowledgeCard(a),
                    ),
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }

  Widget _buildKnowledgeCard(dynamic article) {
    final title = article.title ?? '';
    final category = (article.category?.isNotEmpty == true ? article.category! : 'SOP GUIDE').toUpperCase();
    final summary = article.summary ?? article.body ?? '';

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const KnowledgeBrowserScreen()),
        );
      },
      borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.spaceMd),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.article_outlined, size: 16, color: AppColors.primaryBlue),
                        const SizedBox(width: 6),
                        Text(
                          category,
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.slaHealthy.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.thumb_up_outlined, size: 11, color: AppColors.slaHealthy),
                          const SizedBox(width: 4),
                          Text(
                            '94% helpful',
                            style: AppTypography.codeMd.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.slaHealthy,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  summary,
                  style: AppTypography.bodySm.copyWith(
                    fontSize: 12,
                    color: AppColors.textSecondaryLight,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 13, color: AppColors.textSecondaryLight),
                      const SizedBox(width: 4),
                      Text(
                        '4 min read',
                        style: AppTypography.labelSm.copyWith(fontSize: 11, color: AppColors.textSecondaryLight),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        'Read guide',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_forward, size: 12, color: AppColors.primaryBlue),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkstationDiagnosticPanel(String host) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceLg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(color: Color(0x04000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Registered Workstation Diagnostic',
                    style: AppTypography.headlineSm,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Host: ',
                        style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                      ),
                      Text(
                        host,
                        style: AppTypography.codeMd.copyWith(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '• Device Compliance: Healthy',
                        style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.slaHealthy, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text(
                          'Jamf Agent 10.48 (Sync 5m ago)',
                          style: AppTypography.codeMd.copyWith(fontSize: 11, color: AppColors.textPrimaryLight),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Workstation diagnostics verified: FileVault encrypted, CrowdStrike active, latency normal.')),
                      );
                    },
                    child: const Text('Run Diagnostics'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 900;
              final m1 = _buildDiagnosticMetric(
                label: 'Battery Condition',
                value: '98%',
                progress: 0.98,
                color: AppColors.primaryBlue,
                footer: 'Cycle Count: 42 • Normal',
              );
              final m2 = _buildDiagnosticMetric(
                label: 'FileVault Encryption',
                value: 'Active',
                progress: 1.0,
                color: AppColors.slaHealthy,
                footer: 'APFS Encrypted • Key Escrowed',
              );
              final m3 = _buildDiagnosticMetric(
                label: 'CrowdStrike Falcon',
                value: 'Protected',
                progress: 1.0,
                color: AppColors.slaHealthy,
                footer: 'Engine v7.14 • Zero Threats',
              );
              final m4 = _buildDiagnosticMetric(
                label: 'Gateway Roundtrip',
                value: '48ms',
                progress: 0.45,
                color: AppColors.priorityP2,
                footer: 'Chicago Hub • Moderate Jitter',
                isSparkline: true,
              );

              if (isNarrow) {
                return Column(
                  children: [
                    m1,
                    const SizedBox(height: 8),
                    m2,
                    const SizedBox(height: 8),
                    m3,
                    const SizedBox(height: 8),
                    m4,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: m1),
                  const SizedBox(width: 12),
                  Expanded(child: m2),
                  const SizedBox(width: 12),
                  Expanded(child: m3),
                  const SizedBox(width: 12),
                  Expanded(child: m4),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticMetric({
    required String label,
    required String value,
    required double progress,
    required Color color,
    required String footer,
    bool isSparkline = false,
  }) {
    return Container(
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
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.labelSm.copyWith(color: AppColors.textSecondaryLight, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                value,
                style: AppTypography.codeMd.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isSparkline)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(width: 12, height: 6, decoration: BoxDecoration(color: AppColors.primaryBlue.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 3),
                Container(width: 12, height: 8, decoration: BoxDecoration(color: AppColors.primaryBlue.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 3),
                Container(width: 12, height: 6, decoration: BoxDecoration(color: AppColors.primaryBlue.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 3),
                Container(width: 12, height: 10, decoration: BoxDecoration(color: AppColors.primaryBlue.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 3),
                Container(width: 12, height: 12, decoration: BoxDecoration(color: AppColors.priorityP2, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 3),
                Container(width: 12, height: 14, decoration: BoxDecoration(color: AppColors.priorityP2, borderRadius: BorderRadius.circular(2))),
              ],
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: Colors.white,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            footer,
            style: AppTypography.codeMd.copyWith(fontSize: 10, color: AppColors.textSecondaryLight),
          ),
        ],
      ),
    );
  }
}
