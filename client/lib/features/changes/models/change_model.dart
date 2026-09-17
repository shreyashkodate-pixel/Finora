class ChangeRequestModel {
  final String id;
  final String changeNumber;
  final String title;
  final String description;
  final String reason;
  final String riskLevel;
  final String changeType;
  final String status;
  final String requesterId;
  final String? cabApproverId;
  final String? problemId;
  final String implementationPlan;
  final String testPlan;
  final String rollbackPlan;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final String? cabFeedback;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChangeRequestModel({
    required this.id,
    required this.changeNumber,
    required this.title,
    required this.description,
    required this.reason,
    required this.riskLevel,
    required this.changeType,
    required this.status,
    required this.requesterId,
    this.cabApproverId,
    this.problemId,
    required this.implementationPlan,
    required this.testPlan,
    required this.rollbackPlan,
    this.scheduledStart,
    this.scheduledEnd,
    this.cabFeedback,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChangeRequestModel.fromJson(Map<String, dynamic> json) {
    return ChangeRequestModel(
      id: json['id'] as String,
      changeNumber: json['change_number'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      reason: json['reason'] as String,
      riskLevel: json['risk_level'] as String,
      changeType: json['change_type'] as String,
      status: json['status'] as String,
      requesterId: json['requester_id'] as String,
      cabApproverId: json['cab_approver_id'] as String?,
      problemId: json['problem_id'] as String?,
      implementationPlan: json['implementation_plan'] as String,
      testPlan: json['test_plan'] as String,
      rollbackPlan: json['rollback_plan'] as String,
      scheduledStart: json['scheduled_start'] != null
          ? DateTime.parse(json['scheduled_start'] as String)
          : null,
      scheduledEnd: json['scheduled_end'] != null
          ? DateTime.parse(json['scheduled_end'] as String)
          : null,
      cabFeedback: json['cab_feedback'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
