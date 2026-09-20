import '../entities/purchase_evidence.dart';

/// How the purchase reached the client: bought just now, or found again by a
/// restore. Carried for telemetry only (SUB-13): the server counts restores
/// and purchases separately, and nothing about verification depends on it.
enum PurchaseVerificationSource {
  purchase('purchase'),
  restore('restore');

  const PurchaseVerificationSource(this.code);

  final String code;
}

/// Sends provider purchase evidence to the FaceTune backend for verification.
///
/// This is the seam between the client billing phase and server verification.
/// It exists now, with a deliberately unimplemented backing, so that the
/// purchase flow is *built around* verification from the first line rather than
/// having it retrofitted later — a flow that works without this call is a flow
/// that grants without it.
///
/// The implementation that actually calls the backend, re-fetches the purchase
/// from the provider's API, and persists an entitlement belongs to the next
/// phase. Until it lands, `UnavailablePurchaseVerificationGateway` refuses
/// every call, and the client correctly grants nothing.
abstract interface class PurchaseVerificationGateway {
  /// Submits [evidence] for server-side verification.
  ///
  /// Returns normally only when the server confirms the purchase is genuine and
  /// has recorded whatever entitlement it decided on. The client then re-reads
  /// authoritative subscription state; it does not infer one from this call.
  ///
  /// Note there is no plan, allowance, or expiry in the return type. Returning
  /// an entitlement here would invite the caller to apply it directly, so the
  /// only thing this reports is *that* verification succeeded. What the account
  /// now has is read back from the subscription repository, which is the single
  /// authority for it.
  ///
  /// Throws a `SubscriptionStateFailure` when verification could not be
  /// completed, and when the server rejects the purchase.
  ///
  /// [source] says whether this is a fresh purchase or a restore. It is a
  /// measurement label, not an input to the decision: the server verifies the
  /// same way either way.
  Future<void> verify(
    PurchaseEvidence evidence, {
    PurchaseVerificationSource source = PurchaseVerificationSource.purchase,
  });
}
