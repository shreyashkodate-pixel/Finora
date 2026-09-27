import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ai_helpdesk_client/features/alerts/models/alert_model.dart';
import 'package:ai_helpdesk_client/features/alerts/providers/alert_provider.dart';
import 'package:ai_helpdesk_client/features/alerts/screens/inbound_alerts_screen.dart';
import 'package:ai_helpdesk_client/features/auth/models/user_model.dart';
import 'package:ai_helpdesk_client/features/auth/providers/auth_provider.dart';
import 'package:ai_helpdesk_client/features/cases/providers/case_provider.dart';
import 'package:ai_helpdesk_client/shared/api_client.dart';
import 'package:ai_helpdesk_client/shared/storage.dart';
import 'package:ai_helpdesk_client/shared/theme/app_theme.dart';
import 'package:ai_helpdesk_client/shared/widgets/custom_buttons.dart';
import 'package:ai_helpdesk_client/features/alerts/widgets/create_rule_dialog.dart';

class MockAlertApiClient extends ApiClient {
  MockAlertApiClient() : super(baseUrl: 'http://localhost:8000');

  bool throwError = false;
  bool returnEmpty = false;
  bool ackCalled = false;
  bool ruleCreated = false;

  final List<Map<String, dynamic>> mockAlerts = [
    {
      'id': 'a1111111-1111-1111-1111-111111111111',
      'provider': 'prometheus',
      'external_alert_id': 'prom-pg-01',
      'title': 'PostgreSQL Connection Exhaustion',
      'severity': 'critical',
      'description': 'Active connections reached 980 of 1000 max limit.',
      'fingerprint': 'fp_prom_pg_conn_980',
      'status': 'incident_created',
      'raw_payload': {'alertname': 'PostgresConnExhausted', 'severity': 'critical'},
      'case_id': 'c1111111-1111-1111-1111-111111111111',
      'acknowledged_at': null,
      'acknowledged_by_id': null,
      'created_at': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    },
    {
      'id': 'a2222222-2222-2222-2222-222222222222',
      'provider': 'datadog',
      'external_alert_id': 'dd-cpu-99',
      'title': 'High CPU Utilization on Node 03',
      'severity': 'high',
      'description': 'CPU utilization exceeded 92% sustained for 10m.',
      'fingerprint': 'fp_dd_cpu_92_node3',
      'status': 'received',
      'raw_payload': {'event_title': 'High CPU', 'alert_type': 'error'},
      'case_id': null,
      'acknowledged_at': null,
      'acknowledged_by_id': null,
      'created_at': DateTime.now().subtract(const Duration(minutes: 12)).toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    },
    {
      'id': 'a3333333-3333-3333-3333-333333333333',
      'provider': 'sentry',
      'external_alert_id': 'sentry-500-auth',
      'title': 'Unhandled OAuth Callback NullPointerException',
      'severity': 'warning',
      'description': 'Null pointer exception during Google token validation.',
      'fingerprint': 'fp_sentry_npe_auth',
      'status': 'acknowledged',
      'raw_payload': {'level': 'warning', 'culprit': 'auth_service.py'},
      'case_id': null,
      'acknowledged_at': DateTime.now().toIso8601String(),
      'acknowledged_by_id': 'u1111111-1111-1111-1111-111111111111',
      'created_at': DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    },
  ];

  final List<Map<String, dynamic>> mockRules = [
    {
      'id': 'r1111111-1111-1111-1111-111111111111',
      'name': 'Kafka Consumer Lag Critical Escalation',
      'provider': 'generic',
      'match_severity': 'critical',
      'match_keyword': 'Kafka',
      'auto_create_incident': true,
      'incident_priority': 'p1',
      'target_team_id': 't1111111-1111-1111-1111-111111111111',
      'is_active': true,
      'created_at': DateTime.now().toIso8601String(),
    },
  ];

  @override
  Future<dynamic> get(String endpoint, {Map<String, dynamic>? queryParameters}) async {
    if (throwError) {
      throw ApiException(
        statusCode: 503,
        code: 'HTTP_503',
        message: '503 Service Unavailable',
      );
    }

    if (endpoint == '/integrations/alerts/rules') {
      if (returnEmpty) return [];
      return mockRules;
    }

    if (endpoint.startsWith('/integrations/alerts')) {
      if (returnEmpty) return [];
      return mockAlerts;
    }

    return <Map<String, dynamic>>[];
  }

