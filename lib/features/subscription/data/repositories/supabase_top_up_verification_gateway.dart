import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/purchase_evidence.dart';
import '../../domain/errors/subscription_state_failure.dart';
import '../../domain/repositories/purchase_verification_gateway.dart';
import '../../domain/repositories/top_up_verification_gateway.dart';
import '../data_sources/purchase_verification_remote_data_source.dart';
import '../data_sources/top_up_verification_remote_data_source.dart';

/// Sends top-up pack purchase evidence to the FaceTune backend for
/// verification and granting.
///
/// Returns only what the client must know to finish with the provider —
/// whether the server consumed the purchase — and nothing about credits. The
/// account's state, including its purchased credits, is re-read from
/// `resolve_subscription_state` afterwards, which remains the single authority
/// on what anyone has.
class SupabaseTopUpVerificationGateway implements TopUpVerificationGateway {
  const SupabaseTopUpVerificationGateway(
    this._remote, {
    this.operationTimeout = const Duration(seconds: 30),
  });

  final TopUpVerificationRemoteDataSource _remote;

  /// Bounded for the reason the subscription gateway gives: the round trip
  /// includes two calls out to Google, and a purchase that cannot be confirmed
  /// promptly is better reported than waited on. An unverified purchase stays
  /// unconsumed and Google refunds it.
  final Duration operationTimeout;

  @override
  Future<TopUpVerificationResult> verify(
    PurchaseEvidence evidence, {
    PurchaseVerificationSource source = PurchaseVerificationSource.purchase,
  }) async {
    if (!evidence.isVerifiable) {
      throw const SubscriptionStateFailure(
        'This purchase is missing the information Google Play needs to '
        'confirm it.',
        kind: SubscriptionStateFailureKind.invalidData,
        retryable: false,
      );
    }
    if (_remote.currentUserId == null) {
      throw const SubscriptionStateFailure(
        'Your session expired. Sign in again, and your purchase will be '
        'confirmed automatically.',
        kind: SubscriptionStateFailureKind.sessionExpired,
        retryable: false,
      );
    }

    Object? payload;
    try {
      payload = await _remote
          .verify(
            purchaseToken: evidence.purchaseToken,
            providerProductId: evidence.providerProductId,
            source: source.code,
          )
          .timeout(operationTimeout);
    } on PurchaseVerificationRemoteFailure catch (failure) {
      throw _fromRemote(failure);
    } catch (error) {
      if (error is SubscriptionStateFailure) rethrow;
      throw _failure(error);
    }

    // Only the two flags the client needs are read. Anything else the server
    // sent — including the state it resolved — is deliberately ignored here:
    // the controller re-reads authoritative state through the one path every
    // surface uses, rather than taking a copy from a purchase response.
    final data = payload is Map
        ? payload.map((key, value) => MapEntry(key.toString(), value))
        : const <String, Object?>{};
    if (data['verified'] != true) {
      throw const SubscriptionStateFailure(
        'Your purchase could not be confirmed. Please try again.',
        kind: SubscriptionStateFailureKind.invalidData,
      );
    }
    return TopUpVerificationResult(
      consumedByServer: data['consumed'] == true,
      replayed: data['replayed'] == true,
    );
  }

  SubscriptionStateFailure _fromRemote(
    PurchaseVerificationRemoteFailure failure,
  ) {
    final kind = switch (failure.status) {
      401 => SubscriptionStateFailureKind.sessionExpired,
      409 => SubscriptionStateFailureKind.invalidData,
      503 => SubscriptionStateFailureKind.offline,
      _ => SubscriptionStateFailureKind.unknown,
    };
    return SubscriptionStateFailure(
      failure.message,
      kind: kind,
      retryable: failure.retryable,
    );
  }

  SubscriptionStateFailure _failure(Object error) {
    if (error is TimeoutException) {
      return const SubscriptionStateFailure(
        'Confirming your purchase took too long. It will be confirmed the '
        'next time you open FaceTune.',
        kind: SubscriptionStateFailureKind.timeout,
      );
    }
    if (error is SocketException) {
      return const SubscriptionStateFailure(
        'You appear to be offline. Your purchase will be confirmed once you '
        'reconnect.',
        kind: SubscriptionStateFailureKind.offline,
      );
    }
    if (error is AuthException) {
      return const SubscriptionStateFailure(
        'Your session expired. Sign in again, and your purchase will be '
        'confirmed automatically.',
        kind: SubscriptionStateFailureKind.sessionExpired,
        retryable: false,
      );
    }
    return const SubscriptionStateFailure(
      'Your purchase could not be confirmed. Please try again.',
    );
  }
}
