import '../../shared/admin_keyset_list_controller.dart';
import 'admin_audit_models.dart';

abstract interface class AdminAuditGateway {
  Future<AdminListPage<AdminAuditListItem>> listAudit(
    AdminAuditFilters filters, {
    String? cursor,
  });

  Future<AdminAuditDetail?> getAuditEvent(String eventId);

  Future<AdminListPage<AdminEntitlementHistoryEvent>> listEntitlementHistory(
    String entitlementId, {
    String? cursor,
  });
}
