import '../../domain/entities/subscription_summary.dart';
import '../../domain/errors/subscription_state_failure.dart';
import '../../domain/repositories/subscription_repository.dart';

/// Stands in when no backend is configured for this build.
///
/// It fails rather than reporting a plan. A stub that returned, say, a Free
/// summary would be the client inventing entitlement, and the difference
/// between "we could not ask" and "you are on Free" is exactly the difference
/// this whole layer exists to preserve.
class UnavailableSubscriptionRepository implements SubscriptionRepository {
  const UnavailableSubscriptionRepository();

  @override
  Future<SubscriptionSummary> resolve() => throw const SubscriptionStateFailure(
    'Subscriptions are unavailable in this build.',
    kind: SubscriptionStateFailureKind.unavailable,
    retryable: false,
  );
}
