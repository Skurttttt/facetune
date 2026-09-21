import 'dart:async';

import 'package:facetune/features/subscription/data/data_sources/google_play_billing_data_source.dart';
import 'package:facetune/features/subscription/data/repositories/google_play_billing_gateway.dart';
import 'package:facetune/features/subscription/domain/catalog/plan_switch_policy.dart';
import 'package:facetune/features/subscription/domain/catalog/store_product_catalog.dart';
import 'package:facetune/features/subscription/domain/catalog/subscription_plan_catalog.dart';
import 'package:facetune/features/subscription/domain/catalog/top_up_pack_catalog.dart';
import 'package:facetune/features/subscription/domain/entities/allowance_unit.dart';
import 'package:facetune/features/subscription/domain/entities/billing_provider.dart';
import 'package:facetune/features/subscription/domain/entities/purchase_update.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_plan_code.dart';
import 'package:facetune/features/subscription/domain/entities/top_up_pack.dart';
import 'package:facetune/features/subscription/domain/errors/plan_switch_conflict.dart';
import 'package:facetune/features/subscription/presentation/controllers/purchase_controller.dart';
import 'package:facetune/features/subscription/presentation/controllers/purchase_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../../helpers/fake_billing.dart';

// ---------------------------------------------------------------------------
// SUB-13B corrective patch: Google Play subscription replacement.
//
// A real sandbox run bought Plus Preview while Plus was active and Play sold
// it as a second, independent subscription, because the purchase request
// carried no replacement parameters. These tests pin the corrected contract:
// what the provider holds decides whether a purchase is new or a replacement,
// the approved equal-price pairs replace without proration, and every state
// with no safe replacement refuses to open the sheet at all.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Provider fixtures, built from the plugin's real wrapper types.
// ---------------------------------------------------------------------------

/// The plain monthly base plan every approved subscription is configured as.
ProductDetailsWrapper monthly(String productId) => ProductDetailsWrapper(
  description: 'description',
  name: productId,
  productId: productId,
  productType: ProductType.subs,
  title: productId,
  subscriptionOfferDetails: [
    SubscriptionOfferDetailsWrapper(
      basePlanId: 'base',
      offerTags: const [],
      offerIdToken: 'offer-token-$productId',
      pricingPhases: const [
        PricingPhaseWrapper(
          billingCycleCount: 0,
          billingPeriod: 'P1M',
          formattedPrice: 'XTS 1.00',
          priceAmountMicros: 1000000,
          priceCurrencyCode: 'XTS',
          recurrenceMode: RecurrenceMode.infiniteRecurring,
        ),
      ],
    ),
  ],
);

/// A top-up pack: a one-time product, never a subscription.
ProductDetailsWrapper oneTime(String productId) => ProductDetailsWrapper(
  description: 'description',
  name: productId,
  productId: productId,
  productType: ProductType.inapp,
  title: productId,
  oneTimePurchaseOfferDetails: const OneTimePurchaseOfferDetailsWrapper(
    formattedPrice: 'XTS 1.00',
    priceAmountMicros: 1000000,
    priceCurrencyCode: 'XTS',
  ),
);

/// A purchase as Play's `queryPurchases` reports it: the SDK object the
/// replacement must reference, carrying the provider's own token.
GooglePlayPurchaseDetails ownedPurchase(
  String productId, {
  String token = 'owned-purchase-token',
  PurchaseStateWrapper state = PurchaseStateWrapper.purchased,
}) => GooglePlayPurchaseDetails.fromPurchase(
  PurchaseWrapper(
    orderId: 'GPA.order-$token',
    packageName: 'io.facetune.app',
    purchaseTime: 0,
    purchaseToken: token,
    signature: 'signature',
    products: [productId],
    isAutoRenewing: true,
    originalJson: '{}',
    isAcknowledged: true,
    purchaseState: state,
  ),
).single;

/// A billing data source driven entirely from the test.
class FakeBillingDataSource extends GooglePlayBillingDataSource {
  FakeBillingDataSource({
    List<ProductDetailsWrapper> products = const [],
    this.owned = const [],
    this.ownedQueryThrows,
  }) : _products = products;

