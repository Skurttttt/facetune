import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/supabase_remote_data_source.dart';
import 'purchase_verification_remote_data_source.dart';

/// Sends a Google Play top-up pack purchase to the backend to be verified and
/// granted.
///
/// The one-time-product counterpart of `PurchaseVerificationRemoteDataSource`,
/// and a separate Edge Function on purpose: a subscription token can never be
/// sent down the granting path, and the SUB-10 subscription verifier is not
/// touched by top-ups. The token travels once, over TLS, and is not stored on
/// the device or logged on either side.
abstract interface class TopUpVerificationRemoteDataSource {
  String? get currentUserId;

  /// Invokes `verify-google-play-top-up` and returns its raw payload.
  ///
  /// [providerProductId] is sent because the client has it and a disagreement
  /// with the provider is worth recording server-side. It is not what decides
  /// the pack — the backend resolves that from the purchase Google returns and
  /// its own pack table — so a client that lied about it would gain nothing.
  Future<Object?> verify({
    required String purchaseToken,
    required String providerProductId,
    String? source,
  });
}

class SupabaseTopUpVerificationRemoteDataSource extends SupabaseRemoteDataSource
    implements TopUpVerificationRemoteDataSource {
  const SupabaseTopUpVerificationRemoteDataSource(super.client);

  @override
  String? get currentUserId => client.auth.currentUser?.id;

  @override
  Future<Object?> verify({
    required String purchaseToken,
    required String providerProductId,
    String? source,
  }) async {
    try {
      final response = await client.functions.invoke(
        'verify-google-play-top-up',
        body: {
          'purchaseToken': purchaseToken,
          'providerProductId': providerProductId,
          'source': ?source,
        },
      );
      return response.data;
    } on FunctionException catch (error) {
      final details = error.details;
      final root = details is Map
          ? details.map((key, value) => MapEntry(key.toString(), value))
          : const <String, Object?>{};
      final nested = root['error'];
      final payload = nested is Map
          ? nested.map((key, value) => MapEntry(key.toString(), value))
          : root;
      // The same sanitized failure shape as the subscription verifier, so the
      // gateway above maps both with one translation.
      throw PurchaseVerificationRemoteFailure(
        status: error.status,
        code: payload['code']?.toString() ?? '',
        message:
            payload['message']?.toString() ??
            'This purchase could not be confirmed.',
        retryable: payload['retryable'] == true,
      );
    }
  }
}