  @override
  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    String? idempotencyKey,
  }) async {
    if (endpoint.contains('/acknowledge')) {
      ackCalled = true;
      return {
        'id': 'a2222222-2222-2222-2222-222222222222',
        'provider': 'datadog',
        'external_alert_id': 'dd-cpu-99',
        'title': 'High CPU Utilization on Node 03',
        'severity': 'high',
        'description': 'CPU utilization exceeded 92% sustained for 10m.',
        'fingerprint': 'fp_dd_cpu_92_node3',
        'status': 'acknowledged',
        'raw_payload': {'event_title': 'High CPU'},
        'case_id': null,
        'acknowledged_at': DateTime.now().toIso8601String(),
        'acknowledged_by_id': 'u1111111-1111-1111-1111-111111111111',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
    }

    if (endpoint == '/integrations/alerts/rules') {
      ruleCreated = true;
      return {
        'id': 'r2222222-2222-2222-2222-222222222222',
        'name': body?['name'] ?? 'New Rule',
        'provider': body?['provider'] ?? 'generic',
        'match_severity': body?['match_severity'] ?? 'critical',
        'match_keyword': body?['match_keyword'] ?? 'Redis',
        'auto_create_incident': body?['auto_create_incident'] ?? true,
        'incident_priority': body?['incident_priority'] ?? 'p1',
        'target_team_id': null,
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
      };
    }

    return null;
  }
}

Widget _createTestApp({
  required MockAlertApiClient apiClient,
  UserModel? user,
}) {
  final storage = SessionStorage();
  final authProvider = AuthProvider(apiClient: apiClient, storage: storage);
  final alertProvider = AlertProvider(apiClient: apiClient);
  final caseProvider = CaseProvider(apiClient: apiClient);

  authProvider.setMockUser(
    user ??
        const UserModel(
          id: 'u1111111-1111-1111-1111-111111111111',
          email: 'operator@finora.internal',
          role: 'operator',
          site: 'HQ',
          emailVerified: true,
        ),
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ChangeNotifierProvider<AlertProvider>.value(value: alertProvider),
      ChangeNotifierProvider<CaseProvider>.value(value: caseProvider),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: const InboundAlertsScreen(),
    ),
  );
}

