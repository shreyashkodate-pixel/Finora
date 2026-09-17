import 'package:flutter/foundation.dart';
import '../../../shared/api_client.dart';
import '../../ai/models/ai_models.dart';

/// Manages multi-tier approval requests and decisions per SRS §4 & §6.1.
class ApprovalProvider extends ChangeNotifier {
  final ApiClient apiClient;

  List<ApprovalModel> _caseApprovals = [];
  List<ApprovalModel> _pendingApprovals = [];
  bool _isLoading = false;
  bool _isActionLoading = false;
  String? _errorMessage;

  ApprovalProvider({required this.apiClient});

  List<ApprovalModel> get caseApprovals => _caseApprovals;
  List<ApprovalModel> get pendingApprovals => _pendingApprovals;
  bool get isLoading => _isLoading;
  bool get isActionLoading => _isActionLoading;
  String? get errorMessage => _errorMessage;

  /// Fetch all approval requests and historical decisions for a case
  Future<void> fetchApprovalsForCase(String caseId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await apiClient.get('/cases/$caseId/approvals');
      final rawList = (res as List?) ?? [];
      _caseApprovals = rawList.map((a) => ApprovalModel.fromJson(a as Map<String, dynamic>)).toList();
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = 'Failed to load approvals.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// List pending approvals awaiting decision by the current user / role
  Future<void> fetchPendingApprovals() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await apiClient.get('/approvals/pending');
      final rawList = (res as Map<String, dynamic>)['items'] as List? ?? [];
      _pendingApprovals = rawList.map((a) => ApprovalModel.fromJson(a as Map<String, dynamic>)).toList();
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = 'Failed to load pending approvals inbox.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Request approval on an ASSIGNED case
  Future<bool> requestApproval({
    required String caseId,
    required String approverId,
    String? reason,
  }) async {
    _isActionLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await apiClient.post(
        '/cases/$caseId/approvals',
        body: {'approver_id': approverId, 'reason': reason},
      );
      final newAppr = ApprovalModel.fromJson(res as Map<String, dynamic>);
      _caseApprovals.insert(0, newAppr);
      _isActionLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isActionLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Failed to request approval.';
      _isActionLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Submit decision (approved / rejected) with optional justification
  Future<bool> decideApproval({
    required String approvalId,
    required String decision,
    String? reason,
  }) async {
    _isActionLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await apiClient.post(
        '/approvals/$approvalId/decision',
        body: {'decision': decision, 'reason': reason},
      );
      final updated = ApprovalModel.fromJson(res as Map<String, dynamic>);

      // Update in lists
      final cIdx = _caseApprovals.indexWhere((a) => a.id == approvalId);
      if (cIdx != -1) _caseApprovals[cIdx] = updated;

      _pendingApprovals.removeWhere((a) => a.id == approvalId);

      _isActionLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isActionLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Failed to record approval decision.';
      _isActionLoading = false;
      notifyListeners();
      return false;
    }
  }
}
