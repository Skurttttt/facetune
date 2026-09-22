import '../../shared/admin_keyset_list_controller.dart';
import 'admin_entitlement_models.dart';

abstract interface class AdminEntitlementsGateway {
  Future<AdminListPage<AdminEntitlementListItem>> listEntitlements(
    AdminEntitlementFilters filters, {
    String? cursor,
  });
}
