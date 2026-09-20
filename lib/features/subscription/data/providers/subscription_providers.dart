import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_availability_provider.dart';
import '../../../../core/supabase/supabase_client_provider.dart';
import '../../domain/repositories/plan_price_source.dart';
import '../../domain/repositories/purchase_verification_gateway.dart';
import '../../domain/repositories/store_billing_gateway.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../../domain/repositories/top_up_price_source.dart';
import '../../domain/repositories/top_up_verification_gateway.dart';
import '../../domain/usecases/resolve_subscription_summary.dart';
import '../data_sources/google_play_billing_data_source.dart';
import '../data_sources/purchase_verification_remote_data_source.dart';
import '../data_sources/subscription_remote_data_source.dart';
import '../data_sources/top_up_verification_remote_data_source.dart';
import '../repositories/google_play_billing_gateway.dart';
import '../repositories/google_play_plan_price_source.dart';
import '../repositories/google_play_top_up_price_source.dart';
import '../repositories/supabase_purchase_verification_gateway.dart';
import '../repositories/supabase_subscription_repository.dart';
import '../repositories/supabase_top_up_verification_gateway.dart';
import '../repositories/unavailable_purchase_verification_gateway.dart';
import '../repositories/unavailable_subscription_repository.dart';
import '../repositories/unavailable_top_up_verification_gateway.dart';

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

/// The connection to Google Play Billing.
///
/// Disposed with the provider so the provider stream subscription and the
/// underlying billing connection are released when the last listener goes away
/// — the lifecycle-safe teardown the phase requires, expressed once here rather
/// than in every widget that happens to use it.
final storeBillingGatewayProvider = Provider<StoreBillingGateway>((ref) {
  final gateway = GooglePlayBillingGateway(GooglePlayBillingDataSource());
  ref.onDispose(gateway.dispose);
  return gateway;
});

/// Where the paywall's prices come from.
///
/// Deliberately its own provider rather than a method on the subscription
/// repository: prices are store configuration, entitlement is account state,
/// and the two have different sources, different failure modes, and different
/// authorities.
final planPriceSourceProvider = Provider<PlanPriceSource>(
  (ref) => GooglePlayPlanPriceSource(ref.watch(storeBillingGatewayProvider)),
);

/// Where provider purchase evidence is sent to be verified.
///
/// Backed by the `verify-google-play-purchase` Edge Function, which is the only
/// thing that can turn a purchase into an entitlement: it re-fetches the
/// purchase from Google's own API, maps the verified product to a plan
/// server-side, writes the entitlement, and acknowledges with Google. The
/// client learns only that verification succeeded and then re-reads
/// authoritative state.
///
/// Falls back to the unavailable implementation when no backend is configured,
/// so a build without Supabase refuses purchases outright rather than appearing
/// to grant one.
final purchaseVerificationGatewayProvider =
    Provider<PurchaseVerificationGateway>((ref) {
      if (!ref.watch(supabaseAvailableProvider)) {
        return const UnavailablePurchaseVerificationGateway();
      }
      return SupabasePurchaseVerificationGateway(
        SupabasePurchaseVerificationRemoteDataSource(
          ref.watch(supabaseClientProvider),
        ),
      );
    });

/// Where the top-up packs' prices come from. Google Play, as for plans.
final topUpPriceSourceProvider = Provider<TopUpPriceSource>(
  (ref) => GooglePlayTopUpPriceSource(ref.watch(storeBillingGatewayProvider)),
);

/// Where top-up pack purchase evidence is sent to be verified and granted.
///
/// Backed by the `verify-google-play-top-up` Edge Function — a separate
/// function from the subscription verifier, so a plan purchase and a pack
/// purchase can never be confused for one another on the server. It re-fetches
/// the purchase from Google's own API, maps the verified product to a pack
/// server-side, grants the credits exactly once, and consumes with Google. The
/// client learns only that verification succeeded and whether consumption
/// happened, then re-reads authoritative state.
final topUpVerificationGatewayProvider = Provider<TopUpVerificationGateway>((
  ref,
) {
  if (!ref.watch(supabaseAvailableProvider)) {
    return const UnavailableTopUpVerificationGateway();
  }
  return SupabaseTopUpVerificationGateway(
    SupabaseTopUpVerificationRemoteDataSource(
      ref.watch(supabaseClientProvider),
    ),
  );
});
