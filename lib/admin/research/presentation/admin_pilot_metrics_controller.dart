import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/admin_authorization_controller.dart';
import '../../auth/presentation/admin_authorization_state.dart';
import '../../shared/admin_keyset_list_controller.dart';
import '../data/admin_research_gateway_provider.dart';
import '../domain/admin_research_gateway.dart';
import '../domain/admin_research_models.dart';

/// The per-pilot listing has no filters: its population is fixed to every
/// Salon Pilot grant, so the filter type is [void].
typedef AdminPilotMetricsState = AdminListState<AdminPilotMetricsRow, void>;

final adminPilotMetricsControllerProvider =
    StateNotifierProvider.autoDispose<
      AdminPilotMetricsController,
      AdminPilotMetricsState
    >((ref) {
      return AdminPilotMetricsController(
        gateway: ref.watch(adminResearchGatewayProvider),
        isAuthorized: () =>
            ref.read(adminAuthorizationControllerProvider) is AdminAuthorized,
        onServerRefusal: ref
            .read(adminAuthorizationControllerProvider.notifier)
            .handleServerRefusal,
      );
    });

class AdminPilotMetricsController
    extends AdminKeysetListController<AdminPilotMetricsRow, void> {
  AdminPilotMetricsController({
    required AdminResearchGateway gateway,
    required super.isAuthorized,
    required super.onServerRefusal,
  }) : _gateway = gateway,
       super(initialFilters: null);

  final AdminResearchGateway _gateway;

  @override
  Future<AdminListPage<AdminPilotMetricsRow>> fetch(
    void filters,
    String? cursor,
  ) => _gateway.listPilots(cursor: cursor);
}
