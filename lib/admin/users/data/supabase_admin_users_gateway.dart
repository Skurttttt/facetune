import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/subscription/domain/errors/subscription_error_code.dart';
import '../../auth/domain/admin_auth_failure.dart';
import '../domain/admin_user_models.dart';
import '../domain/admin_users_failure.dart';
import '../domain/admin_users_gateway.dart';

/// Calls the two read-only WA-5 RPCs with the current admin session.
class SupabaseAdminUsersGateway implements AdminUsersGateway {
  const SupabaseAdminUsersGateway(
    this._client, {
    this.operationTimeout = const Duration(seconds: 20),
  });

  static const searchRpc = 'admin_search_users';
  static const detailRpc = 'admin_get_user';

  final SupabaseClient _client;
  final Duration operationTimeout;

  @override
  Future<AdminUserPage> searchUsers({String? search, String? cursor}) async {
    final payload = await _call(searchRpc, {
      'p_search': _normalizeSearch(search),
      'p_cursor': cursor,
    });
    _throwPayloadFailure(payload);
    return AdminUserPage.decode(payload);
  }

  @override
  Future<AdminUserDetail> getUser(String userId) async {
    final payload = await _call(detailRpc, {'p_user_id': userId});
    _throwPayloadFailure(payload);
    return AdminUserDetail.decode(payload);
  }

  Future<Object?> _call(String rpc, Map<String, Object?> params) async {
    if (_client.auth.currentSession == null) {
      throw const AdminAuthFailure(SubscriptionErrorCode.authRequired);
    }
    try {
      return await _client.rpc(rpc, params: params).timeout(operationTimeout);
    } on PostgrestException catch (error) {
      final status = int.tryParse(error.code ?? '');
      if (status == 401) {
        throw const AdminAuthFailure(SubscriptionErrorCode.authRequired);
      }
      throw const AdminUsersFailure(
        AdminUsersFailureType.unavailable,
        retryable: true,
      );
    } on AdminAuthFailure {
      rethrow;
    } on AdminUsersFailure {
      rethrow;
    } catch (_) {
      throw const AdminUsersFailure(
        AdminUsersFailureType.unavailable,
        retryable: true,
      );
    }
  }

  static void _throwPayloadFailure(Object? payload) {
    if (payload is! Map || payload['ok'] != false) return;
    switch (payload['errorCode']) {
      case 'AUTH_REQUIRED':
        throw const AdminAuthFailure(SubscriptionErrorCode.authRequired);
      case 'ADMIN_UNAUTHORIZED':
        throw const AdminAuthFailure(SubscriptionErrorCode.adminUnauthorized);
      case 'USER_NOT_FOUND':
        throw const AdminUsersFailure(AdminUsersFailureType.notFound);
      default:
        throw const AdminUsersFailure(
          AdminUsersFailureType.unavailable,
          retryable: true,
        );
    }
  }

  static String? _normalizeSearch(String? value) {
    final normalized = value?.trim().toLowerCase();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
