import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ai_helpdesk_client/features/auth/providers/auth_provider.dart';
import 'package:ai_helpdesk_client/features/cases/providers/case_provider.dart';
import 'package:ai_helpdesk_client/features/knowledge/providers/knowledge_provider.dart';
import 'package:ai_helpdesk_client/features/search/models/search_model.dart';
import 'package:ai_helpdesk_client/features/search/providers/search_provider.dart';
import 'package:ai_helpdesk_client/features/search/screens/semantic_search_screen.dart';
import 'package:ai_helpdesk_client/features/search/widgets/search_result_card.dart';
import 'package:ai_helpdesk_client/shared/api_client.dart';
import 'package:ai_helpdesk_client/shared/storage.dart';
import 'package:ai_helpdesk_client/shared/theme/app_theme.dart';

class MockSearchApiClient extends ApiClient {
  bool throwError = false;
  bool throwForbidden = false;
  bool returnEmpty = false;
  int searchCallCount = 0;
  int nlQueryCallCount = 0;
  int historyCallCount = 0;

  final Map<String, dynamic> mockSearchResponse = {
    'query': 'VPN connection error',
    'total_results': 3,
    'results': [
      {
        'entity_type': 'knowledge_article',
        'entity_id': 'art-101',
        'title': 'Global VPN Gateway Configuration & Troubleshooting',
        'content_snippet': 'To resolve GlobalProtect gateway timeout, flush DNS cache and re-enter credentials.',
        'score': 0.92,
        'metadata': {'state': 'published', 'category': 'Network'},
      },
      {
        'entity_type': 'case',
        'entity_id': 'case-202',
        'title': 'VPN Authentication Failure on MacOS Monterey',
        'content_snippet': 'User encountered TLS handshake error when connecting from Campus North.',
        'score': 0.85,
        'metadata': {'status': 'RESOLVED', 'priority': 'P2', 'requester_id': 'usr-req-1'},
      },
      {
        'entity_type': 'problem',
        'entity_id': 'prb-303',
        'title': 'Corporate Gateway Certificate Expiry',
        'content_snippet': 'Root cause identified as expired intermediate CA certificate.',
        'score': 0.65,
        'metadata': {'status': 'CLOSED', 'category': 'Infrastructure'},
      },
    ],
  };

  final Map<String, dynamic> mockNLQueryResponse = {
    'query': 'How do I troubleshoot VPN connection errors?',
    'answer': 'Based on our IT knowledge records:\n\n• [KNOWLEDGE_ARTICLE] Global VPN Gateway: Flush DNS and re-enter credentials.\n• [CASE] VPN Authentication Failure: TLS handshake error on MacOS resolved.\n\nPlease follow these steps to connect.',
    'confidence_score': 0.95,
    'citations': [
      {
        'entity_type': 'knowledge_article',
        'entity_id': 'art-101',
        'title': 'Global VPN Gateway Configuration',
        'snippet': 'Flush DNS cache and re-enter credentials.',
      },
      {
        'entity_type': 'case',
        'entity_id': 'case-202',
        'title': 'VPN Authentication Failure',
        'snippet': 'TLS handshake error on MacOS Monterey.',
      },
    ],
  };

  final List<Map<String, dynamic>> mockHistoryResponse = [
    {
      'id': 'log-001',
      'query_text': 'How do I troubleshoot VPN connection errors?',
      'answer_text': 'Based on our IT knowledge records, flush DNS cache and re-enter credentials.',
      'confidence_score': 0.95,
      'created_at': DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String(),
      'citations': [
        {
          'entity_type': 'knowledge_article',
          'entity_id': 'art-101',
          'title': 'Global VPN Gateway Configuration',
          'snippet': 'Flush DNS cache.',
        },
      ],
    },
  ];

  MockSearchApiClient() : super(baseUrl: 'http://localhost:8000');

  @override
  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    String? idempotencyKey,
  }) async {
    if (throwForbidden) {
      throw ApiException(
        statusCode: 403,
        code: 'FORBIDDEN',
        message: 'Unauthorized access to restricted operational data.',
      );
    }
    if (throwError) {
      throw ApiException(
        statusCode: 500,
        code: 'INTERNAL_ERROR',
        message: 'Semantic embedding backend service unavailable.',
      );
    }

    if (endpoint == '/search/semantic') {
      searchCallCount++;
      if (returnEmpty) {
        return {'query': body?['query'] ?? '', 'total_results': 0, 'results': []};
      }
      return mockSearchResponse;
    }

    if (endpoint == '/search/nl-query') {
      nlQueryCallCount++;
      if (returnEmpty) {
        return {
          'query': body?['query'] ?? '',
          'answer': 'No relevant information found.',
          'confidence_score': 0.20,
          'citations': [],
        };
      }
      return mockNLQueryResponse;
    }

    return {};
  }

  @override
  Future<dynamic> get(String endpoint, {Map<String, dynamic>? queryParameters}) async {
    if (throwForbidden) {
      throw ApiException(
        statusCode: 403,
        code: 'FORBIDDEN',
        message: 'Access denied to search history.',
      );
    }
    if (throwError) {
      throw ApiException(
        statusCode: 500,
        code: 'INTERNAL_ERROR',
        message: 'Failed to retrieve history.',
      );
    }

    if (endpoint == '/search/history') {
      historyCallCount++;
      if (returnEmpty) return [];
      return mockHistoryResponse;
    }

    return {};
  }
}

