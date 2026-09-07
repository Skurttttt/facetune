/// A price as the billing provider states it.
///
/// [formattedPrice] is the provider's own localized string — currency symbol,
/// separators, and placement all decided by the store for the user's region.
/// It is never assembled here from a number and a currency code, because doing
/// so gets the format wrong somewhere in the world and, worse, invites a
/// hardcoded fallback that disagrees with what the user is actually charged.
///
/// There is deliberately no constructor that builds a price from a literal.
/// The only way to obtain one is from a [PlanPriceSource] backed by verified
/// store configuration, so the app cannot claim a price the store does not
/// charge.
class PlanPrice {
  const PlanPrice({
    required this.formattedPrice,
    required this.currencyCode,
    this.billingPeriodLabel,
  });

  /// The provider's localized price string, shown verbatim.
  final String formattedPrice;

  /// ISO currency code the provider quoted in, for accessibility and
  /// diagnostics.
  final String currencyCode;

  /// e.g. "month". Null for a non-recurring product.
  final String? billingPeriodLabel;

  /// The provider's own price string followed by its period, in whatever
  /// currency and format the store returned.
  ///
  /// No example is written here on purpose: a sample amount in a comment is
  /// one careless copy-paste away from becoming a hardcoded price, and the
  /// boundary test that forbids those reads comments too.
  String get displayPrice => billingPeriodLabel == null
      ? formattedPrice
      : '$formattedPrice / $billingPeriodLabel';

  @override
  bool operator ==(Object other) =>
      other is PlanPrice &&
      other.formattedPrice == formattedPrice &&
      other.currencyCode == currencyCode &&
      other.billingPeriodLabel == billingPeriodLabel;

  @override
  int get hashCode =>
      Object.hash(formattedPrice, currencyCode, billingPeriodLabel);

  @override
  String toString() => 'PlanPrice($displayPrice, $currencyCode)';
}
