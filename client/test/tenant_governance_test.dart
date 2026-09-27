import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ai_helpdesk_client/features/auth/models/user_model.dart';
import 'package:ai_helpdesk_client/features/auth/providers/auth_provider.dart';
import 'package:ai_helpdesk_client/features/admin/screens/tenant_governance_screen.dart';
import 'package:ai_helpdesk_client/shared/api_client.dart';
import 'package:ai_helpdesk_client/shared/storage.dart';

void main() {
  group('UserModel Tenant Context Tests', () {
    test('UserModel correctly parses organizationId, organizationName, organizationSlug', () {
      final json = {
        'id': 'usr-101',
        'email': 'admin@enterprise.com',
        'full_name': 'Admin User',
        'role': 'administrator',
        'organization_id': 'org-uuid-1234',
        'organization_name': 'Enterprise Corp',
        'organization_slug': 'enterprise-corp',
        'availability_status': 'available',
        'email_verified': true,
      };

      final user = UserModel.fromJson(json);
      expect(user.id, 'usr-101');
      expect(user.email, 'admin@enterprise.com');
      expect(user.organizationId, 'org-uuid-1234');
      expect(user.organizationName, 'Enterprise Corp');
      expect(user.organizationSlug, 'enterprise-corp');
      expect(user.isAdmin, isTrue);
      expect(user.isStaff, isTrue);

      final outJson = user.toJson();
      expect(outJson['organization_id'], 'org-uuid-1234');
      expect(outJson['organization_name'], 'Enterprise Corp');
      expect(outJson['organization_slug'], 'enterprise-corp');
    });
  });

  group('AuthProvider Logout State Reset Tests', () {
    test('AuthProvider triggers registered logout callbacks on logout', () async {
      final storage = SessionStorage();
      final apiClient = ApiClient(baseUrl: 'http://localhost');
      final authProvider = AuthProvider(apiClient: apiClient, storage: storage);

      authProvider.setMockUser(
        const UserModel(
          id: 'usr-1',
          email: 'op@tenant-a.com',
          role: 'operator',
          organizationId: 'org-a',
        ),
      );

      bool caseCacheCleared = false;
      bool alertCacheCleared = false;

      authProvider.registerLogoutCallback(() {
        caseCacheCleared = true;
      });
      authProvider.registerLogoutCallback(() {
        alertCacheCleared = true;
      });

      expect(authProvider.currentUser, isNotNull);
      expect(caseCacheCleared, isFalse);
      expect(alertCacheCleared, isFalse);

      await authProvider.logout();

      expect(authProvider.currentUser, isNull);
      expect(caseCacheCleared, isTrue);
      expect(alertCacheCleared, isTrue);
    });
  });

  group('Tenant Governance RBAC & Screen Tests', () {
    testWidgets('Non-admin user sees Access Restricted view', (tester) async {
      final storage = SessionStorage();
      final apiClient = ApiClient(baseUrl: 'http://localhost');
      final authProvider = AuthProvider(apiClient: apiClient, storage: storage);

      authProvider.setMockUser(
        const UserModel(
          id: 'usr-requester',
          email: 'requester@tenant-a.com',
          role: 'requester',
        ),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            Provider<ApiClient>.value(value: apiClient),
          ],
          child: const MaterialApp(
            home: TenantGovernanceScreen(),
          ),
        ),
      );

      expect(find.text('Access Restricted'), findsOneWidget);
      expect(find.textContaining('restricted to Organization Administrators'), findsOneWidget);
    });
  });
}
