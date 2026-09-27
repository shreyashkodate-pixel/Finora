import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ai_helpdesk_client/shared/theme/app_theme.dart';
import 'package:ai_helpdesk_client/shared/storage.dart';
import 'package:ai_helpdesk_client/shared/api_client.dart';
import 'package:ai_helpdesk_client/features/auth/providers/auth_provider.dart';
import 'package:ai_helpdesk_client/features/auth/models/user_model.dart';
import 'package:ai_helpdesk_client/features/changes/providers/change_provider.dart';
import 'package:ai_helpdesk_client/features/changes/screens/change_management_screen.dart';
import 'package:ai_helpdesk_client/features/approvals/providers/approval_provider.dart';
import 'package:ai_helpdesk_client/features/approvals/screens/pending_approvals_screen.dart';
import 'package:ai_helpdesk_client/features/cases/providers/case_provider.dart';

class MockChangeApiClient extends ApiClient {
  bool throwForbidden = false;
  bool throwError = false;
  bool returnEmpty = false;

  final List<Map<String, dynamic>> mockChanges = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'chg-001',
      'change_number': 'CR-2026-0001',
      'title': 'Upgrade Core Switch Firmware',
      'description': 'Apply vendor patch v14.2 to resolve BGP flapping in datacenter east.',
      'reason': 'Mitigate recurring datacenter routing brownouts.',
      'change_type': 'normal',
      'risk_level': 'high',
      'status': 'pending_cab',
      'requester_id': 'usr-lead-1',
      'assigned_to': 'usr-operator-1',
      'implementation_plan': '1. Backup running config\n2. Upgrade secondary sup engine\n3. Failover and upgrade primary',
      'test_plan': 'Run ping sweep and verify BGP peering state across all peers',
      'rollback_plan': 'Reboot switches using secondary flash image v14.1.',
      'cab_approved': null,
      'cab_feedback': null,
      'cab_reviewed_at': null,
      'scheduled_start': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
      'scheduled_end': DateTime.now().add(const Duration(days: 2, hours: 4)).toIso8601String(),
      'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      'updated_at': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
    },
    <String, dynamic>{
      'id': 'chg-002',
      'change_number': 'CR-2026-0002',
      'title': 'Emergency Security Patch for OpenSSL',
      'description': 'Hotfix critical CVE vulnerability across all web edge nodes.',
      'reason': 'Immediate patch required for zero-day disclosure.',
      'change_type': 'emergency',
      'risk_level': 'critical',
      'status': 'approved',
      'requester_id': 'usr-operator-1',
      'assigned_to': 'usr-operator-1',
      'implementation_plan': 'Apply package update openssl-3.0.2 via Ansible across all edge nodes',
      'test_plan': 'Verify SSL handshake and TLS 1.3 negotiation with cURL',
      'rollback_plan': 'Restore VM snapshot web-edge-2026-09-20.',
      'cab_approved': true,
      'cab_feedback': 'Fast-tracked emergency approval granted by SecOps Lead.',
      'cab_reviewed_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
      'scheduled_start': DateTime.now().add(const Duration(hours: 2)).toIso8601String(),
      'scheduled_end': DateTime.now().add(const Duration(hours: 3)).toIso8601String(),
      'created_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
      'updated_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
    },
    <String, dynamic>{
      'id': 'chg-003',
      'change_number': 'CR-2026-0003',
      'title': 'Standard Weekly OS Kernel Patching',
      'description': 'Routine standard patch cycle for non-production development cluster.',
      'reason': 'Regular maintenance cycle.',
      'change_type': 'standard',
      'risk_level': 'low',
      'status': 'scheduled',
      'requester_id': 'usr-operator-1',
      'assigned_to': 'usr-operator-1',
      'implementation_plan': 'yum update -y kernel && reboot node01',
      'test_plan': 'Check uptime and k8s node Ready status',
      'rollback_plan': 'Reboot previous kernel version via GRUB default.',
      'cab_approved': null,
      'cab_feedback': null,
      'cab_reviewed_at': null,
      'scheduled_start': DateTime.now().add(const Duration(days: 3)).toIso8601String(),
      'scheduled_end': DateTime.now().add(const Duration(days: 3, hours: 2)).toIso8601String(),
      'created_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      'updated_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
    },
  ];

  final List<Map<String, dynamic>> mockApprovals = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'appr-001',
      'case_id': 'case-101',
      'approver_id': 'usr-lead-1',
      'decision': 'pending',
      'reason': 'Hardware replacement authorization for executive workstation.',
      'created_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
    },
  ];

  MockChangeApiClient() : super(baseUrl: 'http://localhost:8000');

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) async {
    if (throwError) {
      throw ApiException(
        statusCode: 500,
        code: 'INTERNAL_ERROR',
        message: 'Failed to load change requests.',
      );
    }
    if (throwForbidden) {
      throw ApiException(
        statusCode: 403,
        code: 'PERMISSION_DENIED',
        message: 'Requesters cannot access change records.',
      );
    }
    if (path == '/changes') {
      if (returnEmpty) return [];
      var results = List<Map<String, dynamic>>.from(mockChanges);
      if (queryParameters?['status'] != null) {
        results = results.where((c) => c['status'] == queryParameters!['status']).toList();
      }
      return results;
    }
    if (path.startsWith('/changes/')) {
      final id = path.replaceFirst('/changes/', '');
      return mockChanges.firstWhere((c) => c['id'] == id, orElse: () => mockChanges.first);
    }
    if (path == '/approvals/pending') {
      return {
        'items': mockApprovals,
        'total': mockApprovals.length,
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
    if (path == '/changes') {
      final newChg = <String, dynamic>{
        'id': 'chg-${mockChanges.length + 1}',
        'change_number': 'CR-2026-000${mockChanges.length + 1}',
        'title': body?['title'] ?? 'New Change',
        'description': body?['description'] ?? '',
        'reason': body?['reason'] ?? '',
        'change_type': body?['change_type'] ?? 'normal',
        'risk_level': body?['risk_level'] ?? 'medium',
        'status': 'draft',
        'requester_id': 'usr-operator-1',
        'assigned_to': null,
        'implementation_plan': body?['implementation_plan'] ?? '',
        'test_plan': body?['test_plan'] ?? '',
        'rollback_plan': body?['rollback_plan'] ?? '',
        'cab_approved': null,
        'cab_feedback': null,
        'cab_reviewed_at': null,
        'scheduled_start': body?['scheduled_start'],
        'scheduled_end': body?['scheduled_end'],
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      mockChanges.insert(0, newChg);
      return newChg;
    }
    if (path.contains('/cab-decision')) {
      final chgId = path.split('/')[2];
      final chg = mockChanges.firstWhere((c) => c['id'] == chgId);
      chg['cab_approved'] = body?['approved'] ?? true;
      chg['cab_feedback'] = body?['feedback'] ?? '';
      chg['cab_reviewed_at'] = DateTime.now().toIso8601String();
      chg['status'] = (body?['approved'] == true) ? 'approved' : 'rejected';
      return chg;
    }
    if (path.contains('/decision')) {
      final apprId = path.split('/')[2];
      final appr = mockApprovals.firstWhere((a) => a['id'] == apprId);
      appr['decision'] = body?['decision'] ?? 'approved';
      return appr;
    }
    return {};
  }

  @override
  Future<dynamic> patch(String path, {dynamic body}) async {
    if (path.contains('/status')) {
      final uri = Uri.parse(path);
      final chgId = uri.pathSegments[1];
      final newStatus = uri.queryParameters['new_status'] ?? body?['status'];
      final chg = mockChanges.firstWhere((c) => c['id'] == chgId);
      if (newStatus != null) chg['status'] = newStatus;
      return chg;
    }
    return {};
  }
}

Widget createTestApp({
  required MockChangeApiClient apiClient,
  required UserModel currentUser,
  Widget? child,
}) {
  final storage = SessionStorage();
  final authProvider = AuthProvider(apiClient: apiClient, storage: storage);
  authProvider.setMockUser(currentUser);

  final changeProvider = ChangeProvider(apiClient: apiClient);
  final approvalProvider = ApprovalProvider(apiClient: apiClient);
  final caseProvider = CaseProvider(apiClient: apiClient);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ChangeNotifierProvider<ChangeProvider>.value(value: changeProvider),
      ChangeNotifierProvider<ApprovalProvider>.value(value: approvalProvider),
      ChangeNotifierProvider<CaseProvider>.value(value: caseProvider),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child ?? const ChangeManagementScreen()),
    ),
  );
}

