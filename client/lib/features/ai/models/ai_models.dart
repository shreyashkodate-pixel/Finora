/// Models for AI-assisted operations and business approvals per SRS §5 & §4.

class AITriageModel {
  final String? caseId;
  final String? suggestedCategory;
  final String? suggestedPriority;
  final double confidenceScore;
  final String confidenceLevel; // low, moderate, high
  final String? reasoning;

  const AITriageModel({
    this.caseId,
    this.suggestedCategory,
    this.suggestedPriority,
    required this.confidenceScore,
    required this.confidenceLevel,
    this.reasoning,
  });

  factory AITriageModel.fromJson(Map<String, dynamic> json) {
    return AITriageModel(
      caseId: json['case_id'] as String?,
      suggestedCategory: json['suggested_category'] as String?,
      suggestedPriority: json['suggested_priority'] as String?,
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
      confidenceLevel: (json['confidence_level'] as String?)?.toLowerCase() ?? 'moderate',
      reasoning: json['reasoning'] as String?,
    );
  }
}

class CaseSummaryModel {
  final String caseId;
  final String summary;
  final int messageCount;
  final DateTime updatedAt;

  const CaseSummaryModel({
    required this.caseId,
    required this.summary,
    required this.messageCount,
    required this.updatedAt,
  });

  factory CaseSummaryModel.fromJson(Map<String, dynamic> json) {
    return CaseSummaryModel(
      caseId: json['case_id'] as String,
      summary: json['summary'] as String,
      messageCount: json['message_count'] as int? ?? 0,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class RiskAssessmentModel {
  final String caseId;
  final double riskScore;
  final String riskLevel; // low, moderate, high, critical
  final List<dynamic> signals;
  final String? recommendedAction;

  const RiskAssessmentModel({
    required this.caseId,
    required this.riskScore,
    required this.riskLevel,
    this.signals = const [],
    this.recommendedAction,
  });

  factory RiskAssessmentModel.fromJson(Map<String, dynamic> json) {
    return RiskAssessmentModel(
      caseId: json['case_id'] as String,
      riskScore: (json['risk_score'] as num?)?.toDouble() ?? 0.0,
      riskLevel: (json['risk_level'] as String?)?.toLowerCase() ?? 'low',
      signals: json['signals'] as List? ?? [],
      recommendedAction: json['recommended_action'] as String?,
    );
  }
}

class DraftModel {
  final String id;
  final String caseId;
  final String draftType;
  final String body;
  final String status;

  const DraftModel({
    required this.id,
    required this.caseId,
    required this.draftType,
    required this.body,
    required this.status,
  });

  factory DraftModel.fromJson(Map<String, dynamic> json) {
    return DraftModel(
      id: json['id'] as String,
      caseId: json['case_id'] as String,
      draftType: (json['draft_type'] as String?)?.toLowerCase() ?? 'progress_update',
      body: json['body'] as String,
      status: (json['status'] as String?)?.toLowerCase() ?? 'draft',
    );
  }
}

class ApprovalModel {
  final String id;
  final String caseId;
  final String approverId;
  final String decision; // pending, approved, rejected
  final String? reason;
  final DateTime? decidedAt;
  final DateTime createdAt;

  const ApprovalModel({
    required this.id,
    required this.caseId,
    required this.approverId,
    required this.decision,
    this.reason,
    this.decidedAt,
    required this.createdAt,
  });

  bool get isPending => decision == 'pending';
  bool get isApproved => decision == 'approved';
  bool get isRejected => decision == 'rejected';

  factory ApprovalModel.fromJson(Map<String, dynamic> json) {
    return ApprovalModel(
      id: json['id'] as String,
      caseId: json['case_id'] as String,
      approverId: json['approver_id'] as String,
      decision: (json['decision'] as String?)?.toLowerCase() ?? 'pending',
      reason: json['reason'] as String?,
      decidedAt: json['decided_at'] != null ? DateTime.parse(json['decided_at'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
