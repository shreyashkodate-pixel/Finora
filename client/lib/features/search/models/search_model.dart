import 'package:flutter/foundation.dart';

/// Supported searchable entity types across the ITIL ecosystem
enum SearchEntityType {
  all,
  caseItem,
  knowledgeArticle,
  problem,
  knownError,
  auditLog,
}

extension SearchEntityTypeExtension on SearchEntityType {
  String get apiValue {
    switch (this) {
      case SearchEntityType.all:
        return 'all';
      case SearchEntityType.caseItem:
        return 'case';
      case SearchEntityType.knowledgeArticle:
        return 'knowledge_article';
      case SearchEntityType.problem:
        return 'problem';
      case SearchEntityType.knownError:
        return 'known_error';
      case SearchEntityType.auditLog:
        return 'audit_log';
    }
  }

  String get displayName {
    switch (this) {
      case SearchEntityType.all:
        return 'All Resources';
      case SearchEntityType.caseItem:
        return 'Cases';
      case SearchEntityType.knowledgeArticle:
        return 'Knowledge Base';
      case SearchEntityType.problem:
        return 'Problems';
      case SearchEntityType.knownError:
        return 'Known Errors';
      case SearchEntityType.auditLog:
        return 'Audit Logs';
    }
  }

  static SearchEntityType fromApiValue(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'case':
        return SearchEntityType.caseItem;
      case 'knowledge_article':
      case 'article':
        return SearchEntityType.knowledgeArticle;
      case 'problem':
        return SearchEntityType.problem;
      case 'known_error':
        return SearchEntityType.knownError;
      case 'audit_log':
        return SearchEntityType.auditLog;
      default:
        return SearchEntityType.all;
    }
  }
}

/// A matched semantic vector search result item
@immutable
class SemanticSearchResultItemModel {
  final String entityType;
  final String entityId;
  final String title;
  final String contentSnippet;
  final double score;
  final Map<String, dynamic> metadata;

  const SemanticSearchResultItemModel({
    required this.entityType,
    required this.entityId,
    required this.title,
    required this.contentSnippet,
    required this.score,
    required this.metadata,
  });

  int get scorePercentage => (score * 100).clamp(0, 100).round();

  String? get status => metadata['status']?.toString() ?? metadata['state']?.toString();
  String? get category => metadata['category']?.toString();
  String? get priority => metadata['priority']?.toString();

  factory SemanticSearchResultItemModel.fromJson(Map<String, dynamic> json) {
    return SemanticSearchResultItemModel(
      entityType: json['entity_type']?.toString() ?? 'unknown',
      entityId: json['entity_id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled Resource',
      contentSnippet: json['content_snippet']?.toString() ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      metadata: json['metadata'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['metadata'])
          : {},
    );
  }

  Map<String, dynamic> toJson() => {
        'entity_type': entityType,
        'entity_id': entityId,
        'title': title,
        'content_snippet': contentSnippet,
        'score': score,
        'metadata': metadata,
      };
}

/// Container for semantic search response
@immutable
class SemanticSearchResponseModel {
  final String query;
  final int totalResults;
  final List<SemanticSearchResultItemModel> results;

  const SemanticSearchResponseModel({
    required this.query,
    required this.totalResults,
    required this.results,
  });

  factory SemanticSearchResponseModel.fromJson(Map<String, dynamic> json) {
    final rawResults = json['results'] as List<dynamic>? ?? [];
    return SemanticSearchResponseModel(
      query: json['query']?.toString() ?? '',
      totalResults: (json['total_results'] as num?)?.toInt() ?? rawResults.length,
      results: rawResults
          .map((r) => SemanticSearchResultItemModel.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Authoritative citation reference item returned by natural language discovery
@immutable
class CitationModel {
  final String entityType;
  final String entityId;
  final String title;
  final String snippet;

  const CitationModel({
    required this.entityType,
    required this.entityId,
    required this.title,
    required this.snippet,
  });

  factory CitationModel.fromJson(Map<String, dynamic> json) {
    return CitationModel(
      entityType: json['entity_type']?.toString() ?? 'resource',
      entityId: json['entity_id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Document Reference',
      snippet: json['snippet']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'entity_type': entityType,
        'entity_id': entityId,
        'title': title,
        'snippet': snippet,
      };
}

/// Natural language discovery Q&A response
@immutable
class NLQueryResponseModel {
  final String query;
  final String answer;
  final List<CitationModel> citations;
  final double confidenceScore;

  const NLQueryResponseModel({
    required this.query,
    required this.answer,
    required this.citations,
    required this.confidenceScore,
  });

  int get confidencePercentage => (confidenceScore * 100).clamp(0, 100).round();

  factory NLQueryResponseModel.fromJson(Map<String, dynamic> json) {
    final rawCitations = json['citations'] as List<dynamic>? ?? [];
    return NLQueryResponseModel(
      query: json['query']?.toString() ?? '',
      answer: json['answer']?.toString() ?? '',
      citations: rawCitations
          .map((c) => CitationModel.fromJson(c as Map<String, dynamic>))
          .toList(),
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

/// Historical query log entry
@immutable
class NLQueryLogModel {
  final String id;
  final String queryText;
  final String answerText;
  final List<CitationModel> citations;
  final double confidenceScore;
  final DateTime createdAt;

  const NLQueryLogModel({
    required this.id,
    required this.queryText,
    required this.answerText,
    required this.citations,
    required this.confidenceScore,
    required this.createdAt,
  });

  factory NLQueryLogModel.fromJson(Map<String, dynamic> json) {
    final rawCitations = json['citations'] as List<dynamic>? ?? [];
    return NLQueryLogModel(
      id: json['id']?.toString() ?? '',
      queryText: json['query_text']?.toString() ?? '',
      answerText: json['answer_text']?.toString() ?? '',
      citations: rawCitations
          .map((c) => CitationModel.fromJson(c as Map<String, dynamic>))
          .toList(),
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 1.0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())?.toUtc() ?? DateTime.now().toUtc()
          : DateTime.now().toUtc(),
    );
  }
}
