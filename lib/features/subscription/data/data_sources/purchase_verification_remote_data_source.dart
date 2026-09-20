import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/supabase_remote_data_source.dart';

/// Sends a Google Play purchase to the backend to be verified.
///
/// The token travels once, over TLS, to one Edge Function. It is not stored on
/// the device, not written to preferences, and not logged on either side.
abstract interface class PurchaseVerificationRemoteDataSource {
  String? get currentUserId;

  /// Invokes `verify-google-play-purchase` and returns its raw payload.
  ///
  /// [providerProductId] is sent because the client has it and a disagreement
  /// with the provider is worth recording server-side. It is not what decides
  /// the plan — the backend resolves that from the purchase Google returns —
  /// so a client that lied about it would gain nothing.
  ///
  /// [source] (`purchase` or `restore`) is a telemetry label the backend
  /// counts; it changes nothing about how the purchase is verified.
  Future<Object?> verify({
    required String purchaseToken,
    required String providerProductId,
    String? source,
  });
}

/// A sanitized failure returned by the verification function.
///
/// Mirrors `HistoryRemoteFailure`: the controlled code and user-facing message
/// the backend chose, with no provider payload and no transport detail.
class PurchaseVerificationRemoteFailure implements Exception {
  const PurchaseVerificationRemoteFailure({
    required this.status,
    required this.code,
    required this.message,
    required this.retryable,
  });

  final int status;
  final String code;
  final String message;
  final bool retryable;

  @override
  String toString() => 'PurchaseVerificationRemoteFailure($code)';
}

class SupabasePurchaseVerificationRemoteDataSource
    extends SupabaseRemoteDataSource
    implements PurchaseVerificationRemoteDataSource {
  const SupabasePurchaseVerificationRemoteDataSource(super.client);

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
        'verify-google-play-purchase',
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
