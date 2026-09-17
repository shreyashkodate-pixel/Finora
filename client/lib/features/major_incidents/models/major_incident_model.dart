class MajorIncidentTimelineModel {
  final String id;
  final String majorIncidentId;
  final String? authorId;
  final String summary;
  final String? details;
  final DateTime eventTimestamp;

  MajorIncidentTimelineModel({
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

  MajorIncidentModel({
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
}
