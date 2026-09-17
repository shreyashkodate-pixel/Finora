import 'package:flutter/material.dart';
import '../../../shared/api_client.dart';
import '../models/major_incident_model.dart';

class MajorIncidentProvider extends ChangeNotifier {
  final ApiClient apiClient;

  List<MajorIncidentModel> _majorIncidents = [];
  bool _isLoading = false;
  String? _error;

  MajorIncidentProvider({required this.apiClient});

  List<MajorIncidentModel> get majorIncidents => _majorIncidents;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchMajorIncidents({String? status}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final queryParams = <String, String>{};
      if (status != null) queryParams['status'] = status;

      final res = await apiClient.get('/major-incidents', queryParameters: queryParams);
      if (res is List) {
        _majorIncidents = res.map((e) => MajorIncidentModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<MajorIncidentModel?> declareMajorIncident({
    required String caseId,
    required String title,
    String? bridgeUrl,
    String? impactSummary,
  }) async {
    try {
      final res = await apiClient.post('/major-incidents', body: {
        'case_id': caseId,
        'title': title,
        if (bridgeUrl != null) 'bridge_url': bridgeUrl,
        if (impactSummary != null) 'impact_summary': impactSummary,
      });
      final created = MajorIncidentModel.fromJson(res as Map<String, dynamic>);
      _majorIncidents.insert(0, created);
      notifyListeners();
      return created;
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
    try {
      await apiClient.post('/major-incidents/$incidentId/timeline', body: {
        'summary': summary,
        if (details != null) 'details': details,
      });
      await fetchMajorIncidents();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateIncident({
    required String incidentId,
    String? status,
    String? executiveSummary,
    String? postMortemUrl,
  }) async {
    try {
      await apiClient.patch('/major-incidents/$incidentId', body: {
        if (status != null) 'status': status,
        if (executiveSummary != null) 'executive_summary': executiveSummary,
        if (postMortemUrl != null) 'post_mortem_url': postMortemUrl,
      });
      await fetchMajorIncidents();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
