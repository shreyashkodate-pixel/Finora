import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ai_helpdesk_client/app/dashboard_shell.dart';
import 'package:ai_helpdesk_client/features/auth/models/user_model.dart';
import 'package:ai_helpdesk_client/features/auth/providers/auth_provider.dart';
import 'package:ai_helpdesk_client/features/ai/providers/ai_provider.dart';
import 'package:ai_helpdesk_client/features/alerts/providers/alert_provider.dart';
import 'package:ai_helpdesk_client/features/analytics/providers/predictive_analytics_provider.dart';
import 'package:ai_helpdesk_client/features/approvals/providers/approval_provider.dart';
import 'package:ai_helpdesk_client/features/autofix/providers/autofix_provider.dart';
import 'package:ai_helpdesk_client/features/cases/providers/case_provider.dart';
import 'package:ai_helpdesk_client/features/changes/providers/change_provider.dart';
import 'package:ai_helpdesk_client/features/knowledge/providers/knowledge_provider.dart';
import 'package:ai_helpdesk_client/features/major_incidents/providers/major_incident_provider.dart';
import 'package:ai_helpdesk_client/features/notifications/models/device_token_model.dart';
import 'package:ai_helpdesk_client/features/notifications/models/notification_model.dart';
import 'package:ai_helpdesk_client/features/notifications/providers/notification_provider.dart';
import 'package:ai_helpdesk_client/features/notifications/screens/notification_preferences_screen.dart';
import 'package:ai_helpdesk_client/features/problems/providers/problem_provider.dart';
import 'package:ai_helpdesk_client/features/search/providers/search_provider.dart';
import 'package:ai_helpdesk_client/shared/api_client.dart';
import 'package:ai_helpdesk_client/shared/storage.dart';
import 'package:ai_helpdesk_client/shared/widgets/notification_center_dialog.dart';

class MockNotificationApiClient extends ApiClient {
  MockNotificationApiClient() : super(baseUrl: 'http://localhost:8000');

  bool throwError = false;
  bool returnEmpty = false;
  int unreadCountResponse = 3;

  final List<Map<String, dynamic>> mockNotificationItems = [
    {
      'id': 'notif-1',
      'user_id': 'usr-1',
      'case_id': 'case-101',
      'title': 'SLA Breach Warning',
      'message': 'Ticket #case-101 is at risk of breaching SLA in 15 minutes.',
      'event_type': 'sla_breach_warning',
      'is_read': false,
      'created_at': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
    },
    {
      'id': 'notif-2',
      'user_id': 'usr-1',
      'case_id': 'case-102',
      'title': 'Emergency CAB Approval Required',
      'message': 'CR-2026-004 requires your immediate CAB approval review.',
      'event_type': 'approval_required',
      'is_read': false,
      'created_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
    },
    {
      'id': 'notif-3',
      'user_id': 'usr-1',
      'case_id': null,
      'title': 'Alert Correlated',
      'message': 'High CPU anomaly correlated with existing network issue.',
      'event_type': 'alert_correlated',
      'is_read': true,
      'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
    },
  ];

