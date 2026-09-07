import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/subscription_summary.dart';
import '../../domain/errors/subscription_state_failure.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../data_sources/subscription_remote_data_source.dart';
import '../models/subscription_summary_dto.dart';

class SupabaseSubscriptionRepository implements SubscriptionRepository {
  const SupabaseSubscriptionRepository(
    this._remote, {
    this.operationTimeout = const Duration(seconds: 20),
  });

  final SubscriptionRemoteDataSource _remote;

  /// A short budget on purpose. Resolving subscription state is a single
  /// indexed read, not a generation, so a slow answer is a problem to surface
  /// rather than wait out.
  final Duration operationTimeout;

  @override
  Future<SubscriptionSummary> resolve() async {
    if (_remote.currentUserId == null) {
      throw const SubscriptionStateFailure(
        'Your session expired. Sign in again.',
        kind: SubscriptionStateFailureKind.sessionExpired,
        retryable: false,
      );
    }
    try {
      final payload = await _remote.resolveState().timeout(operationTimeout);
      return SubscriptionSummaryDto.fromResponse(payload);
    } catch (error) {
      if (error is SubscriptionStateFailure) rethrow;
      throw _failure(error);
    }
  }

  /// Translates transport and parse errors into the one controlled failure
  /// type. Backend internals never reach presentation.
  SubscriptionStateFailure _failure(Object error) {
    if (error is TimeoutException) {
      return const SubscriptionStateFailure(
        'Checking your subscription took too long. Please try again.',
        kind: SubscriptionStateFailureKind.timeout,
      );
    }
    if (error is SocketException) {
      return const SubscriptionStateFailure(
        'You appear to be offline. Reconnect and try again.',
        kind: SubscriptionStateFailureKind.offline,
      );
    }
    if (error is AuthException) {
      return const SubscriptionStateFailure(
        'Your session expired. Sign in again.',
        kind: SubscriptionStateFailureKind.sessionExpired,
        retryable: false,
      );
    }
    if (error is FormatException) {
      return const SubscriptionStateFailure(
        'Your subscription could not be read. Please try again.',
        kind: SubscriptionStateFailureKind.invalidData,
      );
    }
    if (error is PostgrestException) {
      // 42501 is a revoked or missing EXECUTE grant, which for this RPC means
      // the caller is not an authenticated role any more.
      if (error.code == '42501') {
        return const SubscriptionStateFailure(
          'Your session expired. Sign in again.',
          kind: SubscriptionStateFailureKind.sessionExpired,
          retryable: false,
        );
      }
      return const SubscriptionStateFailure(
        'Your subscription could not be loaded. Please try again.',
      );
    }
    return const SubscriptionStateFailure(
      'Your subscription could not be loaded. Please try again.',
    );
  }
}
