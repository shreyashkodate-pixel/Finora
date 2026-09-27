import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/admin/screens/admin_overview_screen.dart';
import '../features/admin/screens/system_audit_logs_screen.dart';
import '../features/admin/screens/team_management_screen.dart';
import '../features/admin/screens/tenant_governance_screen.dart';
import '../features/admin/screens/user_management_screen.dart';
import '../features/alerts/screens/inbound_alerts_screen.dart';
import '../features/analytics/screens/predictive_analytics_screen.dart';
import '../features/approvals/screens/pending_approvals_screen.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/cases/screens/case_list_screen.dart';
import '../features/changes/screens/change_management_screen.dart';
import '../features/dashboard/screens/manager_insights_screen.dart';
import '../features/dashboard/screens/operator_workspace_screen.dart';
import '../features/dashboard/screens/requester_home_screen.dart';
import '../features/knowledge/screens/knowledge_browser_screen.dart';
import '../features/major_incidents/screens/major_incident_screen.dart';
import '../features/notifications/providers/notification_provider.dart';
import '../features/notifications/screens/notification_preferences_screen.dart';
import '../features/problems/screens/problem_workspace_screen.dart';
import '../features/search/screens/semantic_search_screen.dart';
import '../shared/theme/colors.dart';
import '../shared/theme/dimensions.dart';
import '../shared/theme/typography.dart';
import '../shared/widgets/notification_center_dialog.dart';
import '../shared/widgets/responsive_scaffold.dart';
import '../shared/widgets/role_badge.dart';

