class ProblemCaseLinkModel {
  final String id;
  final String problemId;
  final String caseId;
  final String? linkedBy;
  final DateTime linkedAt;

  ProblemCaseLinkModel({
    required this.id,
    required this.problemId,
    required this.caseId,
    this.linkedBy,
    required this.linkedAt,
  });

  factory ProblemCaseLinkModel.fromJson(Map<String, dynamic> json) {
    return ProblemCaseLinkModel(
      id: json['id'] as String,
      problemId: json['problem_id'] as String,
      caseId: json['case_id'] as String,
      linkedBy: json['linked_by'] as String?,
      linkedAt: DateTime.parse(json['linked_at'] as String),
    );
  }
}

class KnownErrorModel {
  final String id;
  final String problemId;
  final String title;
  final String symptoms;
  final String workaround;
  final String? permanentFix;
  final bool published;
  final DateTime createdAt;

  KnownErrorModel({
    required this.id,
    required this.problemId,
    required this.title,
    required this.symptoms,
    required this.workaround,
    this.permanentFix,
    required this.published,
    required this.createdAt,
  });

  factory KnownErrorModel.fromJson(Map<String, dynamic> json) {
    return KnownErrorModel(
      id: json['id'] as String,
      problemId: json['problem_id'] as String,
      title: json['title'] as String,
      symptoms: json['symptoms'] as String,
      workaround: json['workaround'] as String,
      permanentFix: json['permanent_fix'] as String?,
      published: json['published'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class ProblemModel {
  final String id;
  final String problemNumber;
  final String title;
  final String description;
  final String? rootCause;
  final String? workaround;
  final String status;
  final String priority;
  final String? ownerId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
  final List<ProblemCaseLinkModel> caseLinks;
  final List<KnownErrorModel> knownErrors;

  ProblemModel({
    required this.id,
    required this.problemNumber,
    required this.title,
    required this.description,
    this.rootCause,
    this.workaround,
    required this.status,
    required this.priority,
    this.ownerId,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
    this.caseLinks = const [],
    this.knownErrors = const [],
  });

  factory ProblemModel.fromJson(Map<String, dynamic> json) {
    return ProblemModel(
      id: json['id'] as String,
      problemNumber: json['problem_number'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      rootCause: json['root_cause'] as String?,
      workaround: json['workaround'] as String?,
      status: json['status'] as String,
      priority: json['priority'] as String,
      ownerId: json['owner_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
      caseLinks: (json['case_links'] as List<dynamic>?)
              ?.map((e) => ProblemCaseLinkModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      knownErrors: (json['known_errors'] as List<dynamic>?)
              ?.map((e) => KnownErrorModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
