import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/ai/providers/ai_provider.dart';
import '../features/approvals/providers/approval_provider.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/cases/providers/case_provider.dart';
import '../features/knowledge/providers/knowledge_provider.dart';
import '../shared/api_client.dart';
import '../shared/storage.dart';
import '../shared/theme/app_theme.dart';
import '../shared/theme/colors.dart';
import 'dashboard_shell.dart';

/// Root application widget configuring global providers, theming, and auth-state routing.
class AIHelpdeskApp extends StatelessWidget {
  final ApiClient apiClient;
  final SessionStorage storage;

  const AIHelpdeskApp({
    super.key,
    required this.apiClient,
    required this.storage,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(apiClient: apiClient, storage: storage)..initSession(),
        ),
        ChangeNotifierProvider<CaseProvider>(
          create: (_) => CaseProvider(apiClient: apiClient),
        ),
        ChangeNotifierProvider<AIProvider>(
          create: (_) => AIProvider(apiClient: apiClient),
        ),
        ChangeNotifierProvider<ApprovalProvider>(
          create: (_) => ApprovalProvider(apiClient: apiClient),
        ),
        ChangeNotifierProvider<KnowledgeProvider>(
          create: (_) => KnowledgeProvider(apiClient: apiClient),
        ),
      ],
      child: MaterialApp(
        title: 'AI IT Helpdesk',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const AuthGate(),
      ),
    );
  }
}

/// AuthGate displays the dashboard if logged in, the login screen if unauthenticated,
/// or a splash screen while checking session state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    switch (auth.status) {
      case AuthStatus.authenticated:
        return const DashboardShell();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
      case AuthStatus.initial:
      case AuthStatus.authenticating:
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.support_agent, size: 64, color: AppColors.primaryBlue),
                SizedBox(height: 16),
                Text(
                  'AI IT Helpdesk',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                ),
                SizedBox(height: 8),
                Text(
                  'Verifying session credentials...',
                  style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 13),
                ),
                SizedBox(height: 24),
                CircularProgressIndicator(),
              ],
            ),
          ),
        );
    }
  }
}
