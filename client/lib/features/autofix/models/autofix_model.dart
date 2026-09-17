class AutoFixActionModel {
  final String id;
  final String caseId;
  final String actionType;
  final Map<String, dynamic> parameters;
  final String status;
  final String? initiatedBy;
  final String? executionOutput;
  final String? rollbackOutput;
  final String? errorMessage;
  final DateTime? executedAt;
  final DateTime? completedAt;
  final DateTime createdAt;

  AutoFixActionModel({
    required this.id,
    required this.caseId,
    required this.actionType,
    required this.parameters,
    required this.status,
    this.initiatedBy,
    this.executionOutput,
    this.rollbackOutput,
    this.errorMessage,
    this.executedAt,
    this.completedAt,
    required this.createdAt,
  });

  factory AutoFixActionModel.fromJson(Map<String, dynamic> json) {
    return AutoFixActionModel(
      id: json['id'] as String,
      caseId: json['case_id'] as String,
      actionType: json['action_type'] as String,
      parameters: json['parameters'] as Map<String, dynamic>? ?? {},
      status: json['status'] as String,
      initiatedBy: json['initiated_by'] as String?,
      executionOutput: json['execution_output'] as String?,
      rollbackOutput: json['rollback_output'] as String?,
      errorMessage: json['error_message'] as String?,
      executedAt: json['executed_at'] != null
          ? DateTime.parse(json['executed_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
