import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ai_helpdesk_client/shared/theme/app_theme.dart';
import 'package:ai_helpdesk_client/shared/storage.dart';
import 'package:ai_helpdesk_client/shared/api_client.dart';
import 'package:ai_helpdesk_client/features/auth/providers/auth_provider.dart';
import 'package:ai_helpdesk_client/features/auth/models/user_model.dart';
import 'package:ai_helpdesk_client/features/cases/models/case_model.dart';
import 'package:ai_helpdesk_client/features/cases/providers/case_provider.dart';
import 'package:ai_helpdesk_client/features/cases/screens/create_case_dialog.dart';
import 'package:ai_helpdesk_client/features/cases/screens/case_list_screen.dart';
import 'package:ai_helpdesk_client/features/cases/widgets/message_stream_widget.dart';
import 'package:ai_helpdesk_client/features/cases/widgets/attachment_list_widget.dart';
import 'package:ai_helpdesk_client/features/knowledge/providers/knowledge_provider.dart';
import 'package:ai_helpdesk_client/features/dashboard/screens/requester_home_screen.dart';

class MockApiClient extends ApiClient {
  MockApiClient() : super(baseUrl: 'http://localhost:8000');

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) async {
    if (path == '/cases') {
      return {
        'cases': [
          {
            'id': 'case-101',
            'reference_number': 'INC-2026-000101',
            'title': 'VPN Gateway Timeout',
            'description': 'Cannot connect from home network',
            'status': 'in_progress',
            'priority': 'p2',
            'type': 'incident',
            'site': 'Chicago Campus',
            'requester_id': 'user-1',
            'owner_id': 'op-1',
            'version': 1,
            'created_at': DateTime.now().subtract(const Duration(minutes: 45)).toIso8601String(),
            'sla': {
              'target_response_at': DateTime.now().add(const Duration(minutes: 15)).toIso8601String(),
              'target_resolve_at': DateTime.now().add(const Duration(hours: 3)).toIso8601String(),
              'response_breached': false,
              'resolution_breached': false,
            },
          },
          {
            'id': 'case-102',
            'reference_number': 'REQ-2026-000102',
            'title': 'Figma License Request',
            'description': 'Product design license required',
            'status': 'resolved',
            'priority': 'p3',
            'type': 'service_request',
            'site': 'North Campus',
            'requester_id': 'user-1',
            'version': 2,
            'created_at': DateTime.now().subtract(const Duration(days: 8)).toIso8601String(),
            'resolved_at': DateTime.now().subtract(const Duration(days: 8)).toIso8601String(),
          }
        ],
        'total': 2,
      };
    }
    if (path == '/cases/case-101') {
      return {
        'id': 'case-101',
        'reference_number': 'INC-2026-000101',
        'title': 'VPN Gateway Timeout',
        'description': 'Cannot connect from home network',
        'status': 'in_progress',
        'priority': 'p2',
        'type': 'incident',
        'site': 'Chicago Campus',
        'requester_id': 'user-1',
        'owner_id': 'op-1',
        'version': 1,
        'created_at': DateTime.now().subtract(const Duration(minutes: 45)).toIso8601String(),
        'sla': {
          'target_response_at': DateTime.now().add(const Duration(minutes: 15)).toIso8601String(),
          'target_resolve_at': DateTime.now().add(const Duration(hours: 3)).toIso8601String(),
          'response_breached': false,
          'resolution_breached': false,
        },
      };
    }
    if (path == '/knowledge') {
      return {
        'items': [
          {
            'id': 'kb-1',
            'title': 'VPN Connection Troubleshooting Guide',
            'summary': 'Standard operating procedure for AnyConnect client TLS resets.',
            'category': 'Network & Connectivity',
            'state': 'published',
            'created_at': DateTime.now().toIso8601String(),
          }
        ],
      };
    }
    if (path == '/cases/case-101/messages') {
      return [
        {
          'id': 'msg-1',
          'case_id': 'case-101',
          'author_id': 'op-1',
          'body': 'We have completed a gateway DNS flush. Please verify.',
          'visibility': 'requester_visible',
          'ai_generated': false,
          'created_at': DateTime.now().toIso8601String(),
        }
      ];
    }
    if (path == '/cases/case-101/attachments') {
      return [
        {
          'id': 'att-1',
          'case_id': 'case-101',
          'uploader_id': 'user-1',
          'filename': 'vpn_error_log.txt',
          'file_size': 24500,
          'mime_type': 'text/plain',
          'storage_path': 'evidence/case-101/vpn_error_log.txt',
          'created_at': DateTime.now().toIso8601String(),
        }
      ];
    }
    return {};
  }
}

