import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/subscription/domain/errors/subscription_error_code.dart';
import '../../auth/domain/admin_auth_failure.dart';
import '../domain/admin_dashboard_gateway.dart';
import '../domain/admin_dashboard_metrics.dart';

/// Calls `public.admin_dashboard_metrics()` with the admin's own session.
///
/// The RPC takes no arguments, aggregates in the database, verifies the
/// caller against the admin roster itself, and returns totals only. The
/// browser never receives a row of any table.
class SupabaseAdminDashboardGateway implements AdminDashboardGateway {
  const SupabaseAdminDashboardGateway(
    this._client, {
    this.operationTimeout = const Duration(seconds: 20),
  });

  static const rpcName = 'admin_dashboard_metrics';

  final SupabaseClient _client;
  final Duration operationTimeout;

  @override
  Future<AdminDashboardMetrics> fetchMetrics() async {
    if (_client.auth.currentSession == null) {
      throw const AdminAuthFailure(SubscriptionErrorCode.authRequired);
    }
    Object? payload;
    try {
      payload = await _client.rpc(rpcName).timeout(operationTimeout);
    } on PostgrestException catch (error) {
      // 401/403 from PostgREST mean the session itself was refused before
      // the function ran; anything else is a backend problem.
      final status = int.tryParse(error.code ?? '');
      throw AdminAuthFailure(
        status == 401
            ? SubscriptionErrorCode.authRequired
            : SubscriptionErrorCode.temporaryBackendFailure,
        retryable: status != 401,
      );
    } on AdminAuthFailure {
      rethrow;
    } catch (_) {
      throw const AdminAuthFailure(
        SubscriptionErrorCode.temporaryBackendFailure,
        retryable: true,
      );
    }
    return AdminDashboardMetrics.decode(payload);
  }
}
