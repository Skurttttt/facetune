import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/admin_keyset_list_controller.dart';
import '../../shared/admin_rpc.dart';
import '../domain/admin_usage_gateway.dart';
import '../domain/admin_usage_models.dart';

/// Calls the read-only WA-6 usage-ledger RPC with the current admin session.
class SupabaseAdminUsageGateway implements AdminUsageGateway {
  const SupabaseAdminUsageGateway(this._client);

  static const listRpc = 'admin_list_usage';

  final SupabaseClient _client;

  @override
  Future<AdminListPage<AdminUsageListItem>> listUsage(
    AdminUsageFilters filters, {
    String? cursor,
  }) async {
    final payload = await callAdminReadRpc(_client, listRpc, {
      ...filters.toRpcParams(),
      'p_cursor': cursor,
    });
    return AdminUsageListItem.decodePage(payload);
  }
}
