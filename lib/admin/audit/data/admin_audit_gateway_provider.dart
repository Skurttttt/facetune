import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_availability_provider.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../shared/admin_keyset_list_controller.dart';
import '../../shared/admin_read_failure.dart';
import '../domain/admin_audit_gateway.dart';
import '../domain/admin_audit_models.dart';
import 'supabase_admin_audit_gateway.dart';

final adminAuditGatewayProvider = Provider<AdminAuditGateway>((ref) {
  if (!ref.watch(supabaseAvailableProvider)) {
    return const _UnavailableAdminAuditGateway();
  }
  return SupabaseAdminAuditGateway(ref.watch(supabaseClientProvider));
});

class _UnavailableAdminAuditGateway implements AdminAuditGateway {
  const _UnavailableAdminAuditGateway();

  @override
  Future<AdminListPage<AdminAuditListItem>> listAudit(
    AdminAuditFilters filters, {
    String? cursor,
  }) async => throw const AdminReadFailure(AdminReadFailureType.unavailable);

  @override
  Future<AdminAuditDetail?> getAuditEvent(String eventId) async =>
      throw const AdminReadFailure(AdminReadFailureType.unavailable);

  @override
  Future<AdminListPage<AdminEntitlementHistoryEvent>> listEntitlementHistory(
    String entitlementId, {
    String? cursor,
  }) async => throw const AdminReadFailure(AdminReadFailureType.unavailable);
}