  final List<ProductDetailsWrapper> _products;

  /// What Play reports as currently owned for the account.
  final List<GooglePlayPurchaseDetails> owned;

  /// Thrown from [queryOwnedPurchases] to stand in for a provider that could
  /// not answer — the case that must not fall through to a new subscription.
  final Object? ownedQueryThrows;

  final StreamController<List<PurchaseDetails>> controller =
      StreamController<List<PurchaseDetails>>.broadcast();

  int ownedQueryCount = 0;
  int restoreCount = 0;
  final List<PurchaseParam> bought = [];
  final List<PurchaseParam> boughtTopUps = [];

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<List<GooglePlayProductDetails>> queryProducts(
    Set<String> productIds,
  ) async => [
    for (final wrapper in _products)
      if (productIds.contains(wrapper.productId))
        ...GooglePlayProductDetails.fromProductDetails(wrapper),
  ];

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => controller.stream;

  @override
  Future<List<GooglePlayPurchaseDetails>> queryOwnedPurchases() async {
    ownedQueryCount++;
    final failure = ownedQueryThrows;
    if (failure != null) throw failure;
    return owned;
  }

  @override
  Future<bool> buy(PurchaseParam purchaseParam) async {
    bought.add(purchaseParam);
    return true;
  }

  @override
  Future<bool> buyTopUp(PurchaseParam purchaseParam) async {
    boughtTopUps.add(purchaseParam);
    return true;
  }

  @override
  Future<void> restorePurchases() async {
    restoreCount++;
    // Play answers a restore on the stream, with a `restored` status per
    // purchase it still considers owned.
    controller.add([
      for (final purchase in owned)
        GooglePlayPurchaseDetails(
          purchaseID: purchase.purchaseID,
          productID: purchase.productID,
          verificationData: purchase.verificationData,
          transactionDate: purchase.transactionDate,
          billingClientPurchase: purchase.billingClientPurchase,
          status: PurchaseStatus.restored,
        ),
    ]);
  }
}

/// Every approved subscription product, so any plan can be bought.
List<ProductDetailsWrapper> get allSubscriptionProducts => [
  for (final productId in StoreProductCatalog.purchasableProductIds)
    monthly(productId),
];

/// The approved equal-price pairs, in both directions, as (held, bought).
const approvedSwitches = <(SubscriptionPlanCode, SubscriptionPlanCode)>[
  (SubscriptionPlanCode.plus, SubscriptionPlanCode.plusPreview),
  (SubscriptionPlanCode.plusPreview, SubscriptionPlanCode.plus),
  (SubscriptionPlanCode.pro, SubscriptionPlanCode.proPreview),
  (SubscriptionPlanCode.proPreview, SubscriptionPlanCode.pro),
  (SubscriptionPlanCode.salonPro, SubscriptionPlanCode.salonPreview),
  (SubscriptionPlanCode.salonPreview, SubscriptionPlanCode.salonPro),
];

/// Every other transition between two distinct purchasable plans.
List<(SubscriptionPlanCode, SubscriptionPlanCode)> get unapprovedSwitches => [
  for (final from in SubscriptionPlanCode.values)
    for (final to in SubscriptionPlanCode.values)
      if (from != to &&
          StoreProductCatalog.isPurchasable(from) &&
          StoreProductCatalog.isPurchasable(to) &&
          !approvedSwitches.contains((from, to)))
        (from, to),
];

({GooglePlayBillingGateway gateway, FakeBillingDataSource billing}) harness({
  List<GooglePlayPurchaseDetails> owned = const [],
  Object? ownedQueryThrows,
  List<ProductDetailsWrapper>? products,
}) {
  final billing = FakeBillingDataSource(
    products: products ?? allSubscriptionProducts,
    owned: owned,
    ownedQueryThrows: ownedQueryThrows,
  );
  final gateway = GooglePlayBillingGateway(billing);
  addTearDown(gateway.dispose);
  return (gateway: gateway, billing: billing);
}

