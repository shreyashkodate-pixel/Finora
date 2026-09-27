import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../../../shared/api_client.dart';
import '../models/alert_model.dart';

/// State management provider for Inbound Monitoring Alerts and Alert Transformation Rules.
class AlertProvider extends ChangeNotifier {
  final ApiClient _apiClient;

  List<InboundAlertModel> _alerts = [];
  List<AlertRuleModel> _rules = [];
  InboundAlertModel? _selectedAlert;

  // Filter & Search states
  AlertProviderEnum _selectedProvider = AlertProviderEnum.all;
  AlertSeverityEnum _selectedSeverity = AlertSeverityEnum.all;
  AlertStatusEnum _selectedStatus = AlertStatusEnum.all;
  String _searchQuery = '';

  // Loading & Error states
  bool _isLoadingAlerts = false;
  bool _isLoadingRules = false;
  bool _isAcknowledging = false;
  bool _isCreatingRule = false;
  String? _errorMessage;

  AlertProvider({required ApiClient apiClient}) : _apiClient = apiClient;

  // Getters
  List<InboundAlertModel> get alerts => _alerts;
  List<AlertRuleModel> get rules => _rules;
  InboundAlertModel? get selectedAlert => _selectedAlert;

  AlertProviderEnum get selectedProvider => _selectedProvider;
  AlertSeverityEnum get selectedSeverity => _selectedSeverity;
  AlertStatusEnum get selectedStatus => _selectedStatus;
  String get searchQuery => _searchQuery;

  bool get isLoadingAlerts => _isLoadingAlerts;
  bool get isLoadingRules => _isLoadingRules;
  bool get isAcknowledging => _isAcknowledging;
  bool get isCreatingRule => _isCreatingRule;
  bool get hasError => _errorMessage != null;
  String? get errorMessage => _errorMessage;

  AlertStatsModel get stats => AlertStatsModel.fromAlerts(_alerts);

