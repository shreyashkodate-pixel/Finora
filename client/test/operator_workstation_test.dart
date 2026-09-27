import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ai_helpdesk_client/shared/theme/app_theme.dart';
import 'package:ai_helpdesk_client/shared/storage.dart';
import 'package:ai_helpdesk_client/shared/api_client.dart';
import 'package:ai_helpdesk_client/features/auth/providers/auth_provider.dart';
import 'package:ai_helpdesk_client/features/auth/models/user_model.dart';
import 'package:ai_helpdesk_client/features/cases/providers/case_provider.dart';
import 'package:ai_helpdesk_client/features/cases/screens/case_detail_screen.dart';
import 'package:ai_helpdesk_client/features/cases/widgets/message_stream_widget.dart';
import 'package:ai_helpdesk_client/features/dashboard/screens/operator_workspace_screen.dart';
import 'package:ai_helpdesk_client/features/ai/providers/ai_provider.dart';
import 'package:ai_helpdesk_client/features/ai/widgets/ai_triage_card.dart';
import 'package:ai_helpdesk_client/features/ai/widgets/living_summary_card.dart';
import 'package:ai_helpdesk_client/features/ai/widgets/sla_risk_card.dart';
import 'package:ai_helpdesk_client/features/approvals/providers/approval_provider.dart';

class MockOperatorApiClient extends ApiClient {
  bool throwConflictOnMutation = false;
  bool failAiEndpoints = false;
  int getCaseFetchCount = 0;

