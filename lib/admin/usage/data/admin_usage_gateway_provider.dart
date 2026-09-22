import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_availability_provider.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../shared/admin_keyset_list_controller.dart';
import '../../shared/admin_read_failure.dart';
import '../domain/admin_usage_gateway.dart';
import '../domain/admin_usage_models.dart';
import 'supabase_admin_usage_gateway.dart';

final adminUsageGatewayProvider = Provider<AdminUsageGateway>((ref) {
  if (!ref.watch(supabaseAvailableProvider)) {
    return const _UnavailableAdminUsageGateway();
  }
  return SupabaseAdminUsageGateway(ref.watch(supabaseClientProvider));
});

class _UnavailableAdminUsageGateway implements AdminUsageGateway {
  const _UnavailableAdminUsageGateway();

  @override
  Future<AdminListPage<AdminUsageListItem>> listUsage(
    AdminUsageFilters filters, {
    String? cursor,
  }) async {
    throw const AdminReadFailure(AdminReadFailureType.unavailable);
  }
}
