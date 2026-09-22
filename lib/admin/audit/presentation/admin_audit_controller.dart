import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/admin_auth_failure.dart';
import '../../auth/presentation/admin_authorization_controller.dart';
import '../../auth/presentation/admin_authorization_state.dart';
import '../../shared/admin_keyset_list_controller.dart';
import '../../shared/admin_read_failure.dart';
import '../data/admin_audit_gateway_provider.dart';
import '../domain/admin_audit_gateway.dart';
import '../domain/admin_audit_models.dart';

typedef AdminAuditState = AdminListState<AdminAuditListItem, AdminAuditFilters>;

final adminAuditControllerProvider = StateNotifierProvider.autoDispose
    .family<AdminAuditController, AdminAuditState, AdminAuditFilters>((
      ref,
      initialFilters,
    ) {
      return AdminAuditController(
        gateway: ref.watch(adminAuditGatewayProvider),
        initialFilters: initialFilters,
        isAuthorized: () =>
            ref.read(adminAuthorizationControllerProvider) is AdminAuthorized,
        onServerRefusal: ref
            .read(adminAuthorizationControllerProvider.notifier)
            .handleServerRefusal,
      );
    });

class AdminAuditController
    extends AdminKeysetListController<AdminAuditListItem, AdminAuditFilters> {
  AdminAuditController({
    required AdminAuditGateway gateway,
    required super.initialFilters,
    required super.isAuthorized,
    required super.onServerRefusal,
  }) : _gateway = gateway;

  final AdminAuditGateway _gateway;

  @override
  Future<AdminListPage<AdminAuditListItem>> fetch(
    AdminAuditFilters filters,
    String? cursor,
  ) => _gateway.listAudit(filters, cursor: cursor);
}

sealed class AdminAuditDetailState {
  const AdminAuditDetailState();
}

final class AdminAuditDetailLoading extends AdminAuditDetailState {
  const AdminAuditDetailLoading();
}

final class AdminAuditDetailReady extends AdminAuditDetailState {
  const AdminAuditDetailReady(this.event);
  final AdminAuditDetail event;
}

final class AdminAuditDetailNotFound extends AdminAuditDetailState {
  const AdminAuditDetailNotFound();
}

final class AdminAuditDetailUnavailable extends AdminAuditDetailState {
  const AdminAuditDetailUnavailable({required this.retryable});
  final bool retryable;
}

final adminAuditDetailControllerProvider = StateNotifierProvider.autoDispose
    .family<AdminAuditDetailController, AdminAuditDetailState, String>((
      ref,
      eventId,
    ) {
      return AdminAuditDetailController(
        eventId: eventId,
        gateway: ref.watch(adminAuditGatewayProvider),
        isAuthorized: () =>
            ref.read(adminAuthorizationControllerProvider) is AdminAuthorized,
        onServerRefusal: ref
            .read(adminAuthorizationControllerProvider.notifier)
            .handleServerRefusal,
      );
    });

class AdminAuditDetailController extends StateNotifier<AdminAuditDetailState> {
  AdminAuditDetailController({
    required this.eventId,
    required AdminAuditGateway gateway,
    required bool Function() isAuthorized,
    required void Function(AdminAuthFailure failure) onServerRefusal,
  }) : _gateway = gateway,
       _isAuthorized = isAuthorized,
       _onServerRefusal = onServerRefusal,
       super(const AdminAuditDetailLoading()) {
    load();
  }

  final String eventId;
  final AdminAuditGateway _gateway;
  final bool Function() _isAuthorized;
  final void Function(AdminAuthFailure failure) _onServerRefusal;
  int _generation = 0;

  Future<void> load() async {
    if (!_isAuthorized()) {
      state = const AdminAuditDetailUnavailable(retryable: false);
      return;
    }
    final generation = ++_generation;
    state = const AdminAuditDetailLoading();
    try {
      final event = await _gateway.getAuditEvent(eventId);
      if (generation != _generation) return;
      state = event == null
          ? const AdminAuditDetailNotFound()
          : AdminAuditDetailReady(event);
    } on AdminAuthFailure catch (failure) {
      if (generation != _generation) return;
      _onServerRefusal(failure);
      state = const AdminAuditDetailUnavailable(retryable: false);
    } on AdminReadFailure catch (failure) {
      if (generation != _generation) return;
      state = AdminAuditDetailUnavailable(retryable: failure.retryable);
    } catch (_) {
      if (generation != _generation) return;
      state = const AdminAuditDetailUnavailable(retryable: true);
    }
  }
}

typedef AdminEntitlementHistoryState =
    AdminListState<AdminEntitlementHistoryEvent, String>;

final adminEntitlementHistoryControllerProvider = StateNotifierProvider
    .autoDispose
    .family<
      AdminEntitlementHistoryController,
      AdminEntitlementHistoryState,
      String
    >((ref, entitlementId) {
      return AdminEntitlementHistoryController(
        gateway: ref.watch(adminAuditGatewayProvider),
        initialFilters: entitlementId,
        isAuthorized: () =>
            ref.read(adminAuthorizationControllerProvider) is AdminAuthorized,
        onServerRefusal: ref
            .read(adminAuthorizationControllerProvider.notifier)
            .handleServerRefusal,
      );
    });

class AdminEntitlementHistoryController
    extends AdminKeysetListController<AdminEntitlementHistoryEvent, String> {
  AdminEntitlementHistoryController({
    required AdminAuditGateway gateway,
    required super.initialFilters,
    required super.isAuthorized,
    required super.onServerRefusal,
  }) : _gateway = gateway;

  final AdminAuditGateway _gateway;

  @override
  Future<AdminListPage<AdminEntitlementHistoryEvent>> fetch(
    String entitlementId,
    String? cursor,
  ) => _gateway.listEntitlementHistory(entitlementId, cursor: cursor);
}