/// Role-aware Dashboard Navigation Shell per Section 7 & 8 and Locked RBAC Invariant 4.
class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().loadUnreadCount();
    });
  }

  void _showProfileMenu(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusBottomSheet)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spaceLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primaryBlue,
                      radius: 24,
                      child: Text(
                        (user?.displayName.isNotEmpty == true ? user!.displayName[0] : 'U').toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullName ?? 'Helpdesk User',
                            style: AppTypography.headlineSm.copyWith(fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.email ?? '',
                            style: AppTypography.bodySm,
                          ),
                        ],
                      ),
                    ),
                    RoleBadge(role: user?.role ?? 'requester'),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.badge_outlined, color: AppColors.textSecondaryLight),
                  title: const Text('System Role'),
                  subtitle: Text((user?.role ?? 'REQUESTER').toUpperCase()),
                ),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.location_on_outlined, color: AppColors.textSecondaryLight),
                  title: const Text('Site / Campus'),
                  subtitle: Text(user?.site ?? 'Default Enterprise Campus'),
                ),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.notifications_active_outlined, color: AppColors.primaryBlue),
                  title: const Text('Notification Preferences'),
                  subtitle: const Text('Push devices & delivery channels'),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NotificationPreferencesScreen(),
                      ),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: AppColors.priorityP1),
                  title: Text(
                    'Sign Out',
                    style: AppTypography.bodyMd.copyWith(color: AppColors.priorityP1, fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    auth.logout();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final role = user?.role.toLowerCase().trim() ?? 'requester';

    final List<NavigationDestinationItem> destinations;
    final List<Widget> screens;
    final String title;

    // 1. Administrator Navigation (System Governance - Locked Invariant 4)
    if (role == 'admin' || role == 'administrator') {
      title = 'AI IT Helpdesk — Administration & Governance';
      destinations = const [
        NavigationDestinationItem(
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard_rounded,
          label: 'Overview',
        ),
        NavigationDestinationItem(
          icon: Icons.person_search_outlined,
          selectedIcon: Icons.person_search_rounded,
          label: 'Users',
        ),
        NavigationDestinationItem(
          icon: Icons.groups_outlined,
          selectedIcon: Icons.groups_rounded,
          label: 'Teams',
        ),
        NavigationDestinationItem(
          icon: Icons.admin_panel_settings_outlined,
          selectedIcon: Icons.admin_panel_settings_rounded,
          label: 'Tenant Policy',
        ),
        NavigationDestinationItem(
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long_rounded,
          label: 'Audit Logs',
        ),
        NavigationDestinationItem(
          icon: Icons.insights_outlined,
          selectedIcon: Icons.insights_rounded,
          label: 'Insights',
        ),
        NavigationDestinationItem(
          icon: Icons.auto_graph_outlined,
          selectedIcon: Icons.auto_graph_rounded,
          label: 'Predictive',
        ),
        NavigationDestinationItem(
          icon: Icons.sensors_outlined,
          selectedIcon: Icons.sensors_rounded,
          label: 'Alerts & APM',
        ),
        NavigationDestinationItem(
          icon: Icons.all_inbox_outlined,
          selectedIcon: Icons.all_inbox_rounded,
          label: 'All Tickets',
        ),
        NavigationDestinationItem(
          icon: Icons.approval_outlined,
          selectedIcon: Icons.approval_rounded,
          label: 'Approvals',
        ),
        NavigationDestinationItem(
          icon: Icons.travel_explore_outlined,
          selectedIcon: Icons.travel_explore_rounded,
          label: 'Search & NL',
        ),
        NavigationDestinationItem(
          icon: Icons.menu_book_outlined,
          selectedIcon: Icons.menu_book_rounded,
          label: 'Knowledge',
        ),
      ];
      screens = [
        AdminOverviewScreen(onNavigateTab: (idx) => setState(() => _selectedIndex = idx)),
        const UserManagementScreen(),
        const TeamManagementScreen(),
        const TenantGovernanceScreen(),
        const SystemAuditLogsScreen(),
        const ManagerInsightsScreen(),
        const PredictiveAnalyticsScreen(),
        const InboundAlertsScreen(),
        const CaseListScreen(),
        const PendingApprovalsScreen(),
        const SemanticSearchScreen(),
        const KnowledgeBrowserScreen(),
      ];
    }
    // 2. Manager Navigation (Operational Management & Cross-Team Oversight)
    else if (role == 'manager') {
      title = 'AI IT Helpdesk — Leadership Console';
      destinations = const [
        NavigationDestinationItem(
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard_rounded,
          label: 'Overview',
        ),
        NavigationDestinationItem(
          icon: Icons.auto_graph_outlined,
          selectedIcon: Icons.auto_graph_rounded,
          label: 'Predictive',
        ),
        NavigationDestinationItem(
          icon: Icons.engineering_outlined,
          selectedIcon: Icons.engineering_rounded,
          label: 'Workstation',
        ),
        NavigationDestinationItem(
          icon: Icons.all_inbox_outlined,
          selectedIcon: Icons.all_inbox_rounded,
          label: 'Tickets',
        ),
        NavigationDestinationItem(
          icon: Icons.sensors_outlined,
          selectedIcon: Icons.sensors_rounded,
          label: 'Alerts & APM',
        ),
        NavigationDestinationItem(
          icon: Icons.approval_outlined,
          selectedIcon: Icons.approval_rounded,
          label: 'Approvals',
        ),
        NavigationDestinationItem(
          icon: Icons.fact_check_outlined,
          selectedIcon: Icons.fact_check_rounded,
          label: 'Problems',
        ),
        NavigationDestinationItem(
          icon: Icons.published_with_changes_outlined,
          selectedIcon: Icons.published_with_changes_rounded,
          label: 'Changes',
        ),
        NavigationDestinationItem(
          icon: Icons.warning_amber_outlined,
          selectedIcon: Icons.warning_rounded,
          label: 'Major Outages',
        ),
        NavigationDestinationItem(
          icon: Icons.travel_explore_outlined,
          selectedIcon: Icons.travel_explore_rounded,
          label: 'Search & NL',
        ),
        NavigationDestinationItem(
          icon: Icons.menu_book_outlined,
          selectedIcon: Icons.menu_book_rounded,
          label: 'Knowledge',
        ),
      ];
      screens = const [
        ManagerInsightsScreen(),
        PredictiveAnalyticsScreen(),
        OperatorWorkspaceScreen(),
        CaseListScreen(),
        InboundAlertsScreen(),
        PendingApprovalsScreen(),
        ProblemWorkspaceScreen(),
        ChangeManagementScreen(),
        MajorIncidentScreen(),
        SemanticSearchScreen(),
        KnowledgeBrowserScreen(),
      ];
    }
    // 3. Team Lead Navigation (Team Oversight & Approvals)
    else if (role == 'lead' || role == 'team_lead') {
      title = 'AI IT Helpdesk — Team Lead Console';
      destinations = const [
        NavigationDestinationItem(
          icon: Icons.engineering_outlined,
          selectedIcon: Icons.engineering_rounded,
          label: 'Workstation',
        ),
        NavigationDestinationItem(
          icon: Icons.auto_graph_outlined,
          selectedIcon: Icons.auto_graph_rounded,
          label: 'Predictive',
        ),
        NavigationDestinationItem(
          icon: Icons.all_inbox_outlined,
          selectedIcon: Icons.all_inbox_rounded,
          label: 'Queue',
        ),
        NavigationDestinationItem(
          icon: Icons.sensors_outlined,
          selectedIcon: Icons.sensors_rounded,
          label: 'Alerts & APM',
        ),
        NavigationDestinationItem(
          icon: Icons.approval_outlined,
          selectedIcon: Icons.approval_rounded,
          label: 'Approvals',
        ),
        NavigationDestinationItem(
          icon: Icons.fact_check_outlined,
          selectedIcon: Icons.fact_check_rounded,
          label: 'Problems',
        ),
        NavigationDestinationItem(
          icon: Icons.published_with_changes_outlined,
          selectedIcon: Icons.published_with_changes_rounded,
          label: 'Changes',
        ),
        NavigationDestinationItem(
          icon: Icons.warning_amber_outlined,
          selectedIcon: Icons.warning_rounded,
          label: 'Major Outages',
        ),
        NavigationDestinationItem(
          icon: Icons.travel_explore_outlined,
          selectedIcon: Icons.travel_explore_rounded,
          label: 'Search & NL',
        ),
        NavigationDestinationItem(
          icon: Icons.menu_book_outlined,
          selectedIcon: Icons.menu_book_rounded,
          label: 'Knowledge',
        ),
      ];
      screens = const [
        OperatorWorkspaceScreen(),
        PredictiveAnalyticsScreen(),
        CaseListScreen(),
        InboundAlertsScreen(),
        PendingApprovalsScreen(),
        ProblemWorkspaceScreen(),
        ChangeManagementScreen(),
        MajorIncidentScreen(),
        SemanticSearchScreen(),
        KnowledgeBrowserScreen(),
      ];
    }
    // 4. Operator Navigation (L1/L2 Incident & Request Workstation)
    else if (role == 'operator' || role == 'level1' || role == 'level2') {
      title = 'AI IT Helpdesk — Operator Workstation';
      destinations = const [
        NavigationDestinationItem(
          icon: Icons.engineering_outlined,
          selectedIcon: Icons.engineering_rounded,
          label: 'Workstation',
        ),
        NavigationDestinationItem(
          icon: Icons.all_inbox_outlined,
          selectedIcon: Icons.all_inbox_rounded,
          label: 'Tickets',
        ),
        NavigationDestinationItem(
          icon: Icons.sensors_outlined,
          selectedIcon: Icons.sensors_rounded,
          label: 'Alerts & APM',
        ),
        NavigationDestinationItem(
          icon: Icons.fact_check_outlined,
          selectedIcon: Icons.fact_check_rounded,
          label: 'Problems',
        ),
        NavigationDestinationItem(
          icon: Icons.published_with_changes_outlined,
          selectedIcon: Icons.published_with_changes_rounded,
          label: 'Changes',
        ),
        NavigationDestinationItem(
          icon: Icons.warning_amber_outlined,
          selectedIcon: Icons.warning_rounded,
          label: 'Major Outages',
        ),
        NavigationDestinationItem(
          icon: Icons.travel_explore_outlined,
          selectedIcon: Icons.travel_explore_rounded,
          label: 'Search & NL',
        ),
        NavigationDestinationItem(
          icon: Icons.menu_book_outlined,
          selectedIcon: Icons.menu_book_rounded,
          label: 'Knowledge',
        ),
      ];
      screens = const [
        OperatorWorkspaceScreen(),
        CaseListScreen(),
        InboundAlertsScreen(),
        ProblemWorkspaceScreen(),
        ChangeManagementScreen(),
        MajorIncidentScreen(),
        SemanticSearchScreen(),
        KnowledgeBrowserScreen(),
      ];
    }
    // 5. Requester Navigation (Employee Self-Service Portal)
    else {
      title = 'AI IT Helpdesk — Self-Service Portal';
      destinations = const [
        NavigationDestinationItem(
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
          label: 'Home',
        ),
        NavigationDestinationItem(
          icon: Icons.confirmation_number_outlined,
          selectedIcon: Icons.confirmation_number_rounded,
          label: 'My Tickets',
        ),
        NavigationDestinationItem(
          icon: Icons.travel_explore_outlined,
          selectedIcon: Icons.travel_explore_rounded,
          label: 'Search & NL',
        ),
        NavigationDestinationItem(
          icon: Icons.menu_book_outlined,
          selectedIcon: Icons.menu_book_rounded,
          label: 'Knowledge Base',
        ),
      ];
      screens = const [
        RequesterHomeScreen(),
        CaseListScreen(),
        SemanticSearchScreen(),
        KnowledgeBrowserScreen(),
      ];
    }

    final safeIndex = _selectedIndex < screens.length ? _selectedIndex : 0;

    return ResponsiveScaffold(
      title: title,
      selectedIndex: safeIndex,
      onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
      destinations: destinations,
      actions: [
        Consumer<NotificationProvider>(
          builder: (context, notifProvider, _) {
            final unread = notifProvider.unreadCount;
            return IconButton(
              tooltip: unread > 0 ? 'Notifications ($unread unread)' : 'Notifications',
              icon: unread > 0
                  ? Badge.count(
                      count: unread,
                      backgroundColor: AppColors.priorityP1,
                      textColor: Colors.white,
                      child: const Icon(Icons.notifications_outlined),
                    )
                  : const Icon(Icons.notifications_outlined),
              onPressed: () => NotificationCenterDialog.show(context),
            );
          },
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'User Profile & Sign Out',
          icon: CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.12),
            child: Text(
              (user?.displayName.isNotEmpty == true ? user!.displayName[0] : 'U').toUpperCase(),
              style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          onPressed: () => _showProfileMenu(context),
        ),
        const SizedBox(width: 8),
      ],
      body: IndexedStack(
        index: safeIndex,
        children: screens,
      ),
    );
  }
}
