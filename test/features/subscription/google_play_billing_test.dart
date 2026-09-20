import 'dart:async';

import 'package:facetune/features/subscription/data/data_sources/google_play_billing_data_source.dart';
import 'package:facetune/features/subscription/data/repositories/google_play_billing_gateway.dart';
import 'package:facetune/features/subscription/data/repositories/google_play_plan_price_source.dart';
import 'package:facetune/features/subscription/data/repositories/unavailable_purchase_verification_gateway.dart';
import 'package:facetune/features/subscription/domain/catalog/store_product_catalog.dart';
import 'package:facetune/features/subscription/domain/catalog/subscription_plan_catalog.dart';
import 'package:facetune/features/subscription/domain/entities/billing_provider.dart';
import 'package:facetune/features/subscription/domain/entities/plan_price.dart';
import 'package:facetune/features/subscription/domain/entities/purchase_evidence.dart';
import 'package:facetune/features/subscription/domain/entities/purchase_update.dart';
import 'package:facetune/features/subscription/domain/entities/store_product.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_plan_code.dart';
import 'package:facetune/features/subscription/domain/errors/subscription_state_failure.dart';
import 'package:facetune/features/subscription/presentation/controllers/purchase_controller.dart';
import 'package:facetune/features/subscription/presentation/controllers/purchase_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../../helpers/fake_billing.dart';

// ---------------------------------------------------------------------------
// Provider fixtures
//
// Built from the real wrapper types the plugin returns, rather than from a
// hand-rolled stand-in, so the offer/pricing-phase shape under test is the one
// Google Play actually produces.
// ---------------------------------------------------------------------------

PricingPhaseWrapper phase({
  required String billingPeriod,
  required String formattedPrice,
  String currency = 'XTS',
}) => PricingPhaseWrapper(
  billingCycleCount: 0,
  billingPeriod: billingPeriod,
  formattedPrice: formattedPrice,
  priceAmountMicros: 1000000,
  priceCurrencyCode: currency,
  recurrenceMode: RecurrenceMode.infiniteRecurring,
);

/// A subscription product with one offer per entry of [offers].
ProductDetailsWrapper subscription(
  String productId,
  List<List<PricingPhaseWrapper>> offers,
) => ProductDetailsWrapper(
  description: 'description',
  name: productId,
  productId: productId,
  productType: ProductType.subs,
  title: productId,
  subscriptionOfferDetails: [
    for (var index = 0; index < offers.length; index++)
      SubscriptionOfferDetailsWrapper(
        basePlanId: 'base',
        offerTags: const [],
        offerIdToken: 'offer-token-$productId-$index',
        pricingPhases: offers[index],
      ),
  ],
);

/// The plain monthly base plan every approved product is configured as.
ProductDetailsWrapper monthly(String productId, String formattedPrice) =>
    subscription(productId, [
      [phase(billingPeriod: 'P1M', formattedPrice: formattedPrice)],
    ]);

List<GooglePlayProductDetails> detailsFor(
  List<ProductDetailsWrapper> wrappers,
) => [
  for (final wrapper in wrappers)
    ...GooglePlayProductDetails.fromProductDetails(wrapper),
];

/// A billing data source driven entirely from the test.
class FakeBillingDataSource extends GooglePlayBillingDataSource {
  FakeBillingDataSource({
    this.available = true,
    List<ProductDetailsWrapper> products = const [],
    this.queryThrows,
  }) : _products = products;

  final bool available;
  final List<ProductDetailsWrapper> _products;
  final Object? queryThrows;

  final StreamController<List<PurchaseDetails>> controller =
      StreamController<List<PurchaseDetails>>.broadcast();

  int queryCount = 0;
  int streamReads = 0;
  final List<PurchaseParam> bought = [];
  final List<PurchaseDetails> completed = [];

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<List<GooglePlayProductDetails>> queryProducts(
    Set<String> productIds,
  ) async {
    queryCount++;
    final failure = queryThrows;
    if (failure != null) throw failure;
    return detailsFor(
      _products.where((p) => productIds.contains(p.productId)).toList(),
    );
  }

