import 'package:flutter/material.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/dimensions.dart';
import '../../../shared/theme/typography.dart';

/// Stitch Screen: team_management
/// Operational team groups, lead assignment, and routing boundaries.
class TeamManagementScreen extends StatefulWidget {
  const TeamManagementScreen({super.key});

  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen> {
  final _searchController = TextEditingController();
  String _selectedDept = 'all';

  final List<Map<String, dynamic>> _teams = [
    {
      'name': 'L2 Network Operations',
      'dept': 'operations',
      'deptLabel': 'Operations',
      'uid': '#TM-NET-02',
      'activeIncidents': 14,
      'description': 'Triage, diagnosis, and remediation of regional VPN concentrators, routing, and SD-WAN gateways.',
      'leadName': 'Sarah Jenkins',
      'leadRole': 'Lead Network Specialist',
      'operators': 8,
      'routing': ['Network & VPN', 'VPN Gateway', 'Firewall Rules'],
      'icon': Icons.hub_rounded,
      'color': AppColors.primaryBlue,
    },
    {
      'name': 'Cloud Infrastructure & DB',
      'dept': 'infrastructure',
      'deptLabel': 'Infrastructure',
      'uid': '#TM-CLD-05',
      'activeIncidents': 9,
      'description': 'AWS CloudWatch, Datadog Postgres RDS pools, Kubernetes node provisioning and auto-scaling.',
      'leadName': 'Clara Lin',
      'leadRole': 'Staff Cloud Architect',
      'operators': 6,
      'routing': ['Cloud & DevOps', 'Database', 'Kubernetes'],
      'icon': Icons.cloud_sync_rounded,
      'color': AppColors.secondaryIndigo,
    },
    {
      'name': 'Workplace & End-User (L1)',
      'dept': 'support',
      'deptLabel': 'End-User Support',
      'uid': '#TM-SUP-01',
      'activeIncidents': 26,
      'description': 'Initial case intake triage, hardware peripherals, Windows/macOS troubleshooting, and software licensing.',
      'leadName': 'Michael Chang',
      'leadRole': 'L1 Support Lead',
      'operators': 14,
      'routing': ['Hardware', 'Software & Accounts', 'Client Printers'],
      'icon': Icons.headset_mic_rounded,
      'color': AppColors.statusAssigned,
    },
    {
      'name': 'SecOps & Identity',
      'dept': 'security',
      'deptLabel': 'Security',
      'uid': '#TM-SEC-03',
      'activeIncidents': 5,
      'description': 'Zero Trust architecture, OAuth token validation, RBAC audits, and suspicious intrusion mitigation.',
      'leadName': 'Alex Vance',
      'leadRole': 'Lead SecOps Architect',
      'operators': 4,
      'routing': ['MFA/SSO', 'Incident Response', 'Access Audit'],
      'icon': Icons.security_rounded,
      'color': AppColors.priorityP1,
    },
    {
      'name': 'IT Operations Leadership',
      'dept': 'operations',
      'deptLabel': 'Operations',
      'uid': '#TM-MGR-01',
      'activeIncidents': 0,
      'description': 'Executive service desk governance, SLA breach mitigation, CAB change approvals, and budget allocation.',
      'leadName': 'Marcus Davies',
      'leadRole': 'IT Operations Director',
      'operators': 5,
      'routing': ['Approvals', 'CAB Review', 'Escalations'],
      'icon': Icons.admin_panel_settings_rounded,
      'color': AppColors.slaHealthy,
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showRoutingRulesDialog(String teamName, List<String> routing) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.tune_rounded, color: AppColors.primaryBlue),
            const SizedBox(width: 8),
            Text('Routing Rules: $teamName'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Active automated dispatch tokens mapped to this operational team:', style: AppTypography.bodySm),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: routing.map((r) => Chip(
                label: Text(r, style: AppTypography.codeMd.copyWith(fontSize: 12)),
                backgroundColor: AppColors.primaryLight.withValues(alpha: 0.1),
              )).toList(),
            ),
            const SizedBox(height: 16),
            const Divider(),
            ListTile(
              dense: true,
              leading: const Icon(Icons.auto_awesome, color: AppColors.aiAccent),
              title: const Text('AI Auto-Triage Dispatch'),
              subtitle: const Text('Gemini 2.5 Flash routes high-confidence matches directly to this queue.'),
              trailing: Switch(value: true, onChanged: (_) {}),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filteredTeams = _teams.where((t) {
      if (query.isNotEmpty) {
        final match = (t['name'] as String).toLowerCase().contains(query) ||
            (t['leadName'] as String).toLowerCase().contains(query);
        if (!match) return false;
      }
      if (_selectedDept != 'all' && t['dept'] != _selectedDept) return false;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header Zone
            _buildHeader(context),
            const SizedBox(height: AppDimensions.spaceLg),

            // 2. Operational Notice
            _buildNoticeBanner(),
            const SizedBox(height: AppDimensions.spaceLg),

            // 3. Toolstrip
            _buildToolstrip(),
            const SizedBox(height: AppDimensions.spaceLg),

            // 4. Teams Grid
            _buildTeamsGrid(filteredTeams),
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
                const Icon(Icons.device_hub, size: 16, color: AppColors.secondaryIndigo),
                const SizedBox(width: 6),
                Text(
                  'ORG HIERARCHY • IAM / ITIL ARCHITECTURE',
                  style: AppTypography.labelSm.copyWith(
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondaryIndigo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Team Management & Routing Hierarchy', style: AppTypography.headlineLg),
            const SizedBox(height: 4),
            Text(
              'Organize operational groups, designate team leads, and configure queue routing boundaries in accordance with SRS §2.1 and PRD §3.',
              style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondaryLight),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.backgroundLight, borderRadius: BorderRadius.circular(6)),
                child: Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.slaHealthy, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('5 Active Teams', style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text('37 Operators Online', style: AppTypography.codeMd.copyWith(fontSize: 12, color: AppColors.textSecondaryLight)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.priorityP1.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                child: Text('54 Active Incidents', style: AppTypography.codeMd.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.priorityP1)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoticeBanner() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.secondaryIndigo.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.secondaryIndigo.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.secondaryIndigo.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.info_outline, color: AppColors.secondaryIndigo, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Operational Scope Notice: Team Administration manages structural membership and assignment routing. For real-time workload balancing, queue throughput, and capacity forecasting, refer to the Manager Operational Health dashboard.',
              style: AppTypography.bodySm.copyWith(color: AppColors.textPrimaryLight),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolstrip() {
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
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search team name or lead...',
                prefixIcon: Icon(Icons.search, size: 18),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<String>(
            value: _selectedDept,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Departments')),
              DropdownMenuItem(value: 'operations', child: Text('Operations')),
              DropdownMenuItem(value: 'infrastructure', child: Text('Infrastructure')),
              DropdownMenuItem(value: 'support', child: Text('End-User Support')),
              DropdownMenuItem(value: 'security', child: Text('Security')),
            ],
            onChanged: (val) => setState(() => _selectedDept = val ?? 'all'),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.group_add, size: 16),
            label: const Text('+ Create New Team'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Team creation dialog opened.')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTeamsGrid(List<Map<String, dynamic>> teams) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1200
            ? 3
            : constraints.maxWidth > 768
                ? 2
                : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: AppDimensions.spaceMd,
            mainAxisSpacing: AppDimensions.spaceMd,
            mainAxisExtent: 310,
          ),
          itemCount: teams.length,
          itemBuilder: (context, idx) {
            final t = teams[idx];
            return _buildTeamCard(t);
          },
        );
      },
    );
  }

  Widget _buildTeamCard(Map<String, dynamic> t) {
    final routing = t['routing'] as List<String>;
    final color = t['color'] as Color;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceLg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(color: Color(0x03000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
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
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(t['icon'] as IconData, size: 20, color: color),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t['name'] as String, style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.bold)),
                          Text('Dept: ${t['deptLabel']} • ${t['uid']}', style: AppTypography.labelSm.copyWith(color: AppColors.textSecondaryLight, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (t['activeIncidents'] as int) > 0 ? AppColors.priorityP1.withValues(alpha: 0.1) : AppColors.slaHealthy.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                    ),
                    child: Text(
                      '${t['activeIncidents']} Active',
                      style: AppTypography.codeMd.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: (t['activeIncidents'] as int) > 0 ? AppColors.priorityP1 : AppColors.slaHealthy,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                t['description'] as String,
                style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              // Team Lead Row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: AppColors.backgroundLight, borderRadius: BorderRadius.circular(6)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: color.withValues(alpha: 0.2),
                          child: Text((t['leadName'] as String)[0], style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t['leadName'] as String, style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold)),
                            Text(t['leadRole'] as String, style: AppTypography.labelSm.copyWith(fontSize: 10, color: AppColors.textSecondaryLight)),
                          ],
                        ),
                      ],
                    ),
                    Text('${t['operators']} Operators', style: AppTypography.codeMd.copyWith(fontSize: 11, color: AppColors.textSecondaryLight)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Inbound Routing Tokens
              Text('ASSIGNED INBOUND ROUTING', style: AppTypography.labelSm.copyWith(fontSize: 9, color: AppColors.textSecondaryLight, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: routing.take(3).map((r) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.backgroundLight, borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.borderLight)),
                  child: Text(r, style: AppTypography.codeMd.copyWith(fontSize: 10, color: AppColors.textPrimaryLight)),
                )).toList(),
              ),
            ],
          ),
          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.tune, size: 14),
                label: const Text('Routing Rules'),
                onPressed: () => _showRoutingRulesDialog(t['name'] as String, routing),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), minimumSize: Size.zero),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Managing members for ${t['name']}')),
                  );
                },
                child: const Text('Members'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
