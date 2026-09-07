import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_availability_provider.dart';
import '../../../../core/supabase/supabase_client_provider.dart';
import '../../domain/repositories/plan_price_source.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../../domain/usecases/resolve_subscription_summary.dart';
import '../data_sources/subscription_remote_data_source.dart';
import '../repositories/supabase_subscription_repository.dart';
import '../repositories/unavailable_plan_price_source.dart';
import '../repositories/unavailable_subscription_repository.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  if (!ref.watch(supabaseAvailableProvider)) {
    return const UnavailableSubscriptionRepository();
  }
  return SupabaseSubscriptionRepository(
    SupabaseSubscriptionRemoteDataSource(ref.watch(supabaseClientProvider)),
  );
});

final resolveSubscriptionSummaryProvider = Provider<ResolveSubscriptionSummary>(
  (ref) =>
      ResolveSubscriptionSummary(ref.watch(subscriptionRepositoryProvider)),
);

/// Where the paywall's prices come from.
///
/// Deliberately its own provider rather than a method on the subscription
/// repository: prices are store configuration, entitlement is account state,
/// and the two have different sources, different failure modes, and different
/// authorities. SUB-9 replaces this override with the Google Play source.
final planPriceSourceProvider = Provider<PlanPriceSource>(
  (ref) => const UnavailablePlanPriceSource(),
);