  @override
  Stream<List<PurchaseDetails>> get purchaseStream {
    streamReads++;
    return controller.stream;
  }

  @override
  Future<bool> buy(PurchaseParam purchaseParam) async {
    bought.add(purchaseParam);
    return true;
  }

  @override
  Future<void> complete(PurchaseDetails purchase) async {
    completed.add(purchase);
  }
}

PurchaseDetails purchaseOf({
  required String productId,
  required PurchaseStatus status,
  String token = 'provider-purchase-token',
  bool pendingCompletePurchase = true,
}) {
  final details = PurchaseDetails(
    productID: productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local',
      serverVerificationData: token,
      source: 'google_play',
    ),
    transactionDate: null,
    status: status,
  );
  details.pendingCompletePurchase = pendingCompletePurchase;
  return details;
}

/// Builds a controller and disposes it with the test.
({
  PurchaseController controller,
  FakeStoreBillingGateway store,
  FakePurchaseVerificationGateway verify,
  List<int> refreshes,
})
harness({
  bool available = true,
  Object? verificationFailure,
  Object? startThrows,
  String? accountId = 'account-uuid',
}) {
  final store = FakeStoreBillingGateway(
    available: available,
    startThrows: startThrows,
  );
  final verification = FakePurchaseVerificationGateway(
    failure: verificationFailure,
  );
  final refreshes = <int>[];
  final controller = PurchaseController(
    store: store,
    verification: () => verification,
    refreshSubscription: () async => refreshes.add(1),
    accountId: accountId,
  );
  addTearDown(controller.dispose);
  addTearDown(store.dispose);
  return (
    controller: controller,
    store: store,
    verify: verification,
    refreshes: refreshes,
  );
}

