/// Represents an IT Helpdesk Case per SRS §4.1.
class CaseModel {
  final String id;
  final String referenceNumber;
  final String title;
  final String? description;
  final String type; // incident, service_request, problem, change
  final String status; // new, in_assessment, assigned, awaiting_requester, awaiting_approval, resolved, closed, cancelled
  final String priority; // p1, p2, p3, p4
  final String requesterId;
  final String? ownerId;
  final String? teamId;
  final String? site;
  final int version;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final DateTime? closedAt;
  final SLAModel? sla;

  const CaseModel({
    required this.id,
    required this.referenceNumber,
    required this.title,
    this.description,
    required this.type,
    required this.status,
    required this.priority,
    required this.requesterId,
    this.ownerId,
    this.teamId,
    this.site,
    required this.version,
    required this.createdAt,
    this.resolvedAt,
    this.closedAt,
    this.sla,
  });

  bool get isResolvedOrClosed => status == 'resolved' || status == 'closed';
  bool get isAwaitingApproval => status == 'awaiting_approval';
  bool get isAssigned => status == 'assigned';

  factory CaseModel.fromJson(Map<String, dynamic> json) {
    return CaseModel(
      id: json['id'] as String,
      referenceNumber: json['reference_number'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      type: (json['type'] as String?)?.toLowerCase() ?? 'incident',
      status: (json['status'] as String?)?.toLowerCase() ?? 'new',
      priority: (json['priority'] as String?)?.toLowerCase() ?? 'p3',
      requesterId: (json['requester_id'] ?? json['reporter_id']) as String? ?? '',
      ownerId: json['owner_id'] as String?,
      teamId: json['team_id'] as String?,
      site: json['site'] as String?,
      version: json['version'] as int? ?? 1,
      createdAt: DateTime.parse(json['created_at'] as String),
      resolvedAt: json['resolved_at'] != null ? DateTime.parse(json['resolved_at'] as String) : null,
      closedAt: json['closed_at'] != null ? DateTime.parse(json['closed_at'] as String) : null,
      sla: json['sla'] != null ? SLAModel.fromJson(json['sla'] as Map<String, dynamic>) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reference_number': referenceNumber,
      'title': title,
      'description': description,
      'type': type,
      'status': status,
      'priority': priority,
      'requester_id': requesterId,
      'owner_id': ownerId,
      'team_id': teamId,
      'site': site,
      'version': version,
      'created_at': createdAt.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
      'closed_at': closedAt?.toIso8601String(),
      'sla': sla?.toJson(),
    };
  }
}

/// 24/7 SLA Tracking Model per SRS §4.3.
class SLAModel {
  final String? id;
  final DateTime targetResponseAt;
  final DateTime targetResolveAt;
  final DateTime? respondedAt;
  final DateTime? resolvedAt;
  final bool responseBreached;
  final bool resolutionBreached;

  const SLAModel({
    this.id,
    required this.targetResponseAt,
    required this.targetResolveAt,
    this.respondedAt,
    this.resolvedAt,
    required this.responseBreached,
    required this.resolutionBreached,
  });

  factory SLAModel.fromJson(Map<String, dynamic> json) {
    final respRaw = json['responded_at'] ?? json['first_response_at'];
    return SLAModel(
      id: json['id'] as String?,
      targetResponseAt: DateTime.parse(json['target_response_at'] as String),
      targetResolveAt: DateTime.parse(json['target_resolve_at'] as String),
      respondedAt: respRaw != null ? DateTime.parse(respRaw as String) : null,
      resolvedAt: json['resolved_at'] != null ? DateTime.parse(json['resolved_at'] as String) : null,
      responseBreached: json['response_breached'] as bool? ?? false,
      resolutionBreached: json['resolution_breached'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'target_response_at': targetResponseAt.toIso8601String(),
      'target_resolve_at': targetResolveAt.toIso8601String(),
      'responded_at': respondedAt?.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
      'response_breached': responseBreached,
      'resolution_breached': resolutionBreached,
    };
  }
}

/// Case Communication Message Model per SRS §4.1.
class MessageModel {
  final String id;
  final String caseId;
  final String authorId;
  final String body;
  final String visibility; // requester_visible, internal_only
  final bool aiGenerated;
  final DateTime createdAt;

  const MessageModel({
    required this.id,
    required this.caseId,
    required this.authorId,
    required this.body,
    required this.visibility,
    this.aiGenerated = false,
    required this.createdAt,
  });

  bool get isInternalOnly => visibility == 'internal_only';
  bool get isRequesterVisible => visibility == 'requester_visible';

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      caseId: json['case_id'] as String,
      authorId: json['author_id'] as String,
      body: json['body'] as String,
      visibility: (json['visibility'] as String?)?.toLowerCase() ?? 'requester_visible',
      aiGenerated: json['ai_generated'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'case_id': caseId,
      'author_id': authorId,
      'body': body,
      'visibility': visibility,
      'ai_generated': aiGenerated,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Case Evidence Attachment Model per SRS §7.5.
class AttachmentModel {
  final String id;
  final String caseId;
  final String filename;
  final String mimeType;
  final int sizeBytes;
  final String storagePath;
  final DateTime createdAt;

  const AttachmentModel({
    required this.id,
    required this.caseId,
    required this.filename,
    required this.mimeType,
    required this.sizeBytes,
    required this.storagePath,
    required this.createdAt,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory AttachmentModel.fromJson(Map<String, dynamic> json) {
    return AttachmentModel(
      id: json['id'] as String,
      caseId: json['case_id'] as String,
      filename: json['filename'] as String,
      mimeType: json['mime_type'] as String,
      sizeBytes: json['size_bytes'] as int,
      storagePath: json['storage_path'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'case_id': caseId,
      'filename': filename,
      'mime_type': mimeType,
      'size_bytes': sizeBytes,
      'storage_path': storagePath,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
