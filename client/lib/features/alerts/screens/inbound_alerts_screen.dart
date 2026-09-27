import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/dimensions.dart';
import '../../../shared/theme/typography.dart';
import '../../../shared/widgets/custom_buttons.dart';
import '../../../shared/widgets/global_states.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/alert_model.dart';
import '../providers/alert_provider.dart';
import '../widgets/alert_detail_pane.dart';
import '../widgets/alert_kpi_card.dart';
import '../widgets/alert_list_card.dart';
import '../widgets/create_rule_dialog.dart';

/// Inbound Monitoring Alerts & ITSM Ingestion Dashboard Screen
class InboundAlertsScreen extends StatefulWidget {
  const InboundAlertsScreen({super.key});

  @override
  State<InboundAlertsScreen> createState() => _InboundAlertsScreenState();
}

class _InboundAlertsScreenState extends State<InboundAlertsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AlertProvider>().refreshAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _canCreateRules(String? role) {
    final r = role?.toLowerCase().trim() ?? '';
    return r == 'team_lead' || r == 'lead' || r == 'manager' || r == 'admin' || r == 'administrator';
  }

  void _openCreateRuleDialog() {
    showDialog(
      context: context,
      builder: (_) => const CreateRuleDialog(),
    );
  }

  void _openMobileDetailModal(BuildContext context, InboundAlertModel alert) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusBottomSheet)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollCtrl) {
            return AlertDetailPane(
              alert: alert,
              onClose: () => Navigator.of(ctx).pop(),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final userRole = auth.currentUser?.role;

    // RBAC check: Requester has zero access to Inbound APM Monitoring
    if (userRole == 'requester') {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(AppDimensions.spaceLg),
            child: UnauthorizedState(
              message: 'Inbound monitoring feeds and alert rules are restricted to IT staff members.',
            ),
          ),
        ),
      );
    }

    final alertProvider = context.watch<AlertProvider>();
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Operational Header
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spaceLg,
                vertical: AppDimensions.spaceMd,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surfaceLight,
                border: Border(bottom: BorderSide(color: AppColors.borderLight)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: AppDimensions.priorityBorderRadius,
                        ),
                        child: const Icon(Icons.sensors_rounded, color: AppColors.primaryBlue, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text(
                                  'Inbound APM & Observability',
                                  style: AppTypography.headlineMd.copyWith(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                                    borderRadius: AppDimensions.priorityBorderRadius,
                                  ),
                                  child: Text(
                                    'LOSSLESS INGESTION',
                                    style: AppTypography.labelSm.copyWith(
                                      color: AppColors.primaryBlue,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Prometheus, Datadog, Sentry, CloudWatch normalization & automated incident triage',
                              style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                            ),
                          ],
                        ),
                      ),

                      // Refresh & Action CTAs
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        tooltip: 'Refresh Feed',
                        onPressed: () => alertProvider.refreshAll(),
                      ),

                      if (_canCreateRules(userRole))
                        PrimaryButton(
                          label: 'Create Rule',
                          icon: Icons.add_rounded,
                          onPressed: _openCreateRuleDialog,
                        ),
                    ],
                  ),

                  const SizedBox(height: AppDimensions.spaceSm),

                  // Navigation Tabs
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: const [
                      Tab(
                        child: Row(
                          children: [
                            Icon(Icons.monitor_heart_outlined, size: 18),
                            SizedBox(width: 6),
                            Text('Inbound Feed'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          children: [
                            Icon(Icons.tune_rounded, size: 18),
                            SizedBox(width: 6),
                            Text('Alert Rules'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tab View Body
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 0: Inbound Alerts Dashboard
                  _buildAlertsDashboard(context, alertProvider, isDesktop),

                  // Tab 1: Alert Rules Management
                  _buildRulesTab(context, alertProvider, userRole),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsDashboard(
    BuildContext context,
    AlertProvider alertProvider,
    bool isDesktop,
  ) {
    if (alertProvider.isLoadingAlerts && alertProvider.alerts.isEmpty) {
      return const LoadingState(message: 'Loading inbound monitoring feed...');
    }

    if (alertProvider.hasError && alertProvider.alerts.isEmpty) {
      return ErrorState(
        title: 'Feed Ingestion Error',
        message: alertProvider.errorMessage ?? 'Failed to load inbound alerts.',
        onRetry: () => alertProvider.fetchAlerts(),
      );
    }

    final stats = alertProvider.stats;
    final filtered = alertProvider.filteredAlerts;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Telemetry Summary KPI Cards
          LayoutBuilder(
            builder: (ctx, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width >= 1100 ? 5 : (width >= 700 ? 3 : 2);

              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: width >= 1100 ? 1.6 : 1.3,
                children: [
                  AlertKpiCard(
                    title: 'Total Feed',
                    value: stats.totalAlerts.toString(),
                    subtitle: 'All APM Ingestions',
                    icon: Icons.hub_outlined,
                    accentColor: AppColors.primaryBlue,
                    onTap: () => alertProvider.clearFilters(),
                  ),
                  AlertKpiCard(
                    title: 'Critical & High',
                    value: stats.criticalHighCount.toString(),
                    subtitle: 'Priority Thresholds',
                    icon: Icons.warning_amber_rounded,
                    accentColor: AppColors.priorityP1,
                    onTap: () => alertProvider.setSeverityFilter(AlertSeverityEnum.critical),
                  ),
                  AlertKpiCard(
                    title: 'Unacknowledged',
                    value: stats.unacknowledgedCount.toString(),
                    subtitle: 'Requires Operator Action',
                    icon: Icons.pending_actions_rounded,
                    accentColor: AppColors.priorityP2,
                    onTap: () => alertProvider.setStatusFilter(AlertStatusEnum.received),
                  ),
                  AlertKpiCard(
                    title: 'Incidents Created',
                    value: stats.incidentCreatedCount.toString(),
                    subtitle: 'Auto-Triage P1/P2 Cases',
                    icon: Icons.auto_awesome_rounded,
                    accentColor: AppColors.statusAssigned,
                    onTap: () => alertProvider.setStatusFilter(AlertStatusEnum.incidentCreated),
                  ),
                  AlertKpiCard(
                    title: 'Correlated (Dedup)',
                    value: stats.correlatedCount.toString(),
                    subtitle: '15-min Window Deduped',
                    icon: Icons.link_rounded,
                    accentColor: const Color(0xFF7C3AED),
                    onTap: () => alertProvider.setStatusFilter(AlertStatusEnum.correlated),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: AppDimensions.spaceLg),

          // Search & Filter Controls Bar
          Container(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: AppDimensions.cardBorderRadius,
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Input Field
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search alerts by title, description, fingerprint, or case...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              alertProvider.setSearchQuery('');
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (val) => alertProvider.setSearchQuery(val),
                ),

                const SizedBox(height: AppDimensions.spaceMd),

                // Provider Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: AlertProviderEnum.values.map((p) {
                      final isSelected = alertProvider.selectedProvider == p;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          avatar: Icon(
                            p.icon,
                            size: 14,
                            color: isSelected ? Colors.white : p.brandColor,
                          ),
                          label: Text(p.displayName),
                          selected: isSelected,
                          selectedColor: AppColors.primaryBlue,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textPrimaryLight,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                          onSelected: (_) => alertProvider.setProviderFilter(p),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: AppDimensions.spaceSm),

                // Severity & Status Dropdowns + Clear Filter Row
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Severity Dropdown
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Severity: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        DropdownButton<AlertSeverityEnum>(
                          value: alertProvider.selectedSeverity,
                          items: AlertSeverityEnum.values
                              .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s.displayName, style: TextStyle(fontSize: 12, color: s.color)),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) alertProvider.setSeverityFilter(val);
                          },
                        ),
                      ],
                    ),

                    // Status Dropdown
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Status: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        DropdownButton<AlertStatusEnum>(
                          value: alertProvider.selectedStatus,
                          items: AlertStatusEnum.values
                              .map((st) => DropdownMenuItem(
                                    value: st,
                                    child: Text(st.displayName, style: TextStyle(fontSize: 12, color: st.color)),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) alertProvider.setStatusFilter(val);
                          },
                        ),
                      ],
                    ),

                    TextButton.icon(
                      icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                      label: const Text('Reset Filters', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        _searchCtrl.clear();
                        alertProvider.clearFilters();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppDimensions.spaceLg),

          // Main Workspace: Master-Detail on Desktop, Stacked List on Mobile
          if (filtered.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: EmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'No Matching Alerts Found',
                  description: 'No inbound monitoring alerts match the active filter criteria.',
                  actionLabel: 'Reset All Filters',
                  onAction: () {
                    _searchCtrl.clear();
                    alertProvider.clearFilters();
                  },
                ),
              ),
            )
          else if (isDesktop)
            // Desktop Master-Detail Pane Layout
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Alert List
                Expanded(
                  flex: 5,
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, idx) {
                      final item = filtered[idx];
                      final isSelected = alertProvider.selectedAlert?.id == item.id;
                      return AlertListCard(
                        alert: item,
                        isSelected: isSelected,
                        onTap: () => alertProvider.selectAlert(item),
                      );
                    },
                  ),
                ),

                const SizedBox(width: AppDimensions.spaceLg),

                // Right Column: Alert Detail Inspector Pane
                Expanded(
                  flex: 6,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: AppDimensions.cardBorderRadius,
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: alertProvider.selectedAlert != null
                        ? AlertDetailPane(
                            alert: alertProvider.selectedAlert!,
                            onClose: () => alertProvider.selectAlert(null),
                          )
                        : const Padding(
                            padding: EdgeInsets.all(40),
                            child: EmptyState(
                              icon: Icons.touch_app_outlined,
                              title: 'Select an Alert to Inspect',
                              description: 'Click any alert card on the left to inspect raw payload, correlation metadata, and trigger operator acknowledgement.',
                            ),
                          ),
                  ),
                ),
              ],
            )
          else
            // Mobile Stacked List Layout
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, idx) {
                final item = filtered[idx];
                return AlertListCard(
                  alert: item,
                  onTap: () {
                    alertProvider.selectAlert(item);
                    _openMobileDetailModal(context, item);
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRulesTab(
    BuildContext context,
    AlertProvider alertProvider,
    String? userRole,
  ) {
    if (alertProvider.isLoadingRules && alertProvider.rules.isEmpty) {
      return const LoadingState(message: 'Loading alert transformation rules...');
    }

    final rules = alertProvider.rules;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active Transformation & Ingestion Rules',
                    style: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Rules dictate automatic priority escalation and case generation upon webhook delivery.',
                    style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                  ),
                ],
              ),
              if (_canCreateRules(userRole))
                PrimaryButton(
                  label: 'Add Rule',
                  icon: Icons.add_rounded,
                  onPressed: _openCreateRuleDialog,
                ),
            ],
          ),

          const SizedBox(height: AppDimensions.spaceLg),

          if (rules.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: EmptyState(
                  icon: Icons.rule_folder_outlined,
                  title: 'No Alert Rules Configured',
                  description: 'No custom transformation rules are currently registered. Ingested alerts follow default critical auto-triage rules.',
                  actionLabel: _canCreateRules(userRole) ? 'Create Alert Rule' : null,
                  onAction: _canCreateRules(userRole) ? _openCreateRuleDialog : null,
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rules.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, idx) {
                final rule = rules[idx];
                final provider = rule.provider;

                return Container(
                  padding: const EdgeInsets.all(AppDimensions.spaceMd),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: AppDimensions.cardBorderRadius,
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: provider.brandColor.withValues(alpha: 0.12),
                              borderRadius: AppDimensions.priorityBorderRadius,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(provider.icon, size: 14, color: provider.brandColor),
                                const SizedBox(width: 4),
                                Text(
                                  provider.displayName,
                                  style: TextStyle(color: provider.brandColor, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              rule.name,
                              style: AppTypography.headlineSm.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: rule.isActive
                                  ? AppColors.statusResolved.withValues(alpha: 0.12)
                                  : AppColors.textSecondaryLight.withValues(alpha: 0.12),
                              borderRadius: AppDimensions.pillBorderRadius,
                            ),
                            child: Text(
                              rule.isActive ? 'ACTIVE' : 'DISABLED',
                              style: TextStyle(
                                color: rule.isActive ? AppColors.statusResolved : AppColors.textSecondaryLight,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppDimensions.spaceSm),

                      // Matching criteria & Auto-incident details
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          if (rule.matchSeverity != null)
                            Text(
                              'Match Severity: ${rule.matchSeverity!.toUpperCase()}',
                              style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
                            ),
                          if (rule.matchKeyword != null)
                            Text(
                              'Match Keyword: "${rule.matchKeyword}"',
                              style: AppTypography.bodySm.copyWith(color: AppColors.primaryBlue),
                            ),
                          Text(
                            'Target Priority: ${rule.incidentPriority.toUpperCase()}',
                            style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.bold, color: AppColors.priorityP1),
                          ),
                          Text(
                            'Auto-Create Case: ${rule.autoCreateIncident ? "YES" : "NO"}',
                            style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
