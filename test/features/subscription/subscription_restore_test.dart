import 'package:facetune/features/subscription/domain/entities/billing_provider.dart';
import 'package:facetune/features/subscription/domain/entities/purchase_evidence.dart';
import 'package:facetune/features/subscription/domain/entities/purchase_update.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_plan_code.dart';
import 'package:facetune/features/subscription/domain/errors/subscription_state_failure.dart';
import 'package:facetune/features/subscription/presentation/controllers/purchase_controller.dart';
import 'package:facetune/features/subscription/presentation/controllers/purchase_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_billing.dart';

/// SUB-11's restore path, driven through the real controller.
///
/// The rule under test is the one the whole subscription architecture rests
/// on: "I bought this before" is a claim, not an entitlement. A restored
/// purchase takes the identical route a fresh one takes — provider evidence,
/// server verification, then and only then acknowledgement, then an
/// authoritative re-read — and nothing on this side ever decides what the
/// account has.
void main() {
  const evidence = PurchaseEvidence(
    provider: BillingProvider.googlePlay,
    providerProductId: 'facetune_plus',
    purchaseToken: 'restored-token-value',
  );

  const restoredUpdate = PurchaseUpdate(
    status: PurchaseUpdateStatus.restored,
    awaitingCompletion: true,
    planCode: SubscriptionPlanCode.plus,
    evidence: evidence,
  );

  /// Builds a started controller over fakes.
  ///
  /// The settle window is zero so the "nothing found" path resolves
  /// immediately; production gives the provider five seconds to answer.
  Future<
    ({
      PurchaseController controller,
      FakeStoreBillingGateway store,
      FakePurchaseVerificationGateway verification,
      List<String> refreshes,
    })
  >
  build({
    bool storeAvailable = true,
    Object? verificationFailure,
    Object? restoreThrows,
    List<PurchaseUpdate> delivers = const [],
  }) async {
    final store = FakeStoreBillingGateway(available: storeAvailable)
      ..restoreThrows = restoreThrows
      ..restoreDelivers = delivers;
    final verification = FakePurchaseVerificationGateway(
      failure: verificationFailure,
    );
    final refreshes = <String>[];

    final controller = PurchaseController(
      store: store,
      verification: () => verification,
      refreshSubscription: () async => refreshes.add('refresh'),
      accountId: 'account-uuid',
      restoreSettleWindow: Duration.zero,
    );
    addTearDown(controller.dispose);
    addTearDown(store.dispose);

    await controller.start();
    return (
      controller: controller,
      store: store,
      verification: verification,
      refreshes: refreshes,
    );
  }

  group('a restored purchase is verified like any other', () {
    test(
      'it reaches the server before the provider is told anything',
      () async {
        final harness = await build(delivers: [restoredUpdate]);

        await harness.controller.restore();
        await pumpEventQueue();

        expect(
          harness.verification.received.single.purchaseToken,
          'restored-token-value',
          reason: 'the evidence must be sent to the backend',
        );
        expect(
          harness.store.completed.single.purchaseToken,
          'restored-token-value',
          reason: 'and only then acknowledged with the provider',
        );
        expect(harness.refreshes, hasLength(1));
        expect(harness.controller.state.phase, PurchasePhase.verified);
      },
    );

    test(
      'a refused verification restores nothing and acknowledges nothing',
      () async {
        // The security property, on the restore path this time: an unverified
        // purchase stays unacknowledged so Google's automatic refund still
        // protects the user.
        final harness = await build(
          delivers: [restoredUpdate],
          verificationFailure: const SubscriptionStateFailure(
            'This purchase could not be verified.',
          ),
        );

        await harness.controller.restore();
        await pumpEventQueue();

        expect(harness.verification.received, hasLength(1));
        expect(
          harness.store.completed,
          isEmpty,
          reason: 'an unverified purchase must never be acknowledged',
        );
        expect(harness.refreshes, isEmpty);
        expect(harness.controller.state.phase, PurchasePhase.failed);
      },
    );

    test('restoring twice is safe and stays a server decision', () async {
      // Idempotency lives in the database, keyed on the purchase — the client
      // simply presents the same evidence again rather than trying to detect a
      // duplicate itself.
      final harness = await build(delivers: [restoredUpdate]);

      await harness.controller.restore();
      await pumpEventQueue();
      harness.controller.acknowledgeMessage();
      await harness.controller.restore();
      await pumpEventQueue();

      expect(harness.store.restoreCount, 2);
      expect(harness.verification.received, hasLength(2));
      expect(
        harness.verification.received.map((e) => e.purchaseToken).toSet(),
        {'restored-token-value'},
      );
      expect(harness.controller.state.phase, PurchasePhase.verified);
    });
  });

  group('when there is nothing to restore', () {
    test('it says so plainly rather than reporting a failure', () async {
      final harness = await build();

      await harness.controller.restore();

      expect(harness.store.restoreCount, 1);
      expect(harness.controller.state.phase, PurchasePhase.restoredNothing);
      expect(
        harness.controller.state.message,
        contains('no previous FaceTune subscription'),
      );
      expect(harness.verification.received, isEmpty);
      expect(harness.refreshes, isEmpty);
    });

    test(
      'a provider that refused the query is a failure, not an absence',
      () async {
        final harness = await build(
          restoreThrows: Exception('play unavailable'),
        );

        await harness.controller.restore();

        expect(harness.controller.state.phase, PurchasePhase.failed);
        expect(
          harness.controller.state.message,
          contains('could not check your previous purchases'),
        );
        // And no provider payload reaches the user.
        expect(
          harness.controller.state.message,
          isNot(contains('play unavailable')),
        );
      },
    );
  });

  group('restore cannot be started when it could not work', () {
    test('an unusable store is never queried', () async {
      final harness = await build(storeAvailable: false);

      await harness.controller.restore();

      expect(harness.store.restoreCount, 0);
      expect(harness.controller.state.phase, PurchasePhase.unavailable);
    });

    test('a second restore cannot stack on one in flight', () async {
      final harness = await build(delivers: [restoredUpdate]);

      // Not awaited: the first call is still inside its settle window when the
      // second arrives.
      final first = harness.controller.restore();
      await harness.controller.restore();
      await first;
      await pumpEventQueue();

      expect(harness.store.restoreCount, 1);
    });
  });

  group('the restore phases describe a step, never a grant', () {
    test('no phase means the account has a plan', () {
      // `restoredNothing` and `restoring` are provider-query states. Nothing on
      // PurchaseState can hold a plan, an allowance, or an expiry — that is
      // what keeps `if (restored) { unlock() }` unwritable.
      const state = PurchaseState(phase: PurchasePhase.restoredNothing);
      expect(state.isBusy, isFalse);
      expect(state.plan, isNull);

      const busy = PurchaseState(
        phase: PurchasePhase.restoring,
        storeAvailable: true,
      );
      expect(busy.isBusy, isTrue);
      expect(
        busy.canPurchase,
        isFalse,
        reason: 'a restore in flight blocks a purchase and a second restore',
      );
    });
  });
}
