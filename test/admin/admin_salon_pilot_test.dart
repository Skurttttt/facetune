import 'package:facetune/admin/auth/domain/admin_auth_failure.dart';
import 'package:facetune/admin/salon_pilot/data/supabase_admin_salon_pilot_gateway.dart';
import 'package:facetune/admin/salon_pilot/domain/admin_salon_pilot_gateway.dart';
import 'package:facetune/admin/salon_pilot/domain/admin_salon_pilot_models.dart';
import 'package:facetune/admin/salon_pilot/presentation/admin_grant_salon_pilot_controller.dart';
import 'package:facetune/admin/shared/admin_read_failure.dart';
import 'package:facetune/features/subscription/domain/entities/entitlement_status.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_plan_code.dart';
import 'package:facetune/features/subscription/domain/errors/subscription_error_code.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const pilotUserId = '40000000-0000-4000-8000-000000000001';
const pilotEntitlementId = '41000000-0000-4000-8000-000000000001';

/// The Edge Function's success body, byte-for-byte the writer's JSON.
Map<String, Object?> outcomePayload({
  bool replayed = false,
  int available = 30,
}) => {
  'success': true,
  'contractVersion': 'subscription_admin_contract_v1.1',
  'action': 'grant_salon_pilot',
  'replayed': replayed,
  'targetUserId': pilotUserId,
  'entitlementId': pilotEntitlementId,
  'planCode': 'salon_pilot',
  'status': 'active',
  'effectiveAllowance': 30,
  'committedUsage': 0,
  'reservedUsage': 30 - available,
  'availableAiLooks': available,
  'remainingAiLooks': 30,
  'expiresAt': '2026-10-22T23:59:59+00:00',
  'version': 1,
  'updatedAt': '2026-09-22T12:00:00+00:00',
};

class ScriptedSalonPilotGateway implements AdminSalonPilotGateway {
  ScriptedSalonPilotGateway(this.responses);

  final List<Future<AdminMutationOutcome> Function(GrantSalonPilotIntent)>
  responses;
  final List<GrantSalonPilotIntent> calls = [];

  @override
  Future<AdminMutationOutcome> grantSalonPilot(GrantSalonPilotIntent intent) {
    calls.add(intent);
    return responses.removeAt(0)(intent);
  }

  final List<Future<AdminMutationOutcome> Function(AdjustAllowanceIntent)>
  adjustResponses = [];
  final List<AdjustAllowanceIntent> adjustCalls = [];

  @override
  Future<AdminMutationOutcome> adjustAllowance(AdjustAllowanceIntent intent) {
    adjustCalls.add(intent);
    return adjustResponses.removeAt(0)(intent);
  }

  final List<Future<AdminMutationOutcome> Function(LifecycleIntent)>
  lifecycleResponses = [];
  final List<LifecycleIntent> lifecycleCalls = [];

  @override
  Future<AdminMutationOutcome> applyLifecycle(LifecycleIntent intent) {
    lifecycleCalls.add(intent);
    return lifecycleResponses.removeAt(0)(intent);
  }
}

AdminGrantSalonPilotController controller(
  ScriptedSalonPilotGateway gateway, {
  bool authorized = true,
  void Function(AdminAuthFailure)? onRefusal,
  String Function()? mintKey,
}) => AdminGrantSalonPilotController(
  targetUserId: pilotUserId,
  gateway: gateway,
  isAuthorized: () => authorized,
  onServerRefusal: onRefusal ?? (_) {},
  mintIdempotencyKey: mintKey,
);

