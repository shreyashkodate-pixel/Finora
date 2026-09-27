import 'package:flutter/foundation.dart';
import '../../../shared/api_client.dart';
import '../models/search_model.dart';

class SearchProvider extends ChangeNotifier {
  final ApiClient _apiClient;

  SearchProvider({required ApiClient apiClient}) : _apiClient = apiClient;

  // Search state
  bool _isLoading = false;
  bool _isNLQueryLoading = false;
  bool _isHistoryLoading = false;
  String? _errorMessage;

  String _lastQuery = '';
  int _totalResults = 0;
  List<SemanticSearchResultItemModel> _searchResults = [];
  SearchEntityType _selectedEntityType = SearchEntityType.all;
  SemanticSearchResultItemModel? _selectedResult;

  // NL Query state
  NLQueryResponseModel? _nlResponse;

  // History state
  List<NLQueryLogModel> _queryHistory = [];

  // Getters
  bool get isLoading => _isLoading;
  bool get isNLQueryLoading => _isNLQueryLoading;
  bool get isHistoryLoading => _isHistoryLoading;
  String? get errorMessage => _errorMessage;

  String get lastQuery => _lastQuery;
  int get totalResults => _totalResults;
  List<SemanticSearchResultItemModel> get searchResults => _searchResults;
  SearchEntityType get selectedEntityType => _selectedEntityType;
  SemanticSearchResultItemModel? get selectedResult => _selectedResult;

  NLQueryResponseModel? get nlResponse => _nlResponse;
  List<NLQueryLogModel> get queryHistory => _queryHistory;

  List<SemanticSearchResultItemModel> get filteredResults {
    if (_selectedEntityType == SearchEntityType.all) {
      return _searchResults;
    }
    final targetType = _selectedEntityType.apiValue;
    return _searchResults.where((r) => r.entityType.toLowerCase() == targetType).toList();
  }

  void setEntityTypeFilter(SearchEntityType type) {
    _selectedEntityType = type;
    notifyListeners();
  }

  void selectResult(SemanticSearchResultItemModel? result) {
    _selectedResult = result;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearSearch() {
    _lastQuery = '';
    _searchResults = [];
    _totalResults = 0;
    _selectedResult = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Performs semantic vector search using backend /search/semantic endpoint
  Future<void> performSemanticSearch(
    String query, {
    List<String>? entityTypes,
    double minScore = 0.2,
    int limit = 20,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    _isLoading = true;
    _errorMessage = null;
    _lastQuery = trimmed;
    notifyListeners();

    try {
      final payload = <String, dynamic>{
        'query': trimmed,
        'min_score': minScore,
        'limit': limit,
      };

      if (entityTypes != null && entityTypes.isNotEmpty) {
        payload['entity_types'] = entityTypes;
      } else if (_selectedEntityType != SearchEntityType.all) {
        payload['entity_types'] = [_selectedEntityType.apiValue];
      }

      final response = await _apiClient.post(
        '/search/semantic',
        body: payload,
      );

      if (response is Map<String, dynamic>) {
        final parsed = SemanticSearchResponseModel.fromJson(response);
        _searchResults = parsed.results;
        _totalResults = parsed.totalResults;
      } else {
        _searchResults = [];
        _totalResults = 0;
      }
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _searchResults = [];
      _totalResults = 0;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred during semantic search: $e';
      _searchResults = [];
      _totalResults = 0;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Synthesizes natural language advisory answer with citations using /search/nl-query
  Future<void> askNaturalLanguageQuery(
    String query, {
    List<String>? conversationContext,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    _isNLQueryLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final payload = <String, dynamic>{
        'query': trimmed,
      };
      if (conversationContext != null && conversationContext.isNotEmpty) {
        payload['conversation_context'] = conversationContext;
      }

      final response = await _apiClient.post(
        '/search/nl-query',
        body: payload,
      );

      if (response is Map<String, dynamic>) {
        _nlResponse = NLQueryResponseModel.fromJson(response);
      }
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Failed to synthesize natural language answer: $e';
    } finally {
      _isNLQueryLoading = false;
      notifyListeners();
    }
  }

  /// Retrieves user-isolated natural language query logs using /search/history
  Future<void> fetchQueryHistory({int limit = 20}) async {
    _isHistoryLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.get(
        '/search/history',
        queryParameters: {'limit': limit},
      );

      if (response is List) {
        _queryHistory = response
            .map((item) => NLQueryLogModel.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        _queryHistory = [];
      }
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Failed to retrieve query history: $e';
    } finally {
      _isHistoryLoading = false;
      notifyListeners();
    }
  }
}
