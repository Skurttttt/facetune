import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/admin_keyset_list_controller.dart';
import '../../shared/admin_rpc.dart';
import '../domain/admin_audit_gateway.dart';
import '../domain/admin_audit_models.dart';

class SupabaseAdminAuditGateway implements AdminAuditGateway {
  const SupabaseAdminAuditGateway(this._client);

  static const listRpc = 'admin_list_audit_events';
  static const detailRpc = 'admin_get_audit_event';
  static const historyRpc = 'admin_list_entitlement_history';

  final SupabaseClient _client;

  @override
  Future<AdminListPage<AdminAuditListItem>> listAudit(
    AdminAuditFilters filters, {
    String? cursor,
  }) async {
    final payload = await callAdminReadRpc(_client, listRpc, {
      ...filters.toRpcParams(),
      'p_cursor': cursor,
    });
    return AdminAuditListItem.decodePage(payload);
  }

  @override
  Future<AdminAuditDetail?> getAuditEvent(String eventId) async {
    final payload = await callAdminReadRpc(_client, detailRpc, {
      'p_event_id': eventId,
    });
    return AdminAuditDetail.decodeEnvelope(payload);
  }

  @override
  Future<AdminListPage<AdminEntitlementHistoryEvent>> listEntitlementHistory(
    String entitlementId, {
    String? cursor,
  }) async {
    final payload = await callAdminReadRpc(_client, historyRpc, {
      'p_entitlement_id': entitlementId,
      'p_cursor': cursor,
    });
    return AdminEntitlementHistoryEvent.decodePage(payload);
  }
}