void main() {
  const teamLeadUser = UserModel(
    id: 'usr-lead-1',
    email: 'lead@finora.internal',
    fullName: 'Alex Lead',
    role: 'team_lead',
    site: 'HQ Tech Campus',
  );

  const operatorUser = UserModel(
    id: 'usr-operator-1',
    email: 'operator@finora.internal',
    fullName: 'Jane Operator',
    role: 'operator',
    site: 'HQ Tech Campus',
  );

  const requesterUser = UserModel(
    id: 'usr-requester-1',
    email: 'requester@finora.internal',
    fullName: 'John Requester',
    role: 'requester',
    site: 'HQ Tech Campus',
  );

  group('Phase 3B: Change Management + CAB + Approvals Tests', () {
    testWidgets('1. Change list renders KPI metric cards and change items', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockChangeApiClient();
      await tester.pumpWidget(createTestApp(apiClient: mockClient, currentUser: teamLeadUser));
      await tester.pumpAndSettle();

      // Verify KPI Metrics
      expect(find.text('Total Changes'), findsOneWidget);
      expect(find.text('Pending CAB'), findsOneWidget);
      expect(find.text('Approved / Scheduled'), findsOneWidget);
      expect(find.text('Implementing'), findsOneWidget);

      // Verify List items
      expect(find.text('CR-2026-0001'), findsWidgets);
      expect(find.text('Upgrade Core Switch Firmware'), findsWidgets);
      expect(find.text('CR-2026-0002'), findsWidgets);
      expect(find.text('Emergency Security Patch for OpenSSL'), findsWidgets);
    });

    testWidgets('2. Search filters changes dynamically', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockChangeApiClient();
      await tester.pumpWidget(createTestApp(apiClient: mockClient, currentUser: teamLeadUser));
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, 'OpenSSL');
      await tester.pumpAndSettle();

      expect(find.text('Emergency Security Patch for OpenSSL'), findsWidgets);
      expect(find.text('Upgrade Core Switch Firmware'), findsNothing);
    });

    testWidgets('3. Status dropdown filters changes by status', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockChangeApiClient();
      await tester.pumpWidget(createTestApp(apiClient: mockClient, currentUser: teamLeadUser));
      await tester.pumpAndSettle();

      // Select "Approved" in the status dropdown
      final dropdown = find.byType(DropdownButton<String?>).first;
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      final approvedItem = find.text('Approved').last;
      await tester.tap(approvedItem);
      await tester.pumpAndSettle();

      expect(find.text('Emergency Security Patch for OpenSSL'), findsWidgets);
    });

    testWidgets('4. Creating a Change Request opens modal and submits RFC payload', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockChangeApiClient();
      await tester.pumpWidget(createTestApp(apiClient: mockClient, currentUser: teamLeadUser));
      await tester.pumpAndSettle();

      // Click "Submit RFC" button on toolbar
      final submitRfcBtn = find.text('Submit RFC');
      expect(submitRfcBtn, findsOneWidget);
      await tester.tap(submitRfcBtn);
      await tester.pumpAndSettle();

      expect(find.text('Request for Change (RFC)'), findsOneWidget);

      // Fill in Title, Reason, Description, Implementation, Test, Rollback
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'Migrate Auth Service to Kubernetes');
      await tester.enterText(textFields.at(1), 'High availability and auto-scaling support.');
      await tester.enterText(textFields.at(2), 'Zero-downtime deployment of Auth microservice cluster.');
      await tester.enterText(textFields.at(3), 'Deploy deployment.yaml and switch service endpoints.');
      await tester.enterText(textFields.at(4), 'Run auth smoke suite and verify JWT generation.');
      await tester.enterText(textFields.at(5), 'Switch DNS pointer back to standalone legacy VM.');

      // Submit RFC in dialog
      final submitBtn = find.text('Submit RFC').last;
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Verify created RFC appears in list
      expect(find.text('Migrate Auth Service to Kubernetes'), findsWidgets);
    });

    testWidgets('5. Change detail pane displays risk, impact, change type, and plans', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockChangeApiClient();
      await tester.pumpWidget(createTestApp(apiClient: mockClient, currentUser: teamLeadUser));
      await tester.pumpAndSettle();

      // Detail pane on right shows first change details
      expect(find.text('Upgrade Core Switch Firmware'), findsWidgets);
      expect(find.text('Mitigate recurring datacenter routing brownouts.'), findsWidgets);
      expect(find.text('Reboot switches using secondary flash image v14.1.'), findsWidgets);
      expect(find.text('Step-by-Step Implementation Plan'), findsOneWidget);
    });

    testWidgets('6. Detail pane displays CAB review status and feedback', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockChangeApiClient();
      await tester.pumpWidget(createTestApp(apiClient: mockClient, currentUser: teamLeadUser));
      await tester.pumpAndSettle();

      // Select second change (CR-2026-0002) which is CAB approved
      final item2 = find.text('CR-2026-0002');
      await tester.tap(item2);
      await tester.pumpAndSettle();

      expect(find.text('Fast-tracked emergency approval granted by SecOps Lead.'), findsOneWidget);
    });

    testWidgets('7. Team Lead sees CAB Review button and can record approval decision', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockChangeApiClient();
      await tester.pumpWidget(createTestApp(apiClient: mockClient, currentUser: teamLeadUser));
      await tester.pumpAndSettle();

      // First change is pending_cab
      final cabReviewBtn = find.text('CAB Review');
      expect(cabReviewBtn, findsOneWidget);

      await tester.tap(cabReviewBtn);
      await tester.pumpAndSettle();

      expect(find.text('CAB Review: CR-2026-0001'), findsOneWidget);

      // Enter feedback
      final feedbackInput = find.byKey(const Key('cabFeedbackInput'));
      await tester.enterText(feedbackInput, 'Approved for scheduled maintenance window after risk review.');

      // Tap "Approve RFC"
      final approveBtn = find.byKey(const Key('cabApproveConfirmBtn'));
      await tester.tap(approveBtn);
      await tester.pumpAndSettle();

      expect(mockClient.mockChanges[0]['status'], 'approved');
      expect(mockClient.mockChanges[0]['cab_approved'], true);
    });

    testWidgets('8. Operator sees view-only CAB information without approval action buttons', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockChangeApiClient();
      await tester.pumpWidget(createTestApp(apiClient: mockClient, currentUser: operatorUser));
      await tester.pumpAndSettle();

      // Operator should NOT see "CAB Review" button
      expect(find.text('CAB Review'), findsNothing);
    });

    testWidgets('9. Lifecycle transitions: Start Implementation updates change status', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockChangeApiClient();
      await tester.pumpWidget(createTestApp(apiClient: mockClient, currentUser: operatorUser));
      await tester.pumpAndSettle();

      // Select CR-2026-0002 (approved)
      final item2 = find.text('CR-2026-0002');
      await tester.tap(item2);
      await tester.pumpAndSettle();

      final startImplBtn = find.text('Start Implementation');
      expect(startImplBtn, findsOneWidget);

      await tester.tap(startImplBtn);
      await tester.pumpAndSettle();

      expect(find.text('Are you ready to transition Change CR-2026-0002 into IMPLEMENTING state?'), findsOneWidget);

      final confirmBtn = find.widgetWithText(ElevatedButton, 'Confirm');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(mockClient.mockChanges[1]['status'], 'implementing');
    });

    testWidgets('10. Rollback transition updates change status to rollback', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockChangeApiClient();
      // Set second change to implementing
      mockClient.mockChanges[1]['status'] = 'implementing';

      await tester.pumpWidget(createTestApp(apiClient: mockClient, currentUser: operatorUser));
      await tester.pumpAndSettle();

      // Select CR-2026-0002 (implementing)
      final item2 = find.text('CR-2026-0002');
      await tester.tap(item2);
      await tester.pumpAndSettle();

      final rollbackBtn = find.text('Trigger Rollback');
      expect(rollbackBtn, findsOneWidget);

      await tester.tap(rollbackBtn);
      await tester.pumpAndSettle();

      expect(find.text('Trigger Rollback Plan'), findsOneWidget);

      final confirmBtn = find.widgetWithText(ElevatedButton, 'Confirm');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(mockClient.mockChanges[1]['status'], 'rollback');
    });

    testWidgets('11. Responsive layout: Master-Detail view on desktop viewport', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockChangeApiClient();
      await tester.pumpWidget(createTestApp(apiClient: mockClient, currentUser: teamLeadUser));
      await tester.pumpAndSettle();

      // Both list and detail pane are visible on desktop
      expect(find.text('Total Changes'), findsOneWidget);
      expect(find.text('CR-2026-0001'), findsWidgets);
      expect(find.text('Step-by-Step Implementation Plan'), findsOneWidget);
    });

    testWidgets('12. Responsive layout: Single pane navigation on mobile viewport', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockChangeApiClient();
      await tester.pumpWidget(createTestApp(apiClient: mockClient, currentUser: teamLeadUser));
      await tester.pumpAndSettle();

      // List visible
      expect(find.text('CR-2026-0001'), findsOneWidget);

      // Tap to navigate to Mobile Detail Screen
      await tester.tap(find.text('CR-2026-0001'));
      await tester.pumpAndSettle();

      // Mobile Detail Screen shows Change Details
      expect(find.text('Step-by-Step Implementation Plan'), findsOneWidget);
      expect(find.text('Mitigate recurring datacenter routing brownouts.'), findsOneWidget);
    });

    testWidgets('13. Pending Approvals inbox fetches and renders pending authorization requests', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockChangeApiClient();
      await tester.pumpWidget(
        createTestApp(
          apiClient: mockClient,
          currentUser: teamLeadUser,
          child: const PendingApprovalsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pending Approvals'), findsOneWidget);
      expect(find.text('Authorization Request'), findsOneWidget);
      expect(find.textContaining('Hardware replacement authorization'), findsOneWidget);
    });

    testWidgets('14. Pending Approvals inbox executes Approve decision', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockChangeApiClient();
      await tester.pumpWidget(
        createTestApp(
          apiClient: mockClient,
          currentUser: teamLeadUser,
          child: const PendingApprovalsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final approveBtn = find.text('Approve');
      expect(approveBtn, findsOneWidget);

      await tester.tap(approveBtn);
      await tester.pumpAndSettle();

      expect(find.text('Approve Authorization'), findsOneWidget);

      final confirmApproveBtn = find.text('Confirm Approval');
      await tester.tap(confirmApproveBtn);
      await tester.pumpAndSettle();

      expect(mockClient.mockApprovals[0]['decision'], 'approved');
      expect(find.text('All caught up!'), findsOneWidget);
    });

    testWidgets('15. Pending Approvals inbox executes Reject decision', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockChangeApiClient();
      await tester.pumpWidget(
        createTestApp(
          apiClient: mockClient,
          currentUser: teamLeadUser,
          child: const PendingApprovalsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final rejectBtn = find.text('Reject');
      expect(rejectBtn, findsOneWidget);

      await tester.tap(rejectBtn);
      await tester.pumpAndSettle();

      expect(find.text('Reject Authorization'), findsOneWidget);

      final confirmRejectBtn = find.text('Confirm Rejection');
      await tester.tap(confirmRejectBtn);
      await tester.pumpAndSettle();

      expect(mockClient.mockApprovals[0]['decision'], 'rejected');
      expect(find.text('All caught up!'), findsOneWidget);
    });

    testWidgets('16. Error handling: Network / API failure gracefully renders error banner/empty state', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockChangeApiClient()..throwError = true;
      await tester.pumpWidget(createTestApp(apiClient: mockClient, currentUser: teamLeadUser));
      await tester.pumpAndSettle();

      expect(find.text('Failed to load change requests.'), findsOneWidget);
    });

    testWidgets('17. Invariant check: Requester cannot trigger CAB review or unauthorized change mutations', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockChangeApiClient();
      await tester.pumpWidget(createTestApp(apiClient: mockClient, currentUser: requesterUser));
      await tester.pumpAndSettle();

      // Requester should have no CAB Review, Submit RFC, or Implementation actions
      expect(find.text('CAB Review'), findsNothing);
      expect(find.text('Submit RFC'), findsNothing);
      expect(find.text('Start Implementation'), findsNothing);
    });
  });
}
