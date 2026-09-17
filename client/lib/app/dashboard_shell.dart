import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/approvals/screens/pending_approvals_screen.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/cases/screens/case_list_screen.dart';
import '../features/changes/screens/change_management_screen.dart';
import '../features/dashboard/screens/manager_insights_screen.dart';
import '../features/dashboard/screens/operator_workspace_screen.dart';
import '../features/dashboard/screens/requester_home_screen.dart';
import '../features/knowledge/screens/knowledge_browser_screen.dart';
import '../features/major_incidents/screens/major_incident_screen.dart';
import '../features/problems/screens/problem_workspace_screen.dart';
import '../shared/theme/colors.dart';
import '../shared/widgets/responsive_scaffold.dart';

/// Role-aware Dashboard Navigation Shell per SRS §3.1 & §7.
class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int _selectedIndex = 0;

  void _showProfileMenu(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
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
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            user?.email ?? '',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.borderLight),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Role & Authorization'),
                  subtitle: Text(user?.role.toUpperCase() ?? 'REQUESTER'),
                ),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.location_on_outlined),
                  title: const Text('Campus / Site'),
                  subtitle: Text(user?.site ?? 'Not Specified'),
                ),
                const Divider(color: AppColors.borderLight),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.priorityP1),
                  title: const Text('Sign Out', style: TextStyle(color: AppColors.priorityP1, fontWeight: FontWeight.bold)),
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
    final role = user?.role.toLowerCase() ?? 'requester';

    // Configure role-tailored destinations & screens
    final List<NavigationDestinationItem> destinations;
    final List<Widget> screens;
    final String title;

    if (role == 'manager' || role == 'admin' || role == 'administrator' || role == 'lead' || role == 'team_lead') {
      title = 'AI IT Helpdesk - Leadership Console';
      destinations = const [
        NavigationDestinationItem(
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
          label: 'Insights',
        ),
        NavigationDestinationItem(
          icon: Icons.engineering_outlined,
          selectedIcon: Icons.engineering,
          label: 'Workstation',
        ),
        NavigationDestinationItem(
          icon: Icons.all_inbox_outlined,
          selectedIcon: Icons.all_inbox,
          label: 'All Tickets',
        ),
        NavigationDestinationItem(
          icon: Icons.approval_outlined,
          selectedIcon: Icons.approval,
          label: 'Approvals',
        ),
        NavigationDestinationItem(
          icon: Icons.fact_check_outlined,
          selectedIcon: Icons.fact_check,
          label: 'Problems',
        ),
        NavigationDestinationItem(
          icon: Icons.published_with_changes_outlined,
          selectedIcon: Icons.published_with_changes,
          label: 'Changes',
        ),
        NavigationDestinationItem(
          icon: Icons.warning_amber_outlined,
          selectedIcon: Icons.warning,
          label: 'Major Outages',
        ),
        NavigationDestinationItem(
          icon: Icons.menu_book_outlined,
          selectedIcon: Icons.menu_book,
          label: 'Knowledge',
        ),
      ];
      screens = const [
        ManagerInsightsScreen(),
        OperatorWorkspaceScreen(),
        CaseListScreen(),
        PendingApprovalsScreen(),
        ProblemWorkspaceScreen(),
        ChangeManagementScreen(),
        MajorIncidentScreen(),
        KnowledgeBrowserScreen(),
      ];
    } else if (role == 'operator' || role == 'level1' || role == 'level2') {
      title = 'AI IT Helpdesk - Operator Console';
      destinations = const [
        NavigationDestinationItem(
          icon: Icons.engineering_outlined,
          selectedIcon: Icons.engineering,
          label: 'Workstation',
        ),
        NavigationDestinationItem(
          icon: Icons.all_inbox_outlined,
          selectedIcon: Icons.all_inbox,
          label: 'Tickets',
        ),
        NavigationDestinationItem(
          icon: Icons.fact_check_outlined,
          selectedIcon: Icons.fact_check,
          label: 'Problems',
        ),
        NavigationDestinationItem(
          icon: Icons.published_with_changes_outlined,
          selectedIcon: Icons.published_with_changes,
          label: 'Changes',
        ),
        NavigationDestinationItem(
          icon: Icons.warning_amber_outlined,
          selectedIcon: Icons.warning,
          label: 'Major Outages',
        ),
        NavigationDestinationItem(
          icon: Icons.menu_book_outlined,
          selectedIcon: Icons.menu_book,
          label: 'Knowledge',
        ),
      ];
      screens = const [
        OperatorWorkspaceScreen(),
        CaseListScreen(),
        ProblemWorkspaceScreen(),
        ChangeManagementScreen(),
        MajorIncidentScreen(),
        KnowledgeBrowserScreen(),
      ];

    } else {
      // Default: Requester Portal
      title = 'AI IT Helpdesk - Self-Service Portal';
      destinations = const [
        NavigationDestinationItem(
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
          label: 'Home',
        ),
        NavigationDestinationItem(
          icon: Icons.confirmation_number_outlined,
          selectedIcon: Icons.confirmation_number,
          label: 'My Tickets',
        ),
        NavigationDestinationItem(
          icon: Icons.menu_book_outlined,
          selectedIcon: Icons.menu_book,
          label: 'Knowledge Base',
        ),
      ];
      screens = const [
        RequesterHomeScreen(),
        CaseListScreen(),
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
        IconButton(
          tooltip: 'User Profile & Sign Out',
          icon: CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.15),
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
