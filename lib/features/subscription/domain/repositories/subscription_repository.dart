import '../entities/subscription_summary.dart';

/// Reads the authoritative subscription state for the signed-in account.
///
/// Deliberately read-only. There is no `upgrade`, no `grant`, no `consume`, and
/// no `setRemaining`: entitlement changes come from verified purchases and
/// authorized admin operations on the server, and capacity changes come from
/// the usage engine as a side effect of generating a preview. A client-facing
/// method for any of those would be a way to claim a plan.
abstract interface class SubscriptionRepository {
  /// Resolves the current subscription state from the server.
  ///
  /// Throws a `SubscriptionStateFailure` on session, network, or backend
  /// problems.
  Future<SubscriptionSummary> resolve();
}
