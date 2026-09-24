import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_availability_provider.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../shared/admin_keyset_list_controller.dart';
import '../../shared/admin_read_failure.dart';
import '../domain/admin_research_gateway.dart';
import '../domain/admin_research_models.dart';
import 'supabase_admin_research_gateway.dart';

final adminResearchGatewayProvider = Provider<AdminResearchGateway>((ref) {
  if (!ref.watch(supabaseAvailableProvider)) {
    return const _UnavailableAdminResearchGateway();
  }
  return SupabaseAdminResearchGateway(ref.watch(supabaseClientProvider));
});

class _UnavailableAdminResearchGateway implements AdminResearchGateway {
  const _UnavailableAdminResearchGateway();

  @override
  Future<AdminSalonPilotResearch> fetchResearch() async {
    throw const AdminReadFailure(AdminReadFailureType.unavailable);
  }

  @override
  Future<AdminListPage<AdminPilotMetricsRow>> listPilots({
    String? cursor,
  }) async {
    throw const AdminReadFailure(AdminReadFailureType.unavailable);
  }
}
