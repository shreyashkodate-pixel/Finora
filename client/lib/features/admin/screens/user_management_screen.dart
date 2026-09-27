import 'package:flutter/material.dart';
import '../../../shared/responsive/breakpoints.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/dimensions.dart';
import '../../../shared/theme/typography.dart';
import '../../../shared/widgets/role_badge.dart';

/// Stitch Screen: user_management
/// Enterprise user directory, RBAC governance, and access control.
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _searchController = TextEditingController();
  String _selectedRole = 'all';
  String _selectedTeam = 'all';
  String _selectedStatus = 'all';

  final List<Map<String, String>> _users = [
    {
      'name': 'Alex Vance',
      'email': 'alex.vance@acme.corp',
      'role': 'admin',
      'team': 'SecOps & Infrastructure',
      'org': 'Acme Enterprise Corp',
      'auth': 'Dual (OAuth + Pass)',
      'status': 'Active',
      'lastActive': 'Just now',
    },
    {
      'name': 'Sarah Jenkins',
      'email': 'sarah.jenkins@acme.corp',
      'role': 'operator',
      'team': 'L2 Network Operations',
      'org': 'Acme Enterprise Corp',
      'auth': 'Dual (OAuth + Pass)',
      'status': 'Active',
      'lastActive': '4m ago',
    },
    {
      'name': 'Clara Lin',
      'email': 'clara.lin@acme.corp',
      'role': 'lead',
      'team': 'Cloud Infrastructure',
      'org': 'Acme Enterprise Corp',
      'auth': 'Dual (OAuth + Pass)',
      'status': 'Active',
      'lastActive': '12m ago',
    },
    {
      'name': 'Marcus Davies',
      'email': 'marcus.davies@acme.corp',
      'role': 'manager',
      'team': 'Operations Leadership',
      'org': 'Acme Enterprise Corp',
      'auth': 'Dual (OAuth + Pass)',
      'status': 'Active',
      'lastActive': '18m ago',
    },
    {
      'name': 'Alec Turner',
      'email': 'alec.turner@acme.corp',
      'role': 'operator',
      'team': 'Workplace & Support',
      'org': 'Acme Enterprise Corp',
      'auth': 'Dual (OAuth + Pass)',
      'status': 'Active',
      'lastActive': '35m ago',
    },
    {
      'name': 'Michael Chang',
      'email': 'michael.chang@acme.corp',
      'role': 'lead',
      'team': 'Workplace & Support',
      'org': 'Acme Enterprise Corp',
      'auth': 'Dual (OAuth + Pass)',
      'status': 'Active',
      'lastActive': '1h ago',
    },
    {
      'name': 'Requester Demo',
      'email': 'requester@enterprise.com',
      'role': 'requester',
      'team': 'General Enterprise Staff',
      'org': 'Finora Technologies',
      'auth': 'Dual (OAuth + Pass)',
      'status': 'Active',
      'lastActive': '2h ago',
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddUserDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String role = 'operator';
    String team = 'Workplace & Support';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.person_add_rounded, color: AppColors.primaryBlue),
              const SizedBox(width: 8),
              const Text('Add Enterprise User'),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Corporate Email', prefixIcon: Icon(Icons.email_outlined)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'RBAC Role', prefixIcon: Icon(Icons.badge_outlined)),
                  items: const [
                    DropdownMenuItem(value: 'requester', child: Text('Requester')),
                    DropdownMenuItem(value: 'operator', child: Text('Operator (L1/L2)')),
                    DropdownMenuItem(value: 'lead', child: Text('Team Lead')),
                    DropdownMenuItem(value: 'manager', child: Text('Manager')),
                    DropdownMenuItem(value: 'admin', child: Text('Administrator')),
                  ],
                  onChanged: (val) => setDialogState(() => role = val ?? 'operator'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: team,
                  decoration: const InputDecoration(labelText: 'Team Assignment', prefixIcon: Icon(Icons.groups_outlined)),
                  items: const [
                    DropdownMenuItem(value: 'L2 Network Operations', child: Text('L2 Network Operations')),
                    DropdownMenuItem(value: 'Cloud Infrastructure', child: Text('Cloud Infrastructure')),
                    DropdownMenuItem(value: 'Workplace & Support', child: Text('Workplace & Support')),
                    DropdownMenuItem(value: 'SecOps & Infrastructure', child: Text('SecOps & Infrastructure')),
                    DropdownMenuItem(value: 'General Enterprise Staff', child: Text('General Enterprise Staff')),
                  ],
                  onChanged: (val) => setDialogState(() => team = val ?? 'Workplace & Support'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white),
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty && emailCtrl.text.trim().isNotEmpty) {
                  setState(() {
                    _users.insert(0, {
                      'name': nameCtrl.text.trim(),
                      'email': emailCtrl.text.trim(),
                      'role': role,
                      'team': team,
                      'org': 'Acme Enterprise Corp',
                      'auth': 'Dual (OAuth + Pass)',
                      'status': 'Pending Verification',
                      'lastActive': 'Invited Just Now',
                    });
                  });
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('User invitation dispatched to ${emailCtrl.text.trim()}')),
                  );
                }
              },
              child: const Text('Provision Identity'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filteredUsers = _users.where((u) {
      if (query.isNotEmpty) {
        final match = u['name']!.toLowerCase().contains(query) ||
            u['email']!.toLowerCase().contains(query) ||
            u['team']!.toLowerCase().contains(query);
        if (!match) return false;
      }
      if (_selectedRole != 'all' && u['role'] != _selectedRole) return false;
      if (_selectedTeam != 'all' && u['team'] != _selectedTeam) return false;
      if (_selectedStatus != 'all' && u['status'] != _selectedStatus) return false;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header & Actions
            _buildHeader(context),
            const SizedBox(height: AppDimensions.spaceLg),

            // 2. Bento Stats Grid
            _buildBentoGrid(),
            const SizedBox(height: AppDimensions.spaceLg),

            // 3. RBAC Enforcement Invariant Banner
            _buildInvariantBanner(),
            const SizedBox(height: AppDimensions.spaceLg),

            // 4. Filter Matrix
            _buildFilterMatrix(),
            const SizedBox(height: AppDimensions.spaceMd),

            // 5. User Directory Dense Table
            _buildUserTable(filteredUsers),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'IDENTITY GOVERNANCE',
                  style: AppTypography.labelSm.copyWith(
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('•', style: TextStyle(color: AppColors.textSecondaryLight)),
                const SizedBox(width: 8),
                Text(
                  'v4.18-tenant-isolated',
                  style: AppTypography.codeMd.copyWith(fontSize: 11, color: AppColors.textSecondaryLight),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('User Management & Access Control', style: AppTypography.headlineLg),
            const SizedBox(height: 4),
            Text(
              'Manage enterprise identities, RBAC roles, team assignments, and authentication states across tenant boundaries.',
              style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondaryLight),
            ),
          ],
        ),
        Row(
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.file_download_outlined, size: 16),
              label: const Text('Export CSV'),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Exporting enterprise user directory as CSV...')),
                );
              },
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.sync_alt, size: 16),
              label: const Text('SCIM Sync'),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('SCIM directory synchronization triggered.')),
                );
              },
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.person_add, size: 16),
              label: const Text('+ Add New User'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
              ),
              onPressed: _showAddUserDialog,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBentoGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < ResponsiveBreakpoints.mobileMax;
        final c1 = _buildStatCard('Total Directory Seats', '482', '/ 500 Provisioned', 0.964, AppColors.primaryBlue, Icons.groups);
        final c2 = _buildStatCard('MFA & PKCE Enforced', '98.2%', '473 Active', 0.982, AppColors.secondaryIndigo, Icons.verified_user);
        final c3 = _buildStatCard('Pending Verification', '6', 'Auto-expires in 48h', 0.25, AppColors.statusAssigned, Icons.hourglass_top);
        final c4 = _buildStatCard('Admin Role Escalations', '3', 'Tier 0 Critical', 0.15, AppColors.priorityP1, Icons.admin_panel_settings);

        if (isMobile) {
          return Column(children: [c1, const SizedBox(height: 10), c2, const SizedBox(height: 10), c3, const SizedBox(height: 10), c4]);
        }
        return Row(
          children: [
            Expanded(child: c1),
            const SizedBox(width: AppDimensions.spaceMd),
            Expanded(child: c2),
            const SizedBox(width: AppDimensions.spaceMd),
            Expanded(child: c3),
            const SizedBox(width: AppDimensions.spaceMd),
            Expanded(child: c4),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, String sub, double progress, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
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
              Text(label.toUpperCase(), style: AppTypography.labelSm.copyWith(color: AppColors.textSecondaryLight, fontSize: 10)),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(width: 6),
              Text(sub, style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: AppColors.backgroundLight,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvariantBanner() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.primaryBlue.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.shield_outlined, color: AppColors.primaryBlue, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FastAPI Dependency Enforcement Invariant [Sec-RBAC-041]',
                  style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                ),
                Text(
                  'Role-Based Access Control (RBAC) enforced via backend dependency factories. Role escalations require administrative re-authentication and are logged to immutable WORM audit trails.',
                  style: AppTypography.bodySm.copyWith(color: AppColors.textPrimaryLight),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.borderLight)),
            child: Text('DEP_INJECT_V2: PASS', style: AppTypography.codeMd.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterMatrix() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search users by name, email, or team...',
                prefixIcon: Icon(Icons.search, size: 18),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              initialValue: _selectedRole,
              isDense: true,
              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Roles')),
                DropdownMenuItem(value: 'admin', child: Text('Administrator')),
                DropdownMenuItem(value: 'manager', child: Text('Manager')),
                DropdownMenuItem(value: 'lead', child: Text('Team Lead')),
                DropdownMenuItem(value: 'operator', child: Text('Operator L1/L2')),
                DropdownMenuItem(value: 'requester', child: Text('Requester')),
              ],
              onChanged: (val) => setState(() => _selectedRole = val ?? 'all'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              initialValue: _selectedStatus,
              isDense: true,
              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Status')),
                DropdownMenuItem(value: 'Active', child: Text('Active')),
                DropdownMenuItem(value: 'Pending Verification', child: Text('Pending')),
              ],
              onChanged: (val) => setState(() => _selectedStatus = val ?? 'all'),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.filter_alt_off, size: 16),
            label: const Text('Reset'),
            onPressed: () {
              setState(() {
                _searchController.clear();
                _selectedRole = 'all';
                _selectedTeam = 'all';
                _selectedStatus = 'all';
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUserTable(List<Map<String, String>> users) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(3.0),
          1: FlexColumnWidth(1.5),
          2: FlexColumnWidth(2.2),
          3: FlexColumnWidth(2.0),
          4: FlexColumnWidth(1.4),
          5: FlexColumnWidth(1.4),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration: const BoxDecoration(
              color: AppColors.backgroundLight,
              border: Border(bottom: BorderSide(color: AppColors.borderLight)),
            ),
            children: [
              _buildTh('User Profile'),
              _buildTh('RBAC Role'),
              _buildTh('Team Assignment'),
              _buildTh('Organization'),
              _buildTh('Status'),
              _buildTh('Last Active', alignRight: true),
            ],
          ),
          ...users.map((u) {
            return TableRow(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.borderLight, width: 0.5)),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.12),
                        child: Text(
                          u['name']![0],
                          style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(u['name']!, style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.bold)),
                          Text(u['email']!, style: AppTypography.codeMd.copyWith(fontSize: 11, color: AppColors.textSecondaryLight)),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: RoleBadge(role: u['role']!),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Text(u['team']!, style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w500)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Text(u['org']!, style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: u['status'] == 'Active' ? AppColors.slaHealthy.withValues(alpha: 0.12) : AppColors.statusAssigned.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                    ),
                    child: Text(
                      u['status']!,
                      style: AppTypography.labelSm.copyWith(
                        color: u['status'] == 'Active' ? AppColors.slaHealthy : AppColors.statusAssigned,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(u['lastActive']!, style: AppTypography.codeMd.copyWith(fontSize: 11, color: AppColors.textSecondaryLight)),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTh(String text, {bool alignRight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text.toUpperCase(),
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: AppTypography.labelSm.copyWith(
          color: AppColors.textSecondaryLight,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          fontSize: 11,
        ),
      ),
    );
  }
}
