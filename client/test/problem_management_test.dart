import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ai_helpdesk_client/shared/theme/app_theme.dart';
import 'package:ai_helpdesk_client/shared/storage.dart';
import 'package:ai_helpdesk_client/shared/api_client.dart';
import 'package:ai_helpdesk_client/features/auth/providers/auth_provider.dart';
import 'package:ai_helpdesk_client/features/auth/models/user_model.dart';
import 'package:ai_helpdesk_client/features/problems/providers/problem_provider.dart';
import 'package:ai_helpdesk_client/features/problems/screens/problem_workspace_screen.dart';
import 'package:ai_helpdesk_client/features/knowledge/providers/knowledge_provider.dart';

class MockProblemApiClient extends ApiClient {
  bool throwForbidden = false;
  bool returnEmpty = false;

  final List<Map<String, dynamic>> mockProblems = [
    {
      'id': 'prb-001',
      'problem_number': 'PRB-2026-0001',
      'title': 'Database Connection Timeout on Checkout',
      'description': 'High concurrent checkout spikes cause connection pool saturation.',
      'root_cause': 'Connection leak in billing worker service when payment gateway times out.',
      'workaround': 'Restart billing worker service and scale connection pool to 200.',
      'status': 'investigating',
      'priority': 'p1',
      'owner_id': 'usr-operator-1',
      'created_at': DateTime.now().subtract(const Duration(hours: 4)).toIso8601String(),
      'updated_at': DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String(),
      'resolved_at': null,
      'case_links': <Map<String, dynamic>>[
        {
          'id': 'link-1',
          'problem_id': 'prb-001',
          'case_id': 'case-101',
          'linked_by': 'usr-operator-1',
          'linked_at': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
        },
      ],
      'known_errors': <Map<String, dynamic>>[
        {
          'id': 'ke-001',
          'problem_id': 'prb-001',
          'title': 'KEDB: Checkout Gateway Timeout',
          'symptoms': 'Users receive 504 gateway timeout on /checkout/pay',
          'workaround': 'Clear billing worker queue and recycle connection pool',
          'permanent_fix': 'Deploy hotfix v2.4.1 with connection pool release on error',
          'published': true,
          'created_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        },
      ],
    },
    {
      'id': 'prb-002',
      'problem_number': 'PRB-2026-0002',
      'title': 'Memory Leak in Node Service',
      'description': 'Periodic out of memory kills on background worker containers.',
      'root_cause': null,
      'workaround': null,
      'status': 'open',
      'priority': 'p2',
      'owner_id': null,
      'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      'updated_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      'resolved_at': null,
      'case_links': <Map<String, dynamic>>[],
      'known_errors': <Map<String, dynamic>>[],
    },
  ];

  MockProblemApiClient() : super(baseUrl: 'http://localhost:8000');

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) async {
    if (throwForbidden) {
      throw ApiException(
        statusCode: 403,
        code: 'PERMISSION_DENIED',
        message: 'Requesters cannot access problem records.',
      );
    }
    if (path == '/problems') {
      if (returnEmpty) return [];
      var results = List<Map<String, dynamic>>.from(mockProblems);
      if (queryParameters?['status'] != null) {
        results = results.where((p) => p['status'] == queryParameters!['status']).toList();
      }
      if (queryParameters?['priority'] != null) {
        results = results.where((p) => p['priority'] == queryParameters!['priority']).toList();
      }
      return results;
    }
    if (path.startsWith('/problems/')) {
      final id = path.replaceFirst('/problems/', '');
      final p = mockProblems.firstWhere((p) => p['id'] == id, orElse: () => mockProblems.first);
      return p;
    }
    if (path == '/knowledge') {
      return {
        'items': [
          {
            'id': 'kb-1',
            'title': 'Database Connection Recovery Guide',
            'body': 'Steps to recycle connection pool and check for orphaned transactions.',
            'owner_id': 'usr-1',
            'state': 'published',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          }
        ],
        'total': 1,
      };
    }
    return {};
  }

