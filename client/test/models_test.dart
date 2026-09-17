import 'package:flutter_test/flutter_test.dart';
import 'package:ai_helpdesk_client/features/ai/models/ai_models.dart';
import 'package:ai_helpdesk_client/features/auth/models/user_model.dart';
import 'package:ai_helpdesk_client/features/cases/models/case_model.dart';
import 'package:ai_helpdesk_client/features/knowledge/models/knowledge_model.dart';

void main() {
  group('UserModel Serialization', () {
    test('parses requester user correctly', () {
      final json = {
        'id': 'user-123',
        'email': 'jane.doe@enterprise.com',
        'full_name': 'Jane Doe',
        'role': 'requester',
        'site': 'HQ North',
        'is_active': true,
      };

      final user = UserModel.fromJson(json);
      expect(user.id, 'user-123');
      expect(user.email, 'jane.doe@enterprise.com');
      expect(user.fullName, 'Jane Doe');
      expect(user.role, 'requester');
      expect(user.site, 'HQ North');
      expect(user.isStaff, isFalse);
      expect(user.canApprove, isFalse);
      expect(user.isManagerOrAdmin, isFalse);
    });

    test('parses lead / manager user with elevated permissions', () {
      final json = {
        'id': 'lead-456',
        'email': 'lead@enterprise.com',
        'full_name': 'Team Lead',
        'role': 'lead',
        'is_active': true,
      };

      final user = UserModel.fromJson(json);
      expect(user.isStaff, isTrue);
      expect(user.canApprove, isTrue);
      expect(user.isManagerOrAdmin, isFalse);
    });

    test('parses admin user correctly', () {
      final json = {
        'id': 'admin-789',
        'email': 'admin@enterprise.com',
        'full_name': 'System Admin',
        'role': 'admin',
        'is_active': true,
      };

      final user = UserModel.fromJson(json);
      expect(user.isStaff, isTrue);
      expect(user.canApprove, isTrue);
      expect(user.isManagerOrAdmin, isTrue);
    });
  });

  group('Case & SLA Models Serialization', () {
    test('parses case with SLA and version correctly', () {
      final now = DateTime.now().toUtc();
      final json = {
        'id': 'case-111',
        'reference_number': 'INC-2026-000042',
        'title': 'VPN Gateway Down',
        'description': 'Employees cannot connect to Cisco AnyConnect.',
        'type': 'incident',
        'status': 'assigned',
        'priority': 'p1',
        'reporter_id': 'user-123',
        'owner_id': 'op-456',
        'site': 'Campus A',
        'version': 3,
        'created_at': now.toIso8601String(),
        'sla': {
          'id': 'sla-999',
          'case_id': 'case-111',
          'target_response_at': now.add(const Duration(minutes: 15)).toIso8601String(),
          'target_resolve_at': now.add(const Duration(hours: 2)).toIso8601String(),
          'first_response_at': null,
          'response_breached': false,
          'resolution_breached': false,
        },
      };

      final c = CaseModel.fromJson(json);
      expect(c.referenceNumber, 'INC-2026-000042');
      expect(c.priority, 'p1');
      expect(c.version, 3);
      expect(c.sla, isNotNull);
      expect(c.sla!.resolutionBreached, isFalse);
    });

    test('parses messages with visibility correctly', () {
      final now = DateTime.now().toUtc();
      final publicMsgJson = {
        'id': 'msg-1',
        'case_id': 'case-111',
        'author_id': 'user-123',
        'body': 'Any update on this?',
        'visibility': 'requester',
        'created_at': now.toIso8601String(),
      };
      final internalMsgJson = {
        'id': 'msg-2',
        'case_id': 'case-111',
        'author_id': 'op-456',
        'body': 'Restarting auth server in rack 4.',
        'visibility': 'internal_only',
        'created_at': now.toIso8601String(),
      };

      final m1 = MessageModel.fromJson(publicMsgJson);
      final m2 = MessageModel.fromJson(internalMsgJson);

      expect(m1.isInternalOnly, isFalse);
      expect(m2.isInternalOnly, isTrue);
    });
  });

  group('AI & Approval Models Serialization', () {
    test('parses AI triage response', () {
      final json = {
        'id': 'tr-10',
        'case_id': 'case-111',
        'suggested_priority': 'P1',
        'suggested_category': 'Network Infrastructure',
        'confidence_score': 0.94,
        'confidence_level': 'high',
        'reasoning': 'Affects entire department VPN subnet.',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      final triage = AITriageModel.fromJson(json);
      expect(triage.suggestedPriority, 'P1');
      expect(triage.confidenceScore, 0.94);
      expect(triage.reasoning, contains('VPN subnet'));
    });

    test('parses SLA Risk model', () {
      final json = {
        'case_id': 'case-111',
        'risk_score': 0.82,
        'risk_level': 'HIGH',
        'reasoning': 'Only 18 minutes remaining before P1 resolution breach.',
        'signals': ['High ticket load on operator', 'Hardware component replacement required'],
      };

      final risk = RiskAssessmentModel.fromJson(json);
      expect(risk.riskLevel, 'high');
      expect(risk.riskScore, 0.82);
      expect(risk.signals.length, 2);
    });

    test('parses Approval model', () {
      final now = DateTime.now().toUtc();
      final json = {
        'id': 'appr-1',
        'case_id': 'case-111',
        'requester_id': 'op-456',
        'approver_id': 'lead-456',
        'reason': 'Emergency maintenance router reboot authorization',
        'decision': 'pending',
        'created_at': now.toIso8601String(),
        'decided_at': null,
      };

      final appr = ApprovalModel.fromJson(json);
      expect(appr.isPending, isTrue);
      expect(appr.reason, contains('Emergency maintenance'));
    });
  });

  group('Knowledge Article Model Serialization', () {
    test('parses knowledge article correctly', () {
      final now = DateTime.now().toUtc();
      final json = {
        'id': 'art-1',
        'title': 'How to Reset Multi-Factor Authentication (MFA)',
        'body': '1. Open security portal\n2. Request temporary access pass\n3. Re-enroll authenticator app.',
        'owner_id': 'admin-789',
        'state': 'published',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final art = KnowledgeArticleModel.fromJson(json);
      expect(art.isPublished, isTrue);
      expect(art.title, contains('Reset Multi-Factor'));
    });
  });
}
