import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/admin_authorization_controller.dart';
import '../../auth/presentation/admin_authorization_state.dart';
import '../../shared/admin_keyset_list_controller.dart';
import '../data/admin_entitlements_gateway_provider.dart';
import '../domain/admin_entitlement_models.dart';
import '../domain/admin_entitlements_gateway.dart';

typedef AdminEntitlementsState =
    AdminListState<AdminEntitlementListItem, AdminEntitlementFilters>;

/// Keyed by the filters the page opened with (a deep link such as
/// `/entitlements?userId=…`), so the first request already carries them.
final adminEntitlementsControllerProvider = StateNotifierProvider.autoDispose
    .family<
      AdminEntitlementsController,
      AdminEntitlementsState,
      AdminEntitlementFilters
    >((ref, initialFilters) {
      return AdminEntitlementsController(
        gateway: ref.watch(adminEntitlementsGatewayProvider),
        initialFilters: initialFilters,
        isAuthorized: () =>
            ref.read(adminAuthorizationControllerProvider) is AdminAuthorized,
        onServerRefusal: ref
            .read(adminAuthorizationControllerProvider.notifier)
            .handleServerRefusal,
      );
    });

class AdminEntitlementsController
    extends
        AdminKeysetListController<
          AdminEntitlementListItem,
          AdminEntitlementFilters
        > {
  AdminEntitlementsController({
    required AdminEntitlementsGateway gateway,
    required super.initialFilters,
    required super.isAuthorized,
    required super.onServerRefusal,
  }) : _gateway = gateway;

  final AdminEntitlementsGateway _gateway;

  @override
  Future<AdminListPage<AdminEntitlementListItem>> fetch(
    AdminEntitlementFilters filters,
    String? cursor,
  ) => _gateway.listEntitlements(filters, cursor: cursor);
}
