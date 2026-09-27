import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/dimensions.dart';
import '../../../shared/theme/typography.dart';
import '../../../shared/widgets/custom_buttons.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/search_field.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cases/screens/case_detail_screen.dart';
import '../models/major_incident_model.dart';
import '../providers/major_incident_provider.dart';
import 'declare_major_incident_dialog.dart';

class MajorIncidentScreen extends StatefulWidget {
  const MajorIncidentScreen({super.key});

  @override
  State<MajorIncidentScreen> createState() => _MajorIncidentScreenState();
}

class _MajorIncidentScreenState extends State<MajorIncidentScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MajorIncidentProvider>().fetchMajorIncidents();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openDeclareDialog() {
    showDialog<bool>(
      context: context,
      builder: (_) => const DeclareMajorIncidentDialog(),
    ).then((val) {
      if (val == true) {
        context.read<MajorIncidentProvider>().fetchMajorIncidents();
      }
    });
  }

  void _openAddTimelineDialog(MajorIncidentModel inc) {
    final summaryCtrl = TextEditingController();
    final detailsCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.add_comment_outlined, color: AppColors.primaryBlue),
            const SizedBox(width: AppDimensions.spaceSm),
            Text('Log War-Room Event: ${inc.incidentNumber}', style: AppTypography.headlineSm),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('timelineEventSummaryField'),
                controller: summaryCtrl,
                decoration: const InputDecoration(
                  labelText: 'Event Summary *',
                  hintText: 'e.g. Database read-replica promoted to primary',
                  prefixIcon: Icon(Icons.flash_on_outlined),
                ),
              ),
              const SizedBox(height: AppDimensions.spaceMd),
              TextField(
                key: const Key('timelineEventDetailsField'),
                controller: detailsCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Telemetry / Technical Details',
                  hintText: 'Add telemetry logs, metric links, or command output...',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          SecondaryButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          const SizedBox(width: AppDimensions.spaceSm),
          PrimaryButton(
            key: const Key('submitTimelineEventBtn'),
            label: 'Record Event',
            icon: Icons.send_outlined,
            onPressed: () async {
              if (summaryCtrl.text.trim().isEmpty) return;
              final ok = await context.read<MajorIncidentProvider>().addTimelineEvent(
                    incidentId: inc.id,
                    summary: summaryCtrl.text.trim(),
                    details: detailsCtrl.text.trim().isNotEmpty ? detailsCtrl.text.trim() : null,
                  );
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('War-Room event logged successfully')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _openResolveDialog(MajorIncidentModel inc) {
    final summaryCtrl = TextEditingController();
    final postMortemCtrl = TextEditingController(
      text: 'https://wiki.finora.internal/postmortem/${inc.incidentNumber.toLowerCase()}',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: AppColors.slaHealthy),
            const SizedBox(width: AppDimensions.spaceSm),
            Text('Resolve Outage: ${inc.incidentNumber}', style: AppTypography.headlineSm),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('resolveExecutiveSummaryField'),
                controller: summaryCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Executive Resolution Summary *',
                  hintText: 'Root cause addressed, system health verified, monitoring stable.',
                  prefixIcon: Icon(Icons.assignment_turned_in_outlined),
                ),
              ),
              const SizedBox(height: AppDimensions.spaceMd),
              TextField(
                key: const Key('resolvePostMortemUrlField'),
                controller: postMortemCtrl,
                decoration: const InputDecoration(
                  labelText: 'Post-Mortem Document URL',
                  hintText: 'https://wiki.finora.internal/postmortem/...',
                  prefixIcon: Icon(Icons.link_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          SecondaryButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          const SizedBox(width: AppDimensions.spaceSm),
          PrimaryButton(
            key: const Key('confirmResolveOutageBtn'),
            label: 'Resolve Outage',
            icon: Icons.verified_outlined,
            onPressed: () async {
              if (summaryCtrl.text.trim().isEmpty) return;
              final ok = await context.read<MajorIncidentProvider>().updateIncident(
                    incidentId: inc.id,
                    status: 'resolved',
                    executiveSummary: summaryCtrl.text.trim(),
                    postMortemUrl: postMortemCtrl.text.trim().isNotEmpty ? postMortemCtrl.text.trim() : null,
                  );
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Major Incident Resolved Successfully!')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  String _formatDuration(DateTime start, DateTime? end) {
    final stop = end ?? DateTime.now();
    final diff = stop.difference(start);
    if (diff.isNegative) return '0m';
    if (diff.inDays > 0) {
      return '${diff.inDays}d ${diff.inHours % 24}h ${diff.inMinutes % 60}m';
    }
    if (diff.inHours > 0) {
      return '${diff.inHours}h ${diff.inMinutes % 60}m';
    }
    return '${diff.inMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MajorIncidentProvider>();
    final auth = context.watch<AuthProvider>();
    final isWide = MediaQuery.of(context).size.width >= 900;
    final isStaff = auth.currentUser?.isStaff ?? false;
    final isCommander = auth.currentUser?.role == 'manager' ||
        auth.currentUser?.role == 'team_lead' ||
        auth.currentUser?.role == 'administrator';

    // Metrics
    final totalIncidents = provider.majorIncidents.length;
    final activeWarRooms = provider.majorIncidents.where((i) => i.isActive || i.isDeclared).length;
    final mitigatedCount = provider.majorIncidents.where((i) => i.isMitigated).length;
    final resolvedCount = provider.majorIncidents.where((i) => i.isResolved || i.isPostMortem).length;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(
        children: [
          // 1. Top Enterprise Metric Banner
          Container(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.borderLight)),
            ),
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final isCompact = constraints.maxWidth < 650;
                final cards = [
                  MetricCard(
                    label: 'Total Incidents',
                    value: '$totalIncidents',
                    icon: Icons.emergency_outlined,
                  ),
                  MetricCard(
                    label: 'Active War-Rooms',
                    value: '$activeWarRooms',
                    icon: Icons.campaign_outlined,
                    valueColor: AppColors.priorityP1,
                  ),
                  MetricCard(
                    label: 'Mitigated Outages',
                    value: '$mitigatedCount',
                    icon: Icons.shield_outlined,
                    valueColor: AppColors.priorityP2,
                  ),
                  MetricCard(
                    label: 'Resolved Incidents',
                    value: '$resolvedCount',
                    icon: Icons.verified_outlined,
                    valueColor: AppColors.slaHealthy,
                  ),
                ];

                if (isCompact) {
                  return GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.5,
                    children: cards,
                  );
                }

                return Row(
                  children: cards
                      .map((c) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: c,
                            ),
                          ))
                      .toList(),
                );
              },
            ),
          ),

          // 2. Responsive Filter & Action Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceMd, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.borderLight)),
            ),
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final isNarrow = constraints.maxWidth < 750;

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SearchField(
                        controller: _searchCtrl,
                        hintText: 'Search incidents by INC ID, title, impact...',
                        onChanged: (v) => provider.setSearchQuery(v),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButton<String?>(
                              isExpanded: true,
                              value: _selectedStatus,
                              hint: const Text('All Statuses'),
                              items: const [
                                DropdownMenuItem(value: null, child: Text('All Statuses')),
                                DropdownMenuItem(value: 'declared', child: Text('Declared')),
                                DropdownMenuItem(value: 'active', child: Text('Active War-Room')),
                                DropdownMenuItem(value: 'mitigated', child: Text('Mitigated')),
                                DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                                DropdownMenuItem(value: 'post_mortem', child: Text('Post-Mortem')),
                              ],
                              onChanged: (v) {
                                setState(() => _selectedStatus = v);
                                provider.fetchMajorIncidents(status: _selectedStatus);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded),
                            tooltip: 'Refresh',
                            onPressed: () => provider.fetchMajorIncidents(status: _selectedStatus),
                          ),
                        ],
                      ),
                      if (isStaff) ...[
                        const SizedBox(height: 8),
                        PrimaryButton(
                          key: const Key('declareMajorIncidentBtn'),
                          label: 'Declare Major Incident',
                          icon: Icons.flash_on,
                          onPressed: _openDeclareDialog,
                        ),
                      ],
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: SearchField(
                        controller: _searchCtrl,
                        hintText: 'Search incidents by INC ID, title, impact...',
                        onChanged: (v) => provider.setSearchQuery(v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String?>(
                      value: _selectedStatus,
                      hint: const Text('All Statuses'),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All Statuses')),
                        DropdownMenuItem(value: 'declared', child: Text('Declared')),
                        DropdownMenuItem(value: 'active', child: Text('Active War-Room')),
                        DropdownMenuItem(value: 'mitigated', child: Text('Mitigated')),
                        DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                        DropdownMenuItem(value: 'post_mortem', child: Text('Post-Mortem')),
                      ],
                      onChanged: (v) {
                        setState(() => _selectedStatus = v);
                        provider.fetchMajorIncidents(status: _selectedStatus);
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Refresh',
                      onPressed: () => provider.fetchMajorIncidents(status: _selectedStatus),
                    ),
                    if (isStaff) ...[
                      const SizedBox(width: 12),
                      PrimaryButton(
                        key: const Key('declareMajorIncidentBtn'),
                        label: 'Declare Major Incident',
                        icon: Icons.flash_on,
                        onPressed: _openDeclareDialog,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),

          // 3. Error Banner (if any)
          if (provider.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.spaceSm),
              color: AppColors.priorityP1.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.priorityP1, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      provider.error!,
                      style: AppTypography.bodySm.copyWith(color: AppColors.priorityP1),
                    ),
                  ),
                ],
              ),
            ),

          // 4. Main Body: Master-Detail on Desktop, Stacked Cards on Mobile
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.filteredIncidents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.health_and_safety_outlined, size: 64, color: AppColors.slaHealthy),
                            const SizedBox(height: 16),
                            Text('No Major Incidents Found', style: AppTypography.headlineSm),
                            const SizedBox(height: 8),
                            Text(
                              'All production services operating normally without active outages.',
                              style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondaryLight),
                            ),
                          ],
                        ),
                      )
                    : isWide
                        ? _buildMasterDetailLayout(context, provider, isCommander)
                        : _buildMobileList(context, provider, isCommander),
          ),
        ],
      ),
    );
  }

  Widget _buildMasterDetailLayout(
    BuildContext context,
    MajorIncidentProvider provider,
    bool isCommander,
  ) {
    final selected = provider.selectedIncident ?? provider.filteredIncidents.first;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Master List Pane
        SizedBox(
          width: 380,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: AppColors.borderLight)),
            ),
            child: ListView.separated(
              itemCount: provider.filteredIncidents.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.borderLight),
              itemBuilder: (ctx, i) {
                final inc = provider.filteredIncidents[i];
                final isSelected = inc.id == selected.id;

                return InkWell(
                  key: Key('incidentCard_${inc.incidentNumber}'),
                  onTap: () => provider.setSelectedIncident(inc),
                  child: Container(
                    padding: const EdgeInsets.all(AppDimensions.spaceMd),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primaryBlue.withValues(alpha: 0.06) : Colors.white,
                      border: isSelected
                          ? const Border(left: BorderSide(color: AppColors.primaryBlue, width: 4))
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Wrap(
                              spacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  inc.incidentNumber,
                                  style: AppTypography.labelMd.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.priorityP1,
                                  ),
                                ),
                                StatusBadge(status: inc.status),
                              ],
                            ),
                            Text(
                              _formatDuration(inc.declaredAt, inc.resolvedAt),
                              style: AppTypography.bodySm.copyWith(
                                fontWeight: FontWeight.bold,
                                color: inc.isResolved ? AppColors.textSecondaryLight : AppColors.priorityP1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          inc.title,
                          style: AppTypography.bodyMd.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimaryLight,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (inc.impactSummary != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            inc.impactSummary!,
                            style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // Detail Pane (Command Bridge)
        Expanded(
          child: _buildCommandBridgeDetail(context, selected, provider, isCommander),
        ),
      ],
    );
  }

  Widget _buildMobileList(
    BuildContext context,
    MajorIncidentProvider provider,
    bool isCommander,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      itemCount: provider.filteredIncidents.length,
      itemBuilder: (ctx, i) {
        final inc = provider.filteredIncidents[i];
        return Card(
          key: Key('mobileIncidentCard_${inc.incidentNumber}'),
          margin: const EdgeInsets.only(bottom: AppDimensions.spaceMd),
          shape: RoundedRectangleBorder(
            borderRadius: AppDimensions.cardBorderRadius,
            side: BorderSide(
              color: inc.isResolved ? AppColors.borderLight : AppColors.priorityP1.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIncidentHeader(context, inc),
                const SizedBox(height: AppDimensions.spaceMd),
                _buildCommandActions(context, inc, provider, isCommander),
                const SizedBox(height: AppDimensions.spaceMd),
                _buildImpactAndBridgeCard(context, inc),
                const SizedBox(height: AppDimensions.spaceMd),
                _buildRootCaseCard(context, inc),
                const SizedBox(height: AppDimensions.spaceMd),
                _buildTimelineStream(context, inc, provider),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommandBridgeDetail(
    BuildContext context,
    MajorIncidentModel inc,
    MajorIncidentProvider provider,
    bool isCommander,
  ) {
    return SingleChildScrollView(
      key: const Key('commandBridgeDetailPane'),
      padding: const EdgeInsets.all(AppDimensions.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Command Bridge Title & Status Header
          _buildIncidentHeader(context, inc),
          const SizedBox(height: AppDimensions.spaceMd),

          // Incident Commander Actions
          _buildCommandActions(context, inc, provider, isCommander),
          const SizedBox(height: AppDimensions.spaceLg),

          // Outage Impact & Bridge Info
          _buildImpactAndBridgeCard(context, inc),
          const SizedBox(height: AppDimensions.spaceMd),

          // Linked Root Case
          _buildRootCaseCard(context, inc),
          const SizedBox(height: AppDimensions.spaceLg),

          // Live War-Room Timeline Stream
          _buildTimelineStream(context, inc, provider),
        ],
      ),
    );
  }

  Widget _buildIncidentHeader(BuildContext context, MajorIncidentModel inc) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppDimensions.cardBorderRadius,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.priorityP1.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      inc.incidentNumber,
                      style: AppTypography.headlineSm.copyWith(
                        color: AppColors.priorityP1,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  StatusBadge(status: inc.status),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: inc.isResolved ? AppColors.slaHealthy.withValues(alpha: 0.1) : AppColors.priorityP1.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: inc.isResolved ? AppColors.slaHealthy : AppColors.priorityP1,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Outage: ${_formatDuration(inc.declaredAt, inc.resolvedAt)}',
                      style: AppTypography.bodySm.copyWith(
                        fontWeight: FontWeight.bold,
                        color: inc.isResolved ? AppColors.slaHealthy : AppColors.priorityP1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceSm),
          Text(inc.title, style: AppTypography.headlineSm),
          const SizedBox(height: 6),
          Text(
            'Declared at: ${dateFormat.format(inc.declaredAt.toLocal())}',
            style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
          ),
          if (inc.resolvedAt != null) ...[
            const SizedBox(height: 2),
            Text(
              'Resolved at: ${dateFormat.format(inc.resolvedAt!.toLocal())}',
              style: AppTypography.bodySm.copyWith(color: AppColors.slaHealthy, fontWeight: FontWeight.w500),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommandActions(
    BuildContext context,
    MajorIncidentModel inc,
    MajorIncidentProvider provider,
    bool isCommander,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppDimensions.cardBorderRadius,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(Icons.security_outlined, size: 20, color: AppColors.primaryBlue),
              Text('Commander Controls', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceSm),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              if (inc.isDeclared)
                PrimaryButton(
                  key: const Key('activateWarRoomBtn'),
                  label: 'Activate War-Room',
                  icon: Icons.play_arrow,
                  onPressed: isCommander
                      ? () => provider.updateIncident(incidentId: inc.id, status: 'active')
                      : null,
                ),
              if (inc.isActive) ...[
                SecondaryButton(
                  key: const Key('mitigateOutageBtn'),
                  label: 'Mark Mitigated',
                  icon: Icons.shield_outlined,
                  onPressed: isCommander
                      ? () => provider.updateIncident(incidentId: inc.id, status: 'mitigated')
                      : null,
                ),
                PrimaryButton(
                  key: const Key('resolveOutageBtn'),
                  label: 'Resolve Outage',
                  icon: Icons.check_circle_outline,
                  onPressed: isCommander ? () => _openResolveDialog(inc) : null,
                ),
              ],
              if (inc.isMitigated) ...[
                PrimaryButton(
                  key: const Key('resolveOutageBtn'),
                  label: 'Resolve Outage',
                  icon: Icons.check_circle_outline,
                  onPressed: isCommander ? () => _openResolveDialog(inc) : null,
                ),
              ],
              if (inc.isResolved) ...[
                SecondaryButton(
                  key: const Key('postMortemBtn'),
                  label: 'Complete Post-Mortem',
                  icon: Icons.article_outlined,
                  onPressed: isCommander
                      ? () => provider.updateIncident(incidentId: inc.id, status: 'post_mortem')
                      : null,
                ),
              ],
              SecondaryButton(
                key: const Key('logTimelineEventBtn'),
                label: 'Log Timeline Event',
                icon: Icons.add_comment_outlined,
                onPressed: () => _openAddTimelineDialog(inc),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImpactAndBridgeCard(BuildContext context, MajorIncidentModel inc) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppDimensions.cardBorderRadius,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.priorityP1),
              Text('Impact & War-Room Bridge', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceSm),
          if (inc.impactSummary != null) ...[
            Text('Business & Operational Impact:', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(inc.impactSummary!, style: AppTypography.bodyMd),
            const SizedBox(height: AppDimensions.spaceSm),
          ],
          if (inc.bridgeUrl != null) ...[
            Container(
              padding: const EdgeInsets.all(AppDimensions.spaceSm),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.video_call_outlined, color: AppColors.primaryBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Live Video Bridge: ${inc.bridgeUrl}',
                      style: AppTypography.bodySm.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryBlue,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (inc.executiveSummary != null) ...[
            const SizedBox(height: AppDimensions.spaceSm),
            Text('Executive Resolution Summary:', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(inc.executiveSummary!, style: AppTypography.bodyMd),
          ],
          if (inc.postMortemUrl != null) ...[
            const SizedBox(height: AppDimensions.spaceSm),
            Row(
              children: [
                const Icon(Icons.link_outlined, size: 16, color: AppColors.textSecondaryLight),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Post-Mortem: ${inc.postMortemUrl}',
                    style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRootCaseCard(BuildContext context, MajorIncidentModel inc) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppDimensions.cardBorderRadius,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final isNarrow = constraints.maxWidth < 450;
          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.link, size: 18, color: AppColors.textSecondaryLight),
                    const SizedBox(width: 6),
                    Text('Linked Root Case', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  inc.caseId,
                  style: AppTypography.bodySm.copyWith(
                    fontFamily: 'monospace',
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                SecondaryButton(
                  key: const Key('viewRootCaseBtn'),
                  label: 'Inspect Case',
                  icon: Icons.open_in_new,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CaseDetailScreen(caseId: inc.caseId),
                      ),
                    );
                  },
                ),
              ],
            );
          }
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.link, size: 18, color: AppColors.textSecondaryLight),
                        const SizedBox(width: 6),
                        Text('Linked Root Case', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      inc.caseId,
                      style: AppTypography.bodySm.copyWith(
                        fontFamily: 'monospace',
                        color: AppColors.textSecondaryLight,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SecondaryButton(
                key: const Key('viewRootCaseBtn'),
                label: 'Inspect Case',
                icon: Icons.open_in_new,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CaseDetailScreen(caseId: inc.caseId),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimelineStream(
    BuildContext context,
    MajorIncidentModel inc,
    MajorIncidentProvider provider,
  ) {
    final dateFormat = DateFormat('HH:mm:ss (MMM dd)');

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppDimensions.cardBorderRadius,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Icon(Icons.history_toggle_off_outlined, size: 20, color: AppColors.primaryBlue),
                  Text(
                    'War-Room Live Timeline (${inc.timelineEvents.length})',
                    style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: AppColors.primaryBlue),
                tooltip: 'Add Timeline Event',
                onPressed: () => _openAddTimelineDialog(inc),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceSm),
          if (inc.timelineEvents.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppDimensions.spaceMd),
              child: Center(
                child: Text(
                  'No timeline events logged yet for this incident.',
                  style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: inc.timelineEvents.length,
              separatorBuilder: (_, __) => const Divider(height: 16, color: AppColors.borderLight),
              itemBuilder: (ctx, i) {
                final evt = inc.timelineEvents[i];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryBlue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                dateFormat.format(evt.eventTimestamp.toLocal()),
                                style: AppTypography.bodySm.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondaryLight,
                                ),
                              ),
                              if (evt.authorId != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.backgroundLight,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    evt.authorId!,
                                    style: AppTypography.bodySm.copyWith(
                                      fontSize: 11,
                                      color: AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            evt.summary,
                            style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (evt.details != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              evt.details!,
                              style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
