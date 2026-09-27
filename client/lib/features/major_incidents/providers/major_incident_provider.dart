import 'package:flutter/material.dart';
import '../../../shared/api_client.dart';
import '../models/major_incident_model.dart';

class MajorIncidentProvider extends ChangeNotifier {
  final ApiClient apiClient;

  List<MajorIncidentModel> _majorIncidents = [];
  MajorIncidentModel? _selectedIncident;
  bool _isLoading = false;
  bool _isDetailLoading = false;
  String? _error;
  String _searchQuery = '';

  MajorIncidentProvider({required this.apiClient});

  List<MajorIncidentModel> get allIncidents => _majorIncidents;

  List<MajorIncidentModel> get filteredIncidents => majorIncidents;

  List<MajorIncidentModel> get majorIncidents {
    if (_searchQuery.trim().isEmpty) return _majorIncidents;
    final q = _searchQuery.trim().toLowerCase();
    return _majorIncidents.where((inc) {
      return inc.incidentNumber.toLowerCase().contains(q) ||
          inc.title.toLowerCase().contains(q) ||
          (inc.impactSummary?.toLowerCase().contains(q) ?? false) ||
          (inc.executiveSummary?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  MajorIncidentModel? get selectedIncident => _selectedIncident;
  bool get isLoading => _isLoading;
  bool get isDetailLoading => _isDetailLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedIncident(MajorIncidentModel? incident) {
    _selectedIncident = incident;
    notifyListeners();
  }

  Future<void> fetchMajorIncidents({String? status}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final queryParams = <String, String>{};
      if (status != null && status.isNotEmpty) queryParams['status'] = status;

      final res = await apiClient.get('/major-incidents', queryParameters: queryParams);
      if (res is List) {
        _majorIncidents = res.map((e) => MajorIncidentModel.fromJson(e as Map<String, dynamic>)).toList();
        if (_selectedIncident != null) {
          final idx = _majorIncidents.indexWhere((i) => i.id == _selectedIncident!.id);
          if (idx != -1) {
            _selectedIncident = _majorIncidents[idx];
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

  Future<MajorIncidentModel?> fetchIncidentById(String incidentId) async {
    _isDetailLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await apiClient.get('/major-incidents/$incidentId');
      final fetched = MajorIncidentModel.fromJson(res as Map<String, dynamic>);
      _selectedIncident = fetched;
      final idx = _majorIncidents.indexWhere((i) => i.id == incidentId);
      if (idx != -1) {
        _majorIncidents[idx] = fetched;
      } else {
        _majorIncidents.add(fetched);
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

  Future<MajorIncidentModel?> declareMajorIncident({
    required String caseId,
    required String title,
    String? bridgeUrl,
    String? impactSummary,
  }) async {
    _error = null;
    try {
      final res = await apiClient.post('/major-incidents', body: {
        'case_id': caseId,
        'title': title,
        if (bridgeUrl != null && bridgeUrl.isNotEmpty) 'bridge_url': bridgeUrl,
        if (impactSummary != null && impactSummary.isNotEmpty) 'impact_summary': impactSummary,
      });
      final created = MajorIncidentModel.fromJson(res as Map<String, dynamic>);
      _majorIncidents.insert(0, created);
      _selectedIncident = created;
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

  Future<bool> addTimelineEvent({
    required String incidentId,
    required String summary,
    String? details,
  }) async {
    _error = null;
    try {
      final res = await apiClient.post('/major-incidents/$incidentId/timeline', body: {
        'summary': summary,
        if (details != null && details.isNotEmpty) 'details': details,
      });
      final newEvent = MajorIncidentTimelineModel.fromJson(res as Map<String, dynamic>);
      
      final idx = _majorIncidents.indexWhere((i) => i.id == incidentId);
      if (idx != -1) {
        final currentInc = _majorIncidents[idx];
        final updatedEvents = List<MajorIncidentTimelineModel>.from(currentInc.timelineEvents)..add(newEvent);
        final updatedInc = currentInc.copyWith(timelineEvents: updatedEvents);
        _majorIncidents[idx] = updatedInc;
        if (_selectedIncident?.id == incidentId) {
          _selectedIncident = updatedInc;
        }
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

  Future<bool> updateIncident({
    required String incidentId,
    String? status,
    String? commanderId,
    String? bridgeUrl,
    String? executiveSummary,
    String? impactSummary,
    String? postMortemUrl,
  }) async {
    _error = null;
    try {
      final res = await apiClient.patch('/major-incidents/$incidentId', body: {
        if (status != null) 'status': status,
        if (commanderId != null) 'commander_id': commanderId,
        if (bridgeUrl != null) 'bridge_url': bridgeUrl,
        if (executiveSummary != null) 'executive_summary': executiveSummary,
        if (impactSummary != null) 'impact_summary': impactSummary,
        if (postMortemUrl != null) 'post_mortem_url': postMortemUrl,
      });
      final updated = MajorIncidentModel.fromJson(res as Map<String, dynamic>);
      final idx = _majorIncidents.indexWhere((i) => i.id == incidentId);
      if (idx != -1) {
        _majorIncidents[idx] = updated;
      }
      if (_selectedIncident?.id == incidentId) {
        _selectedIncident = updated;
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
