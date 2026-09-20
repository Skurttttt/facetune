import '../entities/purchase_evidence.dart';
import 'purchase_verification_gateway.dart';

/// What the backend reported after verifying and granting a top-up purchase.
///
/// Deliberately tiny. There is no balance here and no pack: the credits the
/// account now holds are read back from `resolve_subscription_state`, which
/// stays the one description of what the account has. The only fact carried
/// is whether the server managed to consume the purchase with Google, because
/// that decides whether the device must do so as the second chance.
class TopUpVerificationResult {
  const TopUpVerificationResult({
    required this.consumedByServer,
    required this.replayed,
  });

  /// Whether Google has been told the purchase was delivered.
  final bool consumedByServer;

  /// Whether the server had already granted this purchase before — a retry,
  /// a duplicate provider delivery, or a restore. Nothing was granted twice.
  final bool replayed;

  @override
  bool operator ==(Object other) =>
      other is TopUpVerificationResult &&
      other.consumedByServer == consumedByServer &&
      other.replayed == replayed;

  @override
  int get hashCode => Object.hash(consumedByServer, replayed);
}

/// Sends provider evidence for a top-up pack purchase to the FaceTune backend
/// for verification and granting.
///
/// The seam between the client billing phase and server verification for
/// one-time products, kept apart from [PurchaseVerificationGateway] so the
/// subscription path is untouched by top-ups and a subscription token can
/// never be sent down the granting path by mistake.
///
/// Implementations must not:
///
/// * return a balance, a quantity, or a pack — see [TopUpVerificationResult];
/// * consume or acknowledge with the provider before the server has answered;
/// * decide anything from the evidence themselves.
///
/// Throws a `SubscriptionStateFailure` when verification could not be
/// completed, and when the server refuses the purchase.
abstract interface class TopUpVerificationGateway {
  Future<TopUpVerificationResult> verify(
    PurchaseEvidence evidence, {
    PurchaseVerificationSource source = PurchaseVerificationSource.purchase,
  });
}
