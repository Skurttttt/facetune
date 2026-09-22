import '../../shared/admin_keyset_list_controller.dart';
import 'admin_usage_models.dart';

abstract interface class AdminUsageGateway {
  Future<AdminListPage<AdminUsageListItem>> listUsage(
    AdminUsageFilters filters, {
    String? cursor,
  });
}
