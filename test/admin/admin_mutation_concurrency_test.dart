import 'dart:async';

import 'package:facetune/admin/salon_pilot/domain/admin_salon_pilot_models.dart';
import 'package:facetune/admin/salon_pilot/presentation/admin_adjust_allowance_controller.dart';
import 'package:facetune/admin/salon_pilot/presentation/admin_grant_salon_pilot_controller.dart';
import 'package:facetune/admin/salon_pilot/presentation/admin_lifecycle_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_adjust_allowance_test.dart'
    show adjustOutcomePayload, pilotId, previewPlus10;
import 'admin_lifecycle_test.dart' show lifecycleController, lifecycleOutcome;
import 'admin_salon_pilot_test.dart'
    show ScriptedSalonPilotGateway, outcomePayload, pilotUserId;

/// WA-11 — the browser side of "duplicate admin operations do not
/// double-apply".
///
/// The server is the authority (same key → replay), but the client must not
/// even *send* twice for one intent while a submission is in flight, and a
/// retry after a timeout must carry the same key. These tests drive the
/// three mutation controllers exactly as a double-click or a retry would:
/// `confirm()` twice without awaiting the first.
void main() {
  group('double-click while submitting', () {
    test(
      'grant: the second confirm is a no-op while the first is in flight',
      () async {
        final gate = Completer<AdminMutationOutcome>();
        final gateway = ScriptedSalonPilotGateway([(_) => gate.future]);
        final c = AdminGrantSalonPilotController(
          targetUserId: pilotUserId,
          gateway: gateway,
          isAuthorized: () => true,
          onServerRefusal: (_) {},
        );
        c.preview(
          expiresAt: DateTime.utc(2027, 1, 31, 23, 59, 59),
          initialAllowance: 30,
          reason: 'Panel research',
        );
        final first = c.confirm();
        final second = c.confirm(); // the double-click
        expect(c.state, isA<AdminGrantSubmitting>());
        gate.complete(AdminMutationOutcome.decode(outcomePayload()));
        await Future.wait([first, second]);
        expect(gateway.calls, hasLength(1));
        expect(c.state, isA<AdminGrantSucceeded>());
      },
    );

    test(
      'adjust: the second confirm is a no-op while the first is in flight',
      () async {
        final gate = Completer<AdminMutationOutcome>();
        final gateway = ScriptedSalonPilotGateway([])
          ..adjustResponses.add((_) => gate.future);
        final c = AdminAdjustAllowanceController(
          entitlementId: pilotId,
          gateway: gateway,
          isAuthorized: () => true,
          onServerRefusal: (_) {},
        );
        previewPlus10(c);
        final first = c.confirm();
        final second = c.confirm();
        expect(c.state, isA<AdminAdjustSubmitting>());
        gate.complete(AdminMutationOutcome.decode(adjustOutcomePayload()));
        await Future.wait([first, second]);
        expect(gateway.adjustCalls, hasLength(1));
        expect(
          (c.state as AdminAdjustSucceeded).outcome.effectiveAllowance,
          40,
        );
      },
    );

    test(
      'revoke: the second confirm is a no-op while the first is in flight',
      () async {
        final gate = Completer<AdminMutationOutcome>();
        final gateway = ScriptedSalonPilotGateway([])
          ..lifecycleResponses.add((_) => gate.future);
        final c = lifecycleController(
          gateway,
          SalonPilotLifecycleAction.revoke,
        );
        c.preview(reason: 'Pilot terminated', expectedVersion: 7);
        final first = c.confirm();
        final second = c.confirm();
        expect(c.state, isA<AdminLifecycleSubmitting>());
        gate.complete(
          AdminMutationOutcome.decode(
            lifecycleOutcome(
              action: SalonPilotLifecycleAction.revoke,
              status: 'revoked',
            ),
          ),
        );
        await Future.wait([first, second]);
        expect(gateway.lifecycleCalls, hasLength(1));
        expect(c.state, isA<AdminLifecycleSucceeded>());
      },
    );
  });

  group('retry after a timeout keeps the same intent', () {
    test(
      'adjust: retry sends the identical key and version; a replay is accepted',
      () async {
        final gateway = ScriptedSalonPilotGateway([])
          ..adjustResponses.addAll([
            (_) async => throw const AdminMutationFailure(
              AdminMutationErrorCode.temporaryBackendFailure,
              retryable: true,
            ),
            (_) async => AdminMutationOutcome.decode(
              adjustOutcomePayload(replayed: true),
            ),
          ]);
        final c = AdminAdjustAllowanceController(
          entitlementId: pilotId,
          gateway: gateway,
          isAuthorized: () => true,
          onServerRefusal: (_) {},
        );
        previewPlus10(c);
        await c.confirm();
        await c.confirm();
        expect(gateway.adjustCalls, hasLength(2));
        expect(
          gateway.adjustCalls[0].idempotencyKey,
          gateway.adjustCalls[1].idempotencyKey,
        );
        expect(
          gateway.adjustCalls[0].expectedVersion,
          gateway.adjustCalls[1].expectedVersion,
        );
        expect(gateway.adjustCalls[0].amount, gateway.adjustCalls[1].amount);
        expect((c.state as AdminAdjustSucceeded).outcome.replayed, isTrue);
      },
    );

    test(
      'revoke: retry sends the identical key; the replayed revocation is shown once',
      () async {
        final gateway = ScriptedSalonPilotGateway([])
          ..lifecycleResponses.addAll([
            (_) async => throw const AdminMutationFailure(
              AdminMutationErrorCode.temporaryBackendFailure,
              retryable: true,
            ),
            (_) async => AdminMutationOutcome.decode(
              lifecycleOutcome(
                action: SalonPilotLifecycleAction.revoke,
                status: 'revoked',
                replayed: true,
              ),
            ),
          ]);
        final c = lifecycleController(
          gateway,
          SalonPilotLifecycleAction.revoke,
        );
        c.preview(reason: 'Pilot terminated', expectedVersion: 7);
        await c.confirm();
        expect((c.state as AdminLifecycleFailed).failure.retryable, isTrue);
        await c.confirm();
        expect(gateway.lifecycleCalls, hasLength(2));
        expect(
          gateway.lifecycleCalls[0].idempotencyKey,
          gateway.lifecycleCalls[1].idempotencyKey,
        );
        expect((c.state as AdminLifecycleSucceeded).outcome.replayed, isTrue);
      },
    );

    test(
      'a stale-version refusal is terminal for that intent: no silent retry, edit re-mints',
      () async {
        final gateway = ScriptedSalonPilotGateway([])
          ..adjustResponses.add(
            (_) async => throw const AdminMutationFailure(
              AdminMutationErrorCode.concurrentModification,
            ),
          );
        final c = AdminAdjustAllowanceController(
          entitlementId: pilotId,
          gateway: gateway,
          isAuthorized: () => true,
          onServerRefusal: (_) {},
        );
        previewPlus10(c);
        final firstKey =
            (c.state as AdminAdjustPreviewing).intent.idempotencyKey;
        await c.confirm();
        expect((c.state as AdminAdjustFailed).failure.retryable, isFalse);
        c.edit();
        previewPlus10(c);
        final secondKey =
            (c.state as AdminAdjustPreviewing).intent.idempotencyKey;
        expect(
          secondKey,
          isNot(firstKey),
          reason: 'a new intent after reloading is a new business action',
        );
        expect(gateway.adjustCalls, hasLength(1));
      },
    );
  });
}
