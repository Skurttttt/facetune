import 'dart:async';

import 'package:facetune/features/subscription/data/models/subscription_summary_dto.dart';
import 'package:facetune/features/subscription/domain/catalog/store_product_catalog.dart';
import 'package:facetune/features/subscription/domain/catalog/top_up_pack_catalog.dart';
import 'package:facetune/features/subscription/domain/entities/allowance_unit.dart';
import 'package:facetune/features/subscription/domain/entities/billing_provider.dart';
import 'package:facetune/features/subscription/domain/entities/purchase_evidence.dart';
import 'package:facetune/features/subscription/domain/entities/purchase_update.dart';
import 'package:facetune/features/subscription/domain/entities/purchased_credit_summary.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_plan_code.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_summary.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_usage_summary.dart';
import 'package:facetune/features/subscription/domain/entities/top_up_pack.dart';
import 'package:facetune/features/subscription/domain/errors/subscription_state_failure.dart';
import 'package:facetune/features/subscription/domain/repositories/purchase_verification_gateway.dart';
import 'package:facetune/features/subscription/domain/repositories/top_up_verification_gateway.dart';
import 'package:facetune/features/subscription/presentation/controllers/purchase_controller.dart';
import 'package:facetune/features/subscription/presentation/controllers/purchase_state.dart';
import 'package:facetune/features/subscription/presentation/utils/ai_look_allowance_copy.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_billing.dart';

