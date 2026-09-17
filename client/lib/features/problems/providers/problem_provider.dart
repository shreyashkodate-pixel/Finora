import 'package:flutter/material.dart';
import '../../../shared/api_client.dart';
import '../models/problem_model.dart';

class ProblemProvider extends ChangeNotifier {
  final ApiClient apiClient;

  List<ProblemModel> _problems = [];
  bool _isLoading = false;
  String? _error;

  ProblemProvider({required this.apiClient});

  List<ProblemModel> get problems => _problems;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchProblems({String? status, String? priority}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final queryParams = <String, String>{};
      if (status != null) queryParams['status'] = status;
      if (priority != null) queryParams['priority'] = priority;

      final res = await apiClient.get('/problems', queryParameters: queryParams);
      if (res is List) {
        _problems = res.map((e) => ProblemModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ProblemModel?> createProblem({
    required String title,
    required String description,
    required String priority,
    String? rootCause,
    String? workaround,
    List<String>? caseIds,
  }) async {
    try {
      final res = await apiClient.post('/problems', body: {
        'title': title,
        'description': description,
        'priority': priority,
        if (rootCause != null) 'root_cause': rootCause,
        if (workaround != null) 'workaround': workaround,
        if (caseIds != null) 'case_ids': caseIds,
      });
      final created = ProblemModel.fromJson(res as Map<String, dynamic>);
      _problems.insert(0, created);
      notifyListeners();
      return created;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> linkCase(String problemId, String caseId) async {
    try {
      await apiClient.post('/problems/$problemId/link-case', body: {
        'case_id': caseId,
      });
      await fetchProblems();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> publishKnownError({
    required String problemId,
    required String title,
    required String symptoms,
    required String workaround,
    String? permanentFix,
  }) async {
    try {
      await apiClient.post('/problems/$problemId/known-error', body: {
        'title': title,
        'symptoms': symptoms,
        'workaround': workaround,
        if (permanentFix != null) 'permanent_fix': permanentFix,
        'published': true,
      });
      await fetchProblems();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
