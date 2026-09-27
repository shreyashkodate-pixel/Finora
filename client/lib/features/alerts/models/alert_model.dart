import 'package:flutter/material.dart';
import '../../../shared/theme/colors.dart';

/// Supported external APM and observability monitoring providers
enum AlertProviderEnum {
  all,
  prometheus,
  datadog,
  sentry,
  cloudwatch,
  generic,
}

extension AlertProviderExtension on AlertProviderEnum {
  String get apiValue {
    switch (this) {
      case AlertProviderEnum.all:
        return 'all';
      case AlertProviderEnum.prometheus:
        return 'prometheus';
      case AlertProviderEnum.datadog:
        return 'datadog';
      case AlertProviderEnum.sentry:
        return 'sentry';
      case AlertProviderEnum.cloudwatch:
        return 'cloudwatch';
      case AlertProviderEnum.generic:
        return 'generic';
    }
  }

  String get displayName {
    switch (this) {
      case AlertProviderEnum.all:
        return 'All Providers';
      case AlertProviderEnum.prometheus:
        return 'Prometheus';
      case AlertProviderEnum.datadog:
        return 'Datadog';
      case AlertProviderEnum.sentry:
        return 'Sentry';
      case AlertProviderEnum.cloudwatch:
        return 'CloudWatch';
      case AlertProviderEnum.generic:
        return 'Generic Webhook';
    }
  }

  IconData get icon {
    switch (this) {
      case AlertProviderEnum.all:
        return Icons.hub_outlined;
      case AlertProviderEnum.prometheus:
        return Icons.local_fire_department_outlined;
      case AlertProviderEnum.datadog:
        return Icons.pets_outlined;
      case AlertProviderEnum.sentry:
        return Icons.bug_report_outlined;
      case AlertProviderEnum.cloudwatch:
        return Icons.cloud_outlined;
      case AlertProviderEnum.generic:
        return Icons.webhook_outlined;
    }
  }

  Color get brandColor {
    switch (this) {
      case AlertProviderEnum.all:
        return AppColors.primaryBlue;
      case AlertProviderEnum.prometheus:
        return const Color(0xFFE6522C);
      case AlertProviderEnum.datadog:
        return const Color(0xFF632CA6);
      case AlertProviderEnum.sentry:
        return const Color(0xFF362D59);
      case AlertProviderEnum.cloudwatch:
        return const Color(0xFFFF9900);
      case AlertProviderEnum.generic:
        return const Color(0xFF0284C7);
    }
  }

  static AlertProviderEnum fromApiValue(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'prometheus':
        return AlertProviderEnum.prometheus;
      case 'datadog':
        return AlertProviderEnum.datadog;
      case 'sentry':
        return AlertProviderEnum.sentry;
      case 'cloudwatch':
        return AlertProviderEnum.cloudwatch;
      case 'generic':
        return AlertProviderEnum.generic;
      default:
        return AlertProviderEnum.generic;
    }
  }
}

/// Alert Severity levels
enum AlertSeverityEnum {
  all,
  critical,
  high,
  warning,
  info,
}

extension AlertSeverityExtension on AlertSeverityEnum {
  String get apiValue {
    switch (this) {
      case AlertSeverityEnum.all:
        return 'all';
      case AlertSeverityEnum.critical:
        return 'critical';
      case AlertSeverityEnum.high:
        return 'high';
      case AlertSeverityEnum.warning:
        return 'warning';
      case AlertSeverityEnum.info:
        return 'info';
    }
  }

  String get displayName {
    switch (this) {
      case AlertSeverityEnum.all:
        return 'All Severities';
      case AlertSeverityEnum.critical:
        return 'Critical';
      case AlertSeverityEnum.high:
        return 'High';
      case AlertSeverityEnum.warning:
        return 'Warning';
      case AlertSeverityEnum.info:
        return 'Info';
    }
  }

  Color get color {
    switch (this) {
      case AlertSeverityEnum.all:
        return AppColors.textSecondaryLight;
      case AlertSeverityEnum.critical:
        return AppColors.priorityP1;
      case AlertSeverityEnum.high:
        return AppColors.priorityP2;
      case AlertSeverityEnum.warning:
        return AppColors.priorityP3;
      case AlertSeverityEnum.info:
        return AppColors.priorityP4;
    }
  }

  static AlertSeverityEnum fromApiValue(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'critical':
      case 'error':
        return AlertSeverityEnum.critical;
      case 'high':
        return AlertSeverityEnum.high;
      case 'warning':
      case 'warn':
        return AlertSeverityEnum.warning;
      case 'info':
      case 'informational':
        return AlertSeverityEnum.info;
      default:
        return AlertSeverityEnum.warning;
    }
  }
}

