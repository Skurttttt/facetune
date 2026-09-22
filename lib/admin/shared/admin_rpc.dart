import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/subscription/domain/errors/subscription_error_code.dart';
import '../auth/domain/admin_auth_failure.dart';
import 'admin_read_failure.dart';

/// Calls one read-only admin RPC with the current admin session and maps the
/// transport and envelope failures onto the admin failure types.
///
/// Every admin read RPC decides authorization for itself against the roster
/// (WA-2) and answers `{ok: false, errorCode}` for a refusal. A request the
/// server rejects outright — a filter outside the vocabulary, a cursor for
/// other filters — arrives as SQLSTATE 22023 and is reported as rejected
/// rather than as an outage. No service-role key exists anywhere on this
/// path: the client holds only the anon key and the caller's own session.
Future<Object?> callAdminReadRpc(
  SupabaseClient client,
  String rpc,
  Map<String, Object?> params, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  if (client.auth.currentSession == null) {
    throw const AdminAuthFailure(SubscriptionErrorCode.authRequired);
  }
  Object? payload;
  try {
    payload = await client.rpc(rpc, params: params).timeout(timeout);
  } on PostgrestException catch (error) {
    if (int.tryParse(error.code ?? '') == 401) {
      throw const AdminAuthFailure(SubscriptionErrorCode.authRequired);
    }
    if (error.code == '22023') {
      throw const AdminReadFailure(AdminReadFailureType.rejected);
    }
    throw const AdminReadFailure(
      AdminReadFailureType.unavailable,
      retryable: true,
    );
  } on AdminAuthFailure {
    rethrow;
  } catch (_) {
    throw const AdminReadFailure(
      AdminReadFailureType.unavailable,
      retryable: true,
    );
  }
  throwEnvelopeFailure(payload);
  return payload;
}

/// Throws for a `{ok: false}` envelope; returns normally for anything else.
void throwEnvelopeFailure(Object? payload) {
  if (payload is! Map || payload['ok'] != false) return;
  switch (payload['errorCode']) {
    case 'AUTH_REQUIRED':
      throw const AdminAuthFailure(SubscriptionErrorCode.authRequired);
    case 'ADMIN_UNAUTHORIZED':
      throw const AdminAuthFailure(SubscriptionErrorCode.adminUnauthorized);
    default:
      throw const AdminReadFailure(
        AdminReadFailureType.unavailable,
        retryable: true,
      );
  }
}
