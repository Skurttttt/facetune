import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/admin_rpc.dart';
import '../domain/admin_dashboard_v2_gateway.dart';
import '../domain/admin_dashboard_v2_metrics.dart';

/// Reads the aggregate-only WA-DASH-1 contract with the admin's own session.
class SupabaseAdminDashboardV2Gateway implements AdminDashboardV2Gateway {
  const SupabaseAdminDashboardV2Gateway(this._client);

  static const rpcName = 'admin_dashboard_v2_metrics';

  final SupabaseClient _client;

  @override
  Future<AdminDashboardV2Metrics> fetchMetrics() async {
    final payload = await callAdminReadRpc(_client, rpcName, const {});
    return AdminDashboardV2Metrics.decode(payload);
  }
}