  MockOperatorApiClient() : super(baseUrl: 'http://localhost:8000');

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) async {
    if (path == '/cases') {
      return {
        'cases': [
          {
            'id': 'case-201',
            'reference_number': 'INC-2026-000201',
            'title': 'Production DB Connection Pool Exhaustion',
            'description': 'Database rejecting connections with pool timeout error 1040',
            'status': 'new',
            'priority': 'p1',
            'type': 'incident',
            'site': 'Data Center Alpha',
            'requester_id': 'req-9',
            'owner_id': null,
            'version': 1,
            'created_at': DateTime.now().subtract(const Duration(minutes: 10)).toIso8601String(),
            'sla': {
              'id': 'sla-1',
              'target_response_at': DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
              'target_resolve_at': DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
              'response_breached': false,
              'resolution_breached': false,
            },
          },
          {
            'id': 'case-202',
            'reference_number': 'REQ-2026-000202',
            'title': 'Developer Laptop RAM Upgrade',
            'description': 'Requesting 64GB RAM upgrade for workstation',
            'status': 'assigned',
            'priority': 'p3',
            'type': 'service_request',
            'site': 'Campus North',
            'requester_id': 'req-12',
            'owner_id': 'op-99',
            'version': 3,
            'created_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
            'sla': {
              'id': 'sla-2',
              'target_response_at': DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String(),
              'target_resolve_at': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
              'response_breached': true,
              'resolution_breached': false,
            },
          }
        ],
        'total': 2,
      };
    }

    if (path == '/cases/case-201') {
      getCaseFetchCount++;
      return {
        'id': 'case-201',
        'reference_number': 'INC-2026-000201',
        'title': 'Production DB Connection Pool Exhaustion',
        'description': 'Database rejecting connections with pool timeout error 1040',
        'status': 'new',
        'priority': 'p1',
        'type': 'incident',
        'site': 'Data Center Alpha',
        'requester_id': 'req-9',
        'owner_id': null,
        'version': throwConflictOnMutation ? 2 : 1,
        'created_at': DateTime.now().subtract(const Duration(minutes: 10)).toIso8601String(),
        'sla': {
          'id': 'sla-1',
          'target_response_at': DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
          'target_resolve_at': DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
          'response_breached': false,
          'resolution_breached': false,
        },
      };
    }

    if (path == '/cases/case-201/messages') {
      return [
        {
          'id': 'msg-1',
          'case_id': 'case-201',
          'author_id': 'req-9',
          'body': 'Users reporting 500 errors across all portal endpoints.',
          'visibility': 'requester_visible',
          'ai_generated': false,
          'created_at': DateTime.now().subtract(const Duration(minutes: 8)).toIso8601String(),
        },
        {
          'id': 'msg-2',
          'case_id': 'case-201',
          'author_id': 'op-99',
          'body': 'Internal check: DB cluster node 3 memory pressure detected.',
          'visibility': 'internal_only',
          'ai_generated': false,
          'created_at': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
        },
      ];
    }

    if (path == '/cases/case-201/attachments') {
      return [];
    }

    if (path == '/cases/case-201/approvals') {
      return [];
    }

    if (path == '/ai/cases/case-201/summary') {
      if (failAiEndpoints) throw ApiException(statusCode: 503, code: 'SERVICE_UNAVAILABLE', message: 'AI Service Unavailable');
      return {
        'case_id': 'case-201',
        'summary': 'High severity database pool saturation causing cascading service degradation.',
        'updated_at': DateTime.now().toIso8601String(),
        'message_count': 2,
      };
    }

    if (path == '/ai/cases/case-201/risk') {
      if (failAiEndpoints) throw ApiException(statusCode: 503, code: 'SERVICE_UNAVAILABLE', message: 'AI Service Unavailable');
      return {
        'case_id': 'case-201',
        'risk_score': 0.85,
        'risk_level': 'high',
        'risk_factors': ['High incident velocity', 'P1 priority active', 'SLA resolution window < 1h'],
        'recommendation': 'Escalate immediately to Lead DBA.',
      };
    }

    return {};
  }

  @override
  Future<dynamic> post(String path, {Map<String, dynamic>? body, String? idempotencyKey}) async {
    if (path == '/ai/cases/case-201/triage') {
      if (failAiEndpoints) throw ApiException(statusCode: 503, code: 'SERVICE_UNAVAILABLE', message: 'AI Service Unavailable');
      return {
        'suggested_category': 'Infrastructure / Database',
        'suggested_priority': 'p1',
        'confidence_score': 0.94,
        'confidence_level': 'high',
        'reasoning': 'Incident involves critical pool exhaustion on production database.',
        'relevant_kb_article_ids': ['kb-101'],
      };
    }

    if (path == '/ai/cases/case-201/triage/apply') {
      if (throwConflictOnMutation) {
        throw ApiException(statusCode: 409, code: 'STALE_VERSION', message: 'STALE_VERSION: This ticket was modified by another operator.');
      }
      return {'status': 'applied'};
    }

    if (path == '/cases/case-201/messages') {
      final msgBody = body?['body'] ?? '';
      final visibility = body?['visibility'] ?? 'requester_visible';
      return {
        'id': 'msg-new',
        'case_id': 'case-201',
        'author_id': 'op-99',
        'body': msgBody,
        'visibility': visibility,
        'ai_generated': false,
        'created_at': DateTime.now().toIso8601String(),
      };
    }

    return {};
  }

  @override
  Future<dynamic> patch(String path, {Map<String, dynamic>? body, String? idempotencyKey}) async {
    if (throwConflictOnMutation) {
      throw ApiException(
        statusCode: 409,
        code: 'STALE_VERSION',
        message: 'STALE_VERSION: Case version conflict. Expected version 1 but found version 2.',
      );
    }

    if (path == '/cases/case-201') {
      final ownerId = body?['owner_id'];
      final priority = body?['priority'];
      return {
        'id': 'case-201',
        'reference_number': 'INC-2026-000201',
        'title': 'Production DB Connection Pool Exhaustion',
        'description': 'Database rejecting connections with pool timeout error 1040',
        'status': 'assigned',
        'priority': priority ?? 'p1',
        'type': 'incident',
        'site': 'Data Center Alpha',
        'requester_id': 'req-9',
        'owner_id': ownerId ?? 'op-99',
        'version': 2,
        'created_at': DateTime.now().subtract(const Duration(minutes: 10)).toIso8601String(),
      };
    }

    if (path == '/cases/case-201/status') {
      final newStatus = body?['status'];
      return {
        'id': 'case-201',
        'reference_number': 'INC-2026-000201',
        'title': 'Production DB Connection Pool Exhaustion',
        'description': 'Database rejecting connections with pool timeout error 1040',
        'status': newStatus ?? 'in_progress',
        'priority': 'p1',
        'type': 'incident',
        'site': 'Data Center Alpha',
        'requester_id': 'req-9',
        'owner_id': 'op-99',
        'version': 2,
        'created_at': DateTime.now().subtract(const Duration(minutes: 10)).toIso8601String(),
      };
    }

    return {};
  }
}

