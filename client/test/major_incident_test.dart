import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ai_helpdesk_client/shared/theme/app_theme.dart';
import 'package:ai_helpdesk_client/shared/storage.dart';
import 'package:ai_helpdesk_client/shared/api_client.dart';
import 'package:ai_helpdesk_client/features/auth/providers/auth_provider.dart';
import 'package:ai_helpdesk_client/features/auth/models/user_model.dart';
import 'package:ai_helpdesk_client/features/ai/providers/ai_provider.dart';
import 'package:ai_helpdesk_client/features/major_incidents/providers/major_incident_provider.dart';
import 'package:ai_helpdesk_client/features/major_incidents/screens/major_incident_screen.dart';
import 'package:ai_helpdesk_client/features/approvals/providers/approval_provider.dart';
import 'package:ai_helpdesk_client/features/cases/providers/case_provider.dart';
import 'package:ai_helpdesk_client/features/cases/screens/case_detail_screen.dart';

class MockMajorIncidentApiClient extends ApiClient {
  bool throwForbidden = false;
  bool throwError = false;
  bool returnEmpty = false;

  final List<Map<String, dynamic>> mockIncidents = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'inc-001',
      'incident_number': 'INC-2026-0001',
      'case_id': '550e8400-e29b-41d4-a716-446655440001',
      'title': 'Core Payment Gateway 500 Outage',
      'status': 'active',
      'commander_id': 'usr-manager-1',
      'bridge_url': 'https://meet.google.com/fin-war-room-1',
      'communications_lead_id': 'usr-lead-1',
      'executive_summary': null,
      'impact_summary': '100% of checkout payments failing in EU-Central-1.',
      'declared_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
      'mitigated_at': null,
      'resolved_at': null,
      'post_mortem_url': null,
      'timeline_events': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'evt-001',
          'major_incident_id': 'inc-001',
          'author_id': 'usr-manager-1',
          'summary': 'Major incident declared by Incident Commander',
          'details': 'Activated P1 alert page and initiated bridge call.',
          'event_timestamp': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        },
        <String, dynamic>{
          'id': 'evt-002',
          'major_incident_id': 'inc-001',
          'author_id': 'usr-operator-1',
          'summary': 'Isolated traffic to healthy payment provider replica',
          'details': 'Traffic rerouted via Cloudflare DNS failover pool.',
          'event_timestamp': DateTime.now().subtract(const Duration(minutes: 45)).toIso8601String(),
        },
      ],
    },
    <String, dynamic>{
      'id': 'inc-002',
      'incident_number': 'INC-2026-0002',
      'case_id': '550e8400-e29b-41d4-a716-446655440002',
      'title': 'Internal Active Directory SSO Latency',
      'status': 'declared',
      'commander_id': 'usr-lead-1',
      'bridge_url': 'https://meet.google.com/fin-war-room-2',
      'communications_lead_id': null,
      'executive_summary': null,
      'impact_summary': 'Employees experiencing 20s login delays on internal portals.',
      'declared_at': DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String(),
      'mitigated_at': null,
      'resolved_at': null,
      'post_mortem_url': null,
      'timeline_events': <Map<String, dynamic>>[],
    },
    <String, dynamic>{
      'id': 'inc-003',
      'incident_number': 'INC-2026-0003',
      'case_id': '550e8400-e29b-41d4-a716-446655440003',
      'title': 'Customer Support Phone Trunk Line Drop',
      'status': 'mitigated',
      'commander_id': 'usr-manager-1',
      'bridge_url': 'https://meet.google.com/fin-war-room-3',
      'communications_lead_id': 'usr-lead-1',
      'executive_summary': null,
      'impact_summary': 'SIP trunk provider gateway degraded.',
      'declared_at': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(),
      'mitigated_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
      'resolved_at': null,
      'post_mortem_url': null,
      'timeline_events': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'evt-003',
          'major_incident_id': 'inc-003',
          'author_id': 'usr-manager-1',
          'summary': 'Secondary SIP trunk activated',
          'details': 'Call queues resumed at 95% throughput.',
          'event_timestamp': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
        },
      ],
    },
    <String, dynamic>{
      'id': 'inc-004',
      'incident_number': 'INC-2026-0004',
      'case_id': '550e8400-e29b-41d4-a716-446655440004',
      'title': 'Analytics Pipeline Kafka Partition Lock',
      'status': 'resolved',
      'commander_id': 'usr-manager-1',
      'bridge_url': 'https://meet.google.com/fin-war-room-4',
      'communications_lead_id': 'usr-lead-1',
      'executive_summary': 'Kafka broker cluster rebalanced and consumer group lag cleared.',
      'impact_summary': 'BI reporting delayed by 2 hours.',
      'declared_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      'mitigated_at': DateTime.now().subtract(const Duration(hours: 22)).toIso8601String(),
      'resolved_at': DateTime.now().subtract(const Duration(hours: 20)).toIso8601String(),
      'post_mortem_url': 'https://wiki.finora.internal/postmortem/inc-2026-0004',
      'timeline_events': <Map<String, dynamic>>[],
    },
  ];

  MockMajorIncidentApiClient() : super(baseUrl: 'http://localhost:8000');

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) async {
    if (throwError) {
      throw ApiException(
        statusCode: 500,
        code: 'INTERNAL_ERROR',
        message: 'Failed to load major incidents from server.',
      );
    }
    if (throwForbidden) {
      throw ApiException(
        statusCode: 403,
        code: 'PERMISSION_DENIED',
        message: 'Requesters cannot access Major Incident Command Bridge.',
      );
    }
    if (path == '/major-incidents') {
      if (returnEmpty) return [];
      var results = List<Map<String, dynamic>>.from(mockIncidents);
      if (queryParameters?['status'] != null) {
        results = results.where((i) => i['status'] == queryParameters!['status']).toList();
      }
      return results;
    }
    if (path.startsWith('/major-incidents/')) {
      final id = path.replaceFirst('/major-incidents/', '');
      return mockIncidents.firstWhere((i) => i['id'] == id, orElse: () => mockIncidents.first);
    }
    if (path == '/cases/550e8400-e29b-41d4-a716-446655440001' || path.startsWith('/cases/')) {
      return {
        'id': '550e8400-e29b-41d4-a716-446655440001',
        'ticket_number': 'TICK-101',
        'title': 'Core Payment Gateway 500 Outage',
        'description': 'Root case for major incident',
        'status': 'in_progress',
        'priority': 'p1',
        'version': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'sla_progress': {'resolution_remaining_minutes': 30, 'state': 'active'},
      };
    }
    if (path == '/cases') {
      return {'items': <dynamic>[], 'total': 0};
    }
    return {};
  }

  @override
  Future<dynamic> post(String path, {Map<String, dynamic>? body, String? idempotencyKey}) async {
    if (throwForbidden) {
      throw ApiException(
        statusCode: 403,
        code: 'PERMISSION_DENIED',
        message: 'Operation not permitted for this role.',
      );
    }
    if (path == '/major-incidents') {
      final newInc = <String, dynamic>{
        'id': 'inc-${mockIncidents.length + 1}',
        'incident_number': 'INC-2026-000${mockIncidents.length + 1}',
        'case_id': body?['case_id'] ?? '550e8400-e29b-41d4-a716-446655440099',
        'title': body?['title'] ?? 'Newly Declared Major Incident',
        'status': 'declared',
        'commander_id': 'usr-manager-1',
        'bridge_url': body?['bridge_url'],
        'communications_lead_id': null,
        'executive_summary': null,
        'impact_summary': body?['impact_summary'],
        'declared_at': DateTime.now().toIso8601String(),
        'mitigated_at': null,
        'resolved_at': null,
        'post_mortem_url': null,
        'timeline_events': <Map<String, dynamic>>[],
      };
      mockIncidents.insert(0, newInc);
      return newInc;
    }
    if (path.contains('/timeline')) {
      final incId = path.split('/')[2];
      final inc = mockIncidents.firstWhere((i) => i['id'] == incId);
      final newEvt = <String, dynamic>{
        'id': 'evt-${DateTime.now().millisecondsSinceEpoch}',
        'major_incident_id': incId,
        'author_id': 'usr-manager-1',
        'summary': body?['summary'] ?? '',
        'details': body?['details'],
        'event_timestamp': DateTime.now().toIso8601String(),
      };
      final events = (inc['timeline_events'] as List<dynamic>);
      events.add(newEvt);
      return newEvt;
    }
    return {};
  }

  @override
  Future<dynamic> patch(String path, {Map<String, dynamic>? body}) async {
    if (throwForbidden) {
      throw ApiException(
        statusCode: 403,
        code: 'PERMISSION_DENIED',
        message: 'Operation not permitted for this role.',
      );
    }
    if (path.startsWith('/major-incidents/')) {
      final id = path.replaceFirst('/major-incidents/', '');
      final inc = mockIncidents.firstWhere((i) => i['id'] == id);
      if (body?.containsKey('status') == true) {
        inc['status'] = body!['status'];
        if (body['status'] == 'mitigated') {
          inc['mitigated_at'] = DateTime.now().toIso8601String();
        } else if (body['status'] == 'resolved') {
          inc['resolved_at'] = DateTime.now().toIso8601String();
        }
      }
      if (body?.containsKey('executive_summary') == true) {
        inc['executive_summary'] = body!['executive_summary'];
      }
      if (body?.containsKey('post_mortem_url') == true) {
        inc['post_mortem_url'] = body!['post_mortem_url'];
      }
      if (body?.containsKey('bridge_url') == true) {
        inc['bridge_url'] = body!['bridge_url'];
      }
      return inc;
    }
    return {};
  }
}

