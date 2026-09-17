import 'package:flutter/material.dart';
import '../../../shared/api_client.dart';
import '../models/change_model.dart';

class ChangeProvider extends ChangeNotifier {
  final ApiClient apiClient;

  List<ChangeRequestModel> _changes = [];
  bool _isLoading = false;
  String? _error;

  ChangeProvider({required this.apiClient});

  List<ChangeRequestModel> get changes => _changes;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchChanges({String? status, String? type}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final queryParams = <String, String>{};
      if (status != null) queryParams['status'] = status;
      if (type != null) queryParams['type'] = type;

      final res = await apiClient.get('/changes', queryParameters: queryParams);
      if (res is List) {
        _changes = res.map((e) => ChangeRequestModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ChangeRequestModel?> createChangeRequest({
    required String title,
    required String description,
    required String reason,
    required String riskLevel,
    required String changeType,
    required String implementationPlan,
    required String testPlan,
    required String rollbackPlan,
    String? problemId,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
  }) async {
    try {
      final res = await apiClient.post('/changes', body: {
        'title': title,
        'description': description,
        'reason': reason,
        'risk_level': riskLevel,
        'change_type': changeType,
        'implementation_plan': implementationPlan,
        'test_plan': testPlan,
        'rollback_plan': rollbackPlan,
        if (problemId != null) 'problem_id': problemId,
        if (scheduledStart != null) 'scheduled_start': scheduledStart.toIso8601String(),
        if (scheduledEnd != null) 'scheduled_end': scheduledEnd.toIso8601String(),
      });
      final created = ChangeRequestModel.fromJson(res as Map<String, dynamic>);
      _changes.insert(0, created);
      notifyListeners();
      return created;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> recordCABDecision(String changeId, bool approved, String? feedback) async {
    try {
      await apiClient.post('/changes/$changeId/cab-decision', body: {
        'approved': approved,
        if (feedback != null) 'feedback': feedback,
      });
      await fetchChanges();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateStatus(String changeId, String newStatus) async {
    try {
      await apiClient.patch('/changes/$changeId/status?new_status=$newStatus');
      await fetchChanges();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
