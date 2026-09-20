import '../../domain/entities/purchase_evidence.dart';
import '../../domain/errors/subscription_state_failure.dart';
import '../../domain/repositories/purchase_verification_gateway.dart';

/// The verification gateway in force until server-side purchase verification
/// exists.
///
/// It refuses every call, and that refusal is the correct behaviour rather than
/// a gap: with no server able to check a purchase against Google's API, there
/// is nothing that could truthfully grant an entitlement, so the client grants
/// nothing and says so.
///
/// The alternative — letting the purchase flow "succeed" locally while
/// verification is stubbed out — is precisely the forbidden shortcut, and it
/// would be far harder to spot once the screen looked like it worked.
///
/// ## What this means for a real purchase today
///
/// A purchase made against this build would be paid for and never acknowledged.
/// Google refunds an unacknowledged purchase automatically and revokes it, so
/// no user is left silently charged for nothing — but it does mean this build
/// must not be put in front of real buyers, and the completion report says so.
class UnavailablePurchaseVerificationGateway
    implements PurchaseVerificationGateway {
  const UnavailablePurchaseVerificationGateway();

  @override
  Future<void> verify(
    PurchaseEvidence evidence, {
    PurchaseVerificationSource source = PurchaseVerificationSource.purchase,
  }) async {
    throw const SubscriptionStateFailure(
      'Purchases cannot be confirmed yet. If you were charged, Google Play '
      'will refund it automatically.',
      kind: SubscriptionStateFailureKind.unavailable,
      // Retrying cannot help: the capability is absent, not failing.
      retryable: false,
    );
  }
}
