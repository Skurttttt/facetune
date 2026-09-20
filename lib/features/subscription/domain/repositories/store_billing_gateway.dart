import '../entities/purchase_evidence.dart';
import '../entities/purchase_update.dart';
import '../entities/store_product.dart';
import '../entities/subscription_plan_code.dart';
import '../entities/top_up_pack.dart';
import '../entities/top_up_store_product.dart';

/// The app's view of a billing provider.
///
/// Provider-agnostic on purpose: no SDK type crosses this boundary, so the
/// domain never learns what store it is talking to and a second provider can
/// be added later without a domain change. The Google Play implementation lives
/// in the data layer.
///
/// ## What this interface deliberately cannot do
///
/// There is no `grant`, no `setPlan`, and no `markEntitled`. The only two
/// mutating operations are "start a purchase" and "finish an already-verified
/// one", because those are the only two a client is allowed to perform. A
/// method that turned a provider result into an entitlement would be the
/// forbidden `if (purchaseSucceeded) …` written one layer down.
abstract interface class StoreBillingGateway {
  /// Whether the store is reachable and billing is usable on this device.
  ///
  /// Must answer `false` rather than throw when the provider is missing,
  /// disabled, or unavailable on the platform: an unavailable store is an
  /// ordinary condition the paywall shows honestly, not an error.
  Future<bool> isAvailable();

  /// The purchasable plans as the store currently describes them.
  ///
  /// Returns only products the store actually returned. An identifier the
  /// store does not know is omitted rather than substituted, so a plan that is
  /// not configured yet simply cannot be bought — it never appears with an
  /// invented price.
  Future<List<StoreProduct>> loadProducts();

  /// Provider purchase events, including ones that arrive unprompted.
  ///
  /// A broadcast stream: the provider can deliver a purchase completed on
  /// another device, or one that finished while the app was closed, and those
  /// must reach the same handling as a purchase started here.
  Stream<PurchaseUpdate> get purchaseUpdates;

  /// Opens the provider's purchase sheet for [plan].
  ///
  /// The result never arrives as a return value — it arrives on
  /// [purchaseUpdates], because the provider can also deliver it long after
  /// this future completes. Completing with no error means only that the sheet
  /// was successfully opened.
  ///
  /// [obfuscatedAccountId] is passed to the provider so a purchase can later be
  /// tied back to the account that started it. It must be an opaque, non-
  /// reversible identifier, never an email address.
  Future<void> startPurchase(
    SubscriptionPlanCode plan, {
    String? obfuscatedAccountId,
  });

  /// Asks the provider to re-deliver the purchases this account already owns.
  ///
  /// Like [startPurchase], the result never arrives as a return value: each
  /// recovered purchase is delivered on [purchaseUpdates] and goes through the
  /// identical verification path as a fresh one. Completing with no error
  /// means the provider accepted the request, not that anything was found and
  /// certainly not that anything is restored — a restored purchase is still
  /// only evidence until the server has verified it.
  ///
  /// Deliberately has no return value describing what was found. A count here
  /// would be a client-side answer to "what does this account have", which is
  /// the one question the client is never allowed to answer.
  Future<void> restorePurchases();

  /// Acknowledges a purchase the **server has already verified**.
  ///
  /// Split out from the purchase flow, and named for its precondition, so that
  /// calling it without a verified response reads as obviously wrong at the
  /// call site. Acknowledging on client say-so would tell the provider the
  /// entitlement was delivered when nothing had checked that it should be.
  Future<void> completeVerifiedPurchase(PurchaseEvidence evidence);

  // ---------------------------------------------------------------------------
  // SUB-13B top-up packs. One-time products, sold beside the subscriptions.
  // ---------------------------------------------------------------------------

  /// The purchasable top-up packs as the store currently describes them.
  ///
  /// The same rule as [loadProducts]: only packs the store actually returned,
  /// and never an invented price.
  Future<List<TopUpStoreProduct>> loadTopUpProducts();

  /// Opens the provider's purchase sheet for [pack].
  ///
  /// Like [startPurchase], the result arrives on [purchaseUpdates], carrying
  /// the pack the product maps to as a display and routing hint. The purchase
  /// is started as a consumable that is **not** auto-consumed: consuming
  /// client-side before the server had verified and granted would waive the
  /// automatic refund that protects a purchase nothing was able to verify.
  Future<void> startTopUpPurchase(
    TopUpPack pack, {
    String? obfuscatedAccountId,
  });

  /// Consumes a top-up purchase the **server has already verified and
  /// granted**.
  ///
  /// Normally the server consumes with Google itself, immediately after the
  /// grant, and reports so; then this only releases the provider object held
  /// for the purchase. When the server could not reach Google for the
  /// consumption, [consumedByServer] is false and this consumes from the
  /// device as the second chance — the grant already exists either way, so
  /// nothing here decides what the account has.
  Future<void> completeVerifiedTopUp(
    PurchaseEvidence evidence, {
    required bool consumedByServer,
  });

  /// Releases the provider connection and the update subscription.
  Future<void> dispose();
}
