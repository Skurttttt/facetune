/// Who a given entitlement is billed through.
///
/// This is *verified* provider identity resolved server-side, not a client
/// assertion and not something inferred from the plan name. Flutter receives it
/// on an entitlement; Flutter never chooses it.
enum BillingProvider {
  /// No billing relationship at all — the complimentary Free entitlement.
  none('none'),

  /// Google Play Billing. The only purchasing provider in V1.
  googlePlay('google_play'),

  /// Reserved compatibility code for future iOS support.
  ///
  /// Its presence in the shared contract does not authorize any iOS
  /// implementation, and nothing in the Android-only V1 scope may produce it.
  appleAppStore('apple_app_store'),

  /// Granted by an authorized administrative operation rather than purchased.
  ///
  /// Used by Salon Pilot. It must never be used to shortcut provider
  /// verification for an ordinary public store purchase.
  adminGranted('admin_granted');

  const BillingProvider(this.code);

  /// The stable wire/persistence identifier.
  final String code;

  /// Returns the provider for [code], or `null` when [code] is outside the
  /// controlled vocabulary.
  static BillingProvider? fromCode(String code) {
    for (final provider in values) {
      if (provider.code == code) return provider;
    }
    return null;
  }
}
