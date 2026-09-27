import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/dimensions.dart';
import '../../../shared/theme/typography.dart';
import '../../../shared/widgets/custom_buttons.dart';
import '../../../shared/widgets/global_states.dart';
import '../../../shared/widgets/page_header.dart';
import '../models/device_token_model.dart';
import '../providers/notification_provider.dart';

/// Screen 16: Notification Preferences & Push Device Management per SRS §4.7 & Phase 4E.
class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() => _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState extends State<NotificationPreferencesScreen> {
  final _tokenController = TextEditingController();
  final _deviceNameController = TextEditingController();
  String _selectedPlatform = 'web';
  bool _isSendingTest = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().loadDevices();
    });
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }

  Future<void> _handleSendPushTest() async {
    setState(() => _isSendingTest = true);
    final provider = context.read<NotificationProvider>();
    final result = await provider.sendPushTest(
      title: 'AI IT Helpdesk — Test Notification',
      body: 'Verified push notification delivery channel.',
    );
    setState(() => _isSendingTest = false);

    if (!mounted) return;

    if (result != null) {
      final targeted = result['targeted_devices'] ?? 0;
      final successful = result['successful_dispatches'] ?? 0;
      final failed = result['failed_dispatches'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.statusResolved,
          content: Text(
            'Push notification request sent. (Targeted: $targeted, Succeeded: $successful, Failed: $failed)',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.priorityP1,
          content: Text(provider.deviceErrorMessage ?? 'Failed to send test push notification.'),
        ),
      );
    }
  }

  void _showRegisterDeviceDialog() {
    _tokenController.clear();
    _deviceNameController.clear();
    _selectedPlatform = 'web';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Register Push Device'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Register a device push token for real-time mobile/web alert dispatch.',
                      style: AppTypography.bodySm,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _tokenController,
                      decoration: const InputDecoration(
                        labelText: 'Device Push Token',
                        hintText: 'e.g., fcm-token-xyz...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _deviceNameController,
                      decoration: const InputDecoration(
                        labelText: 'Device Name (Optional)',
                        hintText: 'e.g., Work Laptop Chrome / Pixel 8',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedPlatform,
                      decoration: const InputDecoration(
                        labelText: 'Platform',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'web', child: Text('Web Push')),
                        DropdownMenuItem(value: 'android', child: Text('Android (FCM)')),
                        DropdownMenuItem(value: 'ios', child: Text('iOS (APNs)')),
                        DropdownMenuItem(value: 'macos', child: Text('macOS Desktop')),
                        DropdownMenuItem(value: 'windows', child: Text('Windows Desktop')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => _selectedPlatform = val);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final token = _tokenController.text.trim();
                    if (token.isEmpty) return;
                    final name = _deviceNameController.text.trim().isEmpty ? null : _deviceNameController.text.trim();
                    final success = await context.read<NotificationProvider>().registerDevice(
                          token: token,
                          platform: _selectedPlatform,
                          deviceName: name,
                        );
                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                    }
                    if (mounted) {
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Device registered successfully for push notifications.')),
                        );
                      }
                    }
                  },
                  child: const Text('Register'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmRevokeDevice(DeviceTokenModel dev) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Revoke Device Token?'),
          content: Text(
            'Are you sure you want to unregister ${dev.deviceName ?? dev.platform} (Token: ...${dev.token.length > 8 ? dev.token.substring(dev.token.length - 8) : dev.token})? This device will no longer receive push notifications.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.priorityP1),
              onPressed: () async {
                final success = await context.read<NotificationProvider>().unregisterDevice(dev.token);
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted && success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Device token revoked successfully.')),
                  );
                }
              },
              child: const Text('Revoke', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  IconData _getPlatformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return Icons.phone_android_rounded;
      case 'ios':
        return Icons.phone_iphone_rounded;
      case 'macos':
        return Icons.laptop_mac_rounded;
      case 'windows':
        return Icons.laptop_windows_rounded;
      case 'web':
      default:
        return Icons.language_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final devices = provider.devices;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Preferences'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.spaceLg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeader(
                  title: 'Notification & Push Device Settings',
                  subtitle: 'Manage registered devices for push notifications and view delivery channel status.',
                  actions: [
                    CustomButtons.primary(
                      text: 'Register Device',
                      icon: Icons.add_to_queue_rounded,
                      onPressed: _showRegisterDeviceDialog,
                    ),
                    const SizedBox(width: 8),
                    CustomButtons.secondary(
                      text: _isSendingTest ? 'Sending...' : 'Test Push',
                      icon: Icons.send_rounded,
                      onPressed: _isSendingTest ? null : _handleSendPushTest,
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spaceLg),

                // Section 1: Registered Push Devices
                Card(
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
                          children: [
                            const Icon(Icons.devices_rounded, color: AppColors.primaryBlue),
                            const SizedBox(width: 8),
                            Text(
                              'Registered Push Devices',
                              style: AppTypography.headlineSm.copyWith(fontSize: 16),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Refresh Device List',
                              icon: const Icon(Icons.refresh_rounded, size: 20),
                              onPressed: () => provider.loadDevices(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Push notifications are securely dispatched to active registered endpoints.',
                          style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                        ),
                        const SizedBox(height: 16),
                        if (provider.isLoadingDevices)
                          const LoadingState(message: 'Loading registered devices...')
                        else if (provider.deviceErrorMessage != null)
                          ErrorState(
                            message: provider.deviceErrorMessage!,
                            onRetry: () => provider.loadDevices(),
                          )
                        else if (devices.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(AppDimensions.spaceXl),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.device_unknown_rounded, size: 36, color: AppColors.textSecondaryLight),
                                const SizedBox(height: 8),
                                const Text('No devices currently registered', style: AppTypography.labelMd),
                                const SizedBox(height: 4),
                                Text(
                                  'Register your current browser or mobile token to receive real-time push alerts.',
                                  style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: devices.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final dev = devices[index];
                              final platIcon = _getPlatformIcon(dev.platform);
                              final tokenPreview = dev.token.length > 12
                                  ? '${dev.token.substring(0, 6)}...${dev.token.substring(dev.token.length - 4)}'
                                  : dev.token;

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primaryContainer,
                                  child: Icon(platIcon, color: AppColors.primaryBlue),
                                ),
                                title: Row(
                                  children: [
                                    Text(
                                      dev.deviceName ?? '${dev.platform.toUpperCase()} Device',
                                      style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: dev.isActive
                                            ? AppColors.statusResolvedBackground
                                            : AppColors.surfaceMuted,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: dev.isActive
                                              ? AppColors.statusResolved
                                              : AppColors.borderLight,
                                          width: 0.5,
                                        ),
                                      ),
                                      child: Text(
                                        dev.isActive ? 'ACTIVE' : 'INACTIVE',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: dev.isActive ? AppColors.statusResolved : AppColors.textSecondaryLight,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 2),
                                    Text(
                                      'Token: $tokenPreview • Platform: ${dev.platform.toUpperCase()}',
                                      style: AppTypography.bodySm.copyWith(fontSize: 11),
                                    ),
                                    Text(
                                      'Last seen: ${DateFormat('MMM d, yyyy h:mm a').format(dev.lastSeenAt.toLocal())}',
                                      style: AppTypography.bodySm.copyWith(fontSize: 11, color: AppColors.textSecondaryLight),
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  tooltip: 'Revoke Device',
                                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.priorityP1),
                                  onPressed: () => _confirmRevokeDevice(dev),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceLg),

                // Section 2: Delivery Channels Status & Policy Notice
                Card(
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
                          children: [
                            const Icon(Icons.tune_rounded, color: AppColors.primaryBlue),
                            const SizedBox(width: 8),
                            Text(
                              'Delivery Channels & Notification Policy',
                              style: AppTypography.headlineSm.copyWith(fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const ListTile(
                          dense: true,
                          leading: Icon(Icons.notifications_active_outlined, color: AppColors.statusResolved),
                          title: Text('In-App Notification Center'),
                          subtitle: Text('Always active. Stores real-time ticket, SLA, and approval events in authoritative database.'),
                          trailing: Icon(Icons.check_circle_rounded, color: AppColors.statusResolved),
                        ),
                        const Divider(height: 1),
                        const ListTile(
                          dense: true,
                          leading: Icon(Icons.send_to_mobile_rounded, color: AppColors.primaryBlue),
                          title: Text('Mobile & Web Push (FCM / APNs)'),
                          subtitle: Text('Dispatches priority alerts and SLA breach warnings to registered push device tokens.'),
                          trailing: Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue),
                        ),
                        const Divider(height: 1),
                        const ListTile(
                          dense: true,
                          leading: Icon(Icons.email_outlined, color: AppColors.statusNew),
                          title: Text('Enterprise Email Alerts'),
                          subtitle: Text('Dispatches critical incident notifications and CAB approval requests to verified email addresses.'),
                          trailing: Icon(Icons.check_circle_rounded, color: AppColors.statusNew),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(AppDimensions.spaceMd),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                            border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, color: AppColors.primaryBlue, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Delivery channel rules are governed by enterprise SLA and tenant security policies per Phase 4D & 4E governance contracts.',
                                  style: AppTypography.bodySm.copyWith(color: AppColors.textPrimaryLight),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