/// SUB-13B — the client half of purchased top-up credits.
///
/// Proves the purchase flow routes pack evidence to the top-up verifier and
/// plan evidence to the subscription verifier, consumes only after the server
/// has granted, never counts a credit itself, and reads the server's
/// purchased-credit figures back faithfully.
void main() {
  const packEvidence = PurchaseEvidence(
    provider: BillingProvider.googlePlay,
    providerProductId: 'facetune_preview_credit_topup_10',
    purchaseToken: 'pack-token',
  );
  const planEvidence = PurchaseEvidence(
    provider: BillingProvider.googlePlay,
    providerProductId: 'facetune_pro',
    purchaseToken: 'plan-token',
  );

  PurchaseUpdate packUpdate({
    PurchaseUpdateStatus status = PurchaseUpdateStatus.purchased,
  }) => PurchaseUpdate(
    status: status,
    awaitingCompletion: true,
    topUpPack: TopUpPack.previewBoost,
    evidence: packEvidence,
  );

  ({
    PurchaseController controller,
    FakeStoreBillingGateway store,
    FakePurchaseVerificationGateway plans,
    FakeTopUpVerificationGateway? packs,
    List<int> refreshes,
  })
  harness({
    FakeTopUpVerificationGateway? packs,

    /// A build with no top-up verifier wired at all.
    bool noPacks = false,
    Object? planFailure,
  }) {
    final store = FakeStoreBillingGateway();
    final plans = FakePurchaseVerificationGateway(failure: planFailure);
    final resolvedPacks = noPacks
        ? null
        : (packs ?? FakeTopUpVerificationGateway());
    final refreshes = <int>[];
    final controller = PurchaseController(
      store: store,
      verification: () => plans,
      topUpVerification: resolvedPacks == null ? null : () => resolvedPacks,
      refreshSubscription: () async => refreshes.add(1),
      accountId: 'opaque-account',
    );
    addTearDown(controller.dispose);
    addTearDown(store.dispose);
    return (
      controller: controller,
      store: store,
      plans: plans,
      packs: resolvedPacks,
      refreshes: refreshes,
    );
  }

  group('routing', () {
    test('a pack purchase is verified by the top-up verifier only', () async {
      final h = harness();
      await h.controller.start();

      h.store.updates.add(packUpdate());
      await Future<void>.delayed(Duration.zero);

      expect(h.packs!.received, [packEvidence]);
      expect(h.packs!.sources, [PurchaseVerificationSource.purchase]);
      expect(h.plans.received, isEmpty, reason: 'never the plan path');
      expect(h.controller.state.phase, PurchasePhase.verified);
      expect(h.refreshes, hasLength(1), reason: 'state is re-read, not set');
    });

    test('a plan purchase never reaches the top-up verifier', () async {
      final h = harness();
      await h.controller.start();

      h.store.updates.add(
        const PurchaseUpdate(
          status: PurchaseUpdateStatus.purchased,
          awaitingCompletion: true,
          planCode: SubscriptionPlanCode.pro,
          evidence: planEvidence,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(h.plans.received, [planEvidence]);
      expect(h.packs!.received, isEmpty);
      expect(h.store.completed, [planEvidence]);
      expect(h.store.completedTopUps, isEmpty);
    });

    test(
      'a restored pack is labelled a restore and verified the same way',
      () async {
        final h = harness();
        await h.controller.start();

        h.store.updates.add(packUpdate(status: PurchaseUpdateStatus.restored));
        await Future<void>.delayed(Duration.zero);

        expect(h.packs!.sources, [PurchaseVerificationSource.restore]);
        expect(h.controller.state.phase, PurchasePhase.verified);
      },
    );

    test('the catalogs never share an identifier', () {
      for (final id in TopUpPackCatalog.productIds) {
        expect(StoreProductCatalog.planFor(id), isNull);
      }
      for (final id in StoreProductCatalog.purchasableProductIds) {
        expect(TopUpPackCatalog.packFor(id), isNull);
      }
    });
  });

  group('consumption follows the grant', () {
    test(
      'a server-consumed purchase is not consumed again on the device',
      () async {
        final h = harness(
          packs: FakeTopUpVerificationGateway(consumedByServer: true),
        );
        await h.controller.start();

        h.store.updates.add(packUpdate());
        await Future<void>.delayed(Duration.zero);

        expect(h.store.completedTopUps, hasLength(1));
        expect(h.store.completedTopUps.single.consumedByServer, isTrue);
        expect(h.store.completed, isEmpty, reason: 'not the subscription path');
      },
    );

    test('the device consumes only as the second chance', () async {
      final h = harness(
        packs: FakeTopUpVerificationGateway(consumedByServer: false),
      );
      await h.controller.start();

      h.store.updates.add(packUpdate());
      await Future<void>.delayed(Duration.zero);

      expect(h.store.completedTopUps.single.consumedByServer, isFalse);
      expect(h.controller.state.phase, PurchasePhase.verified);
    });

    test('a refused purchase is never consumed', () async {
      final h = harness(
        packs: FakeTopUpVerificationGateway(
          failure: const SubscriptionStateFailure(
            'Top-up packs can only be added to an active paid plan.',
            kind: SubscriptionStateFailureKind.invalidData,
            retryable: false,
          ),
        ),
      );
      await h.controller.start();

      h.store.updates.add(packUpdate());
      await Future<void>.delayed(Duration.zero);

      expect(h.store.completedTopUps, isEmpty);
      expect(h.controller.state.phase, PurchasePhase.failed);
      expect(h.controller.state.message, contains('active paid plan'));
      expect(h.refreshes, isEmpty);
    });

    test(
      'with no top-up verifier, a pack is refused and left unconsumed',
      () async {
        final h = harness(noPacks: true);
        await h.controller.start();

        h.store.updates.add(packUpdate());
        await Future<void>.delayed(Duration.zero);

        expect(h.plans.received, isEmpty, reason: 'not sent to the plan path');
        expect(h.store.completedTopUps, isEmpty);
        expect(h.controller.state.phase, PurchasePhase.failed);
        expect(h.controller.state.message, contains('refund'));
      },
    );

    test('a replayed grant is reported as already added', () async {
      final h = harness(packs: FakeTopUpVerificationGateway(replayed: true));
      await h.controller.start();

      h.store.updates.add(packUpdate());
      await Future<void>.delayed(Duration.zero);

      expect(h.controller.state.phase, PurchasePhase.verified);
      expect(h.controller.state.message, contains('already'));
    });

    test('a duplicate delivery mid-flight is verified once', () async {
      final gate = Completer<void>();
      final packs = _GatedTopUpGateway(gate);
      final h = harness(packs: packs);
      await h.controller.start();

      h.store.updates.add(packUpdate());
      h.store.updates.add(packUpdate());
      await Future<void>.delayed(Duration.zero);
      gate.complete();
      await Future<void>.delayed(Duration.zero);

      expect(packs.received, hasLength(1));
    });
  });

  group('starting a pack purchase', () {
    test('opens the sheet for the pack with the opaque account id', () async {
      final h = harness();
      await h.controller.start();

      await h.controller.buyTopUp(TopUpPack.extraAiLook);

      expect(h.store.startedTopUps, [TopUpPack.extraAiLook]);
      expect(h.store.accountIds, ['opaque-account']);
      expect(h.controller.state.topUpPack, TopUpPack.extraAiLook);
      expect(h.controller.state.plan, isNull);
      expect(h.controller.state.phase, PurchasePhase.starting);
    });

    test('a plan attempt clears the pack hint and vice versa', () {
      const state = PurchaseState(topUpPack: TopUpPack.previewBoost);
      final planNext = state.copyWith(plan: SubscriptionPlanCode.plus);
      expect(planNext.plan, SubscriptionPlanCode.plus);
      expect(planNext.topUpPack, isNull);
      final packNext = planNext.copyWith(topUpPack: TopUpPack.extraAiLook);
      expect(packNext.topUpPack, TopUpPack.extraAiLook);
      expect(packNext.plan, isNull);
      expect(packNext.copyWith(clearPlan: true).topUpPack, isNull);
    });

    test('the state carries no credit count', () {
      const state = PurchaseState(
        phase: PurchasePhase.verified,
        topUpPack: TopUpPack.previewBoost,
      );
      expect(state.toString(), isNot(contains('10')));
    });
  });

  group('server figures are read back, not computed', () {
    Map<String, Object?> payload({
      int tutorial = 0,
      int preview = 0,
      bool usable = false,
      int available = 0,
      Object? nextSource,
      Object? nextUnit,
    }) => {
      'hasEntitlement': true,
      'planCode': 'plus',
      'planDisplayName': 'FaceTune Plus',
      'entitlementStatus': 'active',
      'billingProvider': 'google_play',
      'resetPolicy': 'billing_period',
      'allowanceUnit': 'ai_look',
      'tutorialEnabled': true,
      'finalPreviewEnabled': true,
      'effectiveAllowance': 3,
      'committedUsage': 3,
      'reservedUsage': 0,
      'availableAiLooks': 0,
      'remainingAiLooks': 0,
      'generationAuthorized': available > 0,
      'resolvedAt': '2026-09-20T12:00:00Z',
      'purchasedTutorialCreditsRemaining': tutorial,
      'purchasedPreviewCreditsRemaining': preview,
      'purchasedCreditsUsable': usable,
      'availablePurchasedCredits': available,
      'nextAllowanceSource': nextSource,
      'nextAllowanceUnit': nextUnit,
    };

    test('parses the purchased-credit figures', () {
      final summary = SubscriptionSummaryDto.fromResponse(
        payload(
          tutorial: 1,
          preview: 10,
          usable: true,
          available: 11,
          nextSource: 'purchased_credit',
          nextUnit: 'ai_look',
        ),
      );
      expect(
        summary.purchasedCredits,
        const PurchasedCreditSummary(
          tutorialCapableRemaining: 1,
          previewOnlyRemaining: 10,
          usable: true,
          availableCompatible: 11,
          nextAllowanceSource: AllowanceSource.purchasedCredit,
          nextAllowanceUnit: AllowanceUnit.aiLook,
        ),
      );
      // The included allowance is untouched by the credits.
      expect(summary.usage.remainingAiLooks, 0);
    });

    test('a payload from before top-ups means no credits', () {
      final legacy = payload()
        ..remove('purchasedTutorialCreditsRemaining')
        ..remove('purchasedPreviewCreditsRemaining')
        ..remove('purchasedCreditsUsable')
        ..remove('availablePurchasedCredits')
        ..remove('nextAllowanceSource')
        ..remove('nextAllowanceUnit');
      final summary = SubscriptionSummaryDto.fromResponse(legacy);
      expect(summary.purchasedCredits, PurchasedCreditSummary.none);
    });

    test('an unknown next unit is never coerced to the Tutorial one', () {
      final summary = SubscriptionSummaryDto.fromResponse(
        payload(
          preview: 5,
          usable: true,
          available: 5,
          nextSource: 'something_new',
          nextUnit: 'super_credit',
        ),
      );
      expect(summary.purchasedCredits.nextAllowanceSource, isNull);
      expect(summary.purchasedCredits.nextAllowanceUnit, isNull);
    });

    test('negative counts are clamped rather than trusted', () {
      final summary = SubscriptionSummaryDto.fromResponse(
        payload(tutorial: -4, preview: -1),
      );
      expect(summary.purchasedCredits.totalRemaining, 0);
    });
  });

  group('copy', () {
    SubscriptionSummary exhausted(PurchasedCreditSummary credits) =>
        SubscriptionSummary(
          hasEntitlement: true,
          planCode: SubscriptionPlanCode.plus,
          planDisplayName: 'FaceTune Plus',
          usage: const SubscriptionUsageSummary(
            effectiveAllowance: 3,
            committedUsage: 3,
          ),
          generationAuthorized: credits.availableCompatible > 0,
          resolvedAt: DateTime.utc(2026, 9, 20),
          purchasedCredits: credits,
        );

    test('a spent plan with a usable Preview-only credit says so plainly', () {
      final copy = AiLookAllowanceCopy.forSummary(
        exhausted(
          const PurchasedCreditSummary(
            tutorialCapableRemaining: 0,
            previewOnlyRemaining: 4,
            usable: true,
            availableCompatible: 4,
            nextAllowanceSource: AllowanceSource.purchasedCredit,
            nextAllowanceUnit: AllowanceUnit.finalPreviewCredit,
          ),
        ),
      );
      expect(copy.headline, isNull, reason: 'not exhausted');
      expect(copy.compactLine, contains('no Tutorial'));
      expect(copy.remainingLine, '0 of 3 AI Looks remaining');
      expect(copy.purchasedLine, 'Plus 4 purchased Final Preview Credits');
    });

    test('a Tutorial-capable credit is named as an AI Look', () {
      final copy = AiLookAllowanceCopy.forSummary(
        exhausted(
          const PurchasedCreditSummary(
            tutorialCapableRemaining: 1,
            previewOnlyRemaining: 0,
            usable: true,
            availableCompatible: 1,
            nextAllowanceSource: AllowanceSource.purchasedCredit,
            nextAllowanceUnit: AllowanceUnit.aiLook,
          ),
        ),
      );
      expect(copy.compactLine, 'Next look uses a purchased AI Look');
      expect(copy.purchasedLine, 'Plus 1 purchased AI Look');
    });

    test(
      'stored but unusable credits are described as kept, not spendable',
      () {
        final copy = AiLookAllowanceCopy.forSummary(
          exhausted(
            const PurchasedCreditSummary(
              tutorialCapableRemaining: 2,
              previewOnlyRemaining: 10,
              usable: false,
              availableCompatible: 0,
            ),
          ),
        );
        expect(copy.headline, 'You have used all your AI Looks');
        expect(
          copy.purchasedLine,
          'Plus 2 purchased AI Looks and 10 purchased Final Preview Credits — '
          'kept for you, usable while a paid plan is active',
        );
      },
    );

    test('no credits means no purchased line', () {
      final copy = AiLookAllowanceCopy.forSummary(
        exhausted(PurchasedCreditSummary.none),
      );
      expect(copy.purchasedLine, isNull);
      expect(copy.headline, 'You have used all your AI Looks');
    });
  });
}

class _GatedTopUpGateway extends FakeTopUpVerificationGateway {
  _GatedTopUpGateway(this.gate);
  final Completer<void> gate;

  @override
  Future<TopUpVerificationResult> verify(
    PurchaseEvidence evidence, {
    PurchaseVerificationSource source = PurchaseVerificationSource.purchase,
  }) async {
    received.add(evidence);
    await gate.future;
    return const TopUpVerificationResult(
      consumedByServer: true,
      replayed: false,
    );
  }
}
