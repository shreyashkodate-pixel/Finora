import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/sla_timer_widget.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cases/models/case_model.dart';
import '../../cases/providers/case_provider.dart';
import '../../cases/screens/case_detail_screen.dart';
import '../../cases/screens/create_case_dialog.dart';
import '../../knowledge/screens/knowledge_browser_screen.dart';

/// Self-service home portal for standard employees/requesters per SRS §4 & §7.
class RequesterHomeScreen extends StatefulWidget {
  const RequesterHomeScreen({super.key});

  @override
  State<RequesterHomeScreen> createState() => _RequesterHomeScreenState();
}

class _RequesterHomeScreenState extends State<RequesterHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CaseProvider>().fetchCases();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final caseProv = context.watch<CaseProvider>();
    final user = auth.currentUser;
    final cases = caseProv.cases;

    final activeCases = cases.where((c) => c.status != 'closed' && c.status != 'cancelled').toList();
    final resolvedCases = cases.where((c) => c.status == 'resolved').toList();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => context.read<CaseProvider>().fetchCases(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Banner
              Card(
                color: AppColors.primaryBlue,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back, ${user?.fullName ?? 'User'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Site: ${user?.site ?? 'Main Campus'} | Role: ${user?.role.toUpperCase() ?? 'REQUESTER'}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primaryBlue,
                            ),
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Submit IT Ticket'),
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
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white),
                            ),
                            icon: const Icon(Icons.menu_book),
                            label: const Text('Search Knowledge Base'),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const KnowledgeBrowserScreen()),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // KPI Metric Cards
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Active Tickets',
                      count: activeCases.length.toString(),
                      icon: Icons.pending_actions,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Resolved',
                      count: resolvedCases.length.toString(),
                      icon: Icons.check_circle_outline,
                      color: AppColors.slaHealthy,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Total Submitted',
                      count: cases.length.toString(),
                      icon: Icons.folder_open,
                      color: AppColors.statusAssigned,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Active Tickets Feed
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Your Active Tickets',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (activeCases.isNotEmpty)
                    Text(
                      '${activeCases.length} open',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              if (caseProv.isLoading && cases.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (activeCases.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle, size: 48, color: AppColors.slaHealthy),
                          const SizedBox(height: 12),
                          const Text('All caught up!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          const Text(
                            'You currently have no open IT incidents or service requests.',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: activeCases.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final c = activeCases[index];
                    return Card(
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        title: Row(
                          children: [
                            Text(
                              c.referenceNumber,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryBlue),
                            ),
                            const SizedBox(width: 8),
                            StatusBadge(status: c.status),
                            const SizedBox(width: 6),
                            PriorityBadge(priority: c.priority),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            c.title,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        trailing: c.sla != null
                            ? SlaTimerWidget(
                                targetTime: c.sla!.targetResolveAt,
                                isBreached: c.sla!.resolutionBreached,
                                completedAt: c.resolvedAt,
                              )
                            : const Icon(Icons.arrow_forward_ios, size: 14),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => CaseDetailScreen(caseId: c.id)),
                          );
                        },
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(
              count,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
            ),
          ],
        ),
      ),
    );
  }
}
