import 'package:flutter/foundation.dart';
import '../../../shared/api_client.dart';
import '../models/ai_models.dart';

/// Manages Gemini AI assistance: triage suggestions, living summaries, risk signals, and drafts per SRS §5.
class AIProvider extends ChangeNotifier {
  final ApiClient apiClient;

  AITriageModel? _triage;
  CaseSummaryModel? _summary;
  RiskAssessmentModel? _risk;
  List<DraftModel> _drafts = [];

  bool _isLoading = false;
  String? _errorMessage;

  AIProvider({required this.apiClient});

  AITriageModel? get triage => _triage;
  CaseSummaryModel? get summary => _summary;
  RiskAssessmentModel? get risk => _risk;
  List<DraftModel> get drafts => _drafts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Fetch or trigger inline AI triage recommendation
  Future<void> fetchTriage(String caseId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await apiClient.post('/ai/cases/$caseId/triage');
      _triage = AITriageModel.fromJson(res as Map<String, dynamic>);
    } catch (e) {
      debugPrint('AI triage lookup fallback: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// One-click Human-in-the-Loop application of AI suggested priority/category
  Future<bool> applyTriage(String caseId, int currentVersion) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await apiClient.post(
        '/ai/cases/$caseId/triage/apply',
        body: {'version': currentVersion},
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Failed to apply triage recommendation.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Load living case summary
  Future<void> fetchSummary(String caseId) async {
    try {
      final res = await apiClient.get('/ai/cases/$caseId/summary');
      _summary = CaseSummaryModel.fromJson(res as Map<String, dynamic>);
      notifyListeners();
    } catch (_) {}
  }

  /// Force synchronous living summary refresh
  Future<void> refreshSummary(String caseId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await apiClient.post('/ai/cases/$caseId/summary/refresh');
      _summary = CaseSummaryModel.fromJson(res as Map<String, dynamic>);
    } catch (_) {} finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load proactive SLA Risk Assessment
  Future<void> fetchRisk(String caseId) async {
    try {
      final res = await apiClient.get('/ai/cases/$caseId/risk');
      _risk = RiskAssessmentModel.fromJson(res as Map<String, dynamic>);
      notifyListeners();
    } catch (_) {}
  }

  /// Request Gemini AI to compose a communication draft
  Future<DraftModel?> generateDraft(String caseId, String draftType) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await apiClient.post(
        '/ai/cases/$caseId/drafts',
        body: {'draft_type': draftType},
      );
      final draft = DraftModel.fromJson(res as Map<String, dynamic>);
      _drafts.insert(0, draft);
      _isLoading = false;
      notifyListeners();
      return draft;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (_) {
      _errorMessage = 'Failed to generate AI communication draft.';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }
}