  List<InboundAlertModel> get filteredAlerts {
    return _alerts.where((alert) {
      // Provider filter
      if (_selectedProvider != AlertProviderEnum.all &&
          alert.provider != _selectedProvider) {
        return false;
      }

      // Severity filter
      if (_selectedSeverity != AlertSeverityEnum.all) {
        final alertSev = AlertSeverityExtension.fromApiValue(alert.severity);
        if (alertSev != _selectedSeverity) {
          return false;
        }
      }

      // Status filter
      if (_selectedStatus != AlertStatusEnum.all &&
          alert.status != _selectedStatus) {
        return false;
      }

      // Search query filter (matches title, description, external alert ID, fingerprint, case reference)
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final matchesTitle = alert.title.toLowerCase().contains(q);
        final matchesDesc = alert.description?.toLowerCase().contains(q) ?? false;
        final matchesExtId = alert.externalAlertId?.toLowerCase().contains(q) ?? false;
        final matchesFp = alert.fingerprint.toLowerCase().contains(q);
        final matchesCase = alert.caseId?.toLowerCase().contains(q) ?? false;

        if (!matchesTitle && !matchesDesc && !matchesExtId && !matchesFp && !matchesCase) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // Filter Setters
  void setProviderFilter(AlertProviderEnum provider) {
    if (_selectedProvider != provider) {
      _selectedProvider = provider;
      notifyListeners();
    }
  }

  void setSeverityFilter(AlertSeverityEnum severity) {
    if (_selectedSeverity != severity) {
      _selectedSeverity = severity;
      notifyListeners();
    }
  }

  void setStatusFilter(AlertStatusEnum status) {
    if (_selectedStatus != status) {
      _selectedStatus = status;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void selectAlert(InboundAlertModel? alert) {
    _selectedAlert = alert;
    notifyListeners();
  }

  void clearFilters() {
    _selectedProvider = AlertProviderEnum.all;
    _selectedSeverity = AlertSeverityEnum.all;
    _selectedStatus = AlertStatusEnum.all;
    _searchQuery = '';
    notifyListeners();
  }

  /// Fetches inbound alerts from GET /integrations/alerts
  Future<void> fetchAlerts({bool notify = true}) async {
    _isLoadingAlerts = true;
    _errorMessage = null;
    if (notify) notifyListeners();

    try {
      final queryParams = <String, String>{
        'limit': '100',
      };
      if (_selectedProvider != AlertProviderEnum.all) {
        queryParams['provider'] = _selectedProvider.apiValue;
      }
      if (_selectedStatus != AlertStatusEnum.all) {
        queryParams['alert_status'] = _selectedStatus.apiValue;
      }
      if (_selectedSeverity != AlertSeverityEnum.all) {
        queryParams['severity'] = _selectedSeverity.apiValue;
      }

      final res = await _apiClient.get('/integrations/alerts', queryParameters: queryParams);

      if (res is List) {
        _alerts = res
            .map((item) => InboundAlertModel.fromJson(item as Map<String, dynamic>))
            .toList();

        // Update selected alert if it is currently in memory
        if (_selectedAlert != null) {
          final updated = _alerts.where((a) => a.id == _selectedAlert!.id).firstOrNull;
          if (updated != null) {
            _selectedAlert = updated;
          }
        }
      }
    } on ApiException catch (e) {
      developer.log('ApiException fetching alerts: ${e.message}', name: 'AlertProvider');
      _errorMessage = e.message;
    } catch (e) {
      developer.log('Error fetching alerts: $e', name: 'AlertProvider');
      _errorMessage = 'Network error loading alerts: $e';
    } finally {
      _isLoadingAlerts = false;
      notifyListeners();
    }
  }

  /// Refreshes both alerts and rules
  Future<void> refreshAll() async {
    await Future.wait([
      fetchAlerts(notify: false),
      fetchRules(notify: false),
    ]);
    notifyListeners();
  }

  /// Acknowledges an alert via POST /integrations/alerts/{alert_id}/acknowledge
  Future<bool> acknowledgeAlert(String alertId) async {
    _isAcknowledging = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _apiClient.post('/integrations/alerts/$alertId/acknowledge');

      if (res is Map<String, dynamic>) {
        final updatedAlert = InboundAlertModel.fromJson(res);
        
        // Update item in local list
        final index = _alerts.indexWhere((a) => a.id == alertId);
        if (index != -1) {
          _alerts[index] = updatedAlert;
        } else {
          _alerts.insert(0, updatedAlert);
        }

        if (_selectedAlert?.id == alertId) {
          _selectedAlert = updatedAlert;
        }

        _isAcknowledging = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Failed to acknowledge alert.';
        _isAcknowledging = false;
        notifyListeners();
        return false;
      }
    } on ApiException catch (e) {
      developer.log('ApiException acknowledging alert: ${e.message}', name: 'AlertProvider');
      _errorMessage = e.message;
      _isAcknowledging = false;
      notifyListeners();
      return false;
    } catch (e) {
      developer.log('Error acknowledging alert $alertId: $e', name: 'AlertProvider');
      _errorMessage = 'Network error acknowledging alert: $e';
      _isAcknowledging = false;
      notifyListeners();
      return false;
    }
  }

  /// Fetches alert rules from GET /integrations/alerts/rules
  Future<void> fetchRules({bool notify = true}) async {
    _isLoadingRules = true;
    if (notify) notifyListeners();

    try {
      final res = await _apiClient.get('/integrations/alerts/rules');

      if (res is List) {
        _rules = res
            .map((item) => AlertRuleModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } on ApiException catch (e) {
      developer.log('ApiException fetching rules: ${e.message}', name: 'AlertProvider');
      _errorMessage = e.message;
    } catch (e) {
      developer.log('Error fetching alert rules: $e', name: 'AlertProvider');
      _errorMessage = 'Network error loading alert rules: $e';
    } finally {
      _isLoadingRules = false;
      notifyListeners();
    }
  }

  /// Creates a new alert rule via POST /integrations/alerts/rules
  Future<bool> createRule(AlertRuleCreatePayload payload) async {
    _isCreatingRule = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _apiClient.post(
        '/integrations/alerts/rules',
        body: payload.toJson(),
      );

      if (res is Map<String, dynamic>) {
        final newRule = AlertRuleModel.fromJson(res);
        _rules.insert(0, newRule);
        _isCreatingRule = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Failed to create alert rule.';
        _isCreatingRule = false;
        notifyListeners();
        return false;
      }
    } on ApiException catch (e) {
      developer.log('ApiException creating rule: ${e.message}', name: 'AlertProvider');
      _errorMessage = e.message;
      _isCreatingRule = false;
      notifyListeners();
      return false;
    } catch (e) {
      developer.log('Error creating alert rule: $e', name: 'AlertProvider');
      _errorMessage = 'Network error creating alert rule: $e';
      _isCreatingRule = false;
      notifyListeners();
      return false;
    }
  }
}
