import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ai_helpdesk_client/features/analytics/models/analytics_model.dart';
import 'package:ai_helpdesk_client/features/analytics/providers/predictive_analytics_provider.dart';
import 'package:ai_helpdesk_client/features/analytics/screens/predictive_analytics_screen.dart';
import 'package:ai_helpdesk_client/features/analytics/widgets/sla_risk_radar_view.dart';
import 'package:ai_helpdesk_client/features/analytics/widgets/team_capacity_view.dart';
import 'package:ai_helpdesk_client/features/analytics/widgets/workload_forecast_view.dart';
import 'package:ai_helpdesk_client/features/auth/models/user_model.dart';
import 'package:ai_helpdesk_client/features/auth/providers/auth_provider.dart';
import 'package:ai_helpdesk_client/features/cases/providers/case_provider.dart';
import 'package:ai_helpdesk_client/shared/api_client.dart';
import 'package:ai_helpdesk_client/shared/storage.dart';
import 'package:ai_helpdesk_client/shared/theme/app_theme.dart';

class MockPredictiveApiClient extends ApiClient {
  MockPredictiveApiClient() : super(baseUrl: 'http://localhost:8000');

  bool throwError = false;
  bool throw403 = false;
  bool returnEmpty = false;
  int? requestedHorizon;

  final Map<String, dynamic> mockWorkload7 = {
    'horizon_days': 7,
    'forecast_date': DateTime.now().toIso8601String(),
    'predicted_total_cases': 42,
    'predicted_p1_cases': 3,
    'predicted_p2_cases': 9,
    'predicted_p3_p4_cases': 30,
    'category_breakdown': {
      'Network & Connectivity': 14,
      'Identity & Access Management': 10,
      'Software & Applications': 10,
      'Hardware & Peripherals': 8,
    },
    'confidence_interval': {
      'lower_bound': 36,
      'upper_bound': 48,
    },
    'recommendation': 'Stable volume expected over 7 days. Staffing is adequate.',
  };

  final Map<String, dynamic> mockWorkload30 = {
    'horizon_days': 30,
    'forecast_date': DateTime.now().toIso8601String(),
    'predicted_total_cases': 180,
    'predicted_p1_cases': 14,
    'predicted_p2_cases': 39,
    'predicted_p3_p4_cases': 127,
    'category_breakdown': {
      'Network & Connectivity': 63,
      'Identity & Access Management': 45,
      'Software & Applications': 45,
      'Hardware & Peripherals': 27,
    },
    'confidence_interval': {
      'lower_bound': 153,
      'upper_bound': 207,
    },
    'recommendation': 'High volume expected. 3-4 concurrent shifts recommended.',
  };

  final Map<String, dynamic> mockRiskResponse = {
    'total_at_risk_cases': 2,
    'high_risk_cases': [
      {
        'case_id': '11111111-1111-1111-1111-111111111111',
        'reference_number': 'INC-2026-8001',
        'title': 'Production DB Connection Pool Saturation',
        'priority': 'P1',
        'current_status': 'assigned',
        'predicted_breach_probability': 0.88,
        'time_to_breach_minutes': 45,
        'risk_drivers': [
          'SLA window is over 80% elapsed',
          'Priority P1 critical business impact',
        ],
      },
      {
        'case_id': '22222222-2222-2222-2222-222222222222',
        'reference_number': 'INC-2026-8002',
        'title': 'SSO Provider Latency Spike',
        'priority': 'P2',
        'current_status': 'in_assessment',
        'predicted_breach_probability': 0.65,
        'time_to_breach_minutes': 110,
        'risk_drivers': [
          'SLA window is over 60% elapsed',
        ],
      },
    ],
    'ai_summary': 'Detected 2 active tickets with high risk of SLA breach. Immediate attention required.',
  };

