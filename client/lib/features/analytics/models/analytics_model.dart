import 'package:flutter/material.dart';
import '../../../shared/theme/colors.dart';

/// Workload forecast response representing statistical ticket volume projections
/// and staffing recommendations across selected horizon windows (7, 14, 30 days).
class WorkloadForecastResponse {
  final int horizonDays;
  final DateTime forecastDate;
  final int predictedTotalCases;
  final int predictedP1Cases;
  final int predictedP2Cases;
  final int predictedP3P4Cases;
  final Map<String, int> categoryBreakdown;
  final Map<String, int> confidenceInterval;
  final String recommendation;

  const WorkloadForecastResponse({
    required this.horizonDays,
    required this.forecastDate,
    required this.predictedTotalCases,
    required this.predictedP1Cases,
    required this.predictedP2Cases,
    required this.predictedP3P4Cases,
    required this.categoryBreakdown,
    required this.confidenceInterval,
    required this.recommendation,
  });

  factory WorkloadForecastResponse.fromJson(Map<String, dynamic> json) {
    return WorkloadForecastResponse(
      horizonDays: json['horizon_days'] as int? ?? 7,
      forecastDate: json['forecast_date'] != null
          ? DateTime.tryParse(json['forecast_date'] as String) ?? DateTime.now()
          : DateTime.now(),
      predictedTotalCases: json['predicted_total_cases'] as int? ?? 0,
      predictedP1Cases: json['predicted_p1_cases'] as int? ?? 0,
      predictedP2Cases: json['predicted_p2_cases'] as int? ?? 0,
      predictedP3P4Cases: json['predicted_p3_p4_cases'] as int? ?? 0,
      categoryBreakdown: (json['category_breakdown'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toInt()),
          ) ??
          {},
      confidenceInterval: (json['confidence_interval'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toInt()),
          ) ??
          {},
      recommendation: json['recommendation'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'horizon_days': horizonDays,
      'forecast_date': forecastDate.toIso8601String(),
      'predicted_total_cases': predictedTotalCases,
      'predicted_p1_cases': predictedP1Cases,
      'predicted_p2_cases': predictedP2Cases,
      'predicted_p3_p4_cases': predictedP3P4Cases,
      'category_breakdown': categoryBreakdown,
      'confidence_interval': confidenceInterval,
      'recommendation': recommendation,
    };
  }
}

/// Detailed SLA breach risk assessment for an active ticket.
class PredictiveRiskItem {
  final String caseId;
  final String referenceNumber;
  final String title;
  final String priority;
  final String currentStatus;
  final double riskScore;
  final int timeToBreachMinutes;
  final List<String> riskDrivers;

  const PredictiveRiskItem({
    required this.caseId,
    required this.referenceNumber,
    required this.title,
    required this.priority,
    required this.currentStatus,
    required this.riskScore,
    required this.timeToBreachMinutes,
    required this.riskDrivers,
  });

