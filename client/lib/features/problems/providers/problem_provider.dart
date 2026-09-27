import 'package:flutter/material.dart';
import '../../../shared/api_client.dart';
import '../models/problem_model.dart';

class ProblemProvider extends ChangeNotifier {
  final ApiClient apiClient;

  List<ProblemModel> _problems = [];
  ProblemModel? _selectedProblem;
  bool _isLoading = false;
  bool _isDetailLoading = false;
  String? _error;
  String _searchQuery = '';

  ProblemProvider({required this.apiClient});

  List<ProblemModel> get problems {
    if (_searchQuery.trim().isEmpty) return _problems;
    final q = _searchQuery.trim().toLowerCase();
    return _problems.where((p) {
      return p.problemNumber.toLowerCase().contains(q) ||
          p.title.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q) ||
          (p.rootCause?.toLowerCase().contains(q) ?? false) ||
          (p.workaround?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  ProblemModel? get selectedProblem => _selectedProblem;
  bool get isLoading => _isLoading;
  bool get isDetailLoading => _isDetailLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedProblem(ProblemModel? problem) {
    _selectedProblem = problem;
    notifyListeners();
  }

  Future<void> fetchProblems({String? status, String? priority}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final queryParams = <String, String>{};
      if (status != null && status.isNotEmpty) queryParams['status'] = status;
      if (priority != null && priority.isNotEmpty) queryParams['priority'] = priority;

      final res = await apiClient.get('/problems', queryParameters: queryParams);
      if (res is List) {
        _problems = res.map((e) => ProblemModel.fromJson(e as Map<String, dynamic>)).toList();
        // If there is a selected problem, sync its latest state
        if (_selectedProblem != null) {
          final idx = _problems.indexWhere((p) => p.id == _selectedProblem!.id);
          if (idx != -1) {
            _selectedProblem = _problems[idx];
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

  Future<ProblemModel?> fetchProblemById(String problemId) async {
    _isDetailLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await apiClient.get('/problems/$problemId');
      final fetched = ProblemModel.fromJson(res as Map<String, dynamic>);
      _selectedProblem = fetched;
      final idx = _problems.indexWhere((p) => p.id == problemId);
      if (idx != -1) {
        _problems[idx] = fetched;
      } else {
        _problems.add(fetched);
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

  Future<ProblemModel?> createProblem({
    required String title,
    required String description,
    required String priority,
    String? rootCause,
    String? workaround,
    List<String>? caseIds,
  }) async {
    _error = null;
    try {
      final res = await apiClient.post('/problems', body: {
        'title': title,
        'description': description,
        'priority': priority,
        if (rootCause != null && rootCause.isNotEmpty) 'root_cause': rootCause,
        if (workaround != null && workaround.isNotEmpty) 'workaround': workaround,
        if (caseIds != null && caseIds.isNotEmpty) 'case_ids': caseIds,
      });
      final created = ProblemModel.fromJson(res as Map<String, dynamic>);
      _problems.insert(0, created);
      _selectedProblem = created;
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

  Future<ProblemModel?> updateProblem(
    String problemId, {
    String? title,
    String? description,
    String? status,
    String? priority,
    String? rootCause,
    String? workaround,
    String? ownerId,
  }) async {
    _error = null;
    try {
      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (description != null) body['description'] = description;
      if (status != null) body['status'] = status;
      if (priority != null) body['priority'] = priority;
      if (rootCause != null) body['root_cause'] = rootCause;
      if (workaround != null) body['workaround'] = workaround;
      if (ownerId != null) body['owner_id'] = ownerId;

      final res = await apiClient.patch('/problems/$problemId', body: body);
      final updated = ProblemModel.fromJson(res as Map<String, dynamic>);
      
      final idx = _problems.indexWhere((p) => p.id == problemId);
      if (idx != -1) {
        _problems[idx] = updated;
      }
      if (_selectedProblem?.id == problemId) {
        _selectedProblem = updated;
      }
      notifyListeners();
      return updated;
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

  Future<bool> linkCase(String problemId, String caseId) async {
    _error = null;
    try {
      await apiClient.post('/problems/$problemId/link-case', body: {
        'case_id': caseId,
      });
      await fetchProblemById(problemId);
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

  Future<bool> unlinkCase(String problemId, String caseId) async {
    _error = null;
    try {
      await apiClient.delete('/problems/$problemId/unlink-case/$caseId');
      await fetchProblemById(problemId);
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

  Future<bool> publishKnownError({
    required String problemId,
    required String title,
    required String symptoms,
    required String workaround,
    String? permanentFix,
    bool published = true,
  }) async {
    _error = null;
    try {
      await apiClient.post('/problems/$problemId/known-error', body: {
        'title': title,
        'symptoms': symptoms,
        'workaround': workaround,
        if (permanentFix != null && permanentFix.isNotEmpty) 'permanent_fix': permanentFix,
        'published': published,
      });
      await fetchProblemById(problemId);
      await fetchProblems();
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