void main() {
  // -------------------------------------------------------------------------
  group('the approved plan-switch policy', () {
    test('exactly the three equal-price pairs replace, both ways', () {
      for (final (from, to) in approvedSwitches) {
        expect(
          PlanSwitchPolicy.classify(from: from, to: to),
          PlanSwitchKind.equalPriceReplacement,
          reason: '${from.code} → ${to.code}',
        );
      }
    });

    test('every cross-tier transition is unapproved, not guessed', () {
      // The paywall shows every purchasable card, so each of these is a
      // transition a user can ask for today. None has approved replacement
      // terms, and none may be classified as anything else by accident.
      expect(unapprovedSwitches, isNotEmpty);
      for (final (from, to) in unapprovedSwitches) {
        expect(
          PlanSwitchPolicy.classify(from: from, to: to),
          PlanSwitchKind.unapproved,
          reason: '${from.code} → ${to.code}',
        );
      }
    });

    test('the same plan is neither a replacement nor a new purchase', () {
      for (final plan in SubscriptionPlanCode.values) {
        expect(
          PlanSwitchPolicy.classify(from: plan, to: plan),
          PlanSwitchKind.samePlan,
        );
      }
    });

    test('the policy is a closed table, not a price comparison', () {
      // Free and Salon Pilot cost nothing and are never a store purchase;
      // they must not become an approved sibling of anything.
      expect(
        PlanSwitchPolicy.equalPriceSiblingOf(SubscriptionPlanCode.free),
        isNull,
      );
      expect(
        PlanSwitchPolicy.equalPriceSiblingOf(SubscriptionPlanCode.salonPilot),
        isNull,
      );
      expect(
        PlanSwitchPolicy.equalPriceSiblingOf(SubscriptionPlanCode.plus),
        SubscriptionPlanCode.plusPreview,
      );
    });
  });

  // -------------------------------------------------------------------------
  group('a brand-new subscription', () {
    test('uses the ordinary purchase path with no replacement', () async {
      final h = harness();

      await h.gateway.startPurchase(
        SubscriptionPlanCode.plus,
        obfuscatedAccountId: 'account-uuid',
      );

      final param = h.billing.bought.single as GooglePlayPurchaseParam;
      expect(param.productDetails.id, 'facetune_plus');
      expect(param.offerToken, 'offer-token-facetune_plus');
      expect(param.applicationUserName, 'account-uuid');
      expect(param.changeSubscriptionParam, isNull);
    });

    test('the provider is asked what it holds before every purchase', () async {
      final h = harness();

      await h.gateway.startPurchase(SubscriptionPlanCode.plus);
      await h.gateway.startPurchase(SubscriptionPlanCode.pro);

      expect(h.billing.ownedQueryCount, 2);
    });

    test('a pending subscription is not a subscription to replace', () async {
      final h = harness(
        owned: [
          ownedPurchase(
            'facetune_plus',
            state: PurchaseStateWrapper.pending,
          ),
        ],
      );

      await h.gateway.startPurchase(SubscriptionPlanCode.plusPreview);

      final param = h.billing.bought.single as GooglePlayPurchaseParam;
      expect(param.changeSubscriptionParam, isNull);
    });

    test('an owned top-up pack is not a subscription to replace', () async {
      // Packs are one-time products. An unconsumed one sits in the same
      // provider answer as the subscriptions, and must be ignored here.
      final h = harness(
        owned: [ownedPurchase('facetune_ai_look_topup_1', token: 'pack')],
      );

      await h.gateway.startPurchase(SubscriptionPlanCode.plus);

      final param = h.billing.bought.single as GooglePlayPurchaseParam;
      expect(param.changeSubscriptionParam, isNull);
    });

    test('a product that is not ours is not a subscription to replace', () async {
      final h = harness(
        owned: [ownedPurchase('some_other_app_product', token: 'foreign')],
      );

      await h.gateway.startPurchase(SubscriptionPlanCode.plus);

      final param = h.billing.bought.single as GooglePlayPurchaseParam;
      expect(param.changeSubscriptionParam, isNull);
    });
  });

  // -------------------------------------------------------------------------
  group('an approved equal-price switch is a replacement', () {
    for (final (from, to) in approvedSwitches) {
      test('${from.code} → ${to.code} replaces the held purchase', () async {
        final held = ownedPurchase(
          StoreProductCatalog.productIdFor(from)!,
          token: 'held-${from.code}',
        );
        final h = harness(owned: [held]);

        await h.gateway.startPurchase(to, obfuscatedAccountId: 'account-uuid');

        // Exactly one purchase launched, for the new product...
        final param = h.billing.bought.single as GooglePlayPurchaseParam;
        expect(param.productDetails.id, StoreProductCatalog.productIdFor(to));
        expect(param.offerToken, isNotNull);

        // ...as a replacement of the provider's own purchase object, in the
        // locked V1 mode...
        final change = param.changeSubscriptionParam;
        expect(change, isNotNull, reason: 'replacement parameters are absent');
        expect(identical(change!.oldPurchaseDetails, held), isTrue);
        expect(change.oldPurchaseDetails.productID, held.productID);
        expect(
          change.oldPurchaseDetails.verificationData.serverVerificationData,
          'held-${from.code}',
        );
        expect(change.replacementMode, ReplacementMode.withoutProration);

        // ...with the account binding intact.
        expect(param.applicationUserName, 'account-uuid');
      });
    }

    test('the old purchase is the provider object, never rebuilt', () async {
      // The plugin reads the old product id and token straight off the
      // supplied `GooglePlayPurchaseDetails`. Passing the provider's own
      // instance is what guarantees the token is Google's and not one the
      // app assembled from an entitlement, a plan code, or a row id.
      final held = ownedPurchase('facetune_pro', token: 'google-issued');
      final h = harness(owned: [held]);

      await h.gateway.startPurchase(SubscriptionPlanCode.proPreview);

      final param = h.billing.bought.single as GooglePlayPurchaseParam;
      expect(
        param.changeSubscriptionParam!.oldPurchaseDetails,
        same(held),
      );
    });
  });

  // -------------------------------------------------------------------------
  group('states with no safe replacement open nothing', () {
    test('more than one active subscription is refused', () async {
      // The invalid state the sandbox account reached. Choosing either would
      // leave the other running; nothing may be started.
      final h = harness(
        owned: [
          ownedPurchase('facetune_plus', token: 'first'),
          ownedPurchase('facetune_plus_preview', token: 'second'),
        ],
      );

      await expectLater(
        h.gateway.startPurchase(SubscriptionPlanCode.plusPreview),
        throwsA(
          isA<PlanSwitchConflict>().having(
            (c) => c.kind,
            'kind',
            PlanSwitchConflictKind.multipleActiveSubscriptions,
          ),
        ),
      );
      expect(h.billing.bought, isEmpty);
    });

    test('two entries for one purchase count once', () async {
      // The plugin emits one `PurchaseDetails` per product on a purchase.
      // The same token twice is one subscription, not two.
      final h = harness(
        owned: [
          ownedPurchase('facetune_plus', token: 'same'),
          ownedPurchase('facetune_plus', token: 'same'),
        ],
      );

      await h.gateway.startPurchase(SubscriptionPlanCode.plusPreview);

      expect(h.billing.bought, hasLength(1));
    });

    test('the plan already held is refused rather than bought twice', () async {
      final h = harness(owned: [ownedPurchase('facetune_plus')]);

      await expectLater(
        h.gateway.startPurchase(SubscriptionPlanCode.plus),
        throwsA(
          isA<PlanSwitchConflict>().having(
            (c) => c.kind,
            'kind',
            PlanSwitchConflictKind.alreadyOwned,
          ),
        ),
      );
      expect(h.billing.bought, isEmpty);
    });

    for (final (from, to) in unapprovedSwitches) {
      test('${from.code} → ${to.code} is blocked, not sold alongside', () async {
        final h = harness(
          owned: [ownedPurchase(StoreProductCatalog.productIdFor(from)!)],
        );

        await expectLater(
          h.gateway.startPurchase(to),
          throwsA(
            isA<PlanSwitchConflict>().having(
              (c) => c.kind,
              'kind',
              PlanSwitchConflictKind.unapprovedSwitch,
            ),
          ),
        );
        // Neither a second independent subscription nor a replacement with
        // a mode nobody approved.
        expect(h.billing.bought, isEmpty);
      });
    }

    test('a provider that cannot say what it holds is refused', () async {
      // Fail closed: "could not check" must not become "nothing to replace".
      final h = harness(
        ownedQueryThrows: const StoreQueryException('provider unavailable'),
      );

      await expectLater(
        h.gateway.startPurchase(SubscriptionPlanCode.plus),
        throwsA(isA<StoreQueryException>()),
      );
      expect(h.billing.bought, isEmpty);
    });

    test('conflict copy carries no token and no provider payload', () {
      const conflicts = [
        PlanSwitchConflict.multipleActiveSubscriptions(),
        PlanSwitchConflict.alreadyOwned(),
      ];
      for (final conflict in [
        ...conflicts,
        PlanSwitchConflict.unapprovedSwitch(
          from: SubscriptionPlanCode.plus,
          to: SubscriptionPlanCode.pro,
        ),
      ]) {
        expect(conflict.message, isNot(contains('token')));
        expect(conflict.message, isNot(contains('facetune_')));
        expect(conflict.toString(), conflict.message);
      }
    });
  });

  // -------------------------------------------------------------------------
  group('the purchase controller surfaces a conflict as recovery guidance', () {
    ({PurchaseController controller, FakeStoreBillingGateway store}) build({
      Object? startThrows,
    }) {
      final store = FakeStoreBillingGateway(startThrows: startThrows);
      final controller = PurchaseController(
        store: store,
        verification: FakePurchaseVerificationGateway.new,
        refreshSubscription: () async {},
        accountId: 'account-uuid',
      );
      addTearDown(controller.dispose);
      addTearDown(store.dispose);
      return (controller: controller, store: store);
    }

    test('multiple active subscriptions block the purchase', () async {
      const conflict = PlanSwitchConflict.multipleActiveSubscriptions();
      final h = build(startThrows: conflict);
      await h.controller.start();

      await h.controller.buy(SubscriptionPlanCode.plusPreview);

      expect(h.controller.state.phase, PurchasePhase.failed);
      // The specific guidance, not the generic "could not open" copy.
      expect(h.controller.state.message, conflict.message);
      expect(h.controller.state.message, contains('Payments & subscriptions'));
      expect(h.store.started, isEmpty);
      // Not stuck: the surface can be cleared and used again.
      h.controller.acknowledgeMessage();
      expect(h.controller.state.canPurchase, isTrue);
    });

    test('an unapproved switch reports which change is unavailable', () async {
      final conflict = PlanSwitchConflict.unapprovedSwitch(
        from: SubscriptionPlanCode.plus,
        to: SubscriptionPlanCode.pro,
      );
      final h = build(startThrows: conflict);
      await h.controller.start();

      await h.controller.buy(SubscriptionPlanCode.pro);

      expect(h.controller.state.phase, PurchasePhase.failed);
      expect(h.controller.state.message, contains('FaceTune Plus'));
      expect(h.controller.state.message, contains('FaceTune Pro'));
      expect(h.store.started, isEmpty);
    });

    test('an already-owned plan points at Restore', () async {
      final h = build(startThrows: const PlanSwitchConflict.alreadyOwned());
      await h.controller.start();

      await h.controller.buy(SubscriptionPlanCode.plus);

      expect(h.controller.state.phase, PurchasePhase.failed);
      expect(h.controller.state.message, contains('Restore'));
      expect(h.store.started, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  group('what the patch leaves alone', () {
    test('a top-up purchase carries no replacement and no owned query', () async {
      final h = harness(
        products: [oneTime('facetune_ai_look_topup_1')],
        owned: [ownedPurchase('facetune_plus')],
      );

      await h.gateway.startTopUpPurchase(
        TopUpPack.extraAiLook,
        obfuscatedAccountId: 'account-uuid',
      );

      final param = h.billing.boughtTopUps.single as GooglePlayPurchaseParam;
      expect(param.productDetails.id, 'facetune_ai_look_topup_1');
      expect(param.changeSubscriptionParam, isNull);
      expect(param.applicationUserName, 'account-uuid');
      expect(h.billing.ownedQueryCount, 0);
      expect(h.billing.bought, isEmpty);
    });

    test('the purchased-credit catalog is unchanged', () {
      expect(TopUpPackCatalog.productIds, {
        'facetune_ai_look_topup_1',
        'facetune_preview_credit_topup_10',
      });
      expect(TopUpPack.extraAiLook.quantity, 1);
      expect(TopUpPack.previewBoost.quantity, 10);
    });

    test('Restore stays provider-authoritative and starts nothing', () async {
      final h = harness(owned: [ownedPurchase('facetune_plus')]);
      final updates = <PurchaseUpdate>[];
      h.gateway.purchaseUpdates.listen(updates.add);

      await h.gateway.restorePurchases();
      await Future<void>.delayed(Duration.zero);

      // What Play holds is delivered as evidence for the server, exactly as
      // before; nothing is bought, replaced, or decided here.
      expect(updates.single.status, PurchaseUpdateStatus.restored);
      final evidence = updates.single.evidence!;
      expect(evidence.provider, BillingProvider.googlePlay);
      expect(evidence.providerProductId, 'facetune_plus');
      expect(evidence.purchaseToken, 'owned-purchase-token');
      expect(h.billing.bought, isEmpty);
      expect(h.billing.ownedQueryCount, 0);
    });

    test('the subscription matrix is still 3/30/8/80/35/350', () {
      const expected = {
        SubscriptionPlanCode.plus: (3, AllowanceUnit.aiLook, true),
        SubscriptionPlanCode.plusPreview: (
          30,
          AllowanceUnit.finalPreviewCredit,
          false,
        ),
        SubscriptionPlanCode.pro: (8, AllowanceUnit.aiLook, true),
        SubscriptionPlanCode.proPreview: (
          80,
          AllowanceUnit.finalPreviewCredit,
          false,
        ),
        SubscriptionPlanCode.salonPro: (35, AllowanceUnit.aiLook, true),
        SubscriptionPlanCode.salonPreview: (
          350,
          AllowanceUnit.finalPreviewCredit,
          false,
        ),
      };
      for (final entry in expected.entries) {
        final definition = SubscriptionPlanCatalog.definitionFor(entry.key);
        final (allowance, unit, tutorial) = entry.value;
        expect(definition.baseAllowance, allowance, reason: entry.key.code);
        expect(definition.allowanceUnit, unit, reason: entry.key.code);
        expect(definition.tutorialEnabled, tutorial, reason: entry.key.code);
      }
    });

    test('Free and Salon Pilot are untouched by the switch machinery', () async {
      // Neither has a store product, so neither can be held on Play, be
      // bought, or be a replacement source. The existing refusal stands.
      for (final plan in [
        SubscriptionPlanCode.free,
        SubscriptionPlanCode.salonPilot,
      ]) {
        expect(StoreProductCatalog.productIdFor(plan), isNull);
        final h = harness(owned: [ownedPurchase('facetune_plus')]);
        await expectLater(
          h.gateway.startPurchase(plan),
          throwsA(isA<StateError>()),
        );
        expect(h.billing.ownedQueryCount, 0);
        expect(h.billing.bought, isEmpty);
      }
      final free = SubscriptionPlanCatalog.definitionFor(
        SubscriptionPlanCode.free,
      );
      expect(free.baseAllowance, 1);
      expect(free.tutorialEnabled, isTrue);
      final pilot = SubscriptionPlanCatalog.definitionFor(
        SubscriptionPlanCode.salonPilot,
      );
      expect(pilot.baseAllowance, 30);
      expect(pilot.publiclyPurchasable, isFalse);
    });
  });
}
