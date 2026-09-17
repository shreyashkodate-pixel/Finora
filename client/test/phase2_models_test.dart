import 'package:flutter_test/flutter_test.dart';
import 'package:ai_helpdesk_client/features/problems/models/problem_model.dart';
import 'package:ai_helpdesk_client/features/changes/models/change_model.dart';
import 'package:ai_helpdesk_client/features/major_incidents/models/major_incident_model.dart';
import 'package:ai_helpdesk_client/features/autofix/models/autofix_model.dart';


void main() {
  group('Phase 2 Models Deserialization Tests', () {
    test('ProblemModel parses json correctly', () {
      final json = {
        'id': 'prob-123',
        'problem_number': 'PRB-2026-0001',
        'title': 'Database Connection Timeout',
        'description': 'Repeated pooled connection exhaustion.',
        'root_cause': 'Max connections limit set too low.',
        'workaround': 'Restart pool service.',
        'status': 'open',
        'priority': 'p2',
        'owner_id': 'user-1',
        'created_at': '2026-09-17T10:00:00Z',
        'updated_at': '2026-09-17T10:30:00Z',
        'resolved_at': null,
        'case_links': [
          {
            'id': 'link-1',
            'problem_id': 'prob-123',
            'case_id': 'case-1',
            'linked_by': 'user-1',
            'linked_at': '2026-09-17T10:05:00Z',
          }
        ],
        'known_errors': [
          {
            'id': 'ke-1',
            'problem_id': 'prob-123',
            'title': 'KEDB: Pool Exhaustion',
            'symptoms': 'High API 500 error spikes.',
            'workaround': 'Execute pool reload.',
            'permanent_fix': 'Scale cluster replicas.',
            'published': true,
            'created_at': '2026-09-17T10:15:00Z',
          }
        ],
      };

      final model = ProblemModel.fromJson(json);
      expect(model.id, 'prob-123');
      expect(model.problemNumber, 'PRB-2026-0001');
      expect(model.caseLinks.length, 1);
      expect(model.knownErrors.length, 1);
      expect(model.knownErrors[0].title, 'KEDB: Pool Exhaustion');
    });

    test('ChangeRequestModel parses json correctly', () {
      final json = {
        'id': 'chg-123',
        'change_number': 'CHG-2026-0001',
        'title': 'Upgrade Postgres',
        'description': 'Upgrade database engine.',
        'reason': 'Security patch.',
        'risk_level': 'medium',
        'change_type': 'normal',
        'status': 'pending_cab',
        'requester_id': 'user-1',
        'cab_approver_id': null,
        'problem_id': null,
        'implementation_plan': '1. Backup 2. Deploy',
        'test_plan': 'Run sanity tests',
        'rollback_plan': 'Restore archive',
        'scheduled_start': '2026-09-20T02:00:00Z',
        'scheduled_end': '2026-09-20T04:00:00Z',
        'cab_feedback': 'Reviewed by CAB',
        'created_at': '2026-09-17T10:00:00Z',
        'updated_at': '2026-09-17T10:30:00Z',
      };

      final model = ChangeRequestModel.fromJson(json);
      expect(model.id, 'chg-123');
      expect(model.changeNumber, 'CHG-2026-0001');
      expect(model.status, 'pending_cab');
      expect(model.riskLevel, 'medium');
      expect(model.implementationPlan, '1. Backup 2. Deploy');
    });

    test('MajorIncidentModel parses json correctly', () {
      final json = {
        'id': 'maj-123',
        'incident_number': 'MAJ-2026-0001',
        'case_id': 'case-999',
        'title': 'Production Outage',
        'status': 'declared',
        'commander_id': 'user-1',
        'bridge_url': 'https://meet.google.com/test-war-room',
        'impact_summary': 'Checkout down',
        'declared_at': '2026-09-17T10:00:00Z',
        'timeline_events': [
          {
            'id': 'tl-1',
            'major_incident_id': 'maj-123',
            'author_id': 'user-1',
            'summary': 'Commander assumed role',
            'details': 'War room established',
            'event_timestamp': '2026-09-17T10:02:00Z',
          }
        ],
      };

      final model = MajorIncidentModel.fromJson(json);
      expect(model.id, 'maj-123');
      expect(model.incidentNumber, 'MAJ-2026-0001');
      expect(model.timelineEvents.length, 1);
      expect(model.timelineEvents[0].summary, 'Commander assumed role');
    });

    test('AutoFixActionModel parses json correctly', () {
      final json = {
        'id': 'act-123',
        'case_id': 'case-1',
        'action_type': 'service_restart',
        'parameters': {'service_name': 'nginx'},
        'status': 'success',
        'initiated_by': 'user-1',
        'execution_output': 'Service restarted successfully.',
        'rollback_output': null,
        'error_message': null,
        'executed_at': '2026-09-17T10:05:00Z',
        'completed_at': '2026-09-17T10:06:00Z',
        'created_at': '2026-09-17T10:00:00Z',
      };

      final model = AutoFixActionModel.fromJson(json);
      expect(model.id, 'act-123');
      expect(model.actionType, 'service_restart');
      expect(model.parameters['service_name'], 'nginx');
      expect(model.status, 'success');
      expect(model.executionOutput, 'Service restarted successfully.');
    });
  });
}
