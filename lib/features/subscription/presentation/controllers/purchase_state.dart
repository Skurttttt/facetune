import '../../domain/entities/subscription_plan_code.dart';
import '../../domain/entities/top_up_pack.dart';

/// Where a purchase attempt has got to on this device.
///
/// Every member describes a *provider or verification* step. There is
/// deliberately no `entitled` member: what the account is entitled to is read
/// from the server through `SubscriptionController`, and giving this enum a
/// member that meant "the user now has the plan" would put that answer in the
/// one place least qualified to give it.
enum PurchasePhase {
  /// Nothing in flight.
  idle,

  /// Billing is not usable — no store, no configured products, or an
  /// unsupported platform. Purchase actions must stay disabled.
  unavailable,

  /// The provider's purchase sheet has been asked for.
  starting,

  /// The provider is holding the purchase pending an out-of-band step.
  /// Nothing is granted, and the app says only that it is waiting.
  awaitingPayment,

  /// The provider has been asked to re-deliver purchases this account already
  /// owns. Anything it returns goes through verification like any other
  /// purchase, so this phase reports a *query* in flight and nothing more.
  restoring,

  /// The restore query finished and the provider returned no purchase for this
  /// account. Deliberately distinct from [failed]: nothing went wrong, there
  /// is simply nothing to restore, and wording it as an error would tell a
  /// user on a new device that their subscription had broken.
  restoredNothing,

  /// Evidence has been sent to the backend and the answer is outstanding.
  verifying,

  /// The backend verified the purchase. Authoritative subscription state has
  /// been re-read; this phase reports that the *step* completed, not what was
  /// granted.
  verified,

  /// The user dismissed the provider's sheet. Not an error, and not worth an
  /// alarming message.
  cancelled,

  /// The provider or the verification step failed.
  failed,
}

/// What the purchase surface knows.
///
/// Note the absence of a plan, an allowance, or an expiry. This class cannot
/// describe an entitlement even by accident, which is the point: the only type
/// that carries one is `SubscriptionSummary`, and the only way to obtain one is
/// a server read.
class PurchaseState {
  const PurchaseState({
    this.phase = PurchasePhase.idle,
    this.storeAvailable = false,
    this.plan,
    this.topUpPack,
    this.message,
    this.viaRestore = false,
  });

  final PurchasePhase phase;

  /// Whether the provider itself is reachable and usable on this device.
  ///
  /// Separate from whether any plan can actually be bought — a reachable store
  /// with no configured products still sells nothing. See [canPurchase].
  final bool storeAvailable;

  /// The plan the in-flight attempt relates to, for wording a progress
  /// message. A display hint only; it grants nothing.
  final SubscriptionPlanCode? plan;

  /// The top-up pack the in-flight attempt relates to, when it is a pack
  /// purchase rather than a plan. The same kind of hint as [plan]: it decides
  /// which card shows progress, and nothing about what the account holds.
  final TopUpPack? topUpPack;

  /// Sanitized, user-facing copy. Never a provider payload, never a token.
  final String? message;

  /// Whether the current attempt began with Restore rather than with a plan.
  ///
  /// A presentation hint only: it decides *where* the outcome is shown (next
  /// to the Restore control rather than above the plan cards), never what the
  /// outcome is. It carries no plan, allowance, or expiry, and a restore that
  /// found something still goes through the same verification as a purchase.
  final bool viaRestore;

  /// Whether a purchase attempt is in flight and the UI should not start
  /// another.
  bool get isBusy =>
      phase == PurchasePhase.starting ||
      phase == PurchasePhase.awaitingPayment ||
      phase == PurchasePhase.restoring ||
      phase == PurchasePhase.verifying;

  /// Whether purchasing could be offered at all.
  ///
  /// Requires the store *and* an idle flow. Whether a particular plan can be
  /// bought additionally requires the store to have returned a price for it,
  /// which the paywall checks per card — a plan with no store product must not
  /// present an enabled button.
  bool get canPurchase => storeAvailable && !isBusy;

  PurchaseState copyWith({
    PurchasePhase? phase,
    bool? storeAvailable,
    SubscriptionPlanCode? plan,
    TopUpPack? topUpPack,
    String? message,
    bool clearMessage = false,
    bool clearPlan = false,
    bool? viaRestore,
  }) => PurchaseState(
    phase: phase ?? this.phase,
    storeAvailable: storeAvailable ?? this.storeAvailable,
    // An attempt is for a plan or for a pack, never both, and a restore is
    // for neither: naming one hint clears the other, and `clearPlan` clears
    // both.
    plan: clearPlan ? null : (plan ?? (topUpPack != null ? null : this.plan)),
    topUpPack: clearPlan
        ? null
        : (topUpPack ?? (plan != null ? null : this.topUpPack)),
    message: clearMessage ? null : (message ?? this.message),
    viaRestore: viaRestore ?? this.viaRestore,
  );

  @override
  bool operator ==(Object other) =>
      other is PurchaseState &&
      other.phase == phase &&
      other.storeAvailable == storeAvailable &&
      other.plan == plan &&
      other.topUpPack == topUpPack &&
      other.message == message;

  @override
  int get hashCode =>
      Object.hash(phase, storeAvailable, plan, topUpPack, message);
}