  final List<Map<String, dynamic>> mockDeviceItems = [
    {
      'id': 'dev-1',
      'user_id': 'usr-1',
      'token': 'fcm-token-pixel8-998877',
      'platform': 'android',
      'device_name': 'Pixel 8 Pro',
      'is_active': true,
      'created_at': '2026-09-01T10:00:00Z',
      'last_seen_at': '2026-09-21T08:30:00Z',
    },
    {
      'id': 'dev-2',
      'user_id': 'usr-1',
      'token': 'web-push-chrome-112233',
      'platform': 'web',
      'device_name': 'Work Chrome Browser',
      'is_active': true,
      'created_at': '2026-09-05T12:00:00Z',
      'last_seen_at': '2026-09-21T09:00:00Z',
    },
  ];

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) async {
    if (throwError) {
      throw ApiException(
        statusCode: 500,
        code: 'NETWORK_ERROR',
        message: 'Simulated network connection failure',
      );
    }

    if (path == '/notifications/unread-count') {
      return {'unread_count': unreadCountResponse};
    }

    if (path == '/notifications') {
      if (returnEmpty) {
        return {
          'items': <Map<String, dynamic>>[],
          'total': 0,
          'page': 1,
          'per_page': 20,
          'unread_count': 0,
        };
      }
      final unreadOnly = queryParameters?['unread_only'] == 'true';
      final filtered = unreadOnly
          ? mockNotificationItems.where((n) => n['is_read'] == false).toList()
          : mockNotificationItems;

      return {
        'items': filtered,
        'total': filtered.length,
        'page': 1,
        'per_page': 20,
        'unread_count': mockNotificationItems.where((n) => n['is_read'] == false).length,
      };
    }

    if (path == '/notifications/devices') {
      if (returnEmpty) return <Map<String, dynamic>>[];
      return mockDeviceItems;
    }

    return super.get(path, queryParameters: queryParameters);
  }

  @override
  Future<dynamic> patch(String path, {dynamic body}) async {
    if (throwError) {
      throw ApiException(
        statusCode: 500,
        code: 'UPDATE_ERROR',
        message: 'Failed to update read state',
      );
    }

    if (path.startsWith('/notifications/') && path.endsWith('/read')) {
      final notifId = path.split('/')[2];
      final item = mockNotificationItems.firstWhere(
        (n) => n['id'] == notifId,
        orElse: () => {
          'id': notifId,
          'user_id': 'usr-1',
          'case_id': 'case-101',
          'title': 'Read notification',
          'message': 'Message',
          'event_type': 'case_created',
          'is_read': true,
          'created_at': DateTime.now().toIso8601String(),
        },
      );
      item['is_read'] = true;
      return item;
    }
    return super.patch(path, body: body);
  }

  @override
  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    String? idempotencyKey,
  }) async {
    if (throwError) {
      throw ApiException(
        statusCode: 500,
        code: 'INTERNAL_ERROR',
        message: 'Action failed',
      );
    }

    if (endpoint == '/notifications/mark-all-read') {
      for (final n in mockNotificationItems) {
        n['is_read'] = true;
      }
      unreadCountResponse = 0;
      return {'message': 'Marked 2 notifications as read.'};
    }

    if (endpoint == '/notifications/devices/register') {
      final mapBody = body ?? {};
      final newDev = {
        'id': 'dev-new',
        'user_id': 'usr-1',
        'token': mapBody['token'],
        'platform': mapBody['platform'] ?? 'android',
        'device_name': mapBody['device_name'],
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
        'last_seen_at': DateTime.now().toIso8601String(),
      };
      mockDeviceItems.add(newDev);
      return newDev;
    }

    if (endpoint == '/notifications/push/test') {
      return {
        'status': 'dispatched',
        'targeted_devices': 2,
        'successful_dispatches': 2,
        'failed_dispatches': 0,
      };
    }

    return super.post(endpoint, body: body, idempotencyKey: idempotencyKey);
  }

  @override
  Future<dynamic> delete(String path) async {
    if (throwError) {
      throw ApiException(
        statusCode: 500,
        code: 'DELETE_ERROR',
        message: 'Delete device token failed',
      );
    }

    if (path.startsWith('/notifications/devices/')) {
      final token = path.split('/').last;
      mockDeviceItems.removeWhere((d) => d['token'] == token);
      return {'message': 'Device token revoked successfully.'};
    }
    return super.delete(path);
  }
}

