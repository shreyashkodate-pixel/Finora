import 'package:flutter/foundation.dart';
import '../../../shared/api_client.dart';
import '../models/knowledge_model.dart';

/// Manages Knowledge Base search, listing, and contextual case suggestions per SRS §5.14.
class KnowledgeProvider extends ChangeNotifier {
  final ApiClient apiClient;

  List<KnowledgeArticleModel> _articles = [];
  List<KnowledgeArticleModel> _caseSuggestions = [];
  bool _isLoading = false;
  String? _errorMessage;

  KnowledgeProvider({required this.apiClient});

  List<KnowledgeArticleModel> get articles => _articles;
  List<KnowledgeArticleModel> get caseSuggestions => _caseSuggestions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Fetch or search knowledge articles
  Future<void> fetchArticles({String? search, String? state}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final params = <String, dynamic>{};
      if (search != null && search.trim().isNotEmpty) params['search'] = search.trim();
      if (state != null && state.isNotEmpty) params['state'] = state;

      final res = await apiClient.get('/knowledge', queryParameters: params);
      final rawList = (res as Map<String, dynamic>)['items'] as List? ?? [];
      _articles = rawList.map((a) => KnowledgeArticleModel.fromJson(a as Map<String, dynamic>)).toList();
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = 'Failed to load knowledge articles.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch contextual recommendations for an active case
  Future<void> fetchSuggestionsForCase(String caseId) async {
    try {
      final res = await apiClient.get('/knowledge/suggestions/case/$caseId');
      final rawList = (res as List?) ?? [];
      _caseSuggestions = rawList.map((a) => KnowledgeArticleModel.fromJson(a as Map<String, dynamic>)).toList();
      notifyListeners();
    } catch (_) {}
  }
}
