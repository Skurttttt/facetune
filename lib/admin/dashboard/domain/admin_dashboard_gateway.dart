import 'admin_dashboard_metrics.dart';

/// Fetches the dashboard's server-aggregated figures for the current admin
/// session. Throws `AdminAuthFailure` when the server refuses or cannot
/// answer. There is nothing to pass: the server decides who is asking.
abstract interface class AdminDashboardGateway {
  Future<AdminDashboardMetrics> fetchMetrics();
}
