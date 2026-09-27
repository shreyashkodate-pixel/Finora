import 'package:flutter/material.dart';
import '../../../shared/api_client.dart';
import '../models/change_model.dart';

class ChangeProvider extends ChangeNotifier {
  final ApiClient apiClient;

  List<ChangeRequestModel> _changes = [];
  ChangeRequestModel? _selectedChange;
  bool _isLoading = false;
  bool _isDetailLoading = false;
  String? _error;
  String _searchQuery = '';

  ChangeProvider({required this.apiClient});

  List<ChangeRequestModel> get changes {
    if (_searchQuery.trim().isEmpty) return _changes;
    final q = _searchQuery.trim().toLowerCase();
    return _changes.where((c) {
      return c.changeNumber.toLowerCase().contains(q) ||
          c.title.toLowerCase().contains(q) ||
          c.reason.toLowerCase().contains(q) ||
          c.description.toLowerCase().contains(q) ||
          c.implementationPlan.toLowerCase().contains(q) ||
          c.rollbackPlan.toLowerCase().contains(q);
    }).toList();
  }

  ChangeRequestModel? get selectedChange => _selectedChange;
  bool get isLoading => _isLoading;
  bool get isDetailLoading => _isDetailLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedChange(ChangeRequestModel? change) {
    _selectedChange = change;
    notifyListeners();
  }

  Future<void> fetchChanges({String? status, String? type}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final queryParams = <String, String>{};
      if (status != null && status.isNotEmpty) queryParams['status'] = status;
      if (type != null && type.isNotEmpty) queryParams['type'] = type;

      final res = await apiClient.get('/changes', queryParameters: queryParams);
      if (res is List) {
        _changes = res.map((e) => ChangeRequestModel.fromJson(e as Map<String, dynamic>)).toList();
        if (_selectedChange != null) {
          final idx = _changes.indexWhere((c) => c.id == _selectedChange!.id);
          if (idx != -1) {
            _selectedChange = _changes[idx];
          }
        }
      }
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ChangeRequestModel?> fetchChangeById(String changeId) async {
    _isDetailLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await apiClient.get('/changes/$changeId');
      final fetched = ChangeRequestModel.fromJson(res as Map<String, dynamic>);
      _selectedChange = fetched;
      final idx = _changes.indexWhere((c) => c.id == changeId);
      if (idx != -1) {
        _changes[idx] = fetched;
      } else {
        _changes.add(fetched);
      }
      return fetched;
    } on ApiException catch (e) {
      _error = e.message;
      return null;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isDetailLoading = false;
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
    _error = null;
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
        if (problemId != null && problemId.isNotEmpty) 'problem_id': problemId,
        if (scheduledStart != null) 'scheduled_start': scheduledStart.toIso8601String(),
        if (scheduledEnd != null) 'scheduled_end': scheduledEnd.toIso8601String(),
      });
      final created = ChangeRequestModel.fromJson(res as Map<String, dynamic>);
      _changes.insert(0, created);
      _selectedChange = created;
      notifyListeners();
      return created;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> recordCABDecision(String changeId, bool approved, String? feedback) async {
    _error = null;
    try {
      final res = await apiClient.post('/changes/$changeId/cab-decision', body: {
        'approved': approved,
        if (feedback != null && feedback.isNotEmpty) 'feedback': feedback,
      });
      final updated = ChangeRequestModel.fromJson(res as Map<String, dynamic>);
      final idx = _changes.indexWhere((c) => c.id == changeId);
      if (idx != -1) {
        _changes[idx] = updated;
      }
      if (_selectedChange?.id == changeId) {
        _selectedChange = updated;
      }
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateStatus(String changeId, String newStatus) async {
    _error = null;
    try {
      final res = await apiClient.patch('/changes/$changeId/status?new_status=$newStatus');
      final updated = ChangeRequestModel.fromJson(res as Map<String, dynamic>);
      final idx = _changes.indexWhere((c) => c.id == changeId);
      if (idx != -1) {
        _changes[idx] = updated;
      }
      if (_selectedChange?.id == changeId) {
        _selectedChange = updated;
      }
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