/// Alert Lifecycle Status
enum AlertStatusEnum {
  all,
  received,
  incidentCreated,
  correlated,
  suppressed,
  acknowledged,
  resolved,
}

extension AlertStatusExtension on AlertStatusEnum {
  String get apiValue {
    switch (this) {
      case AlertStatusEnum.all:
        return 'all';
      case AlertStatusEnum.received:
        return 'received';
      case AlertStatusEnum.incidentCreated:
        return 'incident_created';
      case AlertStatusEnum.correlated:
        return 'correlated';
      case AlertStatusEnum.suppressed:
        return 'suppressed';
      case AlertStatusEnum.acknowledged:
        return 'acknowledged';
      case AlertStatusEnum.resolved:
        return 'resolved';
    }
  }

  String get displayName {
    switch (this) {
      case AlertStatusEnum.all:
        return 'All Statuses';
      case AlertStatusEnum.received:
        return 'Received';
      case AlertStatusEnum.incidentCreated:
        return 'Incident Created';
      case AlertStatusEnum.correlated:
        return 'Correlated';
      case AlertStatusEnum.suppressed:
        return 'Suppressed';
      case AlertStatusEnum.acknowledged:
        return 'Acknowledged';
      case AlertStatusEnum.resolved:
        return 'Resolved';
    }
  }

  Color get color {
    switch (this) {
      case AlertStatusEnum.all:
        return AppColors.textSecondaryLight;
      case AlertStatusEnum.received:
        return AppColors.priorityP3;
      case AlertStatusEnum.incidentCreated:
        return AppColors.priorityP1;
      case AlertStatusEnum.correlated:
        return const Color(0xFF7C3AED);
      case AlertStatusEnum.suppressed:
        return AppColors.textSecondaryLight;
      case AlertStatusEnum.acknowledged:
        return AppColors.statusAssigned;
      case AlertStatusEnum.resolved:
        return AppColors.statusResolved;
    }
  }

  IconData get icon {
    switch (this) {
      case AlertStatusEnum.all:
        return Icons.filter_alt_outlined;
      case AlertStatusEnum.received:
        return Icons.inbox_outlined;
      case AlertStatusEnum.incidentCreated:
        return Icons.error_outline_rounded;
      case AlertStatusEnum.correlated:
        return Icons.link_rounded;
      case AlertStatusEnum.suppressed:
        return Icons.notifications_off_outlined;
      case AlertStatusEnum.acknowledged:
        return Icons.check_circle_outline_rounded;
      case AlertStatusEnum.resolved:
        return Icons.task_alt_rounded;
    }
  }

  static AlertStatusEnum fromApiValue(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'received':
        return AlertStatusEnum.received;
      case 'incident_created':
        return AlertStatusEnum.incidentCreated;
      case 'correlated':
        return AlertStatusEnum.correlated;
      case 'suppressed':
        return AlertStatusEnum.suppressed;
      case 'acknowledged':
        return AlertStatusEnum.acknowledged;
      case 'resolved':
        return AlertStatusEnum.resolved;
      default:
        return AlertStatusEnum.received;
    }
  }
}

/// Authoritative Inbound Alert model matching InboundAlertResponse schema
class InboundAlertModel {
  final String id;
  final AlertProviderEnum provider;
  final String? externalAlertId;
  final String title;
  final String severity;
  final String? description;
  final String fingerprint;
  final AlertStatusEnum status;
  final Map<String, dynamic> rawPayload;
  final String? caseId;
  final DateTime? acknowledgedAt;
  final String? acknowledgedById;
  final DateTime createdAt;
  final DateTime updatedAt;

