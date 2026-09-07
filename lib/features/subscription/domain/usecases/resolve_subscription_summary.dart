import '../entities/subscription_summary.dart';
import '../repositories/subscription_repository.dart';

/// Resolves the signed-in account's authoritative subscription state.
///
/// Matches the existing use-case convention (see `GenerateMakeupPreview`): a
/// single callable that names the intent and keeps the controller free of a
/// direct repository dependency.
class ResolveSubscriptionSummary {
  const ResolveSubscriptionSummary(this._repository);

  final SubscriptionRepository _repository;

  Future<SubscriptionSummary> call() => _repository.resolve();
}
