/// Knowledge Article Model per SRS §4 & §5.14.
class KnowledgeArticleModel {
  final String id;
  final String title;
  final String body;
  final String ownerId;
  final String state; // draft, published, archived
  final DateTime createdAt;
  final DateTime updatedAt;

  const KnowledgeArticleModel({
    required this.id,
    required this.title,
    required this.body,
    required this.ownerId,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPublished => state == 'published';

  factory KnowledgeArticleModel.fromJson(Map<String, dynamic> json) {
    return KnowledgeArticleModel(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      ownerId: json['owner_id'] as String,
      state: (json['state'] as String?)?.toLowerCase() ?? 'draft',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