  final Map<String, dynamic> mockCapacityResponse = {
    'total_teams': 2,
    'overall_utilization_pct': 78.5,
    'teams': [
      {
        'team_id': '33333333-3333-3333-3333-333333333333',
        'team_name': 'Core Infrastructure SRE',
        'active_operators': 4,
        'open_cases': 18,
        'avg_cases_per_operator': 4.5,
        'capacity_utilization_pct': 90.0,
        'burnout_risk': 'high',
        'estimated_closure_velocity_per_day': 18.0,
      },
      {
        'team_id': '44444444-4444-4444-4444-444444444444',
        'team_name': 'Access & Identity Management',
        'active_operators': 3,
        'open_cases': 10,
        'avg_cases_per_operator': 3.3,
        'capacity_utilization_pct': 67.0,
        'burnout_risk': 'moderate',
        'estimated_closure_velocity_per_day': 13.5,
      },
    ],
  };

  @override
  Future<dynamic> get(String endpoint, {Map<String, dynamic>? queryParameters}) async {
    if (throw403) {
      throw ApiException(
        statusCode: 403,
        code: 'FORBIDDEN',
        message: '403 Forbidden: Insufficient operational privileges.',
      );
    }
    if (throwError) {
      throw ApiException(
        statusCode: 500,
        code: 'INTERNAL_ERROR',
        message: 'Internal server failure.',
      );
    }

    if (endpoint == '/api/v1/analytics/predictive/workload') {
      requestedHorizon = queryParameters?['horizon_days'] as int? ?? 7;
      if (requestedHorizon == 30) {
        return mockWorkload30;
      }
      return mockWorkload7;
    }

    if (endpoint == '/api/v1/analytics/predictive/risk-forecast') {
      if (returnEmpty) {
        return {
          'total_at_risk_cases': 0,
          'high_risk_cases': [],
          'ai_summary': 'All queues healthy.',
        };
      }
      return mockRiskResponse;
    }

    if (endpoint == '/api/v1/analytics/capacity/teams') {
      if (returnEmpty) {
        return {
          'total_teams': 0,
          'overall_utilization_pct': 0.0,
          'teams': [],
        };
      }
      return mockCapacityResponse;
    }

    if (endpoint == '/api/v1/cases/') {
      return [];
    }

    return {};
  }
}