  const InboundAlertModel({
    required this.id,
    required this.provider,
    this.externalAlertId,
    required this.title,
    required this.severity,
    this.description,
    required this.fingerprint,
    required this.status,
    required this.rawPayload,
    this.caseId,
    this.acknowledgedAt,
    this.acknowledgedById,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isAcknowledged => status == AlertStatusEnum.acknowledged || acknowledgedAt != null;
  bool get hasLinkedCase => caseId != null && caseId!.isNotEmpty;

  factory InboundAlertModel.fromJson(Map<String, dynamic> json) {
    return InboundAlertModel(
      id: json['id']?.toString() ?? '',
      provider: AlertProviderExtension.fromApiValue(json['provider']?.toString()),
      externalAlertId: json['external_alert_id']?.toString(),
      title: json['title']?.toString() ?? 'Inbound Monitoring Alert',
      severity: json['severity']?.toString() ?? 'warning',
      description: json['description']?.toString(),
      fingerprint: json['fingerprint']?.toString() ?? '',
      status: AlertStatusExtension.fromApiValue(json['status']?.toString()),
      rawPayload: json['raw_payload'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['raw_payload'] as Map)
          : <String, dynamic>{},
      caseId: json['case_id']?.toString(),
      acknowledgedAt: json['acknowledged_at'] != null
          ? DateTime.tryParse(json['acknowledged_at'].toString())?.toLocal()
          : null,
      acknowledgedById: json['acknowledged_by_id']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'provider': provider.apiValue,
      'external_alert_id': externalAlertId,
      'title': title,
      'severity': severity,
      'description': description,
      'fingerprint': fingerprint,
      'status': status.apiValue,
      'raw_payload': rawPayload,
      'case_id': caseId,
      'acknowledged_at': acknowledgedAt?.toUtc().toIso8601String(),
      'acknowledged_by_id': acknowledgedById,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}

/// Alert routing and automation rule model matching AlertRuleResponse
class AlertRuleModel {
  final String id;
  final String name;
  final AlertProviderEnum provider;
  final String? matchSeverity;
  final String? matchKeyword;
  final bool autoCreateIncident;
  final String incidentPriority;
  final String? targetTeamId;
  final bool isActive;
  final DateTime createdAt;

  const AlertRuleModel({
    required this.id,
    required this.name,
    required this.provider,
    this.matchSeverity,
    this.matchKeyword,
    required this.autoCreateIncident,
    required this.incidentPriority,
    this.targetTeamId,
    required this.isActive,
    required this.createdAt,
  });

  factory AlertRuleModel.fromJson(Map<String, dynamic> json) {
    return AlertRuleModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      provider: AlertProviderExtension.fromApiValue(json['provider']?.toString()),
      matchSeverity: json['match_severity']?.toString(),
      matchKeyword: json['match_keyword']?.toString(),
      autoCreateIncident: json['auto_create_incident'] as bool? ?? true,
      incidentPriority: json['incident_priority']?.toString() ?? 'p2',
      targetTeamId: json['target_team_id']?.toString(),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'provider': provider.apiValue,
      'match_severity': matchSeverity,
      'match_keyword': matchKeyword,
      'auto_create_incident': autoCreateIncident,
      'incident_priority': incidentPriority,
      'target_team_id': targetTeamId,
      'is_active': isActive,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}

/// Payload for creating a new AlertRule via POST /api/v1/integrations/alerts/rules
class AlertRuleCreatePayload {
  final String name;
  final AlertProviderEnum provider;
  final String? matchSeverity;
  final String? matchKeyword;
  final bool autoCreateIncident;
  final String incidentPriority;
  final String? targetTeamId;

  const AlertRuleCreatePayload({
    required this.name,
    this.provider = AlertProviderEnum.generic,
    this.matchSeverity,
    this.matchKeyword,
    this.autoCreateIncident = true,
    this.incidentPriority = 'p2',
    this.targetTeamId,
  });

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'name': name,
      'provider': provider.apiValue,
      'auto_create_incident': autoCreateIncident,
      'incident_priority': incidentPriority.toLowerCase(),
    };
    if (matchSeverity != null && matchSeverity!.trim().isNotEmpty) {
      data['match_severity'] = matchSeverity!.trim().toLowerCase();
    }
    if (matchKeyword != null && matchKeyword!.trim().isNotEmpty) {
      data['match_keyword'] = matchKeyword!.trim();
    }
    if (targetTeamId != null && targetTeamId!.trim().isNotEmpty) {
      data['target_team_id'] = targetTeamId!.trim();
    }
    return data;
  }
}

/// Client-computed telemetry stats summary calculated from authoritative alert feed
class AlertStatsModel {
  final int totalAlerts;
  final int criticalHighCount;
  final int unacknowledgedCount;
  final int incidentCreatedCount;
  final int correlatedCount;

  const AlertStatsModel({
    required this.totalAlerts,
    required this.criticalHighCount,
    required this.unacknowledgedCount,
    required this.incidentCreatedCount,
    required this.correlatedCount,
  });

  factory AlertStatsModel.fromAlerts(List<InboundAlertModel> alerts) {
    int criticalHigh = 0;
    int unack = 0;
    int incidentCreated = 0;
    int correlated = 0;

    for (final a in alerts) {
      final sev = a.severity.toLowerCase().trim();
      if (sev == 'critical' || sev == 'error' || sev == 'high') {
        criticalHigh++;
      }
      if (!a.isAcknowledged) {
        unack++;
      }
      if (a.status == AlertStatusEnum.incidentCreated) {
        incidentCreated++;
      }
      if (a.status == AlertStatusEnum.correlated) {
        correlated++;
      }
    }

    return AlertStatsModel(
      totalAlerts: alerts.length,
      criticalHighCount: criticalHigh,
      unacknowledgedCount: unack,
      incidentCreatedCount: incidentCreated,
      correlatedCount: correlated,
    );
  }
}