Widget _createTestApp({
  required MockSearchApiClient apiClient,
}) {
  final storage = SessionStorage();
  final authProvider = AuthProvider(apiClient: apiClient, storage: storage);
  final searchProvider = SearchProvider(apiClient: apiClient);
  final caseProvider = CaseProvider(apiClient: apiClient);
  final knowledgeProvider = KnowledgeProvider(apiClient: apiClient);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ChangeNotifierProvider<SearchProvider>.value(value: searchProvider),
      ChangeNotifierProvider<CaseProvider>.value(value: caseProvider),
      ChangeNotifierProvider<KnowledgeProvider>.value(value: knowledgeProvider),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: const SemanticSearchScreen(),
    ),
  );
}

void main() {
  group('Phase 4A: Models & Serialization Tests', () {
    test('SemanticSearchResultItemModel serializes and deserializes correctly', () {
      final json = {
        'entity_type': 'case',
        'entity_id': 'c-100',
        'title': 'Network Issue',
        'content_snippet': 'Wi-Fi dropped on 3rd floor',
        'score': 0.885,
        'metadata': {'status': 'ASSIGNED', 'priority': 'P1', 'category': 'Network'},
      };

      final model = SemanticSearchResultItemModel.fromJson(json);
      expect(model.entityType, 'case');
      expect(model.entityId, 'c-100');
      expect(model.scorePercentage, 89);
      expect(model.status, 'ASSIGNED');
      expect(model.priority, 'P1');
      expect(model.category, 'Network');
      expect(model.toJson()['title'], 'Network Issue');
    });

    test('NLQueryResponseModel and CitationModel parse correctly', () {
      final json = {
        'query': 'VPN connection',
        'answer': 'Follow VPN guide.',
        'confidence_score': 0.92,
        'citations': [
          {
            'entity_type': 'knowledge_article',
            'entity_id': 'k-1',
            'title': 'VPN Guide',
            'snippet': 'Restart VPN client',
          }
        ],
      };

      final response = NLQueryResponseModel.fromJson(json);
      expect(response.query, 'VPN connection');
      expect(response.confidencePercentage, 92);
      expect(response.citations.length, 1);
      expect(response.citations.first.entityType, 'knowledge_article');
      expect(response.citations.first.title, 'VPN Guide');
    });

    test('NLQueryLogModel parses timestamp and fields', () {
      final json = {
        'id': 'log-1',
        'query_text': 'Printer setup',
        'answer_text': 'Connect to print server',
        'confidence_score': 0.80,
        'created_at': '2026-09-21T10:00:00Z',
        'citations': [],
      };

      final log = NLQueryLogModel.fromJson(json);
      expect(log.id, 'log-1');
      expect(log.queryText, 'Printer setup');
      expect(log.confidenceScore, 0.80);
      expect(log.createdAt.year, 2026);
    });
  });

  group('Phase 4A: UI & Interaction Widget Tests', () {
    testWidgets('renders SemanticSearchScreen header, query bar, mode chips, and filters', (tester) async {
      final apiClient = MockSearchApiClient();
      await tester.pumpWidget(_createTestApp(apiClient: apiClient));
      await tester.pumpAndSettle();

      expect(find.text('Enterprise Discovery & Semantic Search'), findsOneWidget);
      expect(find.text('Vector Search'), findsOneWidget);
      expect(find.text('Natural Language Q&A'), findsOneWidget);
      expect(find.text('Query History'), findsOneWidget);
      expect(find.text('All Resources'), findsOneWidget);
      expect(find.text('Cases'), findsOneWidget);
      expect(find.text('Knowledge Base'), findsOneWidget);
    });

    testWidgets('executes vector search on Enter / Search button click and renders result cards', (tester) async {
      final apiClient = MockSearchApiClient();
      await tester.pumpWidget(_createTestApp(apiClient: apiClient));
      await tester.pumpAndSettle();

      // Enter query
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'VPN connection error');
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      expect(apiClient.searchCallCount, 1);
      expect(find.text('Found 3 relevant records'), findsOneWidget);
      expect(find.text('Global VPN Gateway Configuration & Troubleshooting'), findsOneWidget);
      expect(find.text('92% match'), findsOneWidget);
      expect(find.text('VPN Authentication Failure on MacOS Monterey'), findsOneWidget);
    });

    testWidgets('filters results by entity type chip', (tester) async {
      final apiClient = MockSearchApiClient();
      await tester.pumpWidget(_createTestApp(apiClient: apiClient));
      await tester.pumpAndSettle();

      // Perform search
      await tester.enterText(find.byType(TextField), 'VPN error');
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      expect(find.text('Found 3 relevant records'), findsOneWidget);

      // Select 'Cases' filter chip
      await tester.tap(find.text('Cases'));
      await tester.pumpAndSettle();

      // Should now only show the 1 case item
      expect(find.text('Found 1 relevant record'), findsOneWidget);
      expect(find.text('VPN Authentication Failure on MacOS Monterey'), findsOneWidget);
      expect(find.text('Global VPN Gateway Configuration & Troubleshooting'), findsNothing);
    });

    testWidgets('displays empty state when no results match', (tester) async {
      final apiClient = MockSearchApiClient();
      apiClient.returnEmpty = true;

      await tester.pumpWidget(_createTestApp(apiClient: apiClient));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Nonexistent random topic 12345');
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      expect(find.text('No matching operational records found'), findsOneWidget);
    });

    testWidgets('displays error state on API failure with working retry button', (tester) async {
      final apiClient = MockSearchApiClient();
      apiClient.throwError = true;

      await tester.pumpWidget(_createTestApp(apiClient: apiClient));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'VPN crash');
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      expect(find.text('Search Operation Failed'), findsOneWidget);
      expect(find.text('Semantic embedding backend service unavailable.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Fix error and retry
      apiClient.throwError = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Found 3 relevant records'), findsOneWidget);
    });

    testWidgets('handles Natural Language Q&A mode, prompt suggestions, and citations', (tester) async {
      final apiClient = MockSearchApiClient();
      await tester.pumpWidget(_createTestApp(apiClient: apiClient));
      await tester.pumpAndSettle();

      // Switch to Natural Language Q&A mode
      await tester.tap(find.text('Natural Language Q&A'));
      await tester.pumpAndSettle();

      expect(find.text('SUGGESTED DISCOVERY QUERIES'), findsOneWidget);
      expect(find.text('AI Discovery Synthesis is advisory. Findings are synthesized strictly from indexed operational records.'), findsOneWidget);

      // Tap on a suggested query chip
      final promptChip = find.text('How do I troubleshoot VPN connection errors?');
      expect(promptChip, findsOneWidget);
      await tester.tap(promptChip);
      await tester.pumpAndSettle();

      expect(apiClient.nlQueryCallCount, 1);
      expect(find.text('Synthesized Discovery Answer'), findsOneWidget);
      expect(find.text('95% Confidence'), findsOneWidget);
      expect(find.text('AUTHORITATIVE CITATIONS (2)'), findsOneWidget);
      expect(find.text('Global VPN Gateway Configuration'), findsOneWidget);
    });

    testWidgets('loads and renders Query History tab', (tester) async {
      final apiClient = MockSearchApiClient();
      await tester.pumpWidget(_createTestApp(apiClient: apiClient));
      await tester.pumpAndSettle();

      // Switch to Query History
      await tester.tap(find.text('Query History'));
      await tester.pumpAndSettle();

      expect(apiClient.historyCallCount, 1);
      expect(find.text('How do I troubleshoot VPN connection errors?'), findsOneWidget);
      expect(find.text('1 citation'), findsOneWidget);
    });

    testWidgets('desktop master-detail pane renders selected result preview and allows navigation', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final apiClient = MockSearchApiClient();
      await tester.pumpWidget(_createTestApp(apiClient: apiClient));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'VPN');
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      // Tap first result
      await tester.tap(find.text('Global VPN Gateway Configuration & Troubleshooting'));
      await tester.pumpAndSettle();

      // Right preview pane should now show full record details
      expect(find.text('MATCHED CONTENT SNIPPET'), findsOneWidget);
      expect(find.text('Open Full Record'), findsOneWidget);
      expect(find.text('92% Relevance Score'), findsOneWidget);
    });

    testWidgets('handles 403 Forbidden on unauthorized audit-log/restricted search without leaking data', (tester) async {
      final apiClient = MockSearchApiClient();
      apiClient.throwForbidden = true;

      await tester.pumpWidget(_createTestApp(apiClient: apiClient));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Audit Logs System Events');
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      expect(find.text('Search Operation Failed'), findsOneWidget);
      expect(find.text('Unauthorized access to restricted operational data.'), findsOneWidget);
      // Verify no result cards or leaked data rendered
      expect(find.byType(SearchResultCard), findsNothing);
    });
  });
}