void main() {
  // -------------------------------------------------------------------------
  group('approved store products', () {
    test('exactly the six approved product ids are configured', () {
      // The three V1 products, and the three Preview-only target products the
      // Expansion Source of Truth fixes for SUB-12B. Same-price siblings are
      // distinct products: a purchase is told apart by its product id alone.
      expect(StoreProductCatalog.purchasableProductIds, {
        'facetune_plus',
        'facetune_plus_preview',
        'facetune_pro',
        'facetune_pro_preview',
        'facetune_salon_pro',
        'facetune_salon_preview',
      });
    });

    test('each publicly purchasable plan has exactly one product id', () {
      for (final definition in SubscriptionPlanCatalog.publiclyPurchasable) {
        expect(
          StoreProductCatalog.productIdFor(definition.planCode),
          isNotNull,
          reason: '${definition.planCode.code} is on sale and needs a product',
        );
      }
    });

    test('Salon Pilot cannot be purchased through Google Play', () {
      expect(
        StoreProductCatalog.productIdFor(SubscriptionPlanCode.salonPilot),
        isNull,
      );
      expect(
        StoreProductCatalog.isPurchasable(SubscriptionPlanCode.salonPilot),
        isFalse,
      );
      expect(
        StoreProductCatalog.purchasableProductIds.any(
          (id) => id.contains('pilot'),
        ),
        isFalse,
      );
    });

    test('Free cannot be purchased through Google Play', () {
      expect(
        StoreProductCatalog.productIdFor(SubscriptionPlanCode.free),
        isNull,
      );
      expect(
        StoreProductCatalog.isPurchasable(SubscriptionPlanCode.free),
        isFalse,
      );
    });

    test('the purchasable set matches the catalog exactly', () {
      // Neither side may drift: a plan marked purchasable with no product would
      // show an unbuyable button, and a product for a non-public plan would put
      // Salon Pilot on sale.
      final purchasableInCatalog = SubscriptionPlanCatalog.publiclyPurchasable
          .map((definition) => definition.planCode)
          .toSet();
      final withProducts = SubscriptionPlanCode.values
          .where(StoreProductCatalog.isPurchasable)
          .toSet();
      expect(withProducts, purchasableInCatalog);
    });

    test('a product id maps back to its plan for display only', () {
      expect(
        StoreProductCatalog.planFor('facetune_pro'),
        SubscriptionPlanCode.pro,
      );
      expect(StoreProductCatalog.planFor('something_else'), isNull);
    });
  });

  // -------------------------------------------------------------------------
  group('product query', () {
    test(
      'maps each approved product to its plan and localized price',
      () async {
        final billing = FakeBillingDataSource(
          products: [
            monthly('facetune_plus', 'XTS 1.00'),
            monthly('facetune_pro', 'XTS 2.00'),
            monthly('facetune_salon_pro', 'XTS 3.00'),
          ],
        );
        final gateway = GooglePlayBillingGateway(billing);
        addTearDown(gateway.dispose);

        final products = await gateway.loadProducts();

        expect(products.map((p) => p.planCode), [
          SubscriptionPlanCode.plus,
          SubscriptionPlanCode.pro,
          SubscriptionPlanCode.salonPro,
        ]);
        expect(products.first.providerProductId, 'facetune_plus');
        expect(products.first.price.formattedPrice, 'XTS 1.00');
        expect(products.first.price.currencyCode, 'XTS');
        expect(products.first.price.billingPeriodLabel, 'month');
        expect(products.first.price.displayPrice, 'XTS 1.00 / month');
      },
    );

    test('a product the store does not return is simply absent', () async {
      // Not substituted, not defaulted, and above all not free.
      final billing = FakeBillingDataSource(
        products: [monthly('facetune_plus', 'XTS 1.00')],
      );
      final gateway = GooglePlayBillingGateway(billing);
      addTearDown(gateway.dispose);

      final products = await gateway.loadProducts();

      expect(products.map((p) => p.planCode), [SubscriptionPlanCode.plus]);
    });

    test('an empty store yields no products rather than an error', () async {
      final gateway = GooglePlayBillingGateway(FakeBillingDataSource());
      addTearDown(gateway.dispose);

      expect(await gateway.loadProducts(), isEmpty);
    });

    test('a failing query propagates so the paywall can report it', () async {
      final gateway = GooglePlayBillingGateway(
        FakeBillingDataSource(
          queryThrows: const StoreQueryException('store unreachable'),
        ),
      );
      addTearDown(gateway.dispose);

      expect(gateway.loadProducts(), throwsA(isA<StoreQueryException>()));
    });

    test('the plain base plan wins over an introductory offer', () async {
      // The plugin prices each offer from its *first* pricing phase, so quoting
      // an intro offer would advertise the intro amount as the plan's price.
      final billing = FakeBillingDataSource(
        products: [
          subscription('facetune_plus', [
            // An introductory offer: a discounted phase, then the real one.
            [
              phase(billingPeriod: 'P1M', formattedPrice: 'XTS 0.00'),
              phase(billingPeriod: 'P1M', formattedPrice: 'XTS 1.00'),
            ],
            // The plain base plan.
            [phase(billingPeriod: 'P1M', formattedPrice: 'XTS 1.00')],
          ]),
        ],
      );
      final gateway = GooglePlayBillingGateway(billing);
      addTearDown(gateway.dispose);

      final products = await gateway.loadProducts();

      expect(products.single.price.formattedPrice, 'XTS 1.00');
    });

    test('an unrecognised billing period yields no period label', () async {
      final billing = FakeBillingDataSource(
        products: [
          subscription('facetune_plus', [
            [phase(billingPeriod: 'P10D', formattedPrice: 'XTS 1.00')],
          ]),
        ],
      );
      final gateway = GooglePlayBillingGateway(billing);
      addTearDown(gateway.dispose);

      final price = (await gateway.loadProducts()).single.price;

      // Better to omit the period than to guess one.
      expect(price.billingPeriodLabel, isNull);
      expect(price.displayPrice, 'XTS 1.00');
    });
  });

  // -------------------------------------------------------------------------
  group('paywall prices', () {
    test('an unavailable store yields no prices and no error', () async {
      final source = GooglePlayPlanPriceSource(
        FakeStoreBillingGateway(available: false),
      );

      expect(await source.loadPrices(), isEmpty);
    });

    test('prices are keyed by plan, straight from the provider', () async {
      final source = GooglePlayPlanPriceSource(
        FakeStoreBillingGateway(
          products: const [
            StoreProduct(
              planCode: SubscriptionPlanCode.pro,
              providerProductId: 'facetune_pro',
              price: PlanPrice(
                formattedPrice: 'XTS 2.00',
                currencyCode: 'XTS',
                billingPeriodLabel: 'month',
              ),
            ),
          ],
        ),
      );

      final prices = await source.loadPrices();

      expect(prices.keys, [SubscriptionPlanCode.pro]);
      expect(prices[SubscriptionPlanCode.pro]!.formattedPrice, 'XTS 2.00');
    });
  });

  // -------------------------------------------------------------------------
  group('purchase initiation', () {
    for (final plan in [
      SubscriptionPlanCode.plus,
      SubscriptionPlanCode.pro,
      SubscriptionPlanCode.salonPro,
    ]) {
      test('${plan.code} launches the provider flow with its offer', () async {
        final billing = FakeBillingDataSource(
          products: [
            monthly('facetune_plus', 'XTS 1.00'),
            monthly('facetune_pro', 'XTS 2.00'),
            monthly('facetune_salon_pro', 'XTS 3.00'),
          ],
        );
        final gateway = GooglePlayBillingGateway(billing);
        addTearDown(gateway.dispose);

        await gateway.startPurchase(plan, obfuscatedAccountId: 'account-uuid');

        final param = billing.bought.single as GooglePlayPurchaseParam;
        expect(param.productDetails.id, StoreProductCatalog.productIdFor(plan));
        expect(param.offerToken, isNotNull);
        expect(param.applicationUserName, 'account-uuid');
      });
    }

    test('product details are re-queried for every purchase', () async {
      // Play documents that a stale ProductDetails makes launchBillingFlow fail.
      final billing = FakeBillingDataSource(
        products: [monthly('facetune_plus', 'XTS 1.00')],
      );
      final gateway = GooglePlayBillingGateway(billing);
      addTearDown(gateway.dispose);

      await gateway.loadProducts();
      await gateway.startPurchase(SubscriptionPlanCode.plus);
      await gateway.startPurchase(SubscriptionPlanCode.plus);

      expect(billing.queryCount, 3);
    });

    test('Salon Pilot cannot be launched as a purchase', () async {
      final gateway = GooglePlayBillingGateway(FakeBillingDataSource());
      addTearDown(gateway.dispose);

      expect(
        () => gateway.startPurchase(SubscriptionPlanCode.salonPilot),
        throwsA(isA<StateError>()),
      );
    });

    test('Free cannot be launched as a purchase', () async {
      final gateway = GooglePlayBillingGateway(FakeBillingDataSource());
      addTearDown(gateway.dispose);

      expect(
        () => gateway.startPurchase(SubscriptionPlanCode.free),
        throwsA(isA<StateError>()),
      );
    });

    test('a plan with no configured store product cannot be bought', () async {
      final gateway = GooglePlayBillingGateway(FakeBillingDataSource());
      addTearDown(gateway.dispose);

      expect(
        () => gateway.startPurchase(SubscriptionPlanCode.plus),
        throwsA(isA<StoreQueryException>()),
      );
    });
  });

  // -------------------------------------------------------------------------
  group('provider purchase updates', () {
    Future<PurchaseUpdate> firstUpdateFor(PurchaseDetails purchase) async {
      final billing = FakeBillingDataSource();
      final gateway = GooglePlayBillingGateway(billing);
      addTearDown(gateway.dispose);

      final next = gateway.purchaseUpdates.first;
      billing.controller.add([purchase]);
      return next;
    }

    test('a pending purchase grants nothing and is left untouched', () async {
      final update = await firstUpdateFor(
        purchaseOf(productId: 'facetune_plus', status: PurchaseStatus.pending),
      );

      expect(update.status, PurchaseUpdateStatus.pending);
      // The provider forbids acknowledging a pending purchase.
      expect(update.awaitingCompletion, isFalse);
      expect(update.evidence, isNull);
    });

    test('a paid purchase carries evidence for the backend', () async {
      final update = await firstUpdateFor(
        purchaseOf(productId: 'facetune_pro', status: PurchaseStatus.purchased),
      );

      expect(update.status, PurchaseUpdateStatus.purchased);
      expect(update.planCode, SubscriptionPlanCode.pro);
      expect(update.hasVerifiableEvidence, isTrue);
      expect(update.evidence!.provider, BillingProvider.googlePlay);
      expect(update.evidence!.providerProductId, 'facetune_pro');
      expect(update.awaitingCompletion, isTrue);
    });

    test(
      'user cancellation is reported as cancelled, not as an error',
      () async {
        final update = await firstUpdateFor(
          purchaseOf(
            productId: 'facetune_plus',
            status: PurchaseStatus.canceled,
          ),
        );

        expect(update.status, PurchaseUpdateStatus.cancelled);
        expect(update.message, isNull);
      },
    );

    test('a provider error is reported without the provider payload', () async {
      final update = await firstUpdateFor(
        purchaseOf(productId: 'facetune_plus', status: PurchaseStatus.error),
      );

      expect(update.status, PurchaseUpdateStatus.failed);
      expect(update.message, isNotNull);
      expect(update.message, contains('could not complete'));
    });

    test('a restored purchase still needs verification', () async {
      final update = await firstUpdateFor(
        purchaseOf(productId: 'facetune_plus', status: PurchaseStatus.restored),
      );

      expect(update.status, PurchaseUpdateStatus.restored);
      expect(update.hasVerifiableEvidence, isTrue);
    });

    test('the provider stream is subscribed to exactly once', () async {
      final billing = FakeBillingDataSource();
      final gateway = GooglePlayBillingGateway(billing);
      addTearDown(gateway.dispose);

      gateway.purchaseUpdates.listen((_) {});
      gateway.purchaseUpdates.listen((_) {});
      gateway.purchaseUpdates.listen((_) {});

      // Three listeners, one provider subscription: otherwise each purchase
      // would be forwarded for verification three times.
      expect(billing.streamReads, 1);
    });

    test(
      'disposal releases the provider subscription and the stream',
      () async {
        final billing = FakeBillingDataSource();
        final gateway = GooglePlayBillingGateway(billing);

        gateway.purchaseUpdates.listen((_) {});
        await gateway.dispose();

        // Safe to call twice, and events after disposal are dropped rather than
        // thrown into a closed controller.
        await gateway.dispose();
        expect(() => billing.controller.add([]), returnsNormally);
      },
    );
  });

  // -------------------------------------------------------------------------
  group('acknowledgement is gated on verification', () {
    test('a verified purchase is acknowledged with the provider', () async {
      final billing = FakeBillingDataSource();
      final gateway = GooglePlayBillingGateway(billing);
      addTearDown(gateway.dispose);

      final next = gateway.purchaseUpdates.first;
      billing.controller.add([
        purchaseOf(
          productId: 'facetune_plus',
          status: PurchaseStatus.purchased,
        ),
      ]);
      final update = await next;

      await gateway.completeVerifiedPurchase(update.evidence!);

      expect(billing.completed, hasLength(1));
    });

    test('an unknown purchase is not acknowledged', () async {
      final billing = FakeBillingDataSource();
      final gateway = GooglePlayBillingGateway(billing);
      addTearDown(gateway.dispose);

      await gateway.completeVerifiedPurchase(
        const PurchaseEvidence(
          provider: BillingProvider.googlePlay,
          providerProductId: 'facetune_plus',
          purchaseToken: 'never-seen',
        ),
      );

      expect(billing.completed, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  group('purchase controller', () {
    test('reports unavailable when the store cannot be reached', () async {
      final h = harness(available: false);
      await h.controller.start();

      expect(h.controller.state.phase, PurchasePhase.unavailable);
      expect(h.controller.state.storeAvailable, isFalse);
      expect(h.controller.state.canPurchase, isFalse);
    });

    test('reports idle and purchasable when the store is reachable', () async {
      final h = harness();
      await h.controller.start();

      expect(h.controller.state.phase, PurchasePhase.idle);
      expect(h.controller.state.canPurchase, isTrue);
    });

    test('start is idempotent, so one listener is attached', () async {
      final h = harness();
      await h.controller.start();
      await h.controller.start();
      await h.controller.start();

      expect(h.store.streamReads, 1);
    });

    test(
      'a purchase cannot be started while the store is unavailable',
      () async {
        final h = harness(available: false);
        await h.controller.start();

        await h.controller.buy(SubscriptionPlanCode.pro);

        expect(h.store.started, isEmpty);
      },
    );

    test('buying passes the opaque account id to the provider', () async {
      final h = harness();
      await h.controller.start();

      await h.controller.buy(SubscriptionPlanCode.pro);

      expect(h.store.started, [SubscriptionPlanCode.pro]);
      expect(h.store.accountIds, ['account-uuid']);
      expect(h.controller.state.phase, PurchasePhase.starting);
    });

    test('a second purchase is refused while one is in flight', () async {
      final h = harness();
      await h.controller.start();

      await h.controller.buy(SubscriptionPlanCode.pro);
      await h.controller.buy(SubscriptionPlanCode.plus);

      expect(h.store.started, [SubscriptionPlanCode.pro]);
    });

    test('a failure to open the sheet reports sanitized copy', () async {
      final h = harness(startThrows: Exception('BillingClient code 6: raw'));
      await h.controller.start();

      await h.controller.buy(SubscriptionPlanCode.pro);

      expect(h.controller.state.phase, PurchasePhase.failed);
      expect(h.controller.state.message, isNot(contains('BillingClient')));
      expect(h.controller.state.message, isNot(contains('raw')));
    });

    test(
      'a pending purchase is reported as waiting, never as granted',
      () async {
        final h = harness();
        await h.controller.start();

        h.store.updates.add(
          const PurchaseUpdate(
            status: PurchaseUpdateStatus.pending,
            awaitingCompletion: false,
            planCode: SubscriptionPlanCode.pro,
          ),
        );
        await pumpEventQueue();

        expect(h.controller.state.phase, PurchasePhase.awaitingPayment);
        expect(h.verify.received, isEmpty);
        expect(h.refreshes, isEmpty);
      },
    );

    test('cancellation returns to a neutral state with no alarm', () async {
      final h = harness();
      await h.controller.start();

      h.store.updates.add(
        const PurchaseUpdate(
          status: PurchaseUpdateStatus.cancelled,
          awaitingCompletion: false,
        ),
      );
      await pumpEventQueue();

      expect(h.controller.state.phase, PurchasePhase.cancelled);
      expect(h.controller.state.message, isNull);
    });

    test('a provider error is surfaced and grants nothing', () async {
      final h = harness();
      await h.controller.start();

      h.store.updates.add(
        const PurchaseUpdate(
          status: PurchaseUpdateStatus.failed,
          awaitingCompletion: false,
          message: 'The purchase did not go through.',
        ),
      );
      await pumpEventQueue();

      expect(h.controller.state.phase, PurchasePhase.failed);
      expect(h.refreshes, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  group('the client cannot grant entitlement', () {
    const evidence = PurchaseEvidence(
      provider: BillingProvider.googlePlay,
      providerProductId: 'facetune_pro',
      purchaseToken: 'provider-purchase-token',
    );

    const paid = PurchaseUpdate(
      status: PurchaseUpdateStatus.purchased,
      awaitingCompletion: true,
      planCode: SubscriptionPlanCode.pro,
      evidence: evidence,
    );

    test('a paid purchase is forwarded to the backend, not applied', () async {
      final h = harness();
      await h.controller.start();

      h.store.updates.add(paid);
      await pumpEventQueue();

      expect(h.verify.received.single.purchaseToken, 'provider-purchase-token');
      expect(h.verify.received.single.providerProductId, 'facetune_pro');
    });

    test('server state is re-read only after verification succeeds', () async {
      final h = harness();
      await h.controller.start();

      h.store.updates.add(paid);
      await pumpEventQueue();

      expect(h.controller.state.phase, PurchasePhase.verified);
      expect(h.refreshes, hasLength(1));
      expect(h.store.completed, hasLength(1));
    });

    test(
      'a rejected purchase is never acknowledged and grants nothing',
      () async {
        final h = harness(
          verificationFailure: const SubscriptionStateFailure(
            'Purchases cannot be confirmed yet.',
            kind: SubscriptionStateFailureKind.unavailable,
            retryable: false,
          ),
        );
        await h.controller.start();

        h.store.updates.add(paid);
        await pumpEventQueue();

        expect(h.controller.state.phase, PurchasePhase.failed);
        // Not acknowledged: Google auto-refunds what nothing could verify.
        expect(h.store.completed, isEmpty);
        // And no authoritative state was requested, let alone changed.
        expect(h.refreshes, isEmpty);
      },
    );

    test('an unexpected verification error also grants nothing', () async {
      final h = harness(verificationFailure: Exception('boom'));
      await h.controller.start();

      h.store.updates.add(paid);
      await pumpEventQueue();

      expect(h.controller.state.phase, PurchasePhase.failed);
      expect(h.store.completed, isEmpty);
      expect(h.refreshes, isEmpty);
    });

    test('evidence with no token is not forwarded', () async {
      final h = harness();
      await h.controller.start();

      h.store.updates.add(
        const PurchaseUpdate(
          status: PurchaseUpdateStatus.purchased,
          awaitingCompletion: true,
          evidence: PurchaseEvidence(
            provider: BillingProvider.googlePlay,
            providerProductId: 'facetune_pro',
            purchaseToken: '',
          ),
        ),
      );
      await pumpEventQueue();

      expect(h.verify.received, isEmpty);
      expect(h.controller.state.phase, PurchasePhase.failed);
    });

    test(
      'no state the controller can reach describes an entitlement',
      () async {
        final h = harness();
        await h.controller.start();
        h.store.updates.add(paid);
        await pumpEventQueue();

        // The verified phase reports that a step finished. It carries no plan
        // grant, no allowance, and no expiry — those exist only on the server's
        // SubscriptionSummary.
        final state = h.controller.state;
        expect(state.phase, PurchasePhase.verified);
        expect(state.toString(), isNot(contains('allowance')));
      },
    );
  });

  // -------------------------------------------------------------------------
  group('verification is genuinely absent, not faked', () {
    test('the current gateway refuses every purchase', () async {
      const gateway = UnavailablePurchaseVerificationGateway();

      await expectLater(
        gateway.verify(
          const PurchaseEvidence(
            provider: BillingProvider.googlePlay,
            providerProductId: 'facetune_pro',
            purchaseToken: 'provider-purchase-token',
          ),
        ),
        throwsA(
          isA<SubscriptionStateFailure>()
              .having((f) => f.retryable, 'retryable', isFalse)
              .having(
                (f) => f.kind,
                'kind',
                SubscriptionStateFailureKind.unavailable,
              ),
        ),
      );
    });
  });

  // -------------------------------------------------------------------------
  group('the purchase token is treated as a secret', () {
    const evidence = PurchaseEvidence(
      provider: BillingProvider.googlePlay,
      providerProductId: 'facetune_pro',
      purchaseToken: 'super-secret-provider-token',
    );

    test('it never appears in the evidence string form', () {
      expect(evidence.toString(), isNot(contains('super-secret')));
      expect(evidence.toString(), contains('[REDACTED]'));
    });

    test('nor in a purchase update, nor in controller state', () async {
      const update = PurchaseUpdate(
        status: PurchaseUpdateStatus.purchased,
        awaitingCompletion: true,
        planCode: SubscriptionPlanCode.pro,
        evidence: evidence,
      );
      expect(update.toString(), isNot(contains('super-secret')));

      final h = harness();
      await h.controller.start();
      h.store.updates.add(update);
      await pumpEventQueue();

      expect(h.controller.state.message, isNot(contains('super-secret')));
      expect(h.controller.state.toString(), isNot(contains('super-secret')));
    });
  });
}
