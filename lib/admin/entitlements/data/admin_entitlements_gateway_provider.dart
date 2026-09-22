import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_availability_provider.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../shared/admin_keyset_list_controller.dart';
import '../../shared/admin_read_failure.dart';
import '../domain/admin_entitlement_models.dart';
import '../domain/admin_entitlements_gateway.dart';
import 'supabase_admin_entitlements_gateway.dart';

final adminEntitlementsGatewayProvider = Provider<AdminEntitlementsGateway>((
  ref,
) {
  if (!ref.watch(supabaseAvailableProvider)) {
    return const _UnavailableAdminEntitlementsGateway();
  }
  return SupabaseAdminEntitlementsGateway(ref.watch(supabaseClientProvider));
});

class _UnavailableAdminEntitlementsGateway implements AdminEntitlementsGateway {
  const _UnavailableAdminEntitlementsGateway();

  @override
  Future<AdminListPage<AdminEntitlementListItem>> listEntitlements(
    AdminEntitlementFilters filters, {
    String? cursor,
  }) async {
    throw const AdminReadFailure(AdminReadFailureType.unavailable);
  }
}
