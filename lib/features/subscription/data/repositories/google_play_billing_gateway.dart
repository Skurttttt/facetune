import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
// The pricing phases carrying the billing period live in the wrappers library,
// which the package exports separately from its platform API.
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../../domain/catalog/store_product_catalog.dart';
import '../../domain/entities/billing_provider.dart';
import '../../domain/entities/plan_price.dart';
import '../../domain/entities/purchase_evidence.dart';
import '../../domain/entities/purchase_update.dart';
import '../../domain/entities/store_product.dart';
import '../../domain/entities/subscription_plan_code.dart';
import '../../domain/repositories/store_billing_gateway.dart';
import '../data_sources/google_play_billing_data_source.dart';

/// Google Play's implementation of [StoreBillingGateway].
///
/// Translates between the billing SDK and the provider-agnostic domain, and
/// stops there. It reports what the store said; it never decides what the store
/// said *means* for the account.
class GooglePlayBillingGateway implements StoreBillingGateway {
  GooglePlayBillingGateway(this._billing);

  final GooglePlayBillingDataSource _billing;

  /// Fans provider events out to however many listeners the UI attaches.
  ///
  /// Broadcast because a purchase can arrive while more than one surface cares,
  /// and because a single-subscription stream would make the second listener a
  /// runtime error rather than a supported case.
  final StreamController<PurchaseUpdate> _updates =
      StreamController<PurchaseUpdate>.broadcast();

  /// The provider subscription, held so it is created exactly once and can be
  /// cancelled on [dispose].
  StreamSubscription<List<PurchaseDetails>>? _providerSubscription;

  /// Purchases the provider still expects to be acknowledged, keyed by token.
  ///
  /// Needed because acknowledgement happens *later* — after the server has
  /// verified — and the SDK object required to acknowledge is not reconstructible
  /// from the domain evidence alone. Only purchases the provider flagged as
  /// awaiting completion are kept, and each is dropped once completed.
  ///
  /// This is not a product cache: Play explicitly warns that stale
  /// `ProductDetails` break the purchase flow, which is why [startPurchase]
  /// re-queries every time instead of holding on to one.
  final Map<String, PurchaseDetails> _awaitingCompletion = {};

  bool _disposed = false;

  @override
  Future<bool> isAvailable() => _billing.isAvailable();

  @override
  Stream<PurchaseUpdate> get purchaseUpdates {
    _listenOnce();
    return _updates.stream;
  }

  /// Attaches to the provider stream at most once.
  ///
  /// Every UI listener shares one provider subscription. Without this guard a
  /// rebuild that re-read the stream would attach a second, and each purchase
  /// would be handled — and forwarded for verification — twice.
  void _listenOnce() {
    if (_providerSubscription != null || _disposed) return;
    _providerSubscription = _billing.purchaseStream.listen(
      _onProviderEvent,
      onError: (Object error) {
        _emit(
          const PurchaseUpdate(
            status: PurchaseUpdateStatus.failed,
            awaitingCompletion: false,
            message:
                'Google Play stopped responding during the purchase. '
                'Please try again.',
          ),
        );
      },
    );
  }

