class NotificationModel {
  final String id;
  final String userId;
  final String? caseId;
  final String title;
  final String message;
  final String eventType;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    this.caseId,
    required this.title,
    required this.message,
    required this.eventType,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      caseId: json['case_id'] as String?,
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      eventType: json['event_type'] as String? ?? 'case_created',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'case_id': caseId,
      'title': title,
      'message': message,
      'event_type': eventType,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? caseId,
    String? title,
    String? message,
    String? eventType,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      caseId: caseId ?? this.caseId,
      title: title ?? this.title,
      message: message ?? this.message,
      eventType: eventType ?? this.eventType,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
