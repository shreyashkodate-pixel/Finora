import 'package:flutter/foundation.dart';
import '../../../shared/api_client.dart';
import '../models/device_token_model.dart';
import '../models/notification_model.dart';

class NotificationProvider extends ChangeNotifier {
  final ApiClient apiClient;

  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  int _totalCount = 0;
  bool _isLoading = false;
  String? _errorMessage;

  List<DeviceTokenModel> _devices = [];
  bool _isLoadingDevices = false;
  String? _deviceErrorMessage;

  NotificationProvider({required this.apiClient});

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  int get totalCount => _totalCount;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<DeviceTokenModel> get devices => _devices;
  bool get isLoadingDevices => _isLoadingDevices;
  String? get deviceErrorMessage => _deviceErrorMessage;

  /// Fetch in-app notifications with pagination and unread filter
  Future<void> loadNotifications({
    bool unreadOnly = false,
    int page = 1,
    int perPage = 20,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await apiClient.get(
        '/notifications',
        queryParameters: {
          'unread_only': unreadOnly.toString(),
          'page': page.toString(),
          'per_page': perPage.toString(),
        },
      );

      if (res is Map<String, dynamic>) {
        final items = res['items'] as List<dynamic>? ?? [];
        _notifications = items
            .map((item) => NotificationModel.fromJson(item as Map<String, dynamic>))
            .toList();
        _totalCount = res['total'] as int? ?? _notifications.length;
        _unreadCount = res['unread_count'] as int? ?? 0;
      }
      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load notifications: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Retrieve the unread notification badge count
  Future<void> loadUnreadCount() async {
    try {
      final res = await apiClient.get('/notifications/unread-count');
      if (res is Map<String, dynamic>) {
        _unreadCount = res['unread_count'] as int? ?? 0;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Mark a single notification as read
  Future<bool> markAsRead(String notificationId) async {
    try {
      final res = await apiClient.patch('/notifications/$notificationId/read');
      if (res is Map<String, dynamic>) {
        final updated = NotificationModel.fromJson(res);
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          _notifications[index] = updated;
        }
        if (_unreadCount > 0) {
          _unreadCount -= 1;
        }
        notifyListeners();
        return true;
      }
      return false;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to mark notification as read: $e';
      notifyListeners();
      return false;
    }
  }

  /// Mark all unread notifications as read
  Future<bool> markAllAsRead() async {
    try {
      final res = await apiClient.post('/notifications/mark-all-read');
      if (res is Map<String, dynamic>) {
        _unreadCount = 0;
        _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
        notifyListeners();
        return true;
      }
      return false;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to mark all as read: $e';
      notifyListeners();
      return false;
    }
  }

  /// Fetch registered push devices for current user
  Future<void> loadDevices() async {
    _isLoadingDevices = true;
    _deviceErrorMessage = null;
    notifyListeners();

    try {
      final res = await apiClient.get('/notifications/devices');
      if (res is List<dynamic>) {
        _devices = res
            .map((item) => DeviceTokenModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      _isLoadingDevices = false;
      notifyListeners();
    } on ApiException catch (e) {
      _deviceErrorMessage = e.message;
      _isLoadingDevices = false;
      notifyListeners();
    } catch (e) {
      _deviceErrorMessage = 'Failed to load devices: $e';
      _isLoadingDevices = false;
      notifyListeners();
    }
  }

  /// Register a device push token
  Future<bool> registerDevice({
    required String token,
    String platform = 'android',
    String? deviceName,
  }) async {
    try {
      final res = await apiClient.post(
        '/notifications/devices/register',
        body: {
          'token': token,
          'platform': platform,
          if (deviceName != null) 'device_name': deviceName,
        },
      );
      if (res is Map<String, dynamic>) {
        final newDev = DeviceTokenModel.fromJson(res);
        final index = _devices.indexWhere((d) => d.token == token);
        if (index != -1) {
          _devices[index] = newDev;
        } else {
          _devices.add(newDev);
        }
        notifyListeners();
        return true;
      }
      return false;
    } on ApiException catch (e) {
      _deviceErrorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _deviceErrorMessage = 'Failed to register device: $e';
      notifyListeners();
      return false;
    }
  }

  /// Revoke / unregister a device push token
  Future<bool> unregisterDevice(String token) async {
    try {
      await apiClient.delete('/notifications/devices/$token');
      _devices.removeWhere((d) => d.token == token);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _deviceErrorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _deviceErrorMessage = 'Failed to unregister device: $e';
      notifyListeners();
      return false;
    }
  }

  /// Send test push notification
  Future<Map<String, dynamic>?> sendPushTest({
    String title = 'Test Notification',
    String body = 'This is a test notification from Finora AI IT Helpdesk.',
    Map<String, String>? data,
  }) async {
    try {
      final res = await apiClient.post(
        '/notifications/push/test',
        body: {
          'title': title,
          'body': body,
          if (data != null) 'data': data,
        },
      );
      if (res is Map<String, dynamic>) {
        return res;
      }
      return null;
    } on ApiException catch (e) {
      _deviceErrorMessage = e.message;
      notifyListeners();
      return null;
    } catch (e) {
      _deviceErrorMessage = 'Failed to send test push: $e';
      notifyListeners();
      return null;
    }
  }

  /// Reset state on logout to guarantee zero tenant/user data leakage
  void clearState() {
    _notifications = [];
    _unreadCount = 0;
    _totalCount = 0;
    _isLoading = false;
    _errorMessage = null;
    _devices = [];
    _isLoadingDevices = false;
    _deviceErrorMessage = null;
    notifyListeners();
  }
}
