import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/admin_keyset_list_controller.dart';
import '../../shared/admin_rpc.dart';
import '../domain/admin_entitlement_models.dart';
import '../domain/admin_entitlements_gateway.dart';

/// Calls the read-only WA-6 entitlements RPC with the current admin session.
class SupabaseAdminEntitlementsGateway implements AdminEntitlementsGateway {
  const SupabaseAdminEntitlementsGateway(this._client);

  static const listRpc = 'admin_list_entitlements';

  final SupabaseClient _client;

  @override
  Future<AdminListPage<AdminEntitlementListItem>> listEntitlements(
    AdminEntitlementFilters filters, {
    String? cursor,
  }) async {
    final payload = await callAdminReadRpc(_client, listRpc, {
      ...filters.toRpcParams(),
      'p_cursor': cursor,
    });
    return AdminEntitlementListItem.decodePage(payload);
  }
}
