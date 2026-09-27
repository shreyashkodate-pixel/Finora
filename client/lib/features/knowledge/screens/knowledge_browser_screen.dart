import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../shared/responsive/breakpoints.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/dimensions.dart';
import '../../../shared/theme/typography.dart';
import '../../../shared/widgets/custom_buttons.dart';
import '../../../shared/widgets/page_header.dart';
import '../models/knowledge_model.dart';
import '../providers/knowledge_provider.dart';

/// Stitch-aligned Knowledge Base Browser & SOP Hub
/// Corresponds to Stitch design: knowledge_base_browser_ai_auto_drafter & knowledge_article_rich_viewer
class KnowledgeBrowserScreen extends StatefulWidget {
  const KnowledgeBrowserScreen({super.key});

  @override
  State<KnowledgeBrowserScreen> createState() => _KnowledgeBrowserScreenState();
}

class _KnowledgeBrowserScreenState extends State<KnowledgeBrowserScreen> {
  final _searchController = TextEditingController();
  String _selectedState = 'published';
  KnowledgeArticleModel? _selectedArticle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KnowledgeProvider>().fetchArticles(state: _selectedState);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    context.read<KnowledgeProvider>().fetchArticles(
          search: _searchController.text.trim(),
          state: _selectedState == 'all' ? null : _selectedState,
        );
  }

  @override
  Widget build(BuildContext context) {
    final knowProv = context.watch<KnowledgeProvider>();
    final articles = knowProv.articles;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= ResponsiveBreakpoints.desktopMin;

          return Padding(
            padding: const EdgeInsets.all(AppDimensions.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Page Header
                PageHeader(
                  title: 'Knowledge Base & Standard Operating Procedures',
                  subtitle: 'Curated technical runbooks, troubleshooting guides, and self-service resolutions.',
                  actions: [
                    CustomButtons.secondary(
                      text: 'Refresh Hub',
                      icon: Icons.refresh,
                      isLoading: knowProv.isLoading,
                      onPressed: _search,
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spaceLg),

                // 2. Search & State Filter Bar (Stitch style)
                Container(
                  padding: const EdgeInsets.all(AppDimensions.spaceMd),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search runbooks, error codes, VPN setup, hardware SOPs...',
                            prefixIcon: const Icon(Icons.search, color: AppColors.textSecondaryLight),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      _search();
                                    },
                                  )
                                : null,
                          ),
                          onSubmitted: (_) => _search(),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spaceMd),
                      FilterChip(
                        label: const Text('Published Only'),
                        selected: _selectedState == 'published',
                        onSelected: (sel) {
                          setState(() => _selectedState = sel ? 'published' : 'all');
                          _search();
                        },
                        selectedColor: AppColors.primaryContainer,
                        labelStyle: AppTypography.labelSm.copyWith(
                          color: _selectedState == 'published' ? AppColors.primaryBlue : AppColors.textPrimaryLight,
                          fontWeight: _selectedState == 'published' ? FontWeight.bold : FontWeight.w500,
                        ),
                        side: BorderSide(
                          color: _selectedState == 'published' ? AppColors.primaryBlue : AppColors.borderLight,
                        ),
                      ),
                      const SizedBox(width: 8),
                      CustomButtons.primary(
                        text: 'Search',
                        icon: Icons.search,
                        onPressed: _search,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceLg),

                // 3. Main Content: Master-Detail on Desktop, List on Mobile
                Expanded(
                  child: isWide
                      ? _buildDesktopMasterDetail(articles, knowProv.isLoading)
                      : _buildMobileArticleList(articles, knowProv.isLoading),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDesktopMasterDetail(List<KnowledgeArticleModel> articles, bool isLoading) {
    if (isLoading && articles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (articles.isEmpty) {
      return _buildEmptyState();
    }

    final activeArticle = _selectedArticle ?? articles.first;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Master List Column (40% width)
        Expanded(
          flex: 4,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppDimensions.spaceMd),
              itemCount: articles.length,
              separatorBuilder: (_, __) => const Divider(color: AppColors.borderLight, height: 16),
              itemBuilder: (context, idx) {
                final art = articles[idx];
                final isSelected = activeArticle.id == art.id;

                return InkWell(
                  onTap: () => setState(() => _selectedArticle = art),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primaryContainer.withValues(alpha: 0.5) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? AppColors.primaryBlue : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                art.state.toUpperCase(),
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.primaryBlue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              DateFormat('MMM d, yyyy').format(art.createdAt),
                              style: AppTypography.bodySm.copyWith(
                                color: AppColors.textSecondaryLight,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          art.title,
                          style: AppTypography.headlineSm.copyWith(fontSize: 15),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          art.body,
                          style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.spaceLg),

        // Detail Article Viewer Column (60% width)
        Expanded(
          flex: 6,
          child: _buildArticleViewer(activeArticle),
        ),
      ],
    );
  }

  Widget _buildMobileArticleList(List<KnowledgeArticleModel> articles, bool isLoading) {
    if (isLoading && articles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (articles.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      itemCount: articles.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, idx) {
        final art = articles[idx];
        return Container(
          padding: const EdgeInsets.all(AppDimensions.spaceMd),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      art.state.toUpperCase(),
                      style: AppTypography.labelSm.copyWith(color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    DateFormat('MMM d, yyyy').format(art.createdAt),
                    style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(art.title, style: AppTypography.headlineSm),
              const SizedBox(height: 6),
              Text(
                art.body,
                style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondaryLight),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              CustomButtons.secondary(
                text: 'Read Guide',
                icon: Icons.menu_book,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ArticleDetailScreen(article: art),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildArticleViewer(KnowledgeArticleModel article, {ScrollController? scrollController}) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceLg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: SingleChildScrollView(
        controller: scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_outlined, size: 14, color: AppColors.primaryBlue),
                      const SizedBox(width: 4),
                      Text(
                        'Verified SOP • ${article.state.toUpperCase()}',
                        style: AppTypography.labelSm.copyWith(color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  'Updated ${DateFormat("MMM d, yyyy").format(article.updatedAt)}',
                  style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              article.title,
              style: AppTypography.headlineLg,
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.borderLight),
            const SizedBox(height: 16),
            Text(
              article.body,
              style: AppTypography.bodyLg.copyWith(
                color: AppColors.textPrimaryLight,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.spaceXl),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book_outlined, size: 48, color: AppColors.textSecondaryLight),
            const SizedBox(height: 12),
            Text('No Articles Found', style: AppTypography.headlineSm),
            const SizedBox(height: 4),
            Text(
              'No knowledge base articles match your search or filter criteria.',
              style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondaryLight),
            ),
            const SizedBox(height: 16),
            CustomButtons.secondary(
              text: 'Clear Search',
              icon: Icons.clear,
              onPressed: () {
                _searchController.clear();
                _search();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Standalone Full-Screen Viewer for Knowledge Articles
class ArticleDetailScreen extends StatelessWidget {
  final KnowledgeArticleModel article;

  const ArticleDetailScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(article.title, style: AppTypography.headlineSm),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.spaceLg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Container(
              padding: const EdgeInsets.all(AppDimensions.spaceLg),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                        ),
                        child: Text(
                          article.state.toUpperCase(),
                          style: AppTypography.labelSm.copyWith(color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Last updated ${DateFormat("MMM d, yyyy").format(article.updatedAt)}',
                        style: AppTypography.bodySm.copyWith(color: AppColors.textSecondaryLight),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(article.title, style: AppTypography.headlineLg),
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.borderLight),
                  const SizedBox(height: 16),
                  Text(
                    article.body,
                    style: AppTypography.bodyLg.copyWith(
                      color: AppColors.textPrimaryLight,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