void main() {
  late MockPredictiveApiClient apiClient;
  late SessionStorage storage;
  late AuthProvider authProvider;
  late PredictiveAnalyticsProvider analyticsProvider;
  late CaseProvider caseProvider;

  setUp(() {
    apiClient = MockPredictiveApiClient();
    storage = SessionStorage();
    authProvider = AuthProvider(apiClient: apiClient, storage: storage);
    analyticsProvider = PredictiveAnalyticsProvider(apiClient: apiClient);
    caseProvider = CaseProvider(apiClient: apiClient);
  });

  Widget createTestWidget({required Widget child, String role = 'manager'}) {
    authProvider.setMockUser(
      UserModel(
        id: 'u-1',
        email: 'manager@example.com',
        role: role,
        site: 'Campus North',
      ),
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<PredictiveAnalyticsProvider>.value(value: analyticsProvider),
        ChangeNotifierProvider<CaseProvider>.value(value: caseProvider),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: child,
      ),
    );
  }

  group('Phase 4C: Predictive Analytics Domain Models & Serialization', () {
    test('WorkloadForecastResponse serialization / deserialization', () {
      final json = {
        'horizon_days': 14,
        'forecast_date': '2026-09-21T10:00:00.000Z',
        'predicted_total_cases': 75,
        'predicted_p1_cases': 6,
        'predicted_p2_cases': 16,
        'predicted_p3_p4_cases': 53,
        'category_breakdown': {'Network': 25, 'IAM': 20},
        'confidence_interval': {'lower_bound': 65, 'upper_bound': 85},
        'recommendation': 'Maintain current shifts.',
      };

      final model = WorkloadForecastResponse.fromJson(json);
      expect(model.horizonDays, 14);
      expect(model.predictedTotalCases, 75);
      expect(model.predictedP1Cases, 6);
      expect(model.categoryBreakdown['Network'], 25);
      expect(model.confidenceInterval['lower_bound'], 65);

      final outJson = model.toJson();
      expect(outJson['horizon_days'], 14);
      expect(outJson['predicted_total_cases'], 75);
    });

    test('PredictiveRiskResponse and PredictiveRiskItem modeling', () {
      final json = {
        'total_at_risk_cases': 1,
        'high_risk_cases': [
          {
            'case_id': 'c-101',
            'reference_number': 'INC-101',
            'title': 'Core Gateway Outage',
            'priority': 'P1',
            'current_status': 'assigned',
            'predicted_breach_probability': 0.92,
            'time_to_breach_minutes': 25,
            'risk_drivers': ['SLA window > 80%', 'P1 impact'],
          }
        ],
        'ai_summary': 'Urgent intervention needed.',
      };

      final response = PredictiveRiskResponse.fromJson(json);
      expect(response.totalAtRiskCases, 1);
      expect(response.highRiskCases.first.referenceNumber, 'INC-101');
      expect(response.highRiskCases.first.riskLevel, 'critical');
      expect(response.highRiskCases.first.riskDrivers.length, 2);

      final out = response.toJson();
      expect(out['total_at_risk_cases'], 1);
    });

    test('TeamCapacityOverviewResponse and TeamCapacityMetricItem modeling', () {
      final json = {
        'total_teams': 1,
        'overall_utilization_pct': 92.5,
        'teams': [
          {
            'team_id': 't-101',
            'team_name': 'Platform SRE',
            'active_operators': 5,
            'open_cases': 23,
            'avg_cases_per_operator': 4.6,
            'capacity_utilization_pct': 92.0,
            'burnout_risk': 'high',
            'estimated_closure_velocity_per_day': 22.5,
          }
        ],
      };

      final response = TeamCapacityOverviewResponse.fromJson(json);
      expect(response.totalTeams, 1);
      expect(response.overallUtilizationPct, 92.5);
      expect(response.teams.first.teamName, 'Platform SRE');
      expect(response.teams.first.burnoutRisk, 'high');
    });
  });

  group('Phase 4C: Workload Forecast View Tests', () {
    testWidgets('Renders workload forecast and changes horizon dynamically', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const Scaffold(body: WorkloadForecastView())));
      await tester.pumpAndSettle();

      // Trigger initial load
      await analyticsProvider.fetchWorkloadForecast(horizonDays: 7);
      await tester.pumpAndSettle();

      expect(find.text('Workload Demand Projection'), findsOneWidget);
      expect(find.text('~42 Cases'), findsOneWidget);
      expect(find.textContaining('95% Confidence: 36 – 48 cases'), findsOneWidget);
      expect(find.text('P1 Critical'), findsOneWidget);
      expect(find.text('Network & Connectivity'), findsOneWidget);

      // Select 30 days horizon
      await tester.tap(find.text('30 Days'));
      await tester.pumpAndSettle();

      expect(apiClient.requestedHorizon, 30);
      expect(find.text('~180 Cases'), findsOneWidget);
      expect(find.textContaining('95% Confidence: 153 – 207 cases'), findsOneWidget);
    });

    testWidgets('Renders error and handles retry correctly', (tester) async {
      apiClient.throwError = true;
      await tester.pumpWidget(createTestWidget(child: const Scaffold(body: WorkloadForecastView())));
      await analyticsProvider.fetchWorkloadForecast();
      await tester.pumpAndSettle();

      expect(find.text('Unable to Load Workload Forecast'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Fix error and retry
      apiClient.throwError = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Workload Demand Projection'), findsOneWidget);
    });
  });

  group('Phase 4C: SLA Risk Radar View Tests', () {
    testWidgets('Renders at-risk tickets with risk scores and drivers', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const Scaffold(body: SlaRiskRadarView())));
      await analyticsProvider.fetchRiskForecast();
      await tester.pumpAndSettle();

      expect(find.text('SLA Risk Radar'), findsOneWidget);
      expect(find.text('INC-2026-8001'), findsOneWidget);
      expect(find.text('Production DB Connection Pool Saturation'), findsOneWidget);
      expect(find.textContaining('Risk Score: 0.88'), findsOneWidget);
      expect(find.textContaining('45 mins remaining'), findsOneWidget);
      expect(find.text('• SLA window is over 80% elapsed'), findsOneWidget);
      expect(find.text('Investigate Ticket'), findsNWidgets(2));
    });

    testWidgets('Filters at-risk cases by risk level chip', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const Scaffold(body: SlaRiskRadarView())));
      await analyticsProvider.fetchRiskForecast();
      await tester.pumpAndSettle();

      // Filter by High only (0.65 case)
      await tester.tap(find.text('High (≥0.60)'));
      await tester.pumpAndSettle();

      expect(find.text('INC-2026-8002'), findsOneWidget);
      expect(find.text('INC-2026-8001'), findsNothing);
    });

    testWidgets('Renders empty state when no cases at risk', (tester) async {
      apiClient.returnEmpty = true;
      await tester.pumpWidget(createTestWidget(child: const Scaffold(body: SlaRiskRadarView())));
      await analyticsProvider.fetchRiskForecast();
      await tester.pumpAndSettle();

      expect(find.text('No Cases At Risk'), findsOneWidget);
    });
  });

  group('Phase 4C: Team Capacity View Tests', () {
    testWidgets('Renders squad capacity cards, utilization, and burnout badges', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const Scaffold(body: TeamCapacityView())));
      await analyticsProvider.fetchTeamCapacity();
      await tester.pumpAndSettle();

      expect(find.text('Team Capacity & Utilization Overview'), findsOneWidget);
      expect(find.text('78.5%'), findsOneWidget);
      expect(find.text('Core Infrastructure SRE'), findsOneWidget);
      expect(find.text('HIGH LOAD'), findsOneWidget);
      expect(find.text('4 ops'), findsOneWidget);
      expect(find.text('18 tickets'), findsOneWidget);
      expect(find.text('Access & Identity Management'), findsOneWidget);
      expect(find.text('MODERATE LOAD'), findsOneWidget);
    });

    testWidgets('Handles 403 Forbidden properly for restricted capacity', (tester) async {
      apiClient.throw403 = true;
      await tester.pumpWidget(createTestWidget(child: const Scaffold(body: TeamCapacityView())));
      await analyticsProvider.fetchTeamCapacity();
      await tester.pumpAndSettle();

      expect(find.text('Access Restricted'), findsOneWidget);
    });
  });

  group('Phase 4C: Predictive Analytics Screen & Role-Aware Navigation', () {
    testWidgets('Manager renders full 3-tab layout and refreshes', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const PredictiveAnalyticsScreen(), role: 'manager'));
      await tester.pumpAndSettle();

      expect(find.text('Predictive Analytics & Capacity Intelligence'), findsOneWidget);
      expect(find.text('Workload Forecast'), findsOneWidget);
      expect(find.text('SLA Risk Radar'), findsOneWidget);
      expect(find.text('Team Capacity'), findsOneWidget);

      // Switch to SLA Risk tab
      await tester.tap(find.text('SLA Risk Radar'));
      await tester.pumpAndSettle();
      expect(find.byType(SlaRiskRadarView), findsOneWidget);

      // Switch to Team Capacity tab
      await tester.tap(find.text('Team Capacity'));
      await tester.pumpAndSettle();
      expect(find.byType(TeamCapacityView), findsOneWidget);
    });

    testWidgets('Operator receives dedicated SLA Risk Radar view', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const PredictiveAnalyticsScreen(), role: 'operator'));
      await tester.pumpAndSettle();

      expect(find.text('SLA Risk Radar & Threat Intelligence'), findsOneWidget);
      expect(find.byType(SlaRiskRadarView), findsOneWidget);
      // Operator should NOT see other tabs
      expect(find.text('Workload Forecast'), findsNothing);
      expect(find.text('Team Capacity'), findsNothing);
    });

    testWidgets('Requester is presented with Access Restricted barrier', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const PredictiveAnalyticsScreen(), role: 'requester'));
      await tester.pumpAndSettle();

      expect(find.text('Access Restricted'), findsOneWidget);
      expect(find.textContaining('restricted to staff roles'), findsOneWidget);
    });
  });
}
