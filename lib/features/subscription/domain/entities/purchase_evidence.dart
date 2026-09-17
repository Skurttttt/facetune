import 'billing_provider.dart';

/// What the billing provider says about a completed purchase, in the form the
/// backend needs in order to verify it.
///
/// ## This is evidence, not entitlement
///
/// Every field here came from the client's own process, so none of it proves
/// anything on its own. Its only purpose is to be handed to the server, which
/// re-fetches the purchase from the provider's API and decides what — if
/// anything — the account is entitled to. Nothing in this class may be used to
/// unlock a feature, choose a plan, or set a local flag.
///
/// Note what is deliberately *absent*: there is no plan code, no price, and no
/// allowance. A client-chosen plan travelling alongside a purchase token is
/// exactly the shape that invites a server to trust it, so it is not carried at
/// all. The server maps the verified product itself.
///
/// ## The token is a secret
///
/// [purchaseToken] can be replayed against the provider's API, so it is treated
/// like a credential: [toString] redacts it, and it must never be written to a
/// log, an analytics event, a crash report, or a debug print. The redacting
/// [toString] is the safety net for the accidental `print(evidence)`, not a
/// licence to be careless — `subscription_billing_security_test.dart` also
/// checks the source for logging calls.
class PurchaseEvidence {
  const PurchaseEvidence({
    required this.provider,
    required this.providerProductId,
    required this.purchaseToken,
    this.obfuscatedAccountId,
  });

  /// Which provider issued this purchase. Always [BillingProvider.googlePlay]
  /// in V1, carried explicitly so the backend never has to assume.
  final BillingProvider provider;

  /// The store product that was bought, for the server to map to a plan.
  final String providerProductId;

  /// The provider's purchase token — the thing the server verifies against.
  ///
  /// Secret. Never log it. Never display it.
  final String purchaseToken;

  /// The obfuscated account identifier sent to the provider at purchase time,
  /// when one was supplied, so the server can cross-check which account the
  /// purchase was started from.
  final String? obfuscatedAccountId;

  /// Whether this carries enough to be worth sending for verification.
  ///
  /// A purchase with no token cannot be verified by anyone, so forwarding it
  /// would only produce a confusing server-side failure.
  bool get isVerifiable =>
      purchaseToken.isNotEmpty && providerProductId.isNotEmpty;

  /// Diagnostic form with the token redacted.
  ///
  /// The product id and provider are safe to show — they are public catalog
  /// facts, not credentials — and keeping them makes the redacted form actually
  /// useful when reading a bug report.
  @override
  String toString() =>
      'PurchaseEvidence(${provider.code}, $providerProductId, '
      'token: [REDACTED])';
}