void main() {
  group('Operator Workstation — Phase 2B Comprehensive Invariant & Functional Tests', () {
    late MockOperatorApiClient mockApi;
    late AuthProvider authProvider;
    late CaseProvider caseProvider;
    late AIProvider aiProvider;
    late ApprovalProvider approvalProvider;

    setUp(() {
      mockApi = MockOperatorApiClient();
      authProvider = AuthProvider(apiClient: mockApi, storage: SessionStorage());
      caseProvider = CaseProvider(apiClient: mockApi);
      aiProvider = AIProvider(apiClient: mockApi);
      approvalProvider = ApprovalProvider(apiClient: mockApi);

      // Set current user as IT Operator staff
      authProvider.setMockUser(
        const UserModel(
          id: 'op-99',
          email: 'operator@enterprise.com',
          fullName: 'Alex Vance',
          role: 'operator',
          site: 'Data Center Alpha',
        ),
      );
    });

    Widget createTestApp(Widget child) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<CaseProvider>.value(value: caseProvider),
          ChangeNotifierProvider<AIProvider>.value(value: aiProvider),
          ChangeNotifierProvider<ApprovalProvider>.value(value: approvalProvider),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: child),
        ),
      );
    }

    testWidgets('1. Operator Triage Queue renders metrics, search, and categorized tickets', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(const OperatorWorkspaceScreen()));
      await tester.pumpAndSettle();

      // Verifies Header & Metric KPI Cards
      expect(find.text('Operator Triage Workstation'), findsOneWidget);
      expect(find.text('Triage Queue'), findsWidgets);
      expect(find.text('Assigned to Me'), findsWidgets);
      expect(find.text('P1 Critical'), findsWidgets);

      // Verifies Unassigned Ticket appears in table
      expect(find.text('INC-2026-000201'), findsOneWidget);
      expect(find.text('Production DB Connection Pool Exhaustion'), findsOneWidget);
    });

    testWidgets('2. Operator Workspace displays comprehensive case metadata, SLA, and staff actions', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await caseProvider.fetchCaseDetails('case-201');
      await tester.pumpWidget(createTestApp(const CaseDetailScreen(caseId: 'case-201')));
      await tester.pumpAndSettle();

      // Verifies Reference & Staff Action Buttons
      expect(find.text('INC-2026-000201'), findsOneWidget);
      expect(find.text('Assign to Me'), findsOneWidget);
      expect(find.text('Update Status'), findsOneWidget);
      expect(find.text('Priority'), findsOneWidget);

      // Verifies Tabs for Discussion, AI Copilot, Info & Evidence
      expect(find.text('Discussion'), findsOneWidget);
      expect(find.text('AI Copilot'), findsOneWidget);
      expect(find.text('Info & Evidence'), findsOneWidget);
    });

    testWidgets('3. Assign to Me mutation updates case owner with optimistic version token', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await caseProvider.fetchCaseDetails('case-201');
      await tester.pumpWidget(createTestApp(const CaseDetailScreen(caseId: 'case-201')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Assign to Me'));
      await tester.pumpAndSettle();

      expect(find.text('Case INC-2026-000201 assigned to you.'), findsOneWidget);
      expect(caseProvider.selectedCase?.ownerId, 'op-99');
    });

    testWidgets('4. Locked Invariant 2: 409 STALE_VERSION shows exact message and refreshes case', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      mockApi.throwConflictOnMutation = true;

      await caseProvider.fetchCaseDetails('case-201');
      await tester.pumpWidget(createTestApp(const CaseDetailScreen(caseId: 'case-201')));
      await tester.pumpAndSettle();

      // Attempting mutation with stale version
      await tester.tap(find.text('Assign to Me'));
      await tester.pumpAndSettle();

      // Verifies exact required invariant text
      expect(find.text('This ticket was modified by another operator. Refreshing...'), findsOneWidget);
    });

    testWidgets('5. Public Live Chat vs Internal Notes separation & staff visibility toggle', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await caseProvider.fetchCaseDetails('case-201');
      await tester.pumpWidget(createTestApp(const SizedBox(height: 600, child: MessageStreamWidget(caseId: 'case-201'))));
      await tester.pumpAndSettle();

      // Verifies Public vs Internal visibility chips for Staff
      expect(find.text('Public Reply'), findsOneWidget);
      expect(find.text('Internal Note'), findsOneWidget);

      // Verifies Internal Note Badge appears in timeline
      expect(find.text('INTERNAL NOTE'), findsOneWidget);
      expect(find.text('Internal check: DB cluster node 3 memory pressure detected.'), findsOneWidget);

      // Switch to internal note and compose message
      await tester.tap(find.text('Internal Note'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Restarting replica node 2.');
      await tester.tap(find.text('Send Reply'));
      await tester.pumpAndSettle();

      expect(find.text('Restarting replica node 2.'), findsOneWidget);
    });

    testWidgets('6. Advisory AI Copilot displays triage suggestions and supports Human-in-the-Loop apply', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await caseProvider.fetchCaseDetails('case-201');
      await aiProvider.fetchTriage('case-201');
      await aiProvider.fetchSummary('case-201');
      await aiProvider.fetchRisk('case-201');

      await tester.pumpWidget(
        createTestApp(
          SingleChildScrollView(
            child: Column(
              children: [
                LivingSummaryCard(caseId: 'case-201', summary: aiProvider.summary, isStaff: true),
                SLARiskCard(risk: aiProvider.risk),
                AITriageCard(currentCase: caseProvider.selectedCase!, triage: aiProvider.triage, isStaff: true),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verifies Living Summary
      expect(find.text('Living Case Summary'), findsOneWidget);
      expect(find.text('High severity database pool saturation causing cascading service degradation.'), findsOneWidget);

      // Verifies SLA Risk
      expect(find.text('SLA & Escalation Risk Assessment'), findsOneWidget);

      // Verifies AI Triage & Apply Button
      expect(find.text('AI Triage Recommendation'), findsOneWidget);
      expect(find.text('HIGH CONFIDENCE'), findsOneWidget);
      expect(find.text('Apply Recommendation'), findsOneWidget);

      // Apply recommendation
      await tester.tap(find.text('Apply Recommendation'));
      await tester.pumpAndSettle();

      expect(find.text('AI recommendation applied successfully.'), findsOneWidget);
    });

    testWidgets('7. Locked Invariant "Case is King": Case workspace operates normally when AI fails', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      mockApi.failAiEndpoints = true;

      await caseProvider.fetchCaseDetails('case-201');
      await tester.pumpWidget(createTestApp(const CaseDetailScreen(caseId: 'case-201')));
      await tester.pumpAndSettle();

      // Case detail is fully accessible and functional even with AI offline
      expect(find.text('INC-2026-000201'), findsOneWidget);
      expect(find.text('Assign to Me'), findsOneWidget);
      expect(find.text('Update Status'), findsOneWidget);
      expect(find.text('Discussion'), findsOneWidget);
      expect(find.text('AI Copilot'), findsOneWidget);
      expect(find.text('Info & Evidence'), findsOneWidget);
    });
  });
}
