import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/api_client.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/dimensions.dart';
import '../../../shared/theme/typography.dart';
import '../../auth/providers/auth_provider.dart';

class TenantGovernanceScreen extends StatefulWidget {
  const TenantGovernanceScreen({super.key});

  @override
  State<TenantGovernanceScreen> createState() => _TenantGovernanceScreenState();
}

class _TenantGovernanceScreenState extends State<TenantGovernanceScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _orgData;
  Map<String, dynamic>? _statsData;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchOrgDetails();
  }

  Future<void> _fetchOrgDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiClient = context.read<ApiClient>();
      final orgRes = await apiClient.get('/admin/organizations/me');
      final orgMap = orgRes is Map<String, dynamic> ? orgRes : <String, dynamic>{};

      Map<String, dynamic>? statsMap;
      if (orgMap['id'] != null) {
        try {
          final statsRes = await apiClient.get('/admin/organizations/${orgMap['id']}/stats');
          if (statsRes is Map<String, dynamic>) {
            statsMap = statsRes;
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _orgData = orgMap;
          _statsData = statsMap;
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load organization settings: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updatePolicyField(String key, dynamic value) async {
    if (_orgData == null || _orgData!['id'] == null) return;
    final orgId = _orgData!['id'];

    setState(() => _isSaving = true);
    try {
      final apiClient = context.read<ApiClient>();
      final updatedPolicy = await apiClient.patch(
        '/admin/organizations/$orgId/policy',
        body: {key: value},
      );

      if (mounted) {
        setState(() {
          if (_orgData!['policy'] != null && updatedPolicy is Map<String, dynamic>) {
            _orgData!['policy'] = updatedPolicy;
          }
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Governance policy updated successfully.'),
            backgroundColor: AppColors.priorityP4,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.priorityP1),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update policy: $e'), backgroundColor: AppColors.priorityP1),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    if (user == null || !user.isAdmin) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spaceXl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.g_mobiledata_rounded, size: 64, color: AppColors.priorityP1),
                const SizedBox(height: 16),
                const Text('Access Restricted', style: AppTypography.headlineMd),
                const SizedBox(height: 8),
                Text(
                  'Tenant Governance settings are restricted to Organization Administrators.',
                  style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondaryLight),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.spaceXl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.priorityP1),
                        const SizedBox(height: 16),
                        const Text('Failed to Load Organization', style: AppTypography.headlineSm),
                        const SizedBox(height: 8),
                        Text(_errorMessage!, style: AppTypography.bodyMd, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _fetchOrgDetails,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppDimensions.spaceLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Tenant Governance & Security', style: AppTypography.headlineMd),
                              const SizedBox(height: 4),
                              Text(
                                'Authoritative security policies and resource isolation for your organization.',
                                style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                              ),
                            ],
                          ),
                          if (_isSaving)
                            const Row(
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 8),
                                Text('Saving...'),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Organization Overview Card
                      _buildOrgOverviewCard(),
                      const SizedBox(height: 20),

                      // Statistics Card
                      if (_statsData != null) _buildStatsCard(),
                      const SizedBox(height: 20),

                      // Security & Authentication Policy Card
                      _buildSecurityPolicyCard(),
                      const SizedBox(height: 20),

                      // AI Governance Policy Card
                      _buildAiPolicyCard(),
                      const SizedBox(height: 20),

                      // Data Retention Policy Card
                      _buildRetentionCard(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildOrgOverviewCard() {
    final name = _orgData?['name'] ?? 'Organization';
    final slug = _orgData?['slug'] ?? '';
    final isActive = _orgData?['is_active'] ?? true;
    final slaTier = (_orgData?['sla_tier'] ?? 'enterprise').toString().toUpperCase();
    final domainWhitelist = (_orgData?['domain_whitelist'] as List<dynamic>?)?.join(', ') ?? 'None configured';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.corporate_fare_rounded, color: AppColors.primaryBlue),
                    const SizedBox(width: 8),
                    Text(name, style: AppTypography.headlineSm),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.priorityP4.withValues(alpha: 0.1) : AppColors.priorityP1.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusPriority),
                    border: Border.all(
                      color: isActive ? AppColors.priorityP4 : AppColors.priorityP1,
                    ),
                  ),
                  child: Text(
                    isActive ? 'ACTIVE' : 'DEACTIVATED',
                    style: AppTypography.labelSm.copyWith(
                      color: isActive ? AppColors.priorityP4 : AppColors.priorityP1,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem('Tenant Slug', slug.isNotEmpty ? slug : '—', Icons.tag_rounded),
                ),
                Expanded(
                  child: _buildInfoItem('SLA Tier', slaTier, Icons.speed_rounded),
                ),
                Expanded(
                  child: _buildInfoItem('Allowed Domains', domainWhitelist, Icons.domain_verification_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    final totalUsers = _statsData?['total_users'] ?? 0;
    final totalTeams = _statsData?['total_teams'] ?? 0;
    final activeCases = _statsData?['active_cases'] ?? 0;
    final openProblems = _statsData?['open_problems'] ?? 0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tenant Resource Allocation', style: AppTypography.headlineSm),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildStatItem('Total Users', '$totalUsers', Icons.people_alt_outlined)),
                Expanded(child: _buildStatItem('Active Teams', '$totalTeams', Icons.groups_outlined)),
                Expanded(child: _buildStatItem('Active Cases', '$activeCases', Icons.confirmation_number_outlined)),
                Expanded(child: _buildStatItem('Open Problems', '$openProblems', Icons.bug_report_outlined)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityPolicyCard() {
    final policy = _orgData?['policy'] as Map<String, dynamic>? ?? {};
    final allowPassword = policy['allow_password_auth'] ?? true;
    final allowGoogle = policy['allow_google_oauth'] ?? true;
    final requireMfa = policy['require_mfa'] ?? false;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.security_rounded, color: AppColors.primaryBlue),
                SizedBox(width: 8),
                Text('Authentication & Access Policy', style: AppTypography.headlineSm),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Allow Password Authentication'),
              subtitle: const Text('Enables standard email and Argon2id password sign-in for users in this tenant.'),
              value: allowPassword,
              onChanged: _isSaving ? null : (val) => _updatePolicyField('allow_password_auth', val),
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Allow Google OAuth Sign-in'),
              subtitle: const Text('Permits enterprise Google Workspace federated authentication matching domain whitelist.'),
              value: allowGoogle,
              onChanged: _isSaving ? null : (val) => _updatePolicyField('allow_google_oauth', val),
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Require Multi-Factor Authentication (MFA)'),
              subtitle: const Text('Enforce two-factor verification on user session establishment (governance toggle).'),
              value: requireMfa,
              onChanged: _isSaving ? null : (val) => _updatePolicyField('require_mfa', val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiPolicyCard() {
    final policy = _orgData?['policy'] as Map<String, dynamic>? ?? {};
    final autoTriage = policy['ai_auto_triage_enabled'] ?? true;
    final autofix = policy['ai_autofix_enabled'] ?? true;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.smart_toy_rounded, color: AppColors.primaryBlue),
                SizedBox(width: 8),
                Text('AI Copilot & Automation Policies', style: AppTypography.headlineSm),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Enable AI Auto-Triage on Case Creation'),
              subtitle: const Text('Automatically runs Gemini triage for priority, category, and team suggestions on new cases.'),
              value: autoTriage,
              onChanged: _isSaving ? null : (val) => _updatePolicyField('ai_auto_triage_enabled', val),
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Enable AI Script Autofix Generation'),
              subtitle: const Text('Allows operators to request automated deterministic fix scripts with syntax verification.'),
              value: autofix,
              onChanged: _isSaving ? null : (val) => _updatePolicyField('ai_autofix_enabled', val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRetentionCard() {
    final policy = _orgData?['policy'] as Map<String, dynamic>? ?? {};
    final retentionDays = policy['data_retention_days'] ?? 365;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_delete_rounded, color: AppColors.primaryBlue),
                SizedBox(width: 8),
                Text('Data Retention Governance', style: AppTypography.headlineSm),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Enforces data lifecycle expiration across audit trails, closed tickets, and telemetry for this tenant.',
              style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Retention Period: ',
                  style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  '$retentionDays Days',
                  style: AppTypography.bodyMd.copyWith(color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondaryLight),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTypography.labelSm.copyWith(color: AppColors.textSecondaryLight)),
              const SizedBox(height: 2),
              Text(value, style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String count, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primaryBlue),
          const SizedBox(height: 8),
          Text(count, style: AppTypography.headlineSm),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.labelSm.copyWith(color: AppColors.textSecondaryLight)),
        ],
      ),
    );
  }
}
