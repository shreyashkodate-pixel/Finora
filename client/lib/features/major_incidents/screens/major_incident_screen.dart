import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/accessible_button.dart';
import '../../../shared/widgets/status_badge.dart';
import '../models/major_incident_model.dart';
import '../providers/major_incident_provider.dart';

class MajorIncidentScreen extends StatefulWidget {
  const MajorIncidentScreen({super.key});

  @override
  State<MajorIncidentScreen> createState() => _MajorIncidentScreenState();
}

class _MajorIncidentScreenState extends State<MajorIncidentScreen> {
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MajorIncidentProvider>().fetchMajorIncidents();
    });
  }

  void _openAddTimelineDialog(MajorIncidentModel inc) {
    final summaryCtrl = TextEditingController();
    final detailsCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add War-Room Event: ${inc.incidentNumber}'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: summaryCtrl,
                decoration: const InputDecoration(labelText: 'Event Summary *', hintText: 'e.g. Database failover initiated'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: detailsCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Details / Telemetry', hintText: 'Add technical findings or status...'),
              ),
            ],
          ),
        ),
        actions: [
          AccessibleButton(
            label: 'Cancel',
            isSecondary: true,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          AccessibleButton(
            label: 'Log Event',
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
                    const SnackBar(content: Text('Timeline event recorded')),
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
    final postMortemCtrl = TextEditingController(text: 'https://wiki.finora.internal/postmortem/${inc.incidentNumber.toLowerCase()}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Resolve Major Incident ${inc.incidentNumber}'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: summaryCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Executive Resolution Summary *', hintText: 'Root cause fixed, verification checks passed.'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: postMortemCtrl,
                decoration: const InputDecoration(labelText: 'Post-Mortem Document URL'),
              ),
            ],
          ),
        ),
        actions: [
          AccessibleButton(
            label: 'Cancel',
            isSecondary: true,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          AccessibleButton(
            label: 'Resolve Outage',
            onPressed: () async {
              if (summaryCtrl.text.trim().isEmpty) return;
              final ok = await context.read<MajorIncidentProvider>().updateIncident(
                    incidentId: inc.id,
                    status: 'resolved',
                    executiveSummary: summaryCtrl.text.trim(),
                    postMortemUrl: postMortemCtrl.text.trim(),
                  );
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Major Incident Resolved')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MajorIncidentProvider>();
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Major Incident Commander & War-Room'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Incidents',
            onPressed: () => provider.fetchMajorIncidents(status: _selectedStatus),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Row(
              children: [
                DropdownButton<String?>(
                  value: _selectedStatus,
                  hint: const Text('All Statuses'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All Statuses')),
                    DropdownMenuItem(value: 'declared', child: Text('Declared')),
                    DropdownMenuItem(value: 'active', child: Text('Active War-Room')),
                    DropdownMenuItem(value: 'mitigated', child: Text('Mitigated')),
                    DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                  ],
                  onChanged: (v) {
                    setState(() => _selectedStatus = v);
                    provider.fetchMajorIncidents(status: _selectedStatus);
                  },
                ),
              ],
            ),
          ),

          // Incident List
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.majorIncidents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.health_and_safety_outlined, size: 64, color: AppColors.priorityP4),
                            const SizedBox(height: 16),
                            const Text(
                              'No Active Major Incidents',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'All production systems operating within SLA parameters.',
                              style: TextStyle(color: AppColors.textSecondaryLight),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: provider.majorIncidents.length,
                        itemBuilder: (context, index) {
                          final inc = provider.majorIncidents[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: inc.status == 'resolved'
                                    ? Colors.transparent
                                    : AppColors.priorityP1.withOpacity(0.5),
                                width: 1.5,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppColors.priorityP1.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              inc.incidentNumber,
                                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.priorityP1),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          StatusBadge(status: inc.status),
                                        ],
                                      ),
                                      Text(
                                        'Declared: ${dateFormat.format(inc.declaredAt.toLocal())}',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    inc.title,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  if (inc.impactSummary != null) ...[
                                    const SizedBox(height: 6),
                                    Text('⚠️ Impact: ${inc.impactSummary}'),
                                  ],
                                  if (inc.bridgeUrl != null) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.video_call, color: AppColors.primaryLight, size: 20),
                                        const SizedBox(width: 6),
                                        Text('Bridge URL: ${inc.bridgeUrl}', style: const TextStyle(fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  ],
                                  if (inc.executiveSummary != null) ...[
                                    const SizedBox(height: 8),
                                    Text('📋 Resolution: ${inc.executiveSummary}'),
                                  ],
                                  const SizedBox(height: 16),

                                  // Timeline events
                                  Text(
                                    'War-Room Event Timeline (${inc.timelineEvents.length})',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 8),
                                  ...inc.timelineEvents.map((t) => Padding(
                                        padding: const EdgeInsets.only(left: 8, bottom: 6),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              dateFormat.format(t.eventTimestamp.toLocal()),
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondaryLight),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text('• ${t.summary}${t.details != null ? ' — ${t.details}' : ''}', style: const TextStyle(fontSize: 13)),
                                            ),
                                          ],
                                        ),
                                      )),

                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      AccessibleButton(
                                        label: 'Add Event',
                                        icon: Icons.add_comment,
                                        isSecondary: true,
                                        onPressed: () => _openAddTimelineDialog(inc),
                                      ),
                                      if (inc.status != 'resolved') ...[
                                        const SizedBox(width: 12),
                                        AccessibleButton(
                                          label: 'Resolve Outage',
                                          icon: Icons.check_circle,
                                          onPressed: () => _openResolveDialog(inc),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
