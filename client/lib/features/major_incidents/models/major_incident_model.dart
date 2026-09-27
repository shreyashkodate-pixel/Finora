class MajorIncidentTimelineModel {
  final String id;
  final String majorIncidentId;
  final String? authorId;
  final String summary;
  final String? details;
  final DateTime eventTimestamp;

  const MajorIncidentTimelineModel({
    required this.id,
    required this.majorIncidentId,
    this.authorId,
    required this.summary,
    this.details,
    required this.eventTimestamp,
  });

  factory MajorIncidentTimelineModel.fromJson(Map<String, dynamic> json) {
    return MajorIncidentTimelineModel(
      id: json['id'] as String,
      majorIncidentId: json['major_incident_id'] as String,
      authorId: json['author_id'] as String?,
      summary: json['summary'] as String,
      details: json['details'] as String?,
      eventTimestamp: DateTime.parse(json['event_timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'major_incident_id': majorIncidentId,
      'author_id': authorId,
      'summary': summary,
      'details': details,
      'event_timestamp': eventTimestamp.toIso8601String(),
    };
  }

  MajorIncidentTimelineModel copyWith({
    String? id,
    String? majorIncidentId,
    String? authorId,
    String? summary,
    String? details,
    DateTime? eventTimestamp,
  }) {
    return MajorIncidentTimelineModel(
      id: id ?? this.id,
      majorIncidentId: majorIncidentId ?? this.majorIncidentId,
      authorId: authorId ?? this.authorId,
      summary: summary ?? this.summary,
      details: details ?? this.details,
      eventTimestamp: eventTimestamp ?? this.eventTimestamp,
    );
  }
}

class MajorIncidentModel {
  final String id;
  final String incidentNumber;
  final String caseId;
  final String title;
  final String status;
  final String commanderId;
  final String? bridgeUrl;
  final String? communicationsLeadId;
  final String? executiveSummary;
  final String? impactSummary;
  final DateTime declaredAt;
  final DateTime? mitigatedAt;
  final DateTime? resolvedAt;
  final String? postMortemUrl;
  final List<MajorIncidentTimelineModel> timelineEvents;

  const MajorIncidentModel({
    required this.id,
    required this.incidentNumber,
    required this.caseId,
    required this.title,
    required this.status,
    required this.commanderId,
    this.bridgeUrl,
    this.communicationsLeadId,
    this.executiveSummary,
    this.impactSummary,
    required this.declaredAt,
    this.mitigatedAt,
    this.resolvedAt,
    this.postMortemUrl,
    this.timelineEvents = const [],
  });

  bool get isDeclared => status.toLowerCase() == 'declared';
  bool get isActive => status.toLowerCase() == 'active' || isDeclared;
  bool get isMitigated => status.toLowerCase() == 'mitigated';
  bool get isResolved => status.toLowerCase() == 'resolved';
  bool get isPostMortem => status.toLowerCase() == 'post_mortem';

  factory MajorIncidentModel.fromJson(Map<String, dynamic> json) {
    return MajorIncidentModel(
      id: json['id'] as String,
      incidentNumber: json['incident_number'] as String,
      caseId: json['case_id'] as String,
      title: json['title'] as String,
      status: json['status'] as String,
      commanderId: json['commander_id'] as String,
      bridgeUrl: json['bridge_url'] as String?,
      communicationsLeadId: json['communications_lead_id'] as String?,
      executiveSummary: json['executive_summary'] as String?,
      impactSummary: json['impact_summary'] as String?,
      declaredAt: DateTime.parse(json['declared_at'] as String),
      mitigatedAt: json['mitigated_at'] != null
          ? DateTime.parse(json['mitigated_at'] as String)
          : null,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
      postMortemUrl: json['post_mortem_url'] as String?,
      timelineEvents: (json['timeline_events'] as List<dynamic>?)
              ?.map((e) => MajorIncidentTimelineModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'incident_number': incidentNumber,
      'case_id': caseId,
      'title': title,
      'status': status,
      'commander_id': commanderId,
      'bridge_url': bridgeUrl,
      'communications_lead_id': communicationsLeadId,
      'executive_summary': executiveSummary,
      'impact_summary': impactSummary,
      'declared_at': declaredAt.toIso8601String(),
      'mitigated_at': mitigatedAt?.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
      'post_mortem_url': postMortemUrl,
      'timeline_events': timelineEvents.map((e) => e.toJson()).toList(),
    };
  }

  MajorIncidentModel copyWith({
    String? id,
    String? incidentNumber,
    String? caseId,
    String? title,
    String? status,
    String? commanderId,
    String? bridgeUrl,
    String? communicationsLeadId,
    String? executiveSummary,
    String? impactSummary,
    DateTime? declaredAt,
    DateTime? mitigatedAt,
    DateTime? resolvedAt,
    String? postMortemUrl,
    List<MajorIncidentTimelineModel>? timelineEvents,
  }) {
    return MajorIncidentModel(
      id: id ?? this.id,
      incidentNumber: incidentNumber ?? this.incidentNumber,
      caseId: caseId ?? this.caseId,
      title: title ?? this.title,
      status: status ?? this.status,
      commanderId: commanderId ?? this.commanderId,
      bridgeUrl: bridgeUrl ?? this.bridgeUrl,
      communicationsLeadId: communicationsLeadId ?? this.communicationsLeadId,
      executiveSummary: executiveSummary ?? this.executiveSummary,
      impactSummary: impactSummary ?? this.impactSummary,
      declaredAt: declaredAt ?? this.declaredAt,
      mitigatedAt: mitigatedAt ?? this.mitigatedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      postMortemUrl: postMortemUrl ?? this.postMortemUrl,
      timelineEvents: timelineEvents ?? this.timelineEvents,
    );
  }
}