  @override
  Future<dynamic> post(String path, {Map<String, dynamic>? body, String? idempotencyKey}) async {
    if (throwForbidden) {
      throw ApiException(
        statusCode: 403,
        code: 'PERMISSION_DENIED',
        message: 'Requesters cannot perform problem operations.',
      );
    }
    if (path == '/problems') {
      final newPrb = {
        'id': 'prb-${mockProblems.length + 1}',
        'problem_number': 'PRB-2026-000${mockProblems.length + 1}',
        'title': body?['title'],
        'description': body?['description'],
        'priority': body?['priority'],
        'root_cause': body?['root_cause'],
        'workaround': body?['workaround'],
        'status': 'open',
        'owner_id': 'usr-operator-1',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'resolved_at': null,
        'case_links': [],
        'known_errors': [],
      };
      mockProblems.insert(0, newPrb);
      return newPrb;
    }
    if (path.contains('/link-case')) {
      final prbId = path.split('/')[2];
      final prb = mockProblems.firstWhere((p) => p['id'] == prbId);
      final newLink = {
        'id': 'link-${(prb['case_links'] as List).length + 1}',
        'problem_id': prbId,
        'case_id': body?['case_id'],
        'linked_by': 'usr-operator-1',
        'linked_at': DateTime.now().toIso8601String(),
      };
      (prb['case_links'] as List).add(newLink);
      return newLink;
    }
    if (path.contains('/known-error')) {
      final prbId = path.split('/')[2];
      final prb = mockProblems.firstWhere((p) => p['id'] == prbId);
      final newKe = {
        'id': 'ke-${(prb['known_errors'] as List).length + 1}',
        'problem_id': prbId,
        'title': body?['title'],
        'symptoms': body?['symptoms'],
        'workaround': body?['workaround'],
        'permanent_fix': body?['permanent_fix'],
        'published': body?['published'] ?? true,
        'created_at': DateTime.now().toIso8601String(),
      };
      (prb['known_errors'] as List).add(newKe);
      prb['status'] = 'known_error';
      return newKe;
    }
    return {};
  }

  @override
  Future<dynamic> patch(String path, {dynamic body}) async {
    if (path.startsWith('/problems/')) {
      final prbId = path.replaceFirst('/problems/', '');
      final prb = mockProblems.firstWhere((p) => p['id'] == prbId);
      if (body['status'] != null) prb['status'] = body['status'];
      if (body['root_cause'] != null) prb['root_cause'] = body['root_cause'];
      if (body['workaround'] != null) prb['workaround'] = body['workaround'];
      if (body['title'] != null) prb['title'] = body['title'];
      if (body['description'] != null) prb['description'] = body['description'];
      if (body['priority'] != null) prb['priority'] = body['priority'];
      return prb;
    }
    return {};
  }

  @override
  Future<dynamic> delete(String path) async {
    if (path.contains('/unlink-case/')) {
      final parts = path.split('/');
      final prbId = parts[2];
      final caseId = parts[4];
      final prb = mockProblems.firstWhere((p) => p['id'] == prbId);
      (prb['case_links'] as List).removeWhere((l) => l['case_id'] == caseId);
      return null;
    }
    return null;
  }
}

Widget createTestApp({
  required MockProblemApiClient apiClient,
  required UserModel currentUser,
  Widget? child,
}) {
  final storage = SessionStorage();
  final authProvider = AuthProvider(apiClient: apiClient, storage: storage);
  authProvider.setMockUser(currentUser);

  final problemProvider = ProblemProvider(apiClient: apiClient);
  final knowledgeProvider = KnowledgeProvider(apiClient: apiClient);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ChangeNotifierProvider<ProblemProvider>.value(value: problemProvider),
      ChangeNotifierProvider<KnowledgeProvider>.value(value: knowledgeProvider),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child ?? const ProblemWorkspaceScreen()),
    ),
  );
}

