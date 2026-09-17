import 'package:flutter/material.dart';
import '../../../shared/api_client.dart';
import '../models/autofix_model.dart';

class AutoFixProvider extends ChangeNotifier {
  final ApiClient apiClient;

  List<AutoFixActionModel> _actions = [];
  bool _isLoading = false;
  String? _error;

  AutoFixProvider({required this.apiClient});

  List<AutoFixActionModel> get actions => _actions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchActionsForCase(String caseId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await apiClient.get('/autofix/case/$caseId');
      if (res is List) {
        _actions = res.map((e) => AutoFixActionModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<AutoFixActionModel?> proposeAutoFix({
    required String caseId,
    required String actionType,
    required Map<String, dynamic> parameters,
  }) async {
    try {
      final res = await apiClient.post('/autofix/propose/$caseId', body: {
        'action_type': actionType,
        'parameters': parameters,
      });
      final created = AutoFixActionModel.fromJson(res as Map<String, dynamic>);
      _actions.insert(0, created);
      notifyListeners();
      return created;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> executeAutoFix(String actionId, {bool dryRun = false}) async {
    try {
      await apiClient.post('/autofix/execute/$actionId', body: {
        'dry_run': dryRun,
        'confirmed': true,
      });
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> rollbackAutoFix(String actionId) async {
    try {
      await apiClient.post('/autofix/rollback/$actionId');
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
