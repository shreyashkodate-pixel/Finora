import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/predictive_analytics_provider.dart';
import '../widgets/sla_risk_radar_view.dart';
import '../widgets/team_capacity_view.dart';
import '../widgets/workload_forecast_view.dart';

/// Predictive Workload, SLA Risk Scoring, & Team Capacity Analytics Screen (Phase 4C).
class PredictiveAnalyticsScreen extends StatefulWidget {
  const PredictiveAnalyticsScreen({super.key});

  @override
  State<PredictiveAnalyticsScreen> createState() => _PredictiveAnalyticsScreenState();
}

class _PredictiveAnalyticsScreenState extends State<PredictiveAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userRole = context.read<AuthProvider>().currentUser?.role.toLowerCase().trim() ?? 'requester';
      final isOperatorOnly = userRole == 'operator';

      if (isOperatorOnly) {
        context.read<PredictiveAnalyticsProvider>().fetchRiskForecast();
      } else {
        context.read<PredictiveAnalyticsProvider>().refreshAll();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final role = user?.role.toLowerCase().trim() ?? 'requester';

    // Operator-only view per Locked RBAC
    final isOperator = role == 'operator';

    // Requester view: 403 / Restricted
    if (role == 'requester') {
      return Scaffold(
        appBar: AppBar(title: const Text('Predictive Analytics')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 56, color: AppColors.textSecondaryLight),
                SizedBox(height: 16),
                Text(
                  'Access Restricted',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Predictive workload and SLA analytics are restricted to staff roles.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondaryLight),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (isOperator) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('SLA Risk Radar & Threat Intelligence'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh SLA Risk',
              onPressed: () {
                context.read<PredictiveAnalyticsProvider>().fetchRiskForecast();
              },
            ),
          ],
        ),
        body: const SlaRiskRadarView(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Predictive Analytics & Capacity Intelligence'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Analytics',
            onPressed: () {
              context.read<PredictiveAnalyticsProvider>().refreshAll();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.trending_up),
              text: 'Workload Forecast',
            ),
            Tab(
              icon: Icon(Icons.radar_rounded),
              text: 'SLA Risk Radar',
            ),
            Tab(
              icon: Icon(Icons.groups_outlined),
              text: 'Team Capacity',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          WorkloadForecastView(),
          SlaRiskRadarView(),
          TeamCapacityView(),
        ],
      ),
    );
  }
}
