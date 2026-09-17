import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../shared/theme/colors.dart';
import '../models/knowledge_model.dart';
import '../providers/knowledge_provider.dart';

/// Searchable Knowledge Base browser per SRS §5.14.
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
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Knowledge Base & SOPs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _search,
          ),
        ],
      ),
      body: Row(
        children: [
          // List column
          Expanded(
            flex: isWide ? 4 : 10,
            child: Column(
              children: [
                // Search & Filter header
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search articles, runbooks, FAQs...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    _search();
                                  },
                                )
                              : null,
                        ),
                        onSubmitted: (_) => _search(),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Published', style: TextStyle(fontSize: 12)),
                            selected: _selectedState == 'published',
                            onSelected: (val) {
                              if (val) {
                                setState(() => _selectedState = 'published');
                                _search();
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('All States', style: TextStyle(fontSize: 12)),
                            selected: _selectedState == 'all',
                            onSelected: (val) {
                              if (val) {
                                setState(() => _selectedState = 'all');
                                _search();
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.borderLight),

                // List
                Expanded(
                  child: knowProv.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : articles.isEmpty
                          ? const Center(
                              child: Text(
                                'No articles found matching search query.',
                                style: TextStyle(color: AppColors.textSecondaryLight),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: articles.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, idx) {
                                final art = articles[idx];
                                final isSelected = _selectedArticle?.id == art.id;

                                return ListTile(
                                  selected: isSelected,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(
                                      color: isSelected ? AppColors.primaryBlue : AppColors.borderLight,
                                    ),
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor: art.isPublished
                                        ? AppColors.slaHealthy.withValues(alpha: 0.15)
                                        : AppColors.statusAwaiting.withValues(alpha: 0.15),
                                    child: Icon(
                                      Icons.menu_book,
                                      size: 18,
                                      color: art.isPublished ? AppColors.slaHealthy : AppColors.statusAwaiting,
                                    ),
                                  ),
                                  title: Text(
                                    art.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    DateFormat('MMM d, yyyy').format(art.updatedAt.toLocal()),
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                                  ),
                                  trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                                  onTap: () {
                                    if (isWide) {
                                      setState(() => _selectedArticle = art);
                                    } else {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => ArticleDetailScreen(article: art),
                                        ),
                                      );
                                    }
                                  },
                                );
                              },
                            ),
                ),
              ],
            ),
          ),

          // Desktop Detail Preview column
          if (isWide) ...[
            const VerticalDivider(width: 1, color: AppColors.borderLight),
            Expanded(
              flex: 6,
              child: _selectedArticle == null
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.article_outlined, size: 48, color: AppColors.textSecondaryLight),
                          SizedBox(height: 12),
                          Text(
                            'Select an article from the list to view instructions.',
                            style: TextStyle(color: AppColors.textSecondaryLight),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: _buildArticleContent(_selectedArticle!),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildArticleContent(KnowledgeArticleModel art) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: art.isPublished
                      ? AppColors.slaHealthy.withValues(alpha: 0.15)
                      : AppColors.statusAwaiting.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  art.state.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: art.isPublished ? AppColors.slaHealthy : AppColors.statusAwaiting,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Updated ${DateFormat('MMMM d, yyyy').format(art.updatedAt.toLocal())}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            art.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
          ),
          const Divider(height: 24, color: AppColors.borderLight),
          SelectableText(
            art.body,
            style: const TextStyle(fontSize: 15, height: 1.6),
          ),
        ],
      ),
    );
  }
}

/// Mobile Article Detail Screen
class ArticleDetailScreen extends StatelessWidget {
  final KnowledgeArticleModel article;

  const ArticleDetailScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(article.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: article.isPublished
                        ? AppColors.slaHealthy.withValues(alpha: 0.15)
                        : AppColors.statusAwaiting.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    article.state.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: article.isPublished ? AppColors.slaHealthy : AppColors.statusAwaiting,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Updated ${DateFormat('MMM d, yyyy').format(article.updatedAt.toLocal())}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              article.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const Divider(height: 24, color: AppColors.borderLight),
            SelectableText(
              article.body,
              style: const TextStyle(fontSize: 15, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
