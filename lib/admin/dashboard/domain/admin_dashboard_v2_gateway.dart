import 'admin_dashboard_v2_metrics.dart';

abstract interface class AdminDashboardV2Gateway {
  Future<AdminDashboardV2Metrics> fetchMetrics();
}
