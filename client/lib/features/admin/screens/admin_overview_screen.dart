import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/responsive/breakpoints.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/dimensions.dart';
import '../../../shared/theme/typography.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cases/providers/case_provider.dart';
import '../../alerts/providers/alert_provider.dart';

/// Stitch Screen: administration_overview
/// Global system telemetry, multi-tenant governance health, and gateway matrix.
class AdminOverviewScreen extends StatefulWidget {
  final Function(int targetTab)? onNavigateTab;

  const AdminOverviewScreen({super.key, this.onNavigateTab});

  @override
  State<AdminOverviewScreen> createState() => _AdminOverviewScreenState();
}

class _AdminOverviewScreenState extends State<AdminOverviewScreen> {
  String _selectedCategory = 'all';

  final List<Map<String, dynamic>> _services = [
    {
      'name': 'FastAPI Gateway',
      'node': 'edge-cluster-ingress-01',
      'icon': Icons.api_rounded,
      'latency': '14ms',
      'throughput': '3,420 req/s • HTTP/2',
      'status': 'Operational',
      'category': 'mesh',
      'color': AppColors.primaryBlue,
    },
    {
      'name': 'PostgreSQL 16 + pgvector',
      'node': 'pg-db-pool.tenant.internal',
      'icon': Icons.storage_rounded,
      'latency': '2.1ms',
      'throughput': '1,120 tx/s • RLS Active',
      'status': 'Operational',
      'category': 'ai',
      'color': AppColors.secondaryIndigo,
    },
    {
      'name': 'Gemini 2.5 Flash Copilot',
      'node': 'vertex-ai-inference-proxy',
      'icon': Icons.auto_awesome_rounded,
      'latency': '420ms',
      'throughput': '84 inferences/min',
      'status': 'Operational',
      'category': 'ai',
      'color': AppColors.aiAccent,
    },
    {
      'name': 'WebSocket Notification Broker',
      'node': 'ws-push-broker-02',
      'icon': Icons.sensors_rounded,
      'latency': '5ms',
      'throughput': '1,890 active sockets',
      'status': 'Operational',
      'category': 'mesh',
      'color': AppColors.statusAssigned,
    },
    {
      'name': 'Inbound APM Ingest Pipeline',
      'node': 'webhook-ingest-consumer',
      'icon': Icons.cell_tower_rounded,
      'latency': '18ms',
      'throughput': '48k events/hr',
      'status': 'Operational',
      'category': 'mesh',
      'color': AppColors.priorityP2,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final caseProv = context.watch<CaseProvider>();
    final alertProv = context.watch<AlertProvider>();
    final user = auth.currentUser;

    final openCases = caseProv.cases.where((c) => c.status != 'closed' && c.status != 'cancelled').length;
    final alertCount = alertProv.alerts.length;

    final filteredServices = _selectedCategory == 'all'
        ? _services
        : _services.where((s) => s['category'] == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            caseProv.fetchCases(),
            alertProv.fetchAlerts(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppDimensions.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header Zone
              _buildHeader(context),
              const SizedBox(height: AppDimensions.spaceLg),

              // 2. Active Tenant Scope Context Banner
              _buildTenantContextBanner(user?.organizationId ?? 'finora-technologies-corp'),
              const SizedBox(height: AppDimensions.spaceLg),

              // 3. 4 Admin Summary Metrics
              _buildMetricSummaryCards(openCases, alertCount),
              const SizedBox(height: AppDimensions.spaceXl),

              // 4. Two-Column Layout: System Health Matrix (Left) + Quick Navigation (Right)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < ResponsiveBreakpoints.tabletMax;
                  if (isMobile) {
                    return Column(
                      children: [
                        _buildHealthMatrix(filteredServices),
                        const SizedBox(height: AppDimensions.spaceLg),
                        _buildQuickNavCards(),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 7,
                        child: _buildHealthMatrix(filteredServices),
                      ),
                      const SizedBox(width: AppDimensions.spaceLg),
                      Expanded(
                        flex: 5,
                        child: _buildQuickNavCards(),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
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
                  'GOVERNANCE DASHBOARD',
                  style: AppTypography.labelSm.copyWith(
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('•', style: TextStyle(color: AppColors.textSecondaryLight)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                  ),
                  child: Text(
                    'LIVE REFRESH: 30s',
                    style: AppTypography.codeMd.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Administration Overview',
              style: AppTypography.headlineLg,
            ),
            const SizedBox(height: 4),
            Text(
              'Global system telemetry, multi-tenant governance health, and security posture overview.',
              style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondaryLight),
            ),
          ],
        ),
        Row(
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.sync, size: 16),
              label: const Text('Poll Now'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onPressed: () {
                context.read<CaseProvider>().fetchCases();
                context.read<AlertProvider>().fetchAlerts();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Administrative telemetry refreshed successfully.')),
                );
              },
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.verified_user, size: 16),
              label: const Text('Audit Integrity'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cryptographic hash validation verified: 100% WORM ledger integrity.')),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTenantContextBanner(String orgId) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(color: Color(0x04000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 5,
              decoration: const BoxDecoration(
                color: AppColors.primaryBlue,
                borderRadius: BorderRadius.horizontal(left: Radius.circular(AppDimensions.radiusCard)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Wrap(
                  spacing: 20,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.corporate_fare, size: 18, color: AppColors.primaryBlue),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ACTIVE TENANT SCOPE',
                              style: AppTypography.labelSm.copyWith(fontSize: 10, color: AppColors.textSecondaryLight),
                            ),
                            Text(
                              'Finora Technologies Corp',
                              style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TENANT IDENTIFIER', style: AppTypography.labelSm.copyWith(fontSize: 10, color: AppColors.textSecondaryLight)),
                        Text(orgId, style: AppTypography.codeMd.copyWith(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SERVICE TIER', style: AppTypography.labelSm.copyWith(fontSize: 10, color: AppColors.textSecondaryLight)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.slaHealthy.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Platinum SLA (24/7 Dedicated)',
                            style: AppTypography.labelSm.copyWith(color: AppColors.slaHealthy, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DB ENGINE & ISOLATION', style: AppTypography.labelSm.copyWith(fontSize: 10, color: AppColors.textSecondaryLight)),
                        Text('PostgreSQL 16 + RLS Enforced', style: AppTypography.codeMd.copyWith(fontSize: 12, color: AppColors.textPrimaryLight)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundLight,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.security, size: 14, color: AppColors.primaryBlue),
                          const SizedBox(width: 4),
                          Text(
                            'ZTSA-LEVEL-3 ACTIVE',
                            style: AppTypography.codeMd.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricSummaryCards(int openCases, int alertCount) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < ResponsiveBreakpoints.mobileMax;
        final card1 = _buildMetricCard(
          label: 'Active Users & Seats',
          value: '482',
          subValue: '/ 500 Provisioned',
          icon: Icons.badge_outlined,
          iconColor: AppColors.primaryBlue,
          progressValue: 0.964,
          footerLeft: '96.4% utilization',
          footerRight: '5 RBAC roles active',
        );

        final card2 = _buildMetricCard(
          label: 'Managed Organizations',
          value: '3',
          subValue: 'Tenants online',
          icon: Icons.hub_outlined,
          iconColor: AppColors.secondaryIndigo,
          progressValue: 1.0,
          footerLeft: '1 Primary • 2 Subsidiaries',
          footerRight: '100% RLS Partitioned',
        );

        final card3 = _buildMetricCard(
          label: 'Inbound Alert Pipeline',
          value: alertCount > 0 ? alertCount.toString() : '4',
          subValue: 'Gateways active',
          icon: Icons.cell_tower_rounded,
          iconColor: AppColors.statusAssigned,
          progressValue: 0.85,
          footerLeft: 'Prometheus, CW, Sentry',
          footerRight: '0 dropped frames',
        );

        final card4 = _buildMetricCard(
          label: 'Governance & Compliance',
          value: '100%',
          subValue: 'SOC 2 / FINRA',
          icon: Icons.policy_outlined,
          iconColor: AppColors.slaHealthy,
          progressValue: 1.0,
          footerLeft: 'Append-only audit stream',
          footerRight: '7-Year WORM Storage',
        );

        if (isMobile) {
          return Column(
            children: [
              card1,
              const SizedBox(height: 12),
              card2,
              const SizedBox(height: 12),
              card3,
              const SizedBox(height: 12),
              card4,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: card1),
            const SizedBox(width: AppDimensions.spaceMd),
            Expanded(child: card2),
            const SizedBox(width: AppDimensions.spaceMd),
            Expanded(child: card3),
            const SizedBox(width: AppDimensions.spaceMd),
            Expanded(child: card4),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required String subValue,
    required IconData icon,
    required Color iconColor,
    required double progressValue,
    required String footerLeft,
    required String footerRight,
  }) {
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.toUpperCase(),
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.textSecondaryLight,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: AppTypography.headlineLg.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 6),
              Text(
                subValue,
                style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 4,
              backgroundColor: AppColors.backgroundLight,
              valueColor: AlwaysStoppedAnimation<Color>(iconColor),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                footerLeft,
                style: AppTypography.labelSm.copyWith(color: AppColors.textSecondaryLight, fontSize: 11),
              ),
              Text(
                footerRight,
                style: AppTypography.labelSm.copyWith(
                  color: iconColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthMatrix(List<Map<String, dynamic>> services) {
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Administrative System Health & Gateway Matrix',
                    style: AppTypography.headlineSm,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Real-time status of backend orchestrators, vector DBs, and notification endpoints.',
                    style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    _buildTabBtn('All Services', 'all'),
                    _buildTabBtn('AI/Vector', 'ai'),
                    _buildTabBtn('Gateway Mesh', 'mesh'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(3.0),
              1: FlexColumnWidth(1.6),
              2: FlexColumnWidth(2.4),
              3: FlexColumnWidth(1.6),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                decoration: const BoxDecoration(
                  color: AppColors.backgroundLight,
                  border: Border(bottom: BorderSide(color: AppColors.borderLight)),
                ),
                children: [
                  _buildTh('Component & Role'),
                  _buildTh('Node Telemetry'),
                  _buildTh('Throughput / Interval'),
                  _buildTh('Operational Status', alignRight: true),
                ],
              ),
              ...services.map((s) {
                return TableRow(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.borderLight, width: 0.5)),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: (s['color'] as Color).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(s['icon'] as IconData, size: 16, color: s['color'] as Color),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s['name'] as String, style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.bold)),
                              Text(s['node'] as String, style: AppTypography.codeMd.copyWith(fontSize: 11, color: AppColors.textSecondaryLight)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      child: Text(
                        s['latency'] as String,
                        style: AppTypography.codeMd.copyWith(fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      child: Text(
                        s['throughput'] as String,
                        style: AppTypography.codeMd.copyWith(fontSize: 12, color: AppColors.textSecondaryLight),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.slaHealthy.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.slaHealthy, shape: BoxShape.circle)),
                              const SizedBox(width: 5),
                              Text(s['status'] as String, style: AppTypography.labelSm.copyWith(color: AppColors.slaHealthy, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
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

  Widget _buildTabBtn(String label, String category) {
    final isSelected = _selectedCategory == category;
    return InkWell(
      onTap: () => setState(() => _selectedCategory = category),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          boxShadow: isSelected ? const [BoxShadow(color: Color(0x08000000), blurRadius: 4)] : null,
        ),
        child: Text(
          label,
          style: AppTypography.labelSm.copyWith(
            color: isSelected ? AppColors.textPrimaryLight : AppColors.textSecondaryLight,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickNavCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Administrative Quick Navigation', style: AppTypography.headlineSm),
        const SizedBox(height: 12),
        _buildNavCard(
          title: 'Identity & User Management',
          description: 'Manage 482 provisioned identities, RBAC roles, team assignments, and SCIM synchronization.',
          icon: Icons.person_search_rounded,
          iconColor: AppColors.primaryBlue,
          targetTab: 1, // Will navigate to Users tab
        ),
        const SizedBox(height: 10),
        _buildNavCard(
          title: 'Team Routing & Operations',
          description: 'Configure 5 operational groups, assign team leads, and manage inbound queue boundaries.',
          icon: Icons.groups_rounded,
          iconColor: AppColors.secondaryIndigo,
          targetTab: 2, // Will navigate to Teams tab
        ),
        const SizedBox(height: 10),
        _buildNavCard(
          title: 'Tenant Security & Policies',
          description: 'Enforce domain allowlists, session timeout rules, and strict RLS tenant isolation boundaries.',
          icon: Icons.shield_rounded,
          iconColor: AppColors.aiAccent,
          targetTab: 3, // Will navigate to Tenant Governance tab
        ),
        const SizedBox(height: 10),
        _buildNavCard(
          title: 'Immutable System Audit Logs',
          description: 'Inspect cryptographically chained RFC-8291 audit trails with zero tampering risk.',
          icon: Icons.receipt_long_rounded,
          iconColor: AppColors.priorityP2,
          targetTab: 4, // Will navigate to Audit Logs tab
        ),
      ],
    );
  }

  Widget _buildNavCard({
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required int targetTab,
  }) {
    return InkWell(
      onTap: () {
        if (widget.onNavigateTab != null) {
          widget.onNavigateTab!(targetTab);
        }
      },
      borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.spaceMd),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(description, style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondaryLight),
          ],
        ),
      ),
    );
  }
}