void main() {
  group('NotificationModel & DeviceTokenModel Unit Tests', () {
    test('NotificationModel parses JSON contract correctly', () {
      final json = {
        'id': 'notif-99',
        'user_id': 'usr-200',
        'case_id': 'case-300',
        'title': 'P1 Incident Created',
        'message': 'Core payment gateway outage reported.',
        'event_type': 'major_incident_declared',
        'is_read': false,
        'created_at': '2026-09-21T12:00:00Z',
      };

      final model = NotificationModel.fromJson(json);
      expect(model.id, 'notif-99');
      expect(model.userId, 'usr-200');
      expect(model.caseId, 'case-300');
      expect(model.title, 'P1 Incident Created');
      expect(model.message, 'Core payment gateway outage reported.');
      expect(model.eventType, 'major_incident_declared');
      expect(model.isRead, isFalse);
      expect(model.createdAt, DateTime.parse('2026-09-21T12:00:00Z'));

      final copy = model.copyWith(isRead: true);
      expect(copy.isRead, isTrue);
      expect(copy.id, model.id);

      final out = model.toJson();
      expect(out['id'], 'notif-99');
      expect(out['case_id'], 'case-300');
      expect(out['event_type'], 'major_incident_declared');
    });

    test('DeviceTokenModel parses JSON contract correctly', () {
      final json = {
        'id': 'dev-88',
        'user_id': 'usr-200',
        'token': 'fcm-token-12345',
        'platform': 'iOS',
        'device_name': 'Work iPhone 15',
        'is_active': true,
        'created_at': '2026-09-20T10:00:00Z',
        'last_seen_at': '2026-09-21T11:00:00Z',
      };

      final model = DeviceTokenModel.fromJson(json);
      expect(model.id, 'dev-88');
      expect(model.userId, 'usr-200');
      expect(model.token, 'fcm-token-12345');
      expect(model.platform, 'ios');
      expect(model.deviceName, 'Work iPhone 15');
      expect(model.isActive, isTrue);

      final out = model.toJson();
      expect(out['token'], 'fcm-token-12345');
      expect(out['platform'], 'ios');
    });
  });

  group('NotificationProvider Unit Tests', () {
    late MockNotificationApiClient apiClient;
    late NotificationProvider provider;

    setUp(() {
      apiClient = MockNotificationApiClient();
      provider = NotificationProvider(apiClient: apiClient);
    });

    test('loadNotifications and loadUnreadCount fetch and parse backend responses', () async {
      await provider.loadNotifications();
      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, isNull);
      expect(provider.notifications.length, 3);
      expect(provider.unreadCount, 2);
      expect(provider.totalCount, 3);

      await provider.loadUnreadCount();
      expect(provider.unreadCount, 3);
    });

    test('markAsRead updates notification state and decrements unread count', () async {
      await provider.loadNotifications();
      expect(provider.notifications[0].isRead, isFalse);
      expect(provider.unreadCount, 2);

      final success = await provider.markAsRead('notif-1');
      expect(success, isTrue);
      expect(provider.notifications[0].isRead, isTrue);
      expect(provider.unreadCount, 1);
    });

    test('markAllAsRead marks all notifications read and zeroes unread count', () async {
      await provider.loadNotifications();
      expect(provider.unreadCount, 2);

      final success = await provider.markAllAsRead();
      expect(success, isTrue);
      expect(provider.unreadCount, 0);
      expect(provider.notifications.every((n) => n.isRead), isTrue);
    });

    test('loadDevices, registerDevice, and unregisterDevice operate correctly', () async {
      await provider.loadDevices();
      expect(provider.devices.length, 2);

      final regSuccess = await provider.registerDevice(
        token: 'new-desktop-token-44',
        platform: 'macos',
        deviceName: 'MacBook Pro 16',
      );
      expect(regSuccess, isTrue);
      expect(provider.devices.any((d) => d.token == 'new-desktop-token-44'), isTrue);

      final unregSuccess = await provider.unregisterDevice('new-desktop-token-44');
      expect(unregSuccess, isTrue);
      expect(provider.devices.any((d) => d.token == 'new-desktop-token-44'), isFalse);
    });

    test('sendPushTest calls push test endpoint and returns dispatch details', () async {
      final res = await provider.sendPushTest(title: 'Test Push', body: 'Test Body');
      expect(res, isNotNull);
      expect(res!['status'], 'dispatched');
      expect(res['successful_dispatches'], 2);
    });

    test('clearState cleans up all state for user/tenant isolation on logout', () async {
      await provider.loadNotifications();
      await provider.loadDevices();
      expect(provider.notifications.isNotEmpty, isTrue);
      expect(provider.devices.isNotEmpty, isTrue);

      provider.clearState();
      expect(provider.notifications, isEmpty);
      expect(provider.unreadCount, 0);
      expect(provider.totalCount, 0);
      expect(provider.devices, isEmpty);
      expect(provider.errorMessage, isNull);
      expect(provider.deviceErrorMessage, isNull);
    });

    test('handles API errors gracefully without throwing', () async {
      apiClient.throwError = true;
      await provider.loadNotifications();
      expect(provider.errorMessage, contains('Simulated network connection failure'));
      expect(provider.isLoading, isFalse);

      await provider.loadDevices();
      expect(provider.deviceErrorMessage, contains('Simulated network connection failure'));
    });
  });

  group('In-App Notification Center & Badge Widget Tests', () {
    late MockNotificationApiClient apiClient;
    late NotificationProvider notificationProvider;
    late AuthProvider authProvider;
    late SessionStorage storage;

    setUp(() {
      apiClient = MockNotificationApiClient();
      notificationProvider = NotificationProvider(apiClient: apiClient);
      storage = SessionStorage();
      authProvider = AuthProvider(apiClient: apiClient, storage: storage);
      authProvider.setMockUser(
        const UserModel(
          id: 'usr-1',
          email: 'operator@tenant-a.com',
          role: 'operator',
          fullName: 'Test Operator',
        ),
      );
    });

    testWidgets('NotificationCenterDialog renders notifications and unread badge', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<NotificationProvider>.value(value: notificationProvider),
          ],
          child: const MaterialApp(
            themeMode: ThemeMode.light,
            home: Scaffold(
              body: NotificationCenterDialog(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Unread (2)'), findsOneWidget);
      expect(find.text('SLA Breach Warning'), findsOneWidget);
      expect(find.text('Emergency CAB Approval Required'), findsOneWidget);
      expect(find.text('Alert Correlated'), findsOneWidget);
    });

    testWidgets('Filter chip toggles between All and Unread notifications', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<NotificationProvider>.value(value: notificationProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: NotificationCenterDialog(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Unread filter
      await tester.tap(find.text('Unread (2)'));
      await tester.pumpAndSettle();

      expect(find.text('SLA Breach Warning'), findsOneWidget);
      expect(find.text('Emergency CAB Approval Required'), findsOneWidget);
      expect(find.text('Alert Correlated'), findsNothing);
    });

    testWidgets('Mark all read button updates UI and zeroes unread badge', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<NotificationProvider>.value(value: notificationProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: NotificationCenterDialog(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final markAllBtn = find.byTooltip('Mark all read');
      expect(markAllBtn, findsOneWidget);

      await tester.tap(markAllBtn);
      await tester.pumpAndSettle();

      expect(find.text('2'), findsNothing);
      expect(notificationProvider.unreadCount, 0);
    });

    testWidgets('NotificationCenterDialog renders professional empty state when empty', (tester) async {
      apiClient.returnEmpty = true;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<NotificationProvider>.value(value: notificationProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: NotificationCenterDialog(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('No notifications yet'), findsOneWidget);
    });

    testWidgets('DashboardShell displays notification bell with badge and opens dialog', (tester) async {
      await notificationProvider.loadNotifications();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<NotificationProvider>.value(value: notificationProvider),
            ChangeNotifierProvider<CaseProvider>(create: (_) => CaseProvider(apiClient: apiClient)),
            ChangeNotifierProvider<AIProvider>(create: (_) => AIProvider(apiClient: apiClient)),
            ChangeNotifierProvider<ApprovalProvider>(create: (_) => ApprovalProvider(apiClient: apiClient)),
            ChangeNotifierProvider<KnowledgeProvider>(create: (_) => KnowledgeProvider(apiClient: apiClient)),
            ChangeNotifierProvider<ProblemProvider>(create: (_) => ProblemProvider(apiClient: apiClient)),
            ChangeNotifierProvider<ChangeProvider>(create: (_) => ChangeProvider(apiClient: apiClient)),
            ChangeNotifierProvider<MajorIncidentProvider>(create: (_) => MajorIncidentProvider(apiClient: apiClient)),
            ChangeNotifierProvider<AutoFixProvider>(create: (_) => AutoFixProvider(apiClient: apiClient)),
            ChangeNotifierProvider<SearchProvider>(create: (_) => SearchProvider(apiClient: apiClient)),
            ChangeNotifierProvider<AlertProvider>(create: (_) => AlertProvider(apiClient: apiClient)),
            ChangeNotifierProvider<PredictiveAnalyticsProvider>(create: (_) => PredictiveAnalyticsProvider(apiClient: apiClient)),
          ],
          child: const MaterialApp(
            home: DashboardShell(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find notification button with badge
      final notifBtn = find.byIcon(Icons.notifications_outlined);
      expect(notifBtn, findsOneWidget);

      // Tap bell to open dialog
      await tester.tap(notifBtn);
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsWidgets);
    });
  });

  group('NotificationPreferencesScreen Widget Tests', () {
    late MockNotificationApiClient apiClient;
    late NotificationProvider notificationProvider;
    late AuthProvider authProvider;
    late SessionStorage storage;

    setUp(() {
      apiClient = MockNotificationApiClient();
      notificationProvider = NotificationProvider(apiClient: apiClient);
      storage = SessionStorage();
      authProvider = AuthProvider(apiClient: apiClient, storage: storage);
      authProvider.setMockUser(
        const UserModel(
          id: 'usr-1',
          email: 'operator@tenant-a.com',
          role: 'operator',
          fullName: 'Test Operator',
        ),
      );
    });

    testWidgets('NotificationPreferencesScreen renders devices and delivery channels', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<NotificationProvider>.value(value: notificationProvider),
          ],
          child: const MaterialApp(
            home: NotificationPreferencesScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Notification & Push Device Settings'), findsOneWidget);
      expect(find.text('Registered Push Devices'), findsOneWidget);
      expect(find.text('Pixel 8 Pro'), findsOneWidget);
      expect(find.text('Work Chrome Browser'), findsOneWidget);
      expect(find.text('Delivery Channels & Notification Policy'), findsOneWidget);
      expect(find.text('In-App Notification Center'), findsOneWidget);
      expect(find.text('Mobile & Web Push (FCM / APNs)'), findsOneWidget);
      expect(find.text('Enterprise Email Alerts'), findsOneWidget);
    });

    testWidgets('Test push button triggers dispatch feedback', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<NotificationProvider>.value(value: notificationProvider),
          ],
          child: const MaterialApp(
            home: NotificationPreferencesScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final testBtn = find.text('Test Push');
      expect(testBtn, findsOneWidget);

      await tester.tap(testBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Push notification request sent.'), findsOneWidget);
    });

    testWidgets('Revoke device button shows confirmation and removes device', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<NotificationProvider>.value(value: notificationProvider),
          ],
          child: const MaterialApp(
            home: NotificationPreferencesScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final revokeBtns = find.byIcon(Icons.delete_outline_rounded);
      expect(revokeBtns, findsNWidgets(2));

      await tester.tap(revokeBtns.first);
      await tester.pumpAndSettle();

      expect(find.text('Revoke Device Token?'), findsOneWidget);
      await tester.tap(find.text('Revoke'));
      await tester.pumpAndSettle();

      expect(find.text('Device token revoked successfully.'), findsOneWidget);
      expect(notificationProvider.devices.length, 1);
    });
  });
}
