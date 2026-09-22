import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/subscription/domain/errors/subscription_error_code.dart';
import '../../auth/domain/admin_auth_failure.dart';
import '../domain/admin_salon_pilot_gateway.dart';
import '../domain/admin_salon_pilot_models.dart';

/// Calls the protected `admin-grant-salon-pilot` Edge Function.
///
/// `functions.invoke` attaches the current session's access token; the
/// function verifies it, checks the admin roster, validates the intent, and
/// runs the transactional database writer as that same session. The body
/// carries intent only. Nothing in the response is trusted beyond decoding
/// it strictly.
class SupabaseAdminSalonPilotGateway implements AdminSalonPilotGateway {
  const SupabaseAdminSalonPilotGateway(
    this._client, {
    this.operationTimeout = const Duration(seconds: 30),
  });

  static const functionName = 'admin-grant-salon-pilot';

  final SupabaseClient _client;
  final Duration operationTimeout;

  @override
  Future<AdminMutationOutcome> grantSalonPilot(
    GrantSalonPilotIntent intent,
  ) async {
    if (_client.auth.currentSession == null) {
      throw const AdminAuthFailure(SubscriptionErrorCode.authRequired);
    }
    Object? data;
    try {
      final response = await _client.functions
          .invoke(
            functionName,
            method: HttpMethod.post,
            body: intent.toRequestBody(),
          )
          .timeout(operationTimeout);
      data = response.data;
    } on FunctionException catch (error) {
      throw failureFrom(error);
    } on AdminAuthFailure {
      rethrow;
    } on AdminMutationFailure {
      rethrow;
    } catch (_) {
      throw const AdminMutationFailure(
        AdminMutationErrorCode.temporaryBackendFailure,
        retryable: true,
      );
    }
    return AdminMutationOutcome.decode(data);
  }

  /// Maps a non-2xx answer to a typed failure. Exposed for tests.
  @visibleForTesting
  static Exception failureFrom(FunctionException error) {
    final details = error.details;
    final root = details is Map
        ? details.map((key, value) => MapEntry(key.toString(), value))
        : const <String, Object?>{};
    // Session refusals from `requireAdmin` arrive in the WA-2 envelope
    // (`{error: {code}}`); mutation outcomes in the contract §73 envelope.
    final nested = root['error'];
    final payload = nested is Map
        ? nested.map((key, value) => MapEntry(key.toString(), value))
        : root;
    final code = (payload['errorCode'] ?? payload['code'])?.toString();
    if (error.status == 401 || code == 'AUTH_REQUIRED') {
      return const AdminAuthFailure(SubscriptionErrorCode.authRequired);
    }
    if (error.status == 403 || code == 'ADMIN_UNAUTHORIZED') {
      return const AdminAuthFailure(SubscriptionErrorCode.adminUnauthorized);
    }
    final message = payload['message'];
    final field = payload['field'];
    return AdminMutationFailure(
      AdminMutationErrorCode.fromCode(code),
      message: message is String && message.isNotEmpty ? message : null,
      field: field is String ? field : null,
      retryable: payload['retryable'] == true || error.status >= 500,
    );
  }
}
