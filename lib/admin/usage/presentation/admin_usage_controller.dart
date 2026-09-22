import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/admin_authorization_controller.dart';
import '../../auth/presentation/admin_authorization_state.dart';
import '../../shared/admin_keyset_list_controller.dart';
import '../data/admin_usage_gateway_provider.dart';
import '../domain/admin_usage_gateway.dart';
import '../domain/admin_usage_models.dart';

typedef AdminUsageState = AdminListState<AdminUsageListItem, AdminUsageFilters>;

/// Keyed by the filters the page opened with (`/usage?userId=…` or
/// `?entitlementId=…`), so the first request already carries them.
final adminUsageControllerProvider = StateNotifierProvider.autoDispose
    .family<AdminUsageController, AdminUsageState, AdminUsageFilters>((
      ref,
      initialFilters,
    ) {
      return AdminUsageController(
        gateway: ref.watch(adminUsageGatewayProvider),
        initialFilters: initialFilters,
        isAuthorized: () =>
            ref.read(adminAuthorizationControllerProvider) is AdminAuthorized,
        onServerRefusal: ref
            .read(adminAuthorizationControllerProvider.notifier)
            .handleServerRefusal,
      );
    });

class AdminUsageController
    extends AdminKeysetListController<AdminUsageListItem, AdminUsageFilters> {
  AdminUsageController({
    required AdminUsageGateway gateway,
    required super.initialFilters,
    required super.isAuthorized,
    required super.onServerRefusal,
  }) : _gateway = gateway;

  final AdminUsageGateway _gateway;

  @override
  Future<AdminListPage<AdminUsageListItem>> fetch(
    AdminUsageFilters filters,
    String? cursor,
  ) => _gateway.listUsage(filters, cursor: cursor);
}
