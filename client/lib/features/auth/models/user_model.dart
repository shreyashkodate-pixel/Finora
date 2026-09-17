/// Represents an authenticated user in the AI IT Helpdesk per SRS §4 & §6.
class UserModel {
  final String id;
  final String email;
  final String role; // requester, operator, team_lead, manager, administrator
  final String? teamId;
  final String? site;
  final String availabilityStatus; // available, away, offline
  final bool emailVerified;

  const UserModel({
    required this.id,
    required this.email,
    required this.role,
    this.teamId,
    this.site,
    this.availabilityStatus = 'available',
    this.emailVerified = true,
  });

  bool get isRequester => role == 'requester';
  bool get isOperator => role == 'operator';
  bool get isTeamLead => role == 'team_lead';
  bool get isManager => role == 'manager';
  bool get isAdmin => role == 'administrator';

  bool get isStaff => role != 'requester';
  bool get canApprove => isTeamLead || isManager || isAdmin;
  bool get isManagerOrAdmin => isManager || isAdmin;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      role: (json['role'] as String?)?.toLowerCase() ?? 'requester',
      teamId: json['team_id'] as String?,
      site: json['site'] as String?,
      availabilityStatus: (json['availability_status'] as String?)?.toLowerCase() ?? 'available',
      emailVerified: json['email_verified'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role,
      'team_id': teamId,
      'site': site,
      'availability_status': availabilityStatus,
      'email_verified': emailVerified,
    };
  }
}
