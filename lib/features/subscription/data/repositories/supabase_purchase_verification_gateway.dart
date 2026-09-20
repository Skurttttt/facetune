import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/purchase_evidence.dart';
import '../../domain/errors/subscription_state_failure.dart';
import '../../domain/repositories/purchase_verification_gateway.dart';
import '../data_sources/purchase_verification_remote_data_source.dart';

/// Sends provider purchase evidence to the FaceTune backend for verification.
///
/// This is the implementation the client billing phase left as a stub. What it
/// does *not* do is the important part: it returns `void` on success, so there
/// is no plan, allowance, or expiry for a caller to apply. The account's state
/// is re-read from `resolve_subscription_state` afterwards, which remains the
/// single authority on what anyone is entitled to.
class SupabasePurchaseVerificationGateway
    implements PurchaseVerificationGateway {
  const SupabasePurchaseVerificationGateway(
    this._remote, {
    this.operationTimeout = const Duration(seconds: 30),
  });

  final PurchaseVerificationRemoteDataSource _remote;

  /// Longer than a plain state read, because this round trip includes two
  /// calls out to Google. Still bounded: a purchase that cannot be confirmed
  /// promptly is better reported than waited on, and the purchase itself is
  /// safe either way — an unverified purchase stays unacknowledged and Google
  /// refunds it.
  final Duration operationTimeout;

  @override
  Future<void> verify(
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

    try {
      await _remote
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
  }

  /// Carries the backend's own sanitized message through unchanged.
  ///
  /// The server already chose wording safe to show, and it knows more about
  /// why a purchase was refused than this layer can infer from a status code.
  /// Only the retry hint is re-derived, because a refusal the server called
  /// permanent must not be presented as worth trying again.
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

  /// Translates transport and parse errors into the one controlled failure
  /// type, following `SupabaseSubscriptionRepository`.
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
