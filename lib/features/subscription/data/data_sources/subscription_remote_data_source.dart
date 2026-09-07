import '../../../../core/data/supabase_remote_data_source.dart';

/// Reads subscription state from the server.
///
/// The RPC takes no arguments on purpose: the account comes from the request
/// JWT inside the database function, so there is nothing here that could ask
/// about another user even by mistake.
abstract interface class SubscriptionRemoteDataSource {
  String? get currentUserId;

  /// Invokes `resolve_subscription_state()` and returns its raw payload.
  Future<Object?> resolveState();
}

class SupabaseSubscriptionRemoteDataSource extends SupabaseRemoteDataSource
    implements SubscriptionRemoteDataSource {
  const SupabaseSubscriptionRemoteDataSource(super.client);

  @override
  String? get currentUserId => client.auth.currentUser?.id;

  @override
  Future<Object?> resolveState() => client.rpc('resolve_subscription_state');
}