void main() {
  const operatorUser = UserModel(
    id: 'usr-operator-1',
    email: 'operator@finora.internal',
    fullName: 'Jane Operator',
    role: 'operator',
    site: 'HQ Tech Campus',
  );

  group('Phase 3A: Problem Management & KEDB Tests', () {
    testWidgets('1. Problem list renders metric cards and problem items', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockProblemApiClient();
      await tester.pumpWidget(createTestApp(apiClient: mockClient, currentUser: operatorUser));
      await tester.pumpAndSettle();

      // Verify Metrics
      expect(find.text('Total Problems'), findsOneWidget);
      expect(find.text('Active Investigations'), findsOneWidget);
      expect(find.text('Critical (P1/P2)'), findsOneWidget);
      expect(find.text('KEDB Articles'), findsOneWidget);

      // Verify Problem List Items
      expect(find.text('PRB-2026-0001'), findsWidgets);
      expect(find.text('PRB-2026-0002'), findsWidgets);
      expect(find.text('Database Connection Timeout on Checkout'), findsWidgets);
    });

    testWidgets('2. Problem search filters problems dynamically', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockProblemApiClient();
      await tester.pumpWidget(createTestApp(apiClient: mockClient, currentUser: operatorUser));
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, 'Checkout');
      await tester.pumpAndSettle();

      expect(find.text('Database Connection Timeout on Checkout'), findsWidgets);
      expect(find.text('Memory Leak in Node Service'), findsNothing);
    });

    testWidgets('3. Problem creation dialog submits and adds new record', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockProblemApiClient();
      await tester.pumpWidget(createTestApp(apiClient: mockClient, currentUser: operatorUser));
      await tester.pumpAndSettle();

      // Open creation dialog
      await tester.tap(find.text('New Problem'));
      await tester.pumpAndSettle();

      expect(find.text('Create ITIL Problem Record'), findsOneWidget);

      // Fill in fields
      await tester.enterText(find.widgetWithText(TextFormField, 'Problem Title *'), 'Redis Cache Key Eviction Spike');
      await tester.enterText(find.widgetWithText(TextFormField, 'Detailed Problem Description *'), 'Sudden spikes in key eviction leading to downstream DB query storms.');
      await tester.enterText(find.widgetWithText(TextFormField, 'Known Root Cause (Optional)'), 'TTL expiration set too short on user session keys.');
      await tester.enterText(find.widgetWithText(TextFormField, 'Workaround (Optional)'), 'Increase maxmemory-policy and adjust TTL.');

      // Submit by clicking the action button "Create Problem" inside dialog actions
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Problem'));
      await tester.pumpAndSettle();

      // Verify problem was created
      expect(find.text('Redis Cache Key Eviction Spike'), findsWidgets);
    });

    testWidgets('4. Problem workspace detail displays root cause, workaround, and timestamps', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockProblemApiClient();
      await tester.pumpWidget(createTestApp(apiClient: mockClient, currentUser: operatorUser));
      await tester.pumpAndSettle();

      // Detail pane inspection
      expect(find.text('Investigation & Root Cause Analysis'), findsOneWidget);
      expect(find.text('Connection leak in billing worker service when payment gateway times out.'), findsOneWidget);
      expect(find.text('Restart billing worker service and scale connection pool to 200.'), findsOneWidget);
      expect(find.text('Linked Incidents (1)'), findsOneWidget);
      expect(find.text('Case ID: case-101'), findsOneWidget);
    });

    testWidgets('5. Status lifecycle transition updates problem status', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockProblemApiClient();
      await tester.pumpWidget(createTestApp(apiClient: mockClient, currentUser: operatorUser));
      await tester.pumpAndSettle();

      // Find and click "Resolve Problem"
      expect(find.text('Resolve Problem'), findsOneWidget);
      await tester.tap(find.text('Resolve Problem'));
      await tester.pumpAndSettle();

      expect(mockClient.mockProblems.first['status'], 'resolved');
    });

    testWidgets('6. Problem ↔ Case linking adds linked incident', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockProblemApiClient();
      await tester.pumpWidget(createTestApp(apiClient: mockClient, currentUser: operatorUser));
      await tester.pumpAndSettle();

      // Scroll to Link Incident Case button
      await tester.scrollUntilVisible(find.text('Link Incident Case'), 100, scrollable: find.byType(Scrollable).last);
      await tester.tap(find.text('Link Incident Case'));
      await tester.pumpAndSettle();

      expect(find.text('Link Incident Case (PRB-2026-0001)'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'case-505');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm Link'));
      await tester.pumpAndSettle();

      expect(mockClient.mockProblems.first['case_links'].any((l) => (l as Map)['case_id'] == 'case-505'), isTrue);
    });

    testWidgets('7. Problem ↔ Case unlinking removes linked incident with confirmation', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockProblemApiClient();
      await tester.pumpWidget(createTestApp(apiClient: mockClient, currentUser: operatorUser));
      await tester.pumpAndSettle();

      expect(find.text('Case ID: case-101'), findsOneWidget);

      // Scroll to unlink icon and tap
      await tester.scrollUntilVisible(find.byIcon(Icons.link_off_rounded), 100, scrollable: find.byType(Scrollable).last);
      await tester.tap(find.byIcon(Icons.link_off_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Unlink Incident Case'), findsOneWidget);
      await tester.tap(find.text('Unlink'));
      await tester.pumpAndSettle();

      expect(find.text('Case ID: case-101'), findsNothing);
    });

    testWidgets('8. Known Error publishing dialog publishes to KEDB', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockProblemApiClient();
      await tester.pumpWidget(createTestApp(apiClient: mockClient, currentUser: operatorUser));
      await tester.pumpAndSettle();

      // Click "Publish KEDB" in the top header card
      await tester.tap(find.widgetWithText(ElevatedButton, 'Publish KEDB').first);
      await tester.pumpAndSettle();

      expect(find.text('Publish Known Error Article (PRB-2026-0001)'), findsOneWidget);
      // In the dialog, tap the ElevatedButton "Confirm KEDB Publication"
      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm KEDB Publication'));
      await tester.pumpAndSettle();

      expect(mockClient.mockProblems.first['known_errors'].length, 2);
    });

    testWidgets('9. Related knowledge articles display correctly', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockProblemApiClient();
      await tester.pumpWidget(createTestApp(apiClient: mockClient, currentUser: operatorUser));
      await tester.pumpAndSettle();

      expect(find.text('Related Knowledge Base Articles'), findsOneWidget);
      expect(find.text('Database Connection Recovery Guide'), findsOneWidget);
    });

    testWidgets('10. RBAC / 403 Forbidden error banner displays gracefully', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockProblemApiClient()..throwForbidden = true;
      await tester.pumpWidget(createTestApp(apiClient: mockClient, currentUser: operatorUser));
      await tester.pumpAndSettle();

      expect(find.text('Requesters cannot access problem records.'), findsOneWidget);
    });

    testWidgets('11. Empty state displays friendly prompt when no problems exist', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockProblemApiClient()..returnEmpty = true;
      await tester.pumpWidget(createTestApp(apiClient: mockClient, currentUser: operatorUser));
      await tester.pumpAndSettle();

      expect(find.text('No Problem Records Found'), findsOneWidget);
      expect(find.text('Create First Problem'), findsOneWidget);
    });

    testWidgets('12. Mobile layout renders stacked list and opens detail screen on tap', (tester) async {
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockProblemApiClient();
      await tester.pumpWidget(createTestApp(
        apiClient: mockClient,
        currentUser: operatorUser,
      ));
      await tester.pumpAndSettle();

      expect(find.text('PRB-2026-0001'), findsOneWidget);
      await tester.tap(find.text('PRB-2026-0001'));
      await tester.pumpAndSettle();

      expect(find.text('Investigation & Root Cause Analysis'), findsOneWidget);
    });
  });
}
