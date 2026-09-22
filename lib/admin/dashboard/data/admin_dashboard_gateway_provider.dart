import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_availability_provider.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../features/subscription/domain/errors/subscription_error_code.dart';
import '../../auth/domain/admin_auth_failure.dart';
import '../domain/admin_dashboard_gateway.dart';
import '../domain/admin_dashboard_metrics.dart';
import 'supabase_admin_dashboard_gateway.dart';

final adminDashboardGatewayProvider = Provider<AdminDashboardGateway>((ref) {
  if (!ref.watch(supabaseAvailableProvider)) {
    return const _UnavailableAdminDashboardGateway();
  }
  return SupabaseAdminDashboardGateway(ref.watch(supabaseClientProvider));
});

class _UnavailableAdminDashboardGateway implements AdminDashboardGateway {
  const _UnavailableAdminDashboardGateway();

  @override
  Future<AdminDashboardMetrics> fetchMetrics() async {
    throw const AdminAuthFailure(SubscriptionErrorCode.temporaryBackendFailure);
  }
}
