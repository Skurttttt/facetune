import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_availability_provider.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../shared/admin_read_failure.dart';
import '../domain/admin_dashboard_v2_gateway.dart';
import '../domain/admin_dashboard_v2_metrics.dart';
import 'supabase_admin_dashboard_v2_gateway.dart';

final adminDashboardV2GatewayProvider = Provider<AdminDashboardV2Gateway>((
  ref,
) {
  if (!ref.watch(supabaseAvailableProvider)) {
    return const _UnavailableAdminDashboardV2Gateway();
  }
  return SupabaseAdminDashboardV2Gateway(ref.watch(supabaseClientProvider));
});

class _UnavailableAdminDashboardV2Gateway implements AdminDashboardV2Gateway {
  const _UnavailableAdminDashboardV2Gateway();

  @override
  Future<AdminDashboardV2Metrics> fetchMetrics() async {
    throw const AdminReadFailure(
      AdminReadFailureType.unavailable,
      retryable: true,
    );
  }
}
