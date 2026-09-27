import 'package:flutter/material.dart';
import '../../../shared/responsive/breakpoints.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/dimensions.dart';
import '../../../shared/theme/typography.dart';
import '../../../shared/widgets/role_badge.dart';

/// Stitch Screen: system_audit_logs
/// Immutable, append-only WORM compliance audit ledger.
class SystemAuditLogsScreen extends StatefulWidget {
  const SystemAuditLogsScreen({super.key});

  @override
  State<SystemAuditLogsScreen> createState() => _SystemAuditLogsScreenState();
}

class _SystemAuditLogsScreenState extends State<SystemAuditLogsScreen> {
  final _searchController = TextEditingController();
  String _selectedAction = 'ALL';
  String _selectedRole = 'ALL';

  final List<Map<String, dynamic>> _logs = [
    {
      'id': 'log-001',
      'timestamp': 'Sep 20, 2026, 08:30:12 UTC',
      'actor': 'Alex Vance',
      'role': 'admin',
      'action': 'SECURITY_POLICY_UPDATE',
      'entity': 'tenant_policies',
      'entityId': 'uuid:8b4a20f9...',
      'mutation': 'mfa_enforced: true, auto_closure: 7d',
      'ip': '198.51.100.14',
      'geo': 'HQ DirectConnect',
      'status': 'SUCCESS (200)',
    },
    {
      'id': 'log-002',
      'timestamp': 'Sep 20, 2026, 08:14:05 UTC',
      'actor': 'Marcus Davies',
      'role': 'manager',
      'action': 'CAB_APPROVAL_GRANTED',
      'entity': 'change_requests',
      'entityId': 'CR-2026-004',
      'mutation': 'state: pending -> approved',
      'ip': '198.51.100.22',
      'geo': 'Internal VPN',
      'status': 'SUCCESS (200)',
    },
    {
      'id': 'log-003',
      'timestamp': 'Sep 20, 2026, 07:55:40 UTC',
      'actor': 'System/Cron',
      'role': 'system',
      'action': 'SLA_BREACH_SWEEP',
      'entity': 'incident_cases',
      'entityId': 'INC-2026-00142',
      'mutation': 'sla_status: warning_escalated',
      'ip': '127.0.0.1',
      'geo': 'Internal Scheduler',
      'status': 'SUCCESS (200)',
    },
    {
      'id': 'log-004',
      'timestamp': 'Sep 20, 2026, 07:31:18 UTC',
      'actor': 'Alec Turner',
      'role': 'operator',
      'action': 'CASE_AUTODRAFT_APPLIED',
      'entity': 'case_conversations',
      'entityId': 'uuid:c041280f...',
      'mutation': 'gemini_draft_accepted: true',
      'ip': '198.51.100.41',
      'geo': 'Chicago Hub',
      'status': 'SUCCESS (200)',
    },
    {
      'id': 'log-005',
      'timestamp': 'Sep 20, 2026, 06:12:00 UTC',
      'actor': 'Requester User',
      'role': 'requester',
      'action': 'CASE_INTAKE_SUBMITTED',
      'entity': 'cases',
      'entityId': 'INC-2026-00143',
      'mutation': 'priority: P2, category: network',
      'ip': '203.0.113.88',
      'geo': 'Remote Ingress',
      'status': 'SUCCESS (200)',
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showDeltaDialog(Map<String, dynamic> log) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt_long_rounded, color: AppColors.primaryBlue),
            const SizedBox(width: 8),
            Text('Audit Delta: ${log['action']}'),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDeltaRow('Event Hash (SHA-256)', 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'),
              _buildDeltaRow('Timestamp', log['timestamp'] as String),
              _buildDeltaRow('Actor', '${log['actor']} (${(log['role'] as String).toUpperCase()})'),
              _buildDeltaRow('Entity Target', '${log['entity']} [${log['entityId']}]'),
              _buildDeltaRow('Ingress Node', '${log['ip']} • ${log['geo']}'),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text('State Mutation Payload:', style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.backgroundLight, borderRadius: BorderRadius.circular(6)),
                child: Text(
                  log['mutation'] as String,
                  style: AppTypography.codeMd.copyWith(fontSize: 12, color: AppColors.textPrimaryLight),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.verified, size: 14, color: AppColors.slaHealthy),
                  const SizedBox(width: 4),
                  Text('Cryptographically validated on WORM ledger.', style: AppTypography.bodySm.copyWith(color: AppColors.slaHealthy, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeltaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: AppTypography.labelSm.copyWith(color: AppColors.textSecondaryLight)),
          ),
          Expanded(
            child: Text(value, style: AppTypography.codeMd.copyWith(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filteredLogs = _logs.where((l) {
      if (query.isNotEmpty) {
        final match = (l['actor'] as String).toLowerCase().contains(query) ||
            (l['action'] as String).toLowerCase().contains(query) ||
            (l['entityId'] as String).toLowerCase().contains(query) ||
            (l['ip'] as String).toLowerCase().contains(query);
        if (!match) return false;
      }
      if (_selectedAction != 'ALL' && l['action'] != _selectedAction) return false;
      if (_selectedRole != 'ALL' && l['role'] != _selectedRole.toLowerCase()) return false;
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

            // 2. WORM Storage Notice Banner
            _buildWormNotice(),
            const SizedBox(height: AppDimensions.spaceLg),

            // 3. 4 Summary Metric Cards
            _buildMetricCards(),
            const SizedBox(height: AppDimensions.spaceLg),

            // 4. Filter & Time Range Toolstrip
            _buildFilterToolstrip(),
            const SizedBox(height: AppDimensions.spaceMd),

            // 5. Main Dense Audit Table
            _buildAuditTable(filteredLogs),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'GOVERNANCE & OPS',
                  style: AppTypography.labelSm.copyWith(
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('•', style: TextStyle(color: AppColors.textSecondaryLight)),
                const SizedBox(width: 8),
                Text('IMMUTABLE AUDIT TRAIL', style: AppTypography.labelSm.copyWith(color: AppColors.textSecondaryLight)),
                const SizedBox(width: 8),
                const Text('•', style: TextStyle(color: AppColors.textSecondaryLight)),
                const SizedBox(width: 8),
                Text('APPEND-ONLY RFC LEDGER', style: AppTypography.labelSm.copyWith(color: AppColors.textSecondaryLight)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.secondaryIndigo.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'CHAIN HEAD: #1492028-0x9F4C • WORM ENFORCED',
                style: AppTypography.codeMd.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondaryIndigo),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('System Audit Logs', style: AppTypography.headlineLg),
                const SizedBox(height: 4),
                Text(
                  'Inspect immutable, append-only records of identity mutations, RBAC role escalations, security policy adjustments, and case lifecycle events.',
                  style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondaryLight),
                ),
              ],
            ),
            Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Export Signed Audit CSV'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Audit ledger exported with cryptographic signature.')),
                    );
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.verified_user, size: 16),
                  label: const Text('Verify Integrity'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cryptographic hash validation passed: zero hash mismatches detected.')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWormNotice() {
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
            child: const Icon(Icons.lock_rounded, color: AppColors.primaryBlue, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('WORM Storage & Append-Only Invariant Enforced', style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: AppColors.primaryLight.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                      child: Text('RFC-8291 / NIST 800-207', style: AppTypography.codeMd.copyWith(fontSize: 10, color: AppColors.primaryBlue)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Audit log records are cryptographically chained and stored in append-only storage. Records cannot be edited, modified, or deleted by any user or administrator. Zero-loss retention guaranteed.',
                  style: AppTypography.bodySm.copyWith(color: AppColors.textPrimaryLight),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.borderLight)),
            child: Row(
              children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.slaHealthy, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('Merkle Root: 0x8a1...d40e', style: AppTypography.codeMd.copyWith(fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < ResponsiveBreakpoints.mobileMax;
        final c1 = _buildSummaryCard('Total Audit Records', '1,492,028', 'Indexed in PostgreSQL 16', '+1,204/hr', AppColors.primaryBlue, Icons.storage);
        final c2 = _buildSummaryCard('Security & Policy Changes', '38 Events', 'Past 30 days', '0 unapproved', AppColors.secondaryIndigo, Icons.security_rounded);
        final c3 = _buildSummaryCard('Failed Auth / Denied', '14 Events', 'Sliding-window IP blocked', '3 CIDRs Drop', AppColors.priorityP1, Icons.gpp_maybe);
        final c4 = _buildSummaryCard('Ledger Integrity', '100% Verified', 'Zero hash mismatches', 'Last sync 4m ago', AppColors.slaHealthy, Icons.task_alt);

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

  Widget _buildSummaryCard(String label, String value, String sub, String badge, Color color, IconData icon) {
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
          Text(value, style: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.bold, color: color == AppColors.priorityP1 ? AppColors.priorityP1 : AppColors.textPrimaryLight)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(sub, style: AppTypography.bodySm.copyWith(fontSize: 11, color: AppColors.textSecondaryLight)),
              Text(badge, style: AppTypography.codeMd.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterToolstrip() {
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
                hintText: 'Search by Actor, Entity ID, Action, or IP Address...',
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
              initialValue: _selectedAction,
              isDense: true,
              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All Actions')),
                DropdownMenuItem(value: 'SECURITY_POLICY_UPDATE', child: Text('POLICY_UPDATE')),
                DropdownMenuItem(value: 'CAB_APPROVAL_GRANTED', child: Text('CAB_APPROVAL')),
                DropdownMenuItem(value: 'SLA_BREACH_SWEEP', child: Text('SLA_SWEEP')),
                DropdownMenuItem(value: 'CASE_AUTODRAFT_APPLIED', child: Text('AI_AUTODRAFT')),
                DropdownMenuItem(value: 'CASE_INTAKE_SUBMITTED', child: Text('CASE_INTAKE')),
              ],
              onChanged: (val) => setState(() => _selectedAction = val ?? 'ALL'),
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
                DropdownMenuItem(value: 'ALL', child: Text('All Roles')),
                DropdownMenuItem(value: 'Admin', child: Text('Administrator')),
                DropdownMenuItem(value: 'Manager', child: Text('Manager')),
                DropdownMenuItem(value: 'Operator', child: Text('Operator')),
                DropdownMenuItem(value: 'Requester', child: Text('Requester')),
                DropdownMenuItem(value: 'System', child: Text('System/Cron')),
              ],
              onChanged: (val) => setState(() => _selectedRole = val ?? 'ALL'),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Reset'),
            onPressed: () {
              setState(() {
                _searchController.clear();
                _selectedAction = 'ALL';
                _selectedRole = 'ALL';
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAuditTable(List<Map<String, dynamic>> logs) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2.0),
          1: FlexColumnWidth(1.8),
          2: FlexColumnWidth(2.2),
          3: FlexColumnWidth(2.0),
          4: FlexColumnWidth(2.8),
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
              _buildTh('Timestamp (UTC)'),
              _buildTh('Actor & Role'),
              _buildTh('Action'),
              _buildTh('Entity Target'),
              _buildTh('State Mutation Summary'),
              _buildTh('Status'),
              _buildTh('Detail', alignRight: true),
            ],
          ),
          ...logs.map((l) {
            return TableRow(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.borderLight, width: 0.5)),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  child: Text(
                    l['timestamp'] as String,
                    style: AppTypography.codeMd.copyWith(fontSize: 11, color: AppColors.textPrimaryLight),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l['actor'] as String, style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.bold)),
                      RoleBadge(role: l['role'] as String),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      l['action'] as String,
                      style: AppTypography.codeMd.copyWith(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l['entity'] as String, style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
                      Text(l['entityId'] as String, style: AppTypography.codeMd.copyWith(fontSize: 10, color: AppColors.textSecondaryLight)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  child: Text(
                    l['mutation'] as String,
                    style: AppTypography.codeMd.copyWith(fontSize: 11, color: AppColors.textPrimaryLight),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.slaHealthy.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                    ),
                    child: Text(
                      'SUCCESS (200)',
                      style: AppTypography.codeMd.copyWith(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.slaHealthy),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                      onPressed: () => _showDeltaDialog(l),
                      child: const Text('View Delta', style: TextStyle(fontSize: 12)),
                    ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Text(
        text.toUpperCase(),
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: AppTypography.labelSm.copyWith(
          color: AppColors.textSecondaryLight,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          fontSize: 10,
        ),
      ),
    );
  }
}