  void _onProviderEvent(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      _emit(_toUpdate(purchase));
    }
  }

  void _emit(PurchaseUpdate update) {
    if (_disposed || _updates.isClosed) return;
    _updates.add(update);
  }

  /// Maps one provider purchase into the domain vocabulary.
  ///
  /// Note what does not happen here: nothing is unlocked, no plan is stored,
  /// and the purchase is not acknowledged. A `purchased` status becomes an
  /// update carrying evidence, and the obligation to verify it travels with it.
  PurchaseUpdate _toUpdate(PurchaseDetails purchase) {
    final token = purchase.verificationData.serverVerificationData;
    final plan = StoreProductCatalog.planFor(purchase.productID);
    final awaiting = purchase.pendingCompletePurchase;

    if (awaiting && token.isNotEmpty) {
      _awaitingCompletion[token] = purchase;
    }

    final evidence = token.isEmpty
        ? null
        : PurchaseEvidence(
            provider: BillingProvider.googlePlay,
            providerProductId: purchase.productID,
            purchaseToken: token,
          );

    return switch (purchase.status) {
      PurchaseStatus.pending => PurchaseUpdate(
        status: PurchaseUpdateStatus.pending,
        // A pending purchase must be left entirely alone until it settles, so
        // no completion obligation is reported even if the flag were set.
        awaitingCompletion: false,
        planCode: plan,
      ),
      PurchaseStatus.purchased => PurchaseUpdate(
        status: PurchaseUpdateStatus.purchased,
        awaitingCompletion: awaiting,
        planCode: plan,
        evidence: evidence,
      ),
      PurchaseStatus.restored => PurchaseUpdate(
        status: PurchaseUpdateStatus.restored,
        awaitingCompletion: awaiting,
        planCode: plan,
        evidence: evidence,
      ),
      PurchaseStatus.canceled => PurchaseUpdate(
        status: PurchaseUpdateStatus.cancelled,
        awaitingCompletion: false,
        planCode: plan,
      ),
      PurchaseStatus.error => PurchaseUpdate(
        status: PurchaseUpdateStatus.failed,
        awaitingCompletion: awaiting,
        planCode: plan,
        evidence: evidence,
        // The provider's own message is not shown: it is not written for end
        // users and can name internal state. The purchase is simply reported as
        // not completed.
        message:
            'Google Play could not complete the purchase. '
            'You have not been charged for an incomplete purchase.',
      ),
    };
  }

  @override
  Future<List<StoreProduct>> loadProducts() async {
    final offers = await _billing.queryProducts(
      StoreProductCatalog.purchasableProductIds,
    );

    final products = <StoreProduct>[];
    for (final definition in _plansInCatalogOrder) {
      final productId = StoreProductCatalog.productIdFor(definition);
      if (productId == null) continue;

      final offer = _preferredOfferFor(offers, productId);
      if (offer == null) continue;

      products.add(
        StoreProduct(
          planCode: definition,
          providerProductId: productId,
          price: PlanPrice(
            // The store's own localized string, verbatim. Never rebuilt from
            // `rawPrice` and a currency code, which would format it wrongly
            // somewhere in the world.
            formattedPrice: offer.price,
            currencyCode: offer.currencyCode,
            billingPeriodLabel: _billingPeriodLabelOf(offer),
          ),
        ),
      );
    }
    return products;
  }

  /// The purchasable plans, in the order the catalog declares them.
  List<SubscriptionPlanCode> get _plansInCatalogOrder => SubscriptionPlanCode
      .values
      .where(StoreProductCatalog.isPurchasable)
      .toList(growable: false);

  /// Picks which of a subscription's offers the paywall should quote.
  ///
  /// Play returns one entry per eligible offer, all sharing a product id, and
  /// the plugin takes each one's price from its *first* pricing phase. An
  /// introductory or free-trial offer therefore quotes the introductory amount,
  /// which is not what the plan costs.
  ///
  /// So the plain base plan wins: the offer with the fewest pricing phases has
  /// no introductory phase in front of the recurring one. Ties resolve to the
  /// lowest offer index, which keeps the choice deterministic rather than
  /// dependent on provider ordering. The approved configuration has no
  /// introductory offers, so in practice there is one offer per plan and this
  /// only guarantees the answer stays right if one is ever added.
  GooglePlayProductDetails? _preferredOfferFor(
    List<GooglePlayProductDetails> offers,
    String productId,
  ) {
    GooglePlayProductDetails? best;
    var bestPhases = -1;
    for (final offer in offers) {
      if (offer.id != productId) continue;
      final phases = _pricingPhasesOf(offer).length;
      if (best == null || phases < bestPhases) {
        best = offer;
        bestPhases = phases;
      }
    }
    return best;
  }

  List<PricingPhaseWrapper> _pricingPhasesOf(GooglePlayProductDetails offer) {
    final index = offer.subscriptionIndex;
    final subscriptionOffers = offer.productDetails.subscriptionOfferDetails;
    if (index == null ||
        subscriptionOffers == null ||
        index >= subscriptionOffers.length) {
      return const <PricingPhaseWrapper>[];
    }
    return subscriptionOffers[index].pricingPhases;
  }

  /// How often the quoted price recurs, in the user's words.
  ///
  /// Read from the *recurring* phase — the last one — because that is the phase
  /// that repeats, and derived only from the provider's ISO-8601 billing
  /// period. An unrecognised period yields null, so the price shows without a
  /// period rather than with one the app guessed.
  String? _billingPeriodLabelOf(GooglePlayProductDetails offer) {
    final phases = _pricingPhasesOf(offer);
    if (phases.isEmpty) return null;
    return _labelForIso8601Period(phases.last.billingPeriod);
  }

  static String? _labelForIso8601Period(String period) => switch (period) {
    'P1W' => 'week',
    'P1M' => 'month',
    'P2M' => '2 months',
    'P3M' => '3 months',
    'P6M' => '6 months',
    'P1Y' => 'year',
    _ => null,
  };

  @override
  Future<void> startPurchase(
    SubscriptionPlanCode plan, {
    String? obfuscatedAccountId,
  }) async {
    final productId = StoreProductCatalog.productIdFor(plan);
    if (productId == null) {
      // Free and Salon Pilot have no store product. Reaching here means a
      // caller tried to buy something that is not for sale, which is a bug
      // worth failing loudly rather than a condition to paper over.
      throw StateError('${plan.code} is not a purchasable store product');
    }

    // Re-queried rather than reused: Play documents that a stale ProductDetails
    // makes the billing flow fail, so the object handed to the provider is
    // always one it just returned.
    final offers = await _billing.queryProducts({productId});
    final offer = _preferredOfferFor(offers, productId);
    if (offer == null) {
      throw StoreQueryException(
        'This plan is not available from Google Play right now.',
      );
    }

    await _billing.buy(
      GooglePlayPurchaseParam(
        productDetails: offer,
        offerToken: offer.offerToken,
        // An opaque account identifier, so the provider — and later the
        // server — can tie the purchase to the account that started it. The
        // caller supplies an already-opaque id; no email or display name is
        // ever passed here.
        applicationUserName: obfuscatedAccountId,
      ),
    );
  }

  @override
  Future<void> restorePurchases() async {
    // The provider stream must already be attached, or Play's answer would
    // arrive with nobody listening and the restore would look like it found
    // nothing. Attaching here rather than trusting the UI to have read
    // `purchaseUpdates` first makes the ordering a property of this method
    // instead of a convention.
    _listenOnce();
    await _billing.restorePurchases();
  }

  @override
  Future<void> completeVerifiedPurchase(PurchaseEvidence evidence) async {
    final purchase = _awaitingCompletion.remove(evidence.purchaseToken);
    // Nothing to acknowledge is a normal outcome, not a failure: the provider
    // may have completed it already, or this evidence may have arrived from a
    // replayed update.
    if (purchase == null) return;
    await _billing.complete(purchase);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _providerSubscription?.cancel();
    _providerSubscription = null;
    _awaitingCompletion.clear();
    await _updates.close();
  }
}
