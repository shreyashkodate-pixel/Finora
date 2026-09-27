import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../features/cases/screens/case_detail_screen.dart';
import '../../features/notifications/models/notification_model.dart';
import '../../features/notifications/providers/notification_provider.dart';
import '../../features/notifications/screens/notification_preferences_screen.dart';
import '../theme/colors.dart';
import '../theme/dimensions.dart';
import '../theme/typography.dart';
import 'global_states.dart';

/// In-App Notification Center dialog and drawer per SRS §4.7 and Phase 4E.
class NotificationCenterDialog extends StatefulWidget {
  const NotificationCenterDialog({super.key});

  static Future<void> show(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    if (isDesktop) {
      return showDialog<void>(
        context: context,
        builder: (_) => const Dialog(
          insetPadding: EdgeInsets.symmetric(horizontal: 40, vertical: 40),
          child: SizedBox(
            width: 480,
            height: 600,
            child: NotificationCenterDialog(),
          ),
        ),
      );
    } else {
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusBottomSheet)),
        ),
        builder: (_) => const FractionallySizedBox(
          heightFactor: 0.85,
          child: NotificationCenterDialog(),
        ),
      );
    }
  }

  @override
  State<NotificationCenterDialog> createState() => _NotificationCenterDialogState();
}

class _NotificationCenterDialogState extends State<NotificationCenterDialog> {
  bool _unreadOnly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().loadNotifications(unreadOnly: _unreadOnly);
    });
  }

  void _onFilterChanged(bool unreadOnly) {
    setState(() {
      _unreadOnly = unreadOnly;
    });
    context.read<NotificationProvider>().loadNotifications(unreadOnly: unreadOnly);
  }

  void _handleNotificationTap(NotificationModel notification) {
    final provider = context.read<NotificationProvider>();
    if (!notification.isRead) {
      provider.markAsRead(notification.id);
    }

    if (notification.caseId != null && notification.caseId!.isNotEmpty) {
      Navigator.of(context).pop();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CaseDetailScreen(caseId: notification.caseId!),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(notification.title),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  IconData _getEventIcon(String eventType) {
    switch (eventType.toLowerCase()) {
      case 'sla_breach_warning':
      case 'sla_breached':
        return Icons.warning_amber_rounded;
      case 'approval_required':
      case 'approval_approved':
      case 'approval_rejected':
        return Icons.how_to_reg_outlined;
      case 'major_incident_declared':
        return Icons.campaign_rounded;
      case 'alert_correlated':
        return Icons.sensors_outlined;
      case 'case_assigned':
        return Icons.assignment_ind_outlined;
      case 'case_created':
        return Icons.add_circle_outline_rounded;
      case 'case_resolved':
      case 'case_closed':
        return Icons.check_circle_outline_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _getEventColor(String eventType) {
    switch (eventType.toLowerCase()) {
      case 'sla_breach_warning':
      case 'sla_breached':
      case 'major_incident_declared':
        return AppColors.priorityP1;
      case 'approval_required':
        return AppColors.priorityP2;
      case 'case_resolved':
      case 'case_closed':
        return AppColors.statusResolved;
      case 'alert_correlated':
        return AppColors.aiAccent;
      default:
        return AppColors.primaryBlue;
    }
  }

  String _formatTimestamp(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d, h:mm a').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final notifications = provider.notifications;
    final unreadCount = provider.unreadCount;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceMd, vertical: AppDimensions.spaceSm),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.borderLight)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.notifications_rounded, color: AppColors.primaryBlue),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Notifications',
                        style: AppTypography.headlineSm.copyWith(fontSize: 18),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (unreadCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.priorityP1,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (unreadCount > 0)
                IconButton(
                  tooltip: 'Mark all read',
                  icon: const Icon(Icons.done_all_rounded, size: 20, color: AppColors.primaryBlue),
                  onPressed: () => provider.markAllAsRead(),
                ),
              IconButton(
                tooltip: 'Notification Preferences',
                icon: const Icon(Icons.settings_outlined, size: 20),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationPreferencesScreen(),
                    ),
                  );
                },
              ),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),

        // Filter Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceMd, vertical: AppDimensions.spaceXs),
          child: Row(
            children: [
              FilterChip(
                label: const Text('All'),
                selected: !_unreadOnly,
                onSelected: (val) {
                  if (!_unreadOnly) return;
                  _onFilterChanged(false);
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: Text('Unread (${unreadCount})'),
                selected: _unreadOnly,
                onSelected: (val) {
                  if (_unreadOnly) return;
                  _onFilterChanged(true);
                },
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Body
        Expanded(
          child: Builder(
            builder: (context) {
              if (provider.isLoading) {
                return const LoadingState(message: 'Loading notifications...');
              }

              if (provider.errorMessage != null) {
                return ErrorState(
                  message: provider.errorMessage!,
                  onRetry: () => provider.loadNotifications(unreadOnly: _unreadOnly),
                );
              }

              if (notifications.isEmpty) {
                return EmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: _unreadOnly ? 'No unread notifications' : 'No notifications yet',
                  description: _unreadOnly
                      ? 'You have caught up with all your notifications.'
                      : 'You will receive real-time updates when case events or SLA alerts occur.',
                );
              }

              return RefreshIndicator(
                onRefresh: () => provider.loadNotifications(unreadOnly: _unreadOnly),
                child: ListView.separated(
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                  itemBuilder: (context, index) {
                    final item = notifications[index];
                    final eventColor = _getEventColor(item.eventType);
                    final icon = _getEventIcon(item.eventType);

                    return ListTile(
                      dense: true,
                      tileColor: item.isRead ? null : AppColors.primaryContainer.withValues(alpha: 0.35),
                      leading: CircleAvatar(
                        backgroundColor: eventColor.withValues(alpha: 0.12),
                        radius: 18,
                        child: Icon(icon, color: eventColor, size: 18),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: AppTypography.bodyMd.copyWith(
                                fontWeight: item.isRead ? FontWeight.normal : FontWeight.bold,
                                color: AppColors.textPrimaryLight,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTimestamp(item.createdAt),
                            style: AppTypography.bodySm.copyWith(
                              fontSize: 11,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(
                            item.message,
                            style: AppTypography.bodySm.copyWith(
                              color: item.isRead ? AppColors.textSecondaryLight : AppColors.textPrimaryLight,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (item.caseId != null && item.caseId!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.link_rounded, size: 13, color: AppColors.primaryBlue),
                                const SizedBox(width: 4),
                                Text(
                                  'Ticket #${item.caseId!.length > 8 ? item.caseId!.substring(0, 8) : item.caseId}',
                                  style: AppTypography.bodySm.copyWith(
                                    fontSize: 11,
                                    color: AppColors.primaryBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                      trailing: item.isRead
                          ? null
                          : IconButton(
                              tooltip: 'Mark as read',
                              icon: const Icon(Icons.check_circle_outline_rounded, size: 18, color: AppColors.primaryBlue),
                              onPressed: () => provider.markAsRead(item.id),
                            ),
                      onTap: () => _handleNotificationTap(item),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