  factory PredictiveRiskItem.fromJson(Map<String, dynamic> json) {
    return PredictiveRiskItem(
      caseId: json['case_id'] as String? ?? '',
      referenceNumber: json['reference_number'] as String? ?? '',
      title: json['title'] as String? ?? '',
      priority: json['priority'] as String? ?? 'P3',
      currentStatus: json['current_status'] as String? ?? 'new',
      riskScore: (json['risk_score'] ?? json['predicted_breach_probability'] as num?)?.toDouble() ?? 0.0,
      timeToBreachMinutes: json['time_to_breach_minutes'] as int? ?? 0,
      riskDrivers: (json['risk_drivers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'case_id': caseId,
      'reference_number': referenceNumber,
      'title': title,
      'priority': priority,
      'current_status': currentStatus,
      'risk_score': riskScore,
      'time_to_breach_minutes': timeToBreachMinutes,
      'risk_drivers': riskDrivers,
    };
  }

  /// Categorizes the risk score into standard operational levels.
  String get riskLevel {
    if (riskScore >= 0.80) return 'critical';
    if (riskScore >= 0.60) return 'high';
    if (riskScore >= 0.40) return 'moderate';
    return 'low';
  }

  Color get riskColor {
    switch (riskLevel) {
      case 'critical':
        return AppColors.priorityP1;
      case 'high':
        return AppColors.priorityP2;
      case 'moderate':
        return AppColors.priorityP3;
      default:
        return AppColors.slaHealthy;
    }
  }
}

/// Collective SLA risk overview returned by `/api/v1/analytics/predictive/risk-forecast`.
class PredictiveRiskResponse {
  final int totalAtRiskCases;
  final List<PredictiveRiskItem> highRiskCases;
  final String aiSummary;

  const PredictiveRiskResponse({
    required this.totalAtRiskCases,
    required this.highRiskCases,
    required this.aiSummary,
  });

  factory PredictiveRiskResponse.fromJson(Map<String, dynamic> json) {
    return PredictiveRiskResponse(
      totalAtRiskCases: json['total_at_risk_cases'] as int? ?? 0,
      highRiskCases: (json['high_risk_cases'] as List<dynamic>?)
              ?.map((e) => PredictiveRiskItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      aiSummary: json['ai_summary'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_at_risk_cases': totalAtRiskCases,
      'high_risk_cases': highRiskCases.map((e) => e.toJson()).toList(),
      'ai_summary': aiSummary,
    };
  }
}

/// Team-specific operational capacity metric item.
class TeamCapacityMetricItem {
  final String teamId;
  final String teamName;
  final int activeOperators;
  final int openCases;
  final double avgCasesPerOperator;
  final double capacityUtilizationPct;
  final String burnoutRisk;
  final double estimatedClosureVelocityPerDay;

  const TeamCapacityMetricItem({
    required this.teamId,
    required this.teamName,
    required this.activeOperators,
    required this.openCases,
    required this.avgCasesPerOperator,
    required this.capacityUtilizationPct,
    required this.burnoutRisk,
    required this.estimatedClosureVelocityPerDay,
  });

  factory TeamCapacityMetricItem.fromJson(Map<String, dynamic> json) {
    return TeamCapacityMetricItem(
      teamId: json['team_id'] as String? ?? '',
      teamName: json['team_name'] as String? ?? '',
      activeOperators: json['active_operators'] as int? ?? 1,
      openCases: json['open_cases'] as int? ?? 0,
      avgCasesPerOperator: (json['avg_cases_per_operator'] as num?)?.toDouble() ?? 0.0,
      capacityUtilizationPct: (json['capacity_utilization_pct'] as num?)?.toDouble() ?? 0.0,
      burnoutRisk: json['burnout_risk'] as String? ?? 'low',
      estimatedClosureVelocityPerDay:
          (json['estimated_closure_velocity_per_day'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'team_id': teamId,
      'team_name': teamName,
      'active_operators': activeOperators,
      'open_cases': openCases,
      'avg_cases_per_operator': avgCasesPerOperator,
      'capacity_utilization_pct': capacityUtilizationPct,
      'burnout_risk': burnoutRisk,
      'estimated_closure_velocity_per_day': estimatedClosureVelocityPerDay,
    };
  }

  Color get burnoutColor {
    switch (burnoutRisk.toLowerCase()) {
      case 'critical':
        return AppColors.priorityP1;
      case 'high':
        return AppColors.priorityP2;
      case 'moderate':
        return AppColors.priorityP3;
      default:
        return AppColors.slaHealthy;
    }
  }
}

/// Team capacity overview response returned by `/api/v1/analytics/capacity/teams`.
class TeamCapacityOverviewResponse {
  final int totalTeams;
  final double overallUtilizationPct;
  final List<TeamCapacityMetricItem> teams;

  const TeamCapacityOverviewResponse({
    required this.totalTeams,
    required this.overallUtilizationPct,
    required this.teams,
  });

  factory TeamCapacityOverviewResponse.fromJson(Map<String, dynamic> json) {
    return TeamCapacityOverviewResponse(
      totalTeams: json['total_teams'] as int? ?? 0,
      overallUtilizationPct: (json['overall_utilization_pct'] as num?)?.toDouble() ?? 0.0,
      teams: (json['teams'] as List<dynamic>?)
              ?.map((e) => TeamCapacityMetricItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_teams': totalTeams,
      'overall_utilization_pct': overallUtilizationPct,
      'teams': teams.map((e) => e.toJson()).toList(),
    };
  }
}
