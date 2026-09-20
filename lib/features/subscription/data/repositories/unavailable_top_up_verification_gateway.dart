import '../../domain/entities/purchase_evidence.dart';
import '../../domain/errors/subscription_state_failure.dart';
import '../../domain/repositories/purchase_verification_gateway.dart';
import '../../domain/repositories/top_up_verification_gateway.dart';

/// The top-up verification gateway for a build with no backend configured.
///
/// Refuses every call, for the reason `UnavailablePurchaseVerificationGateway`
/// gives: with no server able to check a purchase against Google's API, there
/// is nothing that could truthfully grant a credit, so the client grants
/// nothing and says so. The purchase stays unconsumed and Google refunds it.
class UnavailableTopUpVerificationGateway implements TopUpVerificationGateway {
  const UnavailableTopUpVerificationGateway();

  @override
  Future<TopUpVerificationResult> verify(
    PurchaseEvidence evidence, {
    PurchaseVerificationSource source = PurchaseVerificationSource.purchase,
  }) async {
    throw const SubscriptionStateFailure(
      'Purchases cannot be confirmed yet. If you were charged, Google Play '
      'will refund it automatically.',
      kind: SubscriptionStateFailureKind.unavailable,
      retryable: false,
    );
  }
}
