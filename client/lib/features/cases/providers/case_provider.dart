import 'package:flutter/foundation.dart';
import '../../../shared/api_client.dart';
import '../models/case_model.dart';

/// Manages case list, search filtering, case workspace details, message stream, and offline caching.
class CaseProvider extends ChangeNotifier {
  final ApiClient apiClient;

  List<CaseModel> _cases = [];
  CaseModel? _selectedCase;
  List<MessageModel> _messages = [];
  List<AttachmentModel> _attachments = [];

  bool _isLoading = false;
  bool _isActionLoading = false;
  String? _errorMessage;

  // Offline read-only cache map
  final Map<String, CaseModel> _offlineCaseCache = {};

  CaseProvider({required this.apiClient});

  List<CaseModel> get cases => _cases;
  CaseModel? get selectedCase => _selectedCase;
  List<MessageModel> get messages => _messages;
  List<AttachmentModel> get attachments => _attachments;
  bool get isLoading => _isLoading;
  bool get isActionLoading => _isActionLoading;
  String? get errorMessage => _errorMessage;

  /// Fetch cases matching status, priority, or search keyword
  Future<void> fetchCases({
    String? status,
    String? priority,
    String? type,
    String? search,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final params = <String, dynamic>{};
      if (status != null && status.isNotEmpty && status != 'all') params['status'] = status;
      if (priority != null && priority.isNotEmpty && priority != 'all') params['priority'] = priority;
      if (type != null && type.isNotEmpty && type != 'all') params['type'] = type;
      if (search != null && search.trim().isNotEmpty) params['search'] = search.trim();

      final res = await apiClient.get('/cases', queryParameters: params);
      final rawList = (res as Map<String, dynamic>)['cases'] as List? ?? [];
      _cases = rawList.map((c) => CaseModel.fromJson(c as Map<String, dynamic>)).toList();

      // Populate offline cache
      for (final c in _cases) {
        _offlineCaseCache[c.id] = c;
      }
    } on ApiException catch (e) {
      _errorMessage = e.message;
      // Fallback to offline cache if network failure
      if (_offlineCaseCache.isNotEmpty) {
        _cases = _offlineCaseCache.values.toList();
      }
    } catch (e) {
      _errorMessage = 'Failed to load cases. Operating in offline cache mode.';
      if (_offlineCaseCache.isNotEmpty) {
        _cases = _offlineCaseCache.values.toList();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load comprehensive case details, timeline messages, and attachments
  Future<void> fetchCaseDetails(String caseId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final caseRes = await apiClient.get('/cases/$caseId');
      _selectedCase = CaseModel.fromJson(caseRes as Map<String, dynamic>);
      _offlineCaseCache[_selectedCase!.id] = _selectedCase!;

      // Load messages
      final msgRes = await apiClient.get('/cases/$caseId/messages');
      final rawMsgs = (msgRes as List?) ?? [];
      _messages = rawMsgs.map((m) => MessageModel.fromJson(m as Map<String, dynamic>)).toList();

      // Load attachments
      final attRes = await apiClient.get('/cases/$caseId/attachments');
      final rawAtts = (attRes as List?) ?? [];
      _attachments = rawAtts.map((a) => AttachmentModel.fromJson(a as Map<String, dynamic>)).toList();
    } on ApiException catch (e) {
      _errorMessage = e.message;
      if (_offlineCaseCache.containsKey(caseId)) {
        _selectedCase = _offlineCaseCache[caseId];
      }
    } catch (_) {
      _errorMessage = 'Could not load live case data. Showing cached content.';
      if (_offlineCaseCache.containsKey(caseId)) {
        _selectedCase = _offlineCaseCache[caseId];
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Submit a new Incident or Service Request
  Future<CaseModel?> createCase({
    required String title,
    required String description,
    required String type,
    required String priority,
    String? site,
  }) async {
    _isActionLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = {
        'title': title,
        'description': description,
        'type': type,
        'priority': priority,
        'site': site,
      };

      final res = await apiClient.post('/cases', body: body);
      final newCase = CaseModel.fromJson(res as Map<String, dynamic>);
      _cases.insert(0, newCase);
      _offlineCaseCache[newCase.id] = newCase;
      _isActionLoading = false;
      notifyListeners();
      return newCase;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isActionLoading = false;
      notifyListeners();
      return null;
    } catch (_) {
      _errorMessage = 'Failed to submit case. Please check connection.';
      _isActionLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Post a note/message (requester-visible or internal-only)
  Future<bool> addMessage({
    required String caseId,
    required String body,
    required String visibility,
  }) async {
    _isActionLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await apiClient.post(
        '/cases/$caseId/messages',
        body: {'body': body, 'visibility': visibility},
      );
      final newMsg = MessageModel.fromJson(res as Map<String, dynamic>);
      _messages.add(newMsg);
      _isActionLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isActionLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Failed to send message.';
      _isActionLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Transition case status (with optimistic locking version check)
  Future<bool> updateStatus({
    required String caseId,
    required String newStatus,
    required int currentVersion,
  }) async {
    _isActionLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await apiClient.patch(
        '/cases/$caseId/status',
        body: {'status': newStatus, 'version': currentVersion},
      );
      _selectedCase = CaseModel.fromJson(res as Map<String, dynamic>);
      _offlineCaseCache[_selectedCase!.id] = _selectedCase!;

      // Update in list
      final idx = _cases.indexWhere((c) => c.id == caseId);
      if (idx != -1) _cases[idx] = _selectedCase!;

      _isActionLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isActionLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Failed to update case status.';
      _isActionLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Reopen a resolved/closed case within 7-day window per SRS §4.1
  Future<bool> reopenCase({
    required String caseId,
    required String reason,
    required int currentVersion,
  }) async {
    _isActionLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await apiClient.post(
        '/cases/$caseId/reopen',
        body: {'reason': reason, 'version': currentVersion},
      );
      _selectedCase = CaseModel.fromJson(res as Map<String, dynamic>);
      _offlineCaseCache[_selectedCase!.id] = _selectedCase!;

      final idx = _cases.indexWhere((c) => c.id == caseId);
      if (idx != -1) _cases[idx] = _selectedCase!;

      _isActionLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isActionLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Failed to reopen case.';
      _isActionLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
