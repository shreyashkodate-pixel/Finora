import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../shared/theme/colors.dart';
import '../../../shared/theme/dimensions.dart';
import '../../../shared/theme/typography.dart';
import '../../../shared/widgets/custom_buttons.dart';
import '../../cases/screens/case_detail_screen.dart';
import '../../knowledge/models/knowledge_model.dart';
import '../../knowledge/screens/knowledge_browser_screen.dart';
import '../models/search_model.dart';
import '../providers/search_provider.dart';
import '../widgets/citation_card.dart';
import '../widgets/search_result_card.dart';

enum SearchScreenMode {
  vectorSearch,
  nlDiscovery,
  history,
}

class SemanticSearchScreen extends StatefulWidget {
  const SemanticSearchScreen({super.key});

  @override
  State<SemanticSearchScreen> createState() => _SemanticSearchScreenState();
}

class _SemanticSearchScreenState extends State<SemanticSearchScreen> {
  final TextEditingController _queryController = TextEditingController();
  SearchScreenMode _currentMode = SearchScreenMode.vectorSearch;

  // Suggested NL query templates
  static const List<String> _suggestedPrompts = [
    'How do I troubleshoot VPN connection errors?',
    'Show recurring network outage cases from this month',
    'Find known errors related to LDAP authentication',
    'Steps to configure enterprise email on mobile',
  ];

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _onSearchSubmit() {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    final searchProv = context.read<SearchProvider>();

    if (_currentMode == SearchScreenMode.nlDiscovery) {
      searchProv.askNaturalLanguageQuery(query);
    } else {
      searchProv.performSemanticSearch(query);
    }
  }

  void _onPromptChipSelected(String prompt) {
    _queryController.text = prompt;
    setState(() {
      _currentMode = SearchScreenMode.nlDiscovery;
    });
    context.read<SearchProvider>().askNaturalLanguageQuery(prompt);
  }

