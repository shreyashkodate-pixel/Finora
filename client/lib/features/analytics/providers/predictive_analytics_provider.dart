import 'package:flutter/material.dart';
import '../../../shared/api_client.dart';
import '../models/analytics_model.dart';

/// State management provider for Phase 4C: Predictive Workload, SLA Risk Scoring, and Team Capacity.
class PredictiveAnalyticsProvider extends ChangeNotifier {
  final ApiClient apiClient;

  WorkloadForecastResponse? _workloadForecast;
  PredictiveRiskResponse? _riskForecast;
  TeamCapacityOverviewResponse? _teamCapacity;

  int _selectedHorizon = 7;
  String _selectedRiskFilter = 'all'; // 'all', 'critical', 'high', 'moderate', 'low'

  bool _isLoadingWorkload = false;
  bool _isLoadingRisk = false;
  bool _isLoadingCapacity = false;

  String? _workloadError;
  String? _riskError;
  String? _capacityError;

  bool _isForbiddenWorkload = false;
  bool _isForbiddenRisk = false;
  bool _isForbiddenCapacity = false;

  PredictiveAnalyticsProvider({required this.apiClient});

  // Getters
  WorkloadForecastResponse? get workloadForecast => _workloadForecast;
  PredictiveRiskResponse? get riskForecast => _riskForecast;
  TeamCapacityOverviewResponse? get teamCapacity => _teamCapacity;

  int get selectedHorizon => _selectedHorizon;
  String get selectedRiskFilter => _selectedRiskFilter;

  bool get isLoadingWorkload => _isLoadingWorkload;
  bool get isLoadingRisk => _isLoadingRisk;
  bool get isLoadingCapacity => _isLoadingCapacity;
  bool get isLoadingAny => _isLoadingWorkload || _isLoadingRisk || _isLoadingCapacity;

  String? get workloadError => _workloadError;
  String? get riskError => _riskError;
  String? get capacityError => _capacityError;

  bool get isForbiddenWorkload => _isForbiddenWorkload;
  bool get isForbiddenRisk => _isForbiddenRisk;
  bool get isForbiddenCapacity => _isForbiddenCapacity;

  List<PredictiveRiskItem> get filteredRiskCases {
    if (_riskForecast == null) return [];
    if (_selectedRiskFilter == 'all') return _riskForecast!.highRiskCases;
    return _riskForecast!.highRiskCases
        .where((c) => c.riskLevel == _selectedRiskFilter)
        .toList();
  }

  void setRiskFilter(String filter) {
    _selectedRiskFilter = filter;
    notifyListeners();
  }

  /// Updates the prediction window horizon and re-fetches authoritative workload data.
  Future<void> setHorizon(int horizonDays) async {
    if (_selectedHorizon == horizonDays && _workloadForecast != null) return;
    _selectedHorizon = horizonDays;
    notifyListeners();
    await fetchWorkloadForecast(horizonDays: horizonDays);
  }

  /// Fetches statistical workload forecast from `/api/v1/analytics/predictive/workload`.
  Future<void> fetchWorkloadForecast({int? horizonDays}) async {
    final horizon = horizonDays ?? _selectedHorizon;
    _isLoadingWorkload = true;
    _workloadError = null;
    _isForbiddenWorkload = false;
    notifyListeners();

    try {
      final res = await apiClient.get(
        '/api/v1/analytics/predictive/workload',
        queryParameters: {'horizon_days': horizon},
      );
      if (res is Map<String, dynamic>) {
        _workloadForecast = WorkloadForecastResponse.fromJson(res);
      }
    } on ApiException catch (e) {
      if (e.isForbidden) {
        _isForbiddenWorkload = true;
      }
      _workloadError = e.message;
    } catch (e) {
      _workloadError = e.toString();
    } finally {
      _isLoadingWorkload = false;
      notifyListeners();
    }
  }

  /// Fetches SLA breach risk forecasts from `/api/v1/analytics/predictive/risk-forecast`.
  Future<void> fetchRiskForecast() async {
    _isLoadingRisk = true;
    _riskError = null;
    _isForbiddenRisk = false;
    notifyListeners();

    try {
      final res = await apiClient.get('/api/v1/analytics/predictive/risk-forecast');
      if (res is Map<String, dynamic>) {
        _riskForecast = PredictiveRiskResponse.fromJson(res);
      }
    } on ApiException catch (e) {
      if (e.isForbidden) {
        _isForbiddenRisk = true;
      }
      _riskError = e.message;
    } catch (e) {
      _riskError = e.toString();
    } finally {
      _isLoadingRisk = false;
      notifyListeners();
    }
  }

  /// Fetches real-time team workload and capacity overview from `/api/v1/analytics/capacity/teams`.
  Future<void> fetchTeamCapacity() async {
    _isLoadingCapacity = true;
    _capacityError = null;
    _isForbiddenCapacity = false;
    notifyListeners();

    try {
      final res = await apiClient.get('/api/v1/analytics/capacity/teams');
      if (res is Map<String, dynamic>) {
        _teamCapacity = TeamCapacityOverviewResponse.fromJson(res);
      }
    } on ApiException catch (e) {
      if (e.isForbidden) {
        _isForbiddenCapacity = true;
      }
      _capacityError = e.message;
    } catch (e) {
      _capacityError = e.toString();
    } finally {
      _isLoadingCapacity = false;
      notifyListeners();
    }
  }

  /// Refreshes all analytics endpoints concurrently.
  Future<void> refreshAll({bool isOperatorOnly = false}) async {
    if (isOperatorOnly) {
      await fetchRiskForecast();
    } else {
      await Future.wait([
        fetchWorkloadForecast(),
        fetchRiskForecast(),
        fetchTeamCapacity(),
      ]);
    }
  }
}
