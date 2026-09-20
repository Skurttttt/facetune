import 'purchase_evidence.dart';
import 'subscription_plan_code.dart';
import 'top_up_pack.dart';

/// What the provider last reported about a purchase the user started.
///
/// Deliberately a *separate* vocabulary from both `PurchaseLifecycleStatus`
/// (verified provider lifecycle, resolved server-side) and `EntitlementStatus`
/// (what the account is actually entitled to). This one is narrower than
/// either: it describes only the client-visible outcome of a purchase flow on
/// this device, which is the least trustworthy of the three and must never be
/// promoted into the other two by assignment.
enum PurchaseUpdateStatus {
  /// Payment has not completed — awaiting an out-of-band step such as a cash
  /// payment or a family approval.
  ///
  /// Not a grant of anything, and explicitly not acknowledgeable: the provider
  /// requires that a purchase stay untouched until it leaves this state.
  pending,

  /// The provider reports the purchase as paid.
  ///
  /// This is the point at which evidence becomes worth sending for
  /// verification. It is *not* the point at which anything is unlocked.
  purchased,

  /// A previously owned purchase was re-delivered to this device.
  ///
  /// Handled on the same terms as [purchased] — it needs the same server
  /// verification, and grants nothing by itself. Surfacing restore as a user
  /// action belongs to a later phase; this member exists because the provider
  /// can deliver one unprompted and it must not be dropped.
  restored,

  /// The user backed out of the provider's purchase sheet. Not an error.
  cancelled,

  /// The provider reported a failure.
  failed,
}

/// A single purchase-flow event from the provider.
///
/// [evidence] is present only for states that could carry a token, and is the
/// sole thing worth forwarding to the backend. [planCode] is a display hint
/// resolved from the product id — see `StoreProductCatalog.planFor` — and
/// carries no authority whatsoever.
class PurchaseUpdate {
  const PurchaseUpdate({
    required this.status,
    required this.awaitingCompletion,
    this.planCode,
    this.topUpPack,
    this.evidence,
    this.message,
  });

  final PurchaseUpdateStatus status;

  /// Whether the provider still expects this purchase to be completed
  /// (acknowledged).
  ///
  /// Tracked because the acknowledgement deadline is real — an unacknowledged
  /// purchase is refunded automatically and its entitlement revoked — but
  /// completion is deliberately *not* performed on the strength of this flag
  /// alone. It may only happen after the server has verified the purchase, so
  /// this records an obligation, not a permission.
  final bool awaitingCompletion;

  /// Which plan the purchased product maps to, for wording a progress message.
  /// Never used to grant.
  final SubscriptionPlanCode? planCode;

  /// Which top-up pack the purchased product maps to, when it is one — see
  /// `TopUpPackCatalog.packFor`. A display and routing hint: it decides which
  /// verifier the evidence is sent to, and nothing about what is granted.
  /// Null for every subscription product.
  final TopUpPack? topUpPack;

  /// Whether this update concerns a top-up pack rather than a plan.
  bool get isTopUp => topUpPack != null;

  /// Provider evidence for the backend to verify. Null unless the state could
  /// produce one.
  final PurchaseEvidence? evidence;

  /// A sanitized, user-facing description of a failure. Never a provider
  /// payload, never a token.
  final String? message;

  /// Whether this update carries something the backend could verify.
  bool get hasVerifiableEvidence => evidence?.isVerifiable ?? false;

  @override
  String toString() =>
      'PurchaseUpdate(${status.name}, plan: ${planCode?.code ?? '-'}, '
      'pack: ${topUpPack?.code ?? '-'})';
}