  void _navigateToEntity(String entityType, String entityId, String title, String snippet) {
    final type = entityType.toLowerCase().trim();

    if (type == 'case') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CaseDetailScreen(caseId: entityId),
        ),
      );
    } else if (type == 'knowledge_article' || type == 'article') {
      final article = KnowledgeArticleModel(
        id: entityId,
        title: title,
        body: snippet,
        ownerId: '',
        state: 'published',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ArticleDetailScreen(article: article),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Viewing $entityType record ($entityId)'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchProv = context.watch<SearchProvider>();
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header & Query Bar
            _buildHeaderAndQueryBar(context, searchProv),

            // Mode Navigation Bar & Filters
            _buildModeAndFilterBar(context, searchProv),

            const Divider(height: 1, color: AppColors.borderLight),

            // Main Body Content
            Expanded(
              child: _buildBodyContent(context, searchProv, isDesktop),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderAndQueryBar(BuildContext context, SearchProvider searchProv) {
    final isNL = _currentMode == SearchScreenMode.nlDiscovery;

    return Container(
      color: AppColors.surfaceLight,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spaceMd,
        vertical: AppDimensions.spaceSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.travel_explore_rounded,
                size: 22,
                color: AppColors.primaryBlue,
              ),
              const SizedBox(width: 8),
              Text(
                'Enterprise Discovery & Semantic Search',
                style: AppTypography.headlineSm.copyWith(
                  fontSize: 16,
                  color: AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Search Field + Action
          Row(
            children: [
              Expanded(
                child: Container(
                  height: AppDimensions.inputHeight,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: AppDimensions.buttonBorderRadius,
                    border: Border.all(color: AppColors.borderLight, width: 1),
                  ),
                  child: TextField(
                    controller: _queryController,
                    onSubmitted: (_) => _onSearchSubmit(),
                    style: AppTypography.bodyMd,
                    decoration: InputDecoration(
                      hintText: isNL
                          ? 'Ask natural language question (e.g. "How to troubleshoot VPN?")...'
                          : 'Enter semantic search query, symptom, or topic...',
                      hintStyle: AppTypography.bodyMd.copyWith(color: AppColors.textSecondaryLight),
                      prefixIcon: Icon(
                        isNL ? Icons.psychology_rounded : Icons.search_rounded,
                        size: 20,
                        color: isNL ? AppColors.aiAccent : AppColors.textSecondaryLight,
                      ),
                      suffixIcon: _queryController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.textSecondaryLight),
                              onPressed: () {
                                _queryController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PrimaryButton(
                label: isNL ? 'Synthesize' : 'Search',
                icon: isNL ? Icons.auto_awesome : Icons.search,
                isLoading: isNL ? searchProv.isNLQueryLoading : searchProv.isLoading,
                onPressed: _onSearchSubmit,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeAndFilterBar(BuildContext context, SearchProvider searchProv) {
    return Container(
      color: AppColors.surfaceLight,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spaceMd,
        vertical: 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mode Switcher Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.manage_search_rounded, size: 16),
                      SizedBox(width: 4),
                      Text('Vector Search'),
                    ],
                  ),
                  selected: _currentMode == SearchScreenMode.vectorSearch,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _currentMode = SearchScreenMode.vectorSearch);
                    }
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.psychology_outlined, size: 16),
                      SizedBox(width: 4),
                      Text('Natural Language Q&A'),
                    ],
                  ),
                  selected: _currentMode == SearchScreenMode.nlDiscovery,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _currentMode = SearchScreenMode.nlDiscovery);
                    }
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_rounded, size: 16),
                      SizedBox(width: 4),
                      Text('Query History'),
                    ],
                  ),
                  selected: _currentMode == SearchScreenMode.history,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _currentMode = SearchScreenMode.history);
                      searchProv.fetchQueryHistory();
                    }
                  },
                ),
              ],
            ),
          ),

          // Secondary Filter Bar for Vector Search
          if (_currentMode == SearchScreenMode.vectorSearch) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(
                    'Filter: ',
                    style: AppTypography.labelSm.copyWith(color: AppColors.textSecondaryLight),
                  ),
                  ...SearchEntityType.values.map((type) {
                    final isSelected = searchProv.selectedEntityType == type;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(type.displayName),
                        selected: isSelected,
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppColors.primaryBlue : AppColors.textPrimaryLight,
                        ),
                        onSelected: (_) {
                          searchProv.setEntityTypeFilter(type);
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBodyContent(BuildContext context, SearchProvider searchProv, bool isDesktop) {
    if (searchProv.errorMessage != null) {
      return _buildErrorState(context, searchProv);
    }

    switch (_currentMode) {
      case SearchScreenMode.vectorSearch:
        return _buildVectorSearchContent(context, searchProv, isDesktop);
      case SearchScreenMode.nlDiscovery:
        return _buildNLDiscoveryContent(context, searchProv);
      case SearchScreenMode.history:
        return _buildHistoryContent(context, searchProv);
    }
  }

  Widget _buildErrorState(BuildContext context, SearchProvider searchProv) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spaceLg),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.priorityP1),
            const SizedBox(height: 12),
            Text(
              'Search Operation Failed',
              style: AppTypography.headlineSm.copyWith(color: AppColors.priorityP1),
            ),
            const SizedBox(height: 6),
            Text(
              searchProv.errorMessage ?? 'An error occurred.',
              style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondaryLight),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SecondaryButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: () {
                searchProv.clearError();
                _onSearchSubmit();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVectorSearchContent(BuildContext context, SearchProvider searchProv, bool isDesktop) {
    if (searchProv.isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Searching operational knowledge embeddings...', style: TextStyle(color: AppColors.textSecondaryLight)),
          ],
        ),
      );
    }

    final results = searchProv.filteredResults;

    if (searchProv.lastQuery.isEmpty && results.isEmpty) {
      return _buildInitialGuidance();
    }

    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_rounded, size: 48, color: AppColors.textSecondaryLight),
              const SizedBox(height: 12),
              Text(
                'No matching operational records found',
                style: AppTypography.headlineSm.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                'Try adjusting your search terms, changing the entity filter, or phrasing as a natural language question.',
                style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Results list
          Expanded(
            flex: 5,
            child: _buildResultsList(context, searchProv, results, true),
          ),
          const VerticalDivider(width: 1, color: AppColors.borderLight),
          // Right: Detail preview pane
          Expanded(
            flex: 5,
            child: _buildResultPreviewPane(context, searchProv),
          ),
        ],
      );
    } else {
      return _buildResultsList(context, searchProv, results, false);
    }
  }

  Widget _buildResultsList(
    BuildContext context,
    SearchProvider searchProv,
    List<SemanticSearchResultItemModel> results,
    bool isDesktop,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Result summary banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceMd, vertical: 8),
          color: AppColors.surfaceMuted,
          child: Row(
            children: [
              Text(
                'Found ${results.length} relevant record${results.length == 1 ? '' : 's'}',
                style: AppTypography.labelSm.copyWith(color: AppColors.textSecondaryLight),
              ),
              const Spacer(),
              Text(
                'Ranked by Cosine Similarity',
                style: AppTypography.labelSm.copyWith(color: AppColors.textSecondaryLight, fontSize: 10),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            itemCount: results.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = results[index];
              final isSelected = searchProv.selectedResult?.entityId == item.entityId;

              return SearchResultCard(
                item: item,
                isSelected: isSelected,
                onTap: () {
                  searchProv.selectResult(item);
                  if (!isDesktop) {
                    _navigateToEntity(item.entityType, item.entityId, item.title, item.contentSnippet);
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResultPreviewPane(BuildContext context, SearchProvider searchProv) {
    final selected = searchProv.selectedResult;

    if (selected == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app_outlined, size: 40, color: AppColors.textSecondaryLight),
            SizedBox(height: 12),
            Text(
              'Select a search result from the list to preview details.',
              style: TextStyle(color: AppColors.textSecondaryLight),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      selected.entityType.toUpperCase(),
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.slaHealthy.withValues(alpha: 0.1),
                      borderRadius: AppDimensions.pillBorderRadius,
                    ),
                    child: Text(
                      '${selected.scorePercentage}% Relevance Score',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.slaHealthy,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              PrimaryButton(
                label: 'Open Full Record',
                icon: Icons.open_in_new_rounded,
                onPressed: () => _navigateToEntity(
                  selected.entityType,
                  selected.entityId,
                  selected.title,
                  selected.contentSnippet,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            selected.title,
            style: AppTypography.headlineMd.copyWith(fontSize: 18),
          ),
          const Divider(height: 24, color: AppColors.borderLight),
          Text(
            'MATCHED CONTENT SNIPPET',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.textSecondaryLight,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: AppDimensions.cardBorderRadius,
              border: Border.all(color: AppColors.borderLight),
            ),
            child: SelectableText(
              selected.contentSnippet,
              style: AppTypography.bodyMd.copyWith(height: 1.5),
            ),
          ),
          if (selected.metadata.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'RECORD METADATA',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.textSecondaryLight,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.spaceMd),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: AppDimensions.cardBorderRadius,
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: selected.metadata.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 120,
                          child: Text(
                            '${entry.key}:',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            entry.value?.toString() ?? '—',
                            style: AppTypography.bodySm.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNLDiscoveryContent(BuildContext context, SearchProvider searchProv) {
    if (searchProv.isNLQueryLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Synthesizing natural language answer with citations...', style: TextStyle(color: AppColors.textSecondaryLight)),
          ],
        ),
      );
    }

    final nlResponse = searchProv.nlResponse;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Prompt suggestions
          Text(
            'SUGGESTED DISCOVERY QUERIES',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.textSecondaryLight,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestedPrompts.map((p) {
              return ActionChip(
                avatar: const Icon(Icons.auto_awesome, size: 14, color: AppColors.aiAccent),
                label: Text(p, style: const TextStyle(fontSize: 12)),
                onPressed: () => _onPromptChipSelected(p),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Advisory Disclaimer Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.aiBackground,
              borderRadius: AppDimensions.cardBorderRadius,
              border: Border.all(color: AppColors.aiBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.aiAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI Discovery Synthesis is advisory. Findings are synthesized strictly from indexed operational records.',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.textPrimaryLight,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (nlResponse != null) ...[
            // Synthesized Answer Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.spaceMd),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: AppDimensions.cardBorderRadius,
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.psychology_rounded, size: 20, color: AppColors.aiAccent),
                      const SizedBox(width: 8),
                      Text(
                        'Synthesized Discovery Answer',
                        style: AppTypography.headlineSm.copyWith(fontSize: 15),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.slaHealthy.withValues(alpha: 0.1),
                          borderRadius: AppDimensions.pillBorderRadius,
                        ),
                        child: Text(
                          '${nlResponse.confidencePercentage}% Confidence',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.slaHealthy,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: AppColors.borderLight),
                  SelectableText(
                    nlResponse.answer,
                    style: AppTypography.bodyMd.copyWith(height: 1.6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Traceable Citations
            if (nlResponse.citations.isNotEmpty) ...[
              Text(
                'AUTHORITATIVE CITATIONS (${nlResponse.citations.length})',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.textSecondaryLight,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: nlResponse.citations.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, idx) {
                  final citation = nlResponse.citations[idx];
                  return CitationCard(
                    citation: citation,
                    onTap: () => _navigateToEntity(
                      citation.entityType,
                      citation.entityId,
                      citation.title,
                      citation.snippet,
                    ),
                  );
                },
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryContent(BuildContext context, SearchProvider searchProv) {
    if (searchProv.isHistoryLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final history = searchProv.queryHistory;

    if (history.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_toggle_off_rounded, size: 48, color: AppColors.textSecondaryLight),
            SizedBox(height: 12),
            Text(
              'No previous natural language queries logged.',
              style: TextStyle(color: AppColors.textSecondaryLight),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      itemCount: history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final item = history[idx];
        return Container(
          padding: const EdgeInsets.all(AppDimensions.spaceMd),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: AppDimensions.cardBorderRadius,
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.help_outline_rounded, size: 16, color: AppColors.primaryBlue),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.queryText,
                      style: AppTypography.headlineSm.copyWith(
                        fontSize: 14,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                  Text(
                    DateFormat('MMM d, HH:mm').format(item.createdAt.toLocal()),
                    style: AppTypography.labelSm.copyWith(color: AppColors.textSecondaryLight, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.answerText,
                style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (item.citations.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.link_rounded, size: 14, color: AppColors.textSecondaryLight),
                    const SizedBox(width: 4),
                    Text(
                      '${item.citations.length} citation${item.citations.length == 1 ? '' : 's'}',
                      style: AppTypography.labelSm.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildInitialGuidance() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spaceLg),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.manage_search_rounded, size: 56, color: AppColors.primaryBlue),
            const SizedBox(height: 16),
            Text(
              'Enterprise Semantic Vector Search',
              style: AppTypography.headlineSm.copyWith(color: AppColors.textPrimaryLight),
            ),
            const SizedBox(height: 8),
            Text(
              'Search across operational cases, knowledge articles, problems, and known errors using natural semantic embeddings.',
              style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondaryLight),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _suggestedPrompts.map((p) {
                return ActionChip(
                  label: Text(p, style: const TextStyle(fontSize: 12)),
                  onPressed: () {
                    _queryController.text = p;
                    _onSearchSubmit();
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
