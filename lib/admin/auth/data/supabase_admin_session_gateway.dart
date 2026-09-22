import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/subscription/domain/errors/subscription_error_code.dart';
import '../domain/admin_auth_failure.dart';
import '../domain/admin_identity.dart';
import '../domain/admin_role.dart';
import '../domain/admin_session_gateway.dart';

/// Calls the protected `admin-session` Edge Function.
///
/// `functions.invoke` attaches the current session's access token as the
/// Authorization header; the function verifies it server-side and consults
/// the admin roster for that session. Nothing about the caller is sent in the
/// body and nothing in the response is trusted beyond decoding it strictly:
/// a payload that does not say `ok: true` with `role: "admin"` is a refusal.
class SupabaseAdminSessionGateway implements AdminSessionGateway {
  const SupabaseAdminSessionGateway(
    this._client, {
    this.operationTimeout = const Duration(seconds: 20),
  });

  static const functionName = 'admin-session';

  final SupabaseClient _client;
  final Duration operationTimeout;

  @override
  Future<AdminIdentity> verifyAdminSession() async {
    if (_client.auth.currentSession == null) {
      throw const AdminAuthFailure(SubscriptionErrorCode.authRequired);
    }
    Object? data;
    try {
      final response = await _client.functions
          .invoke(functionName, method: HttpMethod.post)
          .timeout(operationTimeout);
      data = response.data;
    } on FunctionException catch (error) {
      throw failureFrom(error);
    } on AdminAuthFailure {
      rethrow;
    } catch (_) {
      throw const AdminAuthFailure(
        SubscriptionErrorCode.temporaryBackendFailure,
        retryable: true,
      );
    }
    return decodeAdminSession(data);
  }

  /// Strict decoding of the success payload. Exposed for tests.
  static AdminIdentity decodeAdminSession(Object? data) {
    if (data is! Map) {
      throw const AdminAuthFailure(
        SubscriptionErrorCode.temporaryBackendFailure,
        retryable: true,
      );
    }
    final admin = data['admin'];
    final role = admin is Map ? admin['role'] : null;
    final userId = admin is Map ? admin['userId'] : null;
    if (data['ok'] != true ||
        role is! String ||
        AdminRole.fromCode(role) != AdminRole.admin ||
        userId is! String ||
        userId.isEmpty) {
      throw const AdminAuthFailure(SubscriptionErrorCode.adminUnauthorized);
    }
    final email = admin is Map ? admin['email'] : null;
    return AdminIdentity(
      userId: userId,
      email: email is String && email.isNotEmpty ? email : null,
    );
  }

  /// Maps a protected-function refusal to a typed failure. Exposed for tests.
  @visibleForTesting
  static AdminAuthFailure failureFrom(FunctionException error) {
    final details = error.details;
    final root = details is Map
        ? details.map((key, value) => MapEntry(key.toString(), value))
        : const <String, Object?>{};
    final nested = root['error'];
    final payload = nested is Map
        ? nested.map((key, value) => MapEntry(key.toString(), value))
        : root;
    final code = SubscriptionErrorCode.fromCode(
      payload['code']?.toString() ?? '',
    );
    // The HTTP status is the server's decision too; the code refines it. An
    // unknown code is never promoted to anything but a temporary failure.
    return switch (error.status) {
      401 => const AdminAuthFailure(SubscriptionErrorCode.authRequired),
      403 => const AdminAuthFailure(SubscriptionErrorCode.adminUnauthorized),
      _ => AdminAuthFailure(
        code == SubscriptionErrorCode.authRequired ||
                code == SubscriptionErrorCode.adminUnauthorized
            ? code!
            : SubscriptionErrorCode.temporaryBackendFailure,
        retryable: payload['retryable'] == true || error.status >= 500,
      ),
    };
  }
}