void main() {
  group('Phase 4B: Models & Stats Tests', () {
    test('InboundAlertModel serializes and deserializes correctly', () {
      final json = {
        'id': 'a-100',
        'provider': 'prometheus',
        'external_alert_id': 'prom-1',
        'title': 'Disk Usage High',
        'severity': 'critical',
        'description': 'Disk > 90%',
        'fingerprint': 'fp_disk_90',
        'status': 'incident_created',
        'raw_payload': {'foo': 'bar'},
        'case_id': 'c-200',
        'acknowledged_at': null,
        'acknowledged_by_id': null,
        'created_at': '2026-09-21T10:00:00Z',
        'updated_at': '2026-09-21T10:00:00Z',
      };

      final model = InboundAlertModel.fromJson(json);
      expect(model.id, 'a-100');
      expect(model.provider, AlertProviderEnum.prometheus);
      expect(model.title, 'Disk Usage High');
      expect(model.severity, 'critical');
      expect(model.hasLinkedCase, isTrue);
      expect(model.isAcknowledged, isFalse);
      expect(model.toJson()['fingerprint'], 'fp_disk_90');
    });

    test('AlertRuleModel and AlertStatsModel compute correctly', () {
      final ruleJson = {
        'id': 'r-1',
        'name': 'Memory Warning',
        'provider': 'datadog',
        'match_severity': 'warning',
        'match_keyword': 'Memory',
        'auto_create_incident': true,
        'incident_priority': 'p2',
        'target_team_id': null,
        'is_active': true,
        'created_at': '2026-09-21T10:00:00Z',
      };

      final rule = AlertRuleModel.fromJson(ruleJson);
      expect(rule.name, 'Memory Warning');
      expect(rule.provider, AlertProviderEnum.datadog);
      expect(rule.isActive, isTrue);

      final alerts = [
        InboundAlertModel.fromJson({
          'id': '1',
          'provider': 'datadog',
          'title': 'A1',
          'severity': 'critical',
          'fingerprint': 'fp1',
          'status': 'incident_created',
          'raw_payload': {},
          'created_at': '2026-09-21T10:00:00Z',
          'updated_at': '2026-09-21T10:00:00Z',
        }),
        InboundAlertModel.fromJson({
          'id': '2',
          'provider': 'sentry',
          'title': 'A2',
          'severity': 'warning',
          'fingerprint': 'fp2',
          'status': 'correlated',
          'raw_payload': {},
          'created_at': '2026-09-21T10:00:00Z',
          'updated_at': '2026-09-21T10:00:00Z',
        }),
      ];

      final stats = AlertStatsModel.fromAlerts(alerts);
      expect(stats.totalAlerts, 2);
      expect(stats.criticalHighCount, 1);
      expect(stats.unacknowledgedCount, 2);
      expect(stats.incidentCreatedCount, 1);
      expect(stats.correlatedCount, 1);
    });
  });

  group('Phase 4B: UI & Interaction Widget Tests', () {
    testWidgets('1. Renders InboundAlertsScreen header, telemetry KPIs, and search bar', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final apiClient = MockAlertApiClient();
      await tester.pumpWidget(_createTestApp(apiClient: apiClient));
      await tester.pumpAndSettle();

      expect(find.text('Inbound APM & Observability'), findsOneWidget);
      expect(find.text('LOSSLESS INGESTION'), findsOneWidget);
      expect(find.text('TOTAL FEED'), findsOneWidget);
      expect(find.text('CRITICAL & HIGH'), findsOneWidget);
      expect(find.text('UNACKNOWLEDGED'), findsOneWidget);
      expect(find.text('INCIDENTS CREATED'), findsOneWidget);
      expect(find.text('CORRELATED (DEDUP)'), findsOneWidget);
      expect(find.text('PostgreSQL Connection Exhaustion'), findsOneWidget);
      expect(find.text('High CPU Utilization on Node 03'), findsOneWidget);
      expect(find.text('Unhandled OAuth Callback NullPointerException'), findsOneWidget);
    });

    testWidgets('2. Provider filtering chips isolate matching alerts', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final apiClient = MockAlertApiClient();
      await tester.pumpWidget(_createTestApp(apiClient: apiClient));
      await tester.pumpAndSettle();

      // Click Prometheus filter chip
      await tester.tap(find.widgetWithText(FilterChip, 'Prometheus'));
      await tester.pumpAndSettle();

      expect(find.text('PostgreSQL Connection Exhaustion'), findsOneWidget);
      expect(find.text('High CPU Utilization on Node 03'), findsNothing);

      // Click Datadog filter chip
      await tester.tap(find.widgetWithText(FilterChip, 'Datadog'));
      await tester.pumpAndSettle();

      expect(find.text('High CPU Utilization on Node 03'), findsOneWidget);
      expect(find.text('PostgreSQL Connection Exhaustion'), findsNothing);
    });

    testWidgets('3. Search query filters alert list by text query', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final apiClient = MockAlertApiClient();
      await tester.pumpWidget(_createTestApp(apiClient: apiClient));
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Postgres');
      await tester.pumpAndSettle();

      expect(find.text('PostgreSQL Connection Exhaustion'), findsOneWidget);
      expect(find.text('High CPU Utilization on Node 03'), findsNothing);
    });

    testWidgets('4. Desktop Master-Detail: Selecting an alert displays AlertDetailPane', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final apiClient = MockAlertApiClient();
      await tester.pumpWidget(_createTestApp(apiClient: apiClient));
      await tester.pumpAndSettle();

      // Tap on the first alert card
      await tester.tap(find.text('PostgreSQL Connection Exhaustion'));
      await tester.pumpAndSettle();

      // Inspect detail pane on right side
      expect(find.text('Telemetry & Ingestion Metadata'), findsOneWidget);
      expect(find.text('fp_prom_pg_conn_980'), findsOneWidget);
      expect(find.text('prom-pg-01'), findsOneWidget);
      expect(find.text('Raw Ingested Payload'), findsOneWidget);
      expect(find.text('Acknowledge Alert'), findsOneWidget);
      expect(find.text('Open Linked Incident'), findsOneWidget);
    });

    testWidgets('5. Acknowledging an alert invokes API and updates authoritative state', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final apiClient = MockAlertApiClient();
      await tester.pumpWidget(_createTestApp(apiClient: apiClient));
      await tester.pumpAndSettle();

      // Select Datadog unacknowledged alert
      await tester.tap(find.text('High CPU Utilization on Node 03'));
      await tester.pumpAndSettle();

      // Click Acknowledge Alert button
      await tester.tap(find.text('Acknowledge Alert'));
      await tester.pumpAndSettle();

      // Confirm in dialog
      expect(find.text('Acknowledge Inbound Alert'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Acknowledge'));
      await tester.pumpAndSettle();

      expect(apiClient.ackCalled, isTrue);
      expect(find.text('Alert acknowledged successfully.'), findsOneWidget);
    });

    testWidgets('6. Alert Rules tab renders configured rules and active status', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final apiClient = MockAlertApiClient();
      await tester.pumpWidget(_createTestApp(apiClient: apiClient));
      await tester.pumpAndSettle();

      // Switch to Alert Rules tab
      await tester.tap(find.text('Alert Rules'));
      await tester.pumpAndSettle();

      expect(find.text('Active Transformation & Ingestion Rules'), findsOneWidget);
      expect(find.text('Kafka Consumer Lag Critical Escalation'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.text('Target Priority: P1'), findsOneWidget);
    });

    testWidgets('7. Authorized role (Team Lead) can open Create Rule Dialog and create rule', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final apiClient = MockAlertApiClient();
      final teamLeadUser = const UserModel(
        id: 'u2222222-2222-2222-2222-222222222222',
        email: 'lead@finora.internal',
        role: 'team_lead',
        site: 'HQ',
        emailVerified: true,
      );

      await tester.pumpWidget(_createTestApp(apiClient: apiClient, user: teamLeadUser));
      await tester.pumpAndSettle();

      // Click Create Rule CTA in header
      expect(find.widgetWithText(PrimaryButton, 'Create Rule'), findsOneWidget);
      await tester.tap(find.widgetWithText(PrimaryButton, 'Create Rule'));
      await tester.pumpAndSettle();

      expect(find.text('Automate priority routing and incident auto-creation'), findsOneWidget);

      // Enter Rule Name
      await tester.enterText(find.byType(TextFormField).first, 'New Redis Latency Rule');
      await tester.pumpAndSettle();

      // Tap Create Rule submit button in dialog
      await tester.tap(find.descendant(
        of: find.byType(CreateRuleDialog),
        matching: find.widgetWithText(PrimaryButton, 'Create Rule'),
      ));
      await tester.pumpAndSettle();

      expect(apiClient.ruleCreated, isTrue);
      expect(find.text('Alert rule created successfully.'), findsOneWidget);
    });

    testWidgets('8. Operator role cannot create alert rules (button hidden)', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final apiClient = MockAlertApiClient();
      final operatorUser = const UserModel(
        id: 'u1111111-1111-1111-1111-111111111111',
        email: 'operator@finora.internal',
        role: 'operator',
        site: 'HQ',
        emailVerified: true,
      );

      await tester.pumpWidget(_createTestApp(apiClient: apiClient, user: operatorUser));
      await tester.pumpAndSettle();

      // Operator cannot create rules
      expect(find.text('Create Rule'), findsNothing);

      // Switch to Alert Rules tab
      await tester.tap(find.text('Alert Rules'));
      await tester.pumpAndSettle();

      expect(find.text('Add Rule'), findsNothing);
    });

    testWidgets('9. Requester role cannot access Inbound Alert Dashboard (RBAC barrier)', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final apiClient = MockAlertApiClient();
      final requesterUser = const UserModel(
        id: 'u3333333-3333-3333-3333-333333333333',
        email: 'requester@finora.internal',
        role: 'requester',
        site: 'HQ',
        emailVerified: true,
      );

      await tester.pumpWidget(_createTestApp(apiClient: apiClient, user: requesterUser));
      await tester.pumpAndSettle();

      expect(find.text('Access Restricted'), findsOneWidget);
      expect(find.text('Inbound monitoring feeds and alert rules are restricted to IT staff members.'), findsOneWidget);
      expect(find.text('Inbound APM & Observability'), findsNothing);
    });

    testWidgets('10. Displays Empty State when no alerts match active filters', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final apiClient = MockAlertApiClient();
      await tester.pumpWidget(_createTestApp(apiClient: apiClient));
      await tester.pumpAndSettle();

      // Enter search query that matches nothing
      await tester.enterText(find.byType(TextField), 'non_existent_query_string');
      await tester.pumpAndSettle();

      expect(find.text('No Matching Alerts Found'), findsOneWidget);
      expect(find.text('Reset All Filters'), findsOneWidget);
    });

    testWidgets('11. Displays Error State on API failure with working retry button', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final apiClient = MockAlertApiClient();
      apiClient.throwError = true;

      await tester.pumpWidget(_createTestApp(apiClient: apiClient));
      await tester.pumpAndSettle();

      expect(find.text('Feed Ingestion Error'), findsOneWidget);
      expect(find.text('503 Service Unavailable'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });

    testWidgets('12. Mobile layout (< 900px) renders stacked list and opens modal on tap', (tester) async {
      tester.view.physicalSize = const Size(450, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final apiClient = MockAlertApiClient();
      await tester.pumpWidget(_createTestApp(apiClient: apiClient));
      await tester.pumpAndSettle();

      // Scroll to alert card on mobile if needed and tap
      final alertFinder = find.text('PostgreSQL Connection Exhaustion');
      await tester.ensureVisible(alertFinder);
      await tester.pumpAndSettle();
      await tester.tap(alertFinder);
      await tester.pumpAndSettle();

      // Bottom sheet modal opens with details
      expect(find.text('Telemetry & Ingestion Metadata'), findsOneWidget);
      expect(find.text('fp_prom_pg_conn_980'), findsOneWidget);
    });
  });
}