void main() {
  group('GrantSalonPilotIntent', () {
    test('the body carries intent only, with a UTC expiration', () {
      final intent = GrantSalonPilotIntent(
        targetUserId: pilotUserId,
        expiresAt: DateTime(2026, 10, 22, 23, 59, 59).toUtc(),
        initialAllowance: 30,
        reason: 'Panel research cohort A',
        idempotencyKey: 'key-a',
      );
      final body = intent.toRequestBody();
      expect(body.keys.toSet(), {
        'targetUserId',
        'expiresAt',
        'initialAllowance',
        'reason',
        'idempotencyKey',
      });
      expect(body['expiresAt'], endsWith('Z'));
      expect(salonPilotDefaultInitialAllowance, 30);
    });
  });

  group('AdminMutationOutcome.decode', () {
    test('copies the server figures and the replay flag verbatim', () {
      final outcome = AdminMutationOutcome.decode(
        outcomePayload(replayed: true, available: 29),
      );
      expect(outcome.replayed, isTrue);
      expect(outcome.planCode, SubscriptionPlanCode.salonPilot);
      expect(outcome.status, EntitlementStatus.active);
      expect(outcome.effectiveAllowance, 30);
      expect(outcome.reservedUsage, 1);
      expect(outcome.availableAiLooks, 29);
      expect(outcome.remainingAiLooks, 30);
      expect(outcome.expiresAt, DateTime.utc(2026, 10, 22, 23, 59, 59));
    });

    test('anything but a contract success fails closed', () {
      for (final broken in [
        {...outcomePayload(), 'success': false},
        {...outcomePayload(), 'contractVersion': 'v2'},
        {...outcomePayload(), 'planCode': 'premium'},
        {...outcomePayload(), 'status': 'granted'},
        {...outcomePayload(), 'availableAiLooks': -1},
        {...outcomePayload()}..remove('replayed'),
        'ok',
      ]) {
        expect(
          () => AdminMutationOutcome.decode(broken),
          throwsA(isA<AdminReadFailure>()),
          reason: broken.toString(),
        );
      }
    });
  });

  group('SupabaseAdminSalonPilotGateway.failureFrom', () {
    Exception map(int status, [Object? details]) =>
        SupabaseAdminSalonPilotGateway.failureFrom(
          FunctionException(status: status, details: details),
        );

    test('session refusals become auth failures', () {
      expect(
        (map(401, {
                  'error': {'code': 'AUTH_REQUIRED'},
                })
                as AdminAuthFailure)
            .code,
        SubscriptionErrorCode.authRequired,
      );
      expect(
        (map(403, {
                  'error': {'code': 'ADMIN_UNAUTHORIZED'},
                })
                as AdminAuthFailure)
            .code,
        SubscriptionErrorCode.adminUnauthorized,
      );
    });

    test('contract failures carry their code, message, and retryability', () {
      final failure =
          map(409, {
                'success': false,
                'action': 'grant_salon_pilot',
                'errorCode': 'SALON_PILOT_ALREADY_GRANTED',
                'message':
                    'This account already holds a Salon Pilot entitlement.',
                'retryable': false,
              })
              as AdminMutationFailure;
      expect(failure.code, AdminMutationErrorCode.salonPilotAlreadyGranted);
      expect(failure.message, contains('already holds'));
      expect(failure.retryable, isFalse);

      final invalid =
          map(400, {
                'success': false,
                'errorCode': 'invalid_request',
                'field': 'expiresAt',
                'message': 'expiresAt must be in the future.',
                'retryable': false,
              })
              as AdminMutationFailure;
      expect(invalid.code, AdminMutationErrorCode.invalidRequest);
      expect(invalid.field, 'expiresAt');
    });

    test('an unknown code is never a success and 5xx is retryable', () {
      final failure =
          map(503, {'success': false, 'errorCode': 'SPENT'})
              as AdminMutationFailure;
      expect(failure.code, AdminMutationErrorCode.unknown);
      expect(failure.retryable, isTrue);
    });
  });

  group('AdminGrantSalonPilotController', () {
    test(
      'a zero-allowance intent is sent as submitted and its outcome shows zero',
      () async {
        final gateway = ScriptedSalonPilotGateway([
          (_) async => AdminMutationOutcome.decode({
            ...outcomePayload(),
            'effectiveAllowance': 0,
            'reservedUsage': 0,
            'availableAiLooks': 0,
            'remainingAiLooks': 0,
          }),
        ]);
        final c = controller(gateway);
        c.preview(
          expiresAt: DateTime.utc(2026, 10, 22, 23, 59, 59),
          initialAllowance: 0,
          reason: 'Zero-pool observation account',
        );
        await c.confirm();
        expect(gateway.calls.single.initialAllowance, 0);
        expect(gateway.calls.single.toRequestBody()['initialAllowance'], 0);
        final outcome = (c.state as AdminGrantSucceeded).outcome;
        expect(outcome.effectiveAllowance, 0);
        expect(outcome.availableAiLooks, 0);
      },
    );

    test('preview freezes the intent with a fresh idempotency key', () {
      final c = controller(ScriptedSalonPilotGateway([]));
      c.preview(
        expiresAt: DateTime.utc(2026, 10, 22, 23, 59, 59),
        initialAllowance: 30,
        reason: '  Panel research cohort A ',
      );
      final state = c.state as AdminGrantPreviewing;
      expect(state.intent.targetUserId, pilotUserId);
      expect(state.intent.reason, 'Panel research cohort A');
      expect(state.intent.idempotencyKey, isNotEmpty);
      c.edit();
      expect(c.state, isA<AdminGrantEditing>());
    });

    test(
      'confirm sends the previewed intent and shows the server outcome',
      () async {
        final gateway = ScriptedSalonPilotGateway([
          (_) async => AdminMutationOutcome.decode(outcomePayload()),
        ]);
        final c = controller(gateway);
        c.preview(
          expiresAt: DateTime.utc(2026, 10, 22, 23, 59, 59),
          initialAllowance: 30,
          reason: 'Panel research cohort A',
        );
        final previewed = (c.state as AdminGrantPreviewing).intent;
        await c.confirm();
        expect(gateway.calls.single, same(previewed));
        final state = c.state as AdminGrantSucceeded;
        expect(state.outcome.entitlementId, pilotEntitlementId);
        expect(state.outcome.availableAiLooks, 30);
      },
    );

    test('a retry after a temporary failure reuses the same key', () async {
      final gateway = ScriptedSalonPilotGateway([
        (_) async => throw const AdminMutationFailure(
          AdminMutationErrorCode.temporaryBackendFailure,
          retryable: true,
        ),
        (_) async =>
            AdminMutationOutcome.decode(outcomePayload(replayed: true)),
      ]);
      final c = controller(gateway);
      c.preview(
        expiresAt: DateTime.utc(2026, 10, 22, 23, 59, 59),
        initialAllowance: 30,
        reason: 'Panel research cohort A',
      );
      await c.confirm();
      expect(c.state, isA<AdminGrantFailed>());
      expect((c.state as AdminGrantFailed).failure.retryable, isTrue);
      await c.confirm();
      expect(gateway.calls, hasLength(2));
      expect(gateway.calls[0].idempotencyKey, gateway.calls[1].idempotencyKey);
      expect((c.state as AdminGrantSucceeded).outcome.replayed, isTrue);
    });

    test(
      'a contract refusal is shown and nothing is retried silently',
      () async {
        final gateway = ScriptedSalonPilotGateway([
          (_) async => throw const AdminMutationFailure(
            AdminMutationErrorCode.salonPilotAlreadyGranted,
          ),
        ]);
        final c = controller(gateway);
        c.preview(
          expiresAt: DateTime.utc(2026, 10, 22, 23, 59, 59),
          initialAllowance: 30,
          reason: 'r',
        );
        await c.confirm();
        final state = c.state as AdminGrantFailed;
        expect(
          state.failure.code,
          AdminMutationErrorCode.salonPilotAlreadyGranted,
        );
        expect(state.failure.retryable, isFalse);
        expect(gateway.calls, hasLength(1));
      },
    );

    test(
      'a session refusal is escalated to the authorization controller',
      () async {
        final refusals = <AdminAuthFailure>[];
        final gateway = ScriptedSalonPilotGateway([
          (_) async => throw const AdminAuthFailure(
            SubscriptionErrorCode.adminUnauthorized,
          ),
        ]);
        final c = controller(gateway, onRefusal: refusals.add);
        c.preview(
          expiresAt: DateTime.utc(2026, 10, 22, 23, 59, 59),
          initialAllowance: 30,
          reason: 'r',
        );
        await c.confirm();
        expect(refusals.single.isUnauthorized, isTrue);
        expect(c.state, isA<AdminGrantFailed>());
      },
    );

    test(
      'nothing is sent without an authorized session or a preview',
      () async {
        final gateway = ScriptedSalonPilotGateway([]);
        final c = controller(gateway, authorized: false);
        await c.confirm();
        expect(gateway.calls, isEmpty);
        expect(c.state, isA<AdminGrantEditing>());
        c.preview(
          expiresAt: DateTime.utc(2026, 10, 22, 23, 59, 59),
          initialAllowance: 30,
          reason: 'r',
        );
        await c.confirm();
        expect(gateway.calls, isEmpty);
        expect(c.state, isA<AdminGrantFailed>());
      },
    );
  });
}