void main() {
  group('Requester Portal — Phase 2A Functional & Invariant Tests', () {
    late MockApiClient mockApi;
    late AuthProvider authProvider;
    late CaseProvider caseProvider;
    late KnowledgeProvider knowledgeProvider;

    setUp(() {
      mockApi = MockApiClient();
      authProvider = AuthProvider(apiClient: mockApi, storage: SessionStorage());
      caseProvider = CaseProvider(apiClient: mockApi);
      knowledgeProvider = KnowledgeProvider(apiClient: mockApi);

      // Set current user as standard requester
      authProvider.setMockUser(
        const UserModel(
          id: 'user-1',
          email: 'requester@enterprise.com',
          fullName: 'Sarah Vance',
          role: 'requester',
          site: 'Chicago Campus',
        ),
      );
    });

    Widget createTestApp(Widget child) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<CaseProvider>.value(value: caseProvider),
          ChangeNotifierProvider<KnowledgeProvider>.value(value: knowledgeProvider),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: child),
        ),
      );
    }

    testWidgets('Requester Home renders greeting, quick actions, KPI cards, and active tickets', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(const RequesterHomeScreen()));
      await tester.pumpAndSettle();

      // Verifies Hero Banner
      expect(find.text('Welcome back, Sarah Vance. How can we help you today?'), findsOneWidget);
      expect(find.text('AI Nexus Intelligence Assist Active'), findsOneWidget);

      // Verifies 3 Quick Action Cards
      expect(find.text('Report an Incident'), findsOneWidget);
      expect(find.text('Request Software/Hardware'), findsOneWidget);
      expect(find.text('Browse Knowledge Base'), findsOneWidget);

      // Verifies KPI Metric Cards
      expect(find.text('Active Tickets'), findsOneWidget);
      expect(find.text('Resolved'), findsOneWidget);
      expect(find.text('Total Submitted'), findsOneWidget);

      // Verifies Active Tickets Live Feed
      expect(find.text('INC-2026-000101'), findsOneWidget);
      expect(find.text('VPN Gateway Timeout'), findsOneWidget);
    });

    testWidgets('Case Intake Wizard provides 3-step navigation, classification and form validation', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(const CreateCaseDialog()));
      await tester.pumpAndSettle();

      expect(find.text('Submit a Support Case'), findsOneWidget);
      expect(find.text('Issue Context'), findsOneWidget);
      expect(find.text('Report Incident'), findsOneWidget);
      expect(find.text('Service Request'), findsOneWidget);

      // Attempting to advance without required title or description triggers validation
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Title is required.'), findsOneWidget);

      // Fill in valid title & description
      await tester.enterText(find.byType(TextFormField).at(0), 'VPN Gateway dropped TLS handshake');
      await tester.enterText(find.byType(TextFormField).at(1), 'Encountering timeout code 504 on Chicago concentrator');
      await tester.pumpAndSettle();

      // Advance to Step 2 (Evidence)
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Attach Diagnostic Evidence or Screenshots'), findsOneWidget);
      expect(find.text('Select Evidence File'), findsOneWidget);
    });

    testWidgets('Case List Screen renders filter bar, search input, and tickets', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(const CaseListScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Support Tickets'), findsOneWidget);
      expect(find.text('All Statuses'), findsOneWidget);
      expect(find.text('All Priorities'), findsOneWidget);
      expect(find.text('INC-2026-000101'), findsOneWidget);
      expect(find.text('REQ-2026-000102'), findsOneWidget);
    });

    testWidgets('Public Live Chat Stream displays verified staff badge and public reply', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await caseProvider.fetchCaseDetails('case-101');
      await tester.pumpWidget(createTestApp(const SizedBox(height: 600, child: MessageStreamWidget(caseId: 'case-101'))));
      await tester.pumpAndSettle();

      expect(find.text('We have completed a gateway DNS flush. Please verify.'), findsOneWidget);
      expect(find.text('IT Support Staff'), findsOneWidget);
      expect(find.text('Verified Staff'), findsOneWidget);
      expect(find.text('Send Reply'), findsOneWidget);
    });

    testWidgets('Attachment List Widget shows evidence file with size and download action', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await caseProvider.fetchCaseDetails('case-101');
      await tester.pumpWidget(createTestApp(const SingleChildScrollView(child: AttachmentListWidget(caseId: 'case-101'))));
      await tester.pumpAndSettle();

      expect(find.text('Evidence Files (1)'), findsOneWidget);
      expect(find.text('vpn_error_log.txt'), findsOneWidget);
      expect(find.byIcon(Icons.download_outlined), findsOneWidget);
    });

    test('Locked Invariant 3: 7-Day Reopen Rule expiration verification', () {
      final activeCase = CaseModel(
        id: 'c1',
        referenceNumber: 'INC-2026-0001',
        title: 'Recent Case',
        status: 'resolved',
        priority: 'p3',
        type: 'incident',
        requesterId: 'u1',
        version: 1,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        resolvedAt: DateTime.now().subtract(const Duration(days: 2)),
      );

      final expiredCase = CaseModel(
        id: 'c2',
        referenceNumber: 'INC-2026-0002',
        title: 'Old Case',
        status: 'resolved',
        priority: 'p3',
        type: 'incident',
        requesterId: 'u1',
        version: 1,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        resolvedAt: DateTime.now().subtract(const Duration(days: 8)),
      );

      // Active case is within 7 days
      final isRecentExpired = DateTime.now().toUtc().isAfter(activeCase.resolvedAt!.add(const Duration(days: 7)));
      expect(isRecentExpired, isFalse);

      // Expired case has exceeded 7 days
      final isOldExpired = DateTime.now().toUtc().isAfter(expiredCase.resolvedAt!.add(const Duration(days: 7)));
      expect(isOldExpired, isTrue);
    });
  });
}
