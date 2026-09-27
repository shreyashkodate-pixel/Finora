import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_helpdesk_client/shared/api_client.dart';
import 'package:ai_helpdesk_client/shared/responsive/breakpoints.dart';
import 'package:ai_helpdesk_client/shared/theme/colors.dart';
import 'package:ai_helpdesk_client/shared/theme/dimensions.dart';
import 'package:ai_helpdesk_client/shared/widgets/global_states.dart';
import 'package:ai_helpdesk_client/shared/widgets/priority_badge.dart';
import 'package:ai_helpdesk_client/shared/widgets/role_badge.dart';

void main() {
  group('Design System Tokens & Dimensions', () {
    test('verifies authoritative enterprise color tokens', () {
      expect(AppColors.primaryBlue, const Color(0xFF1E40AF));
      expect(AppColors.primaryDark, const Color(0xFF00288E));
      expect(AppColors.backgroundLight, const Color(0xFFF8FAFC));
      expect(AppColors.surfaceLight, const Color(0xFFFFFFFF));
      expect(AppColors.borderLight, const Color(0xFFE2E8F0));
      expect(AppColors.priorityP1, const Color(0xFFDC2626));
      expect(AppColors.priorityP2, const Color(0xFFEA580C));
      expect(AppColors.priorityP3, const Color(0xFF2563EB));
      expect(AppColors.priorityP4, const Color(0xFF64748B));
      expect(AppColors.statusResolved, const Color(0xFF16A34A));
      expect(AppColors.statusWarning, const Color(0xFFD97706));
      expect(AppColors.aiAccent, const Color(0xFF6366F1));
    });

    test('verifies 8px baseline spacing and radius constants', () {
      expect(AppDimensions.spaceSm, 8.0);
      expect(AppDimensions.spaceMd, 16.0);
      expect(AppDimensions.spaceLg, 24.0);
      expect(AppDimensions.spaceXl, 32.0);
      expect(AppDimensions.radiusCard, 8.0);
      expect(AppDimensions.radiusButton, 6.0);
      expect(AppDimensions.radiusPriority, 4.0);
      expect(AppDimensions.radiusPill, 9999.0);
    });
  });

  group('Responsive Breakpoints', () {
    testWidgets('identifies mobile window correctly (< 768px)', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(ResponsiveBreakpoints.isMobile(context), isTrue);
              expect(ResponsiveBreakpoints.isTablet(context), isFalse);
              expect(ResponsiveBreakpoints.isDesktop(context), isFalse);
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('identifies tablet window correctly (768px - 1024px)', (tester) async {
      tester.view.physicalSize = const Size(800, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(ResponsiveBreakpoints.isMobile(context), isFalse);
              expect(ResponsiveBreakpoints.isTablet(context), isTrue);
              expect(ResponsiveBreakpoints.isDesktop(context), isFalse);
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('identifies desktop window correctly (> 1024px)', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(ResponsiveBreakpoints.isMobile(context), isFalse);
              expect(ResponsiveBreakpoints.isTablet(context), isFalse);
              expect(ResponsiveBreakpoints.isDesktop(context), isTrue);
              return const SizedBox();
            },
          ),
        ),
      );
    });
  });

  group('API Exception & Concurrency Classification', () {
    test('identifies 409 STALE_VERSION concurrency conflict', () {
      final exc = ApiException(
        statusCode: 409,
        code: 'STALE_VERSION',
        message: 'Case version mismatch.',
      );
      expect(exc.isStaleVersion, isTrue);
      expect(exc.isUnauthorized, isFalse);
    });

    test('identifies 401 Unauthorized and 403 Forbidden', () {
      final unauth = ApiException(statusCode: 401, code: 'UNAUTHORIZED', message: 'Token expired');
      final forbidden = ApiException(statusCode: 403, code: 'FORBIDDEN', message: 'Access denied');
      final rateLimited = ApiException(statusCode: 429, code: 'RATE_LIMITED', message: 'Too many requests');

      expect(unauth.isUnauthorized, isTrue);
      expect(forbidden.isForbidden, isTrue);
      expect(rateLimited.isRateLimited, isTrue);
    });
  });

  group('Shared UI Widgets Rendering', () {
    testWidgets('renders PriorityBadge across all tiers', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                PriorityBadge(priority: 'P1'),
                PriorityBadge(priority: 'P2'),
                PriorityBadge(priority: 'P3'),
                PriorityBadge(priority: 'P4'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('P1 Critical'), findsOneWidget);
      expect(find.text('P2 High'), findsOneWidget);
      expect(find.text('P3 Normal'), findsOneWidget);
      expect(find.text('P4 Low'), findsOneWidget);
    });

    testWidgets('renders RoleBadge across all 5 roles', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                RoleBadge(role: 'requester'),
                RoleBadge(role: 'operator'),
                RoleBadge(role: 'lead'),
                RoleBadge(role: 'manager'),
                RoleBadge(role: 'admin'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Requester'), findsOneWidget);
      expect(find.text('Operator'), findsOneWidget);
      expect(find.text('Team Lead'), findsOneWidget);
      expect(find.text('Manager'), findsOneWidget);
      expect(find.text('Administrator'), findsOneWidget);
    });

    testWidgets('renders LoadingState, ErrorState, EmptyState and UnauthorizedState', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const LoadingState(message: 'Loading tickets...'),
                  ErrorState(message: 'Connection failed', onRetry: () {}),
                  const EmptyState(title: 'No Active Tickets', description: 'All caught up!'),
                  const UnauthorizedState(message: 'Admin area restricted.'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Loading tickets...'), findsOneWidget);
      expect(find.text('Connection failed'), findsOneWidget);
      expect(find.text('No Active Tickets'), findsOneWidget);
      expect(find.text('Admin area restricted.'), findsOneWidget);
    });
  });
}