Widget createTestApp({
  required MockMajorIncidentApiClient apiClient,
  required UserModel currentUser,
}) {
  final storage = SessionStorage();
  final authProvider = AuthProvider(apiClient: apiClient, storage: storage);
  authProvider.setMockUser(currentUser);

  final majorIncidentProvider = MajorIncidentProvider(apiClient: apiClient);
  final caseProvider = CaseProvider(apiClient: apiClient);
  final aiProvider = AIProvider(apiClient: apiClient);
  final approvalProvider = ApprovalProvider(apiClient: apiClient);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ChangeNotifierProvider<MajorIncidentProvider>.value(value: majorIncidentProvider),
      ChangeNotifierProvider<CaseProvider>.value(value: caseProvider),
      ChangeNotifierProvider<AIProvider>.value(value: aiProvider),
      ChangeNotifierProvider<ApprovalProvider>.value(value: approvalProvider),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: const Scaffold(body: MajorIncidentScreen()),
    ),
  );
}

void main() {
  const managerUser = UserModel(
    id: 'usr-manager-1',
    email: 'commander@finora.internal',
    fullName: 'Incident Commander Sarah',
    role: 'manager',
    site: 'HQ Tech Campus',
  );

  const requesterUser = UserModel(
    id: 'usr-req-1',
    email: 'requester@finora.internal',
    fullName: 'Requester Bob',
    role: 'requester',
    site: 'HQ Tech Campus',
  );

  group('Phase 3C: Major Incident Management & Command Bridge Tests', () {
    testWidgets('1. Displays incident list with numbers, statuses, and titles', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = MockMajorIncidentApiClient();
      await tester.pumpWidget(createTestApp(apiClient: client, currentUser: managerUser));
      await tester.pumpAndSettle();

      expect(find.text('INC-2026-0001'), findsWidgets);
      expect(find.text('Core Payment Gateway 500 Outage'), findsWidgets);
      expect(find.text('ACTIVE'), findsWidgets);
    });

    testWidgets('2. Displays enterprise KPI metrics banner accurately', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = MockMajorIncidentApiClient();
      await tester.pumpWidget(createTestApp(apiClient: client, currentUser: managerUser));
      await tester.pumpAndSettle();

      expect(find.text('Total Incidents'), findsOneWidget);
      expect(find.text('4'), findsOneWidget); // Total count
      expect(find.text('Active War-Rooms'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // 1 active + 1 declared
      expect(find.text('Mitigated Outages'), findsOneWidget);
      expect(find.text('Resolved Incidents'), findsOneWidget);
      expect(find.text('1'), findsNWidgets(2)); // 1 mitigated, 1 resolved
    });

    testWidgets('3. Search filters major incidents correctly by number or title', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = MockMajorIncidentApiClient();
      await tester.pumpWidget(createTestApp(apiClient: client, currentUser: managerUser));
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, 'Kafka');
      await tester.pumpAndSettle();

      expect(find.text('INC-2026-0004'), findsWidgets);
      expect(find.text('INC-2026-0001'), findsNothing);
    });

    testWidgets('4. Status filter dropdown updates list accordingly', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = MockMajorIncidentApiClient();
      await tester.pumpWidget(createTestApp(apiClient: client, currentUser: managerUser));
      await tester.pumpAndSettle();

      final dropdown = find.byType(DropdownButton<String?>).first;
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Resolved').last);
      await tester.pumpAndSettle();

      expect(find.text('INC-2026-0004'), findsWidgets);
      expect(find.text('INC-2026-0001'), findsNothing);
    });

    testWidgets('5. Opens declare major incident dialog with form fields and validation', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = MockMajorIncidentApiClient();
      await tester.pumpWidget(createTestApp(apiClient: client, currentUser: managerUser));
      await tester.pumpAndSettle();

      final declareBtn = find.byKey(const Key('declareMajorIncidentBtn'));
      expect(declareBtn, findsOneWidget);
      await tester.tap(declareBtn);
      await tester.pumpAndSettle();

      expect(find.text('Declare Major Incident (P1)'), findsOneWidget);
      expect(find.byKey(const Key('majorIncidentCaseIdField')), findsOneWidget);
      expect(find.byKey(const Key('majorIncidentTitleField')), findsOneWidget);
      expect(find.byKey(const Key('majorIncidentImpactField')), findsOneWidget);
      expect(find.byKey(const Key('majorIncidentBridgeUrlField')), findsOneWidget);

      // Validate required fields
      final submitBtn = find.byKey(const Key('declareIncidentSubmitBtn'));
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Root Case ID is required'), findsOneWidget);
    });

    testWidgets('6. Submits new major incident declaration successfully', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = MockMajorIncidentApiClient();
      await tester.pumpWidget(createTestApp(apiClient: client, currentUser: managerUser));
      await tester.pumpAndSettle();

      final declareBtn = find.byKey(const Key('declareMajorIncidentBtn'));
      await tester.tap(declareBtn);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('majorIncidentCaseIdField')),
        '550e8400-e29b-41d4-a716-446655440099',
      );
      await tester.enterText(
        find.byKey(const Key('majorIncidentTitleField')),
        'Global DNS Resolution Blackhole',
      );
      await tester.enterText(
        find.byKey(const Key('majorIncidentImpactField')),
        'All customer DNS requests failing on ns1.finora.internal',
      );
      await tester.enterText(
        find.byKey(const Key('majorIncidentBridgeUrlField')),
        'https://meet.google.com/fin-dns-outage',
      );

      final submitBtn = find.byKey(const Key('declareIncidentSubmitBtn'));
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Global DNS Resolution Blackhole'), findsWidgets);
    });

    testWidgets('7. Renders command bridge header with outage timer and declared timestamp', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = MockMajorIncidentApiClient();
      await tester.pumpWidget(createTestApp(apiClient: client, currentUser: managerUser));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('commandBridgeDetailPane')), findsOneWidget);
      expect(find.text('Core Payment Gateway 500 Outage'), findsWidgets);
      expect(find.textContaining('Declared at:'), findsOneWidget);
      expect(find.textContaining('Outage:'), findsWidgets);
    });

    testWidgets('8. Renders operational impact summary and war-room bridge link', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = MockMajorIncidentApiClient();
      await tester.pumpWidget(createTestApp(apiClient: client, currentUser: managerUser));
      await tester.pumpAndSettle();

      expect(find.text('Impact & War-Room Bridge'), findsOneWidget);
      expect(find.textContaining('100% of checkout payments failing'), findsWidgets);
      expect(find.textContaining('https://meet.google.com/fin-war-room-1'), findsOneWidget);
    });

    testWidgets('9. Renders linked root case card with navigation button to CaseDetailScreen', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = MockMajorIncidentApiClient();
      await tester.pumpWidget(createTestApp(apiClient: client, currentUser: managerUser));
      await tester.pumpAndSettle();

      expect(find.text('Linked Root Case'), findsOneWidget);
      expect(find.text('550e8400-e29b-41d4-a716-446655440001'), findsOneWidget);

      final inspectBtn = find.byKey(const Key('viewRootCaseBtn'));
      expect(inspectBtn, findsOneWidget);
      await tester.tap(inspectBtn);
      await tester.pumpAndSettle();

      expect(find.byType(CaseDetailScreen), findsOneWidget);
    });

    testWidgets('10. Renders live war-room timeline event stream', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = MockMajorIncidentApiClient();
      await tester.pumpWidget(createTestApp(apiClient: client, currentUser: managerUser));
      await tester.pumpAndSettle();

      expect(find.textContaining('War-Room Live Timeline (2)'), findsOneWidget);
      expect(find.text('Major incident declared by Incident Commander'), findsOneWidget);
      expect(find.text('Isolated traffic to healthy payment provider replica'), findsOneWidget);
      expect(find.text('Traffic rerouted via Cloudflare DNS failover pool.'), findsOneWidget);
    });

    testWidgets('11. Allows adding and logging a new war-room timeline event', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = MockMajorIncidentApiClient();
      await tester.pumpWidget(createTestApp(apiClient: client, currentUser: managerUser));
      await tester.pumpAndSettle();

      final logEvtBtn = find.byKey(const Key('logTimelineEventBtn'));
      expect(logEvtBtn, findsOneWidget);
      await tester.tap(logEvtBtn);
      await tester.pumpAndSettle();

      expect(find.text('Log War-Room Event: INC-2026-0001'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('timelineEventSummaryField')),
        'Database failover completed to replica B',
      );
      await tester.enterText(
        find.byKey(const Key('timelineEventDetailsField')),
        'Latency normalized to 14ms on read endpoints.',
      );

      final submitEvt = find.byKey(const Key('submitTimelineEventBtn'));
      await tester.tap(submitEvt);
      await tester.pumpAndSettle();

      expect(find.text('Database failover completed to replica B'), findsOneWidget);
      expect(find.text('Latency normalized to 14ms on read endpoints.'), findsOneWidget);
    });

    testWidgets('12. Commander can transition status from declared to active war-room', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = MockMajorIncidentApiClient();
      await tester.pumpWidget(createTestApp(apiClient: client, currentUser: managerUser));
      await tester.pumpAndSettle();

      // Select INC-002 which is in 'declared' status
      final inc2Card = find.byKey(const Key('incidentCard_INC-2026-0002'));
      await tester.tap(inc2Card);
      await tester.pumpAndSettle();

      final activateBtn = find.byKey(const Key('activateWarRoomBtn'));
      expect(activateBtn, findsOneWidget);
      await tester.tap(activateBtn);
      await tester.pumpAndSettle();

      expect(find.text('ACTIVE'), findsWidgets);
    });

    testWidgets('13. Commander can transition status from active to mitigated', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = MockMajorIncidentApiClient();
      await tester.pumpWidget(createTestApp(apiClient: client, currentUser: managerUser));
      await tester.pumpAndSettle();

      final mitigateBtn = find.byKey(const Key('mitigateOutageBtn'));
      expect(mitigateBtn, findsOneWidget);
      await tester.tap(mitigateBtn);
      await tester.pumpAndSettle();

      expect(find.text('MITIGATED'), findsWidgets);
    });

    testWidgets('14. Commander can resolve outage with executive summary and post-mortem url', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = MockMajorIncidentApiClient();
      await tester.pumpWidget(createTestApp(apiClient: client, currentUser: managerUser));
      await tester.pumpAndSettle();

      final resolveBtn = find.byKey(const Key('resolveOutageBtn'));
      expect(resolveBtn, findsOneWidget);
      await tester.tap(resolveBtn);
      await tester.pumpAndSettle();

      expect(find.text('Resolve Outage: INC-2026-0001'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('resolveExecutiveSummaryField')),
        'Provider upstream BGP leak fixed; transactions 100% processing normally.',
      );
      await tester.enterText(
        find.byKey(const Key('resolvePostMortemUrlField')),
        'https://wiki.finora.internal/postmortem/inc-2026-0001',
      );

      final confirmResolve = find.byKey(const Key('confirmResolveOutageBtn'));
      await tester.tap(confirmResolve);
      await tester.pumpAndSettle();

      expect(find.text('RESOLVED'), findsWidgets);
    });

    testWidgets('15. Displays responsive master-detail layout on wide screen (>= 900px)', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = MockMajorIncidentApiClient();
      await tester.pumpWidget(createTestApp(apiClient: client, currentUser: managerUser));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('commandBridgeDetailPane')), findsOneWidget);
      expect(find.byKey(const Key('incidentCard_INC-2026-0001')), findsOneWidget);
    });

    testWidgets('16. Displays responsive stacked card layout on mobile viewport (< 900px)', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = MockMajorIncidentApiClient();
      await tester.pumpWidget(createTestApp(apiClient: client, currentUser: managerUser));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('commandBridgeDetailPane')), findsNothing);
      expect(find.byKey(const Key('mobileIncidentCard_INC-2026-0001')), findsOneWidget);
    });

    testWidgets('17. Handles 403 forbidden and 500 error gracefully with error banner', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = MockMajorIncidentApiClient()..throwForbidden = true;
      await tester.pumpWidget(createTestApp(apiClient: client, currentUser: requesterUser));
      await tester.pumpAndSettle();

      expect(find.text('Requesters cannot access Major Incident Command Bridge.'), findsOneWidget);
    });
  });
}
