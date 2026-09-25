import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/admin_auth_failure.dart';
import '../../auth/presentation/admin_authorization_controller.dart';
import '../../auth/presentation/admin_authorization_state.dart';
import '../../shared/admin_read_failure.dart';
import '../data/admin_dashboard_v2_gateway_provider.dart';
import '../domain/admin_dashboard_v2_gateway.dart';
import '../domain/admin_dashboard_v2_metrics.dart';

sealed class AdminDashboardV2State {
  const AdminDashboardV2State();
}

final class AdminDashboardV2Loading extends AdminDashboardV2State {
  const AdminDashboardV2Loading();
}

final class AdminDashboardV2Ready extends AdminDashboardV2State {
  const AdminDashboardV2Ready(this.metrics, {this.refreshing = false});

  final AdminDashboardV2Metrics metrics;
  final bool refreshing;
}

final class AdminDashboardV2Unavailable extends AdminDashboardV2State {
  const AdminDashboardV2Unavailable({required this.retryable});

  final bool retryable;
}

final adminDashboardV2ControllerProvider =
    StateNotifierProvider.autoDispose<
      AdminDashboardV2Controller,
      AdminDashboardV2State
    >((ref) {
      return AdminDashboardV2Controller(
        gateway: ref.watch(adminDashboardV2GatewayProvider),
        onServerRefusal: ref
            .read(adminAuthorizationControllerProvider.notifier)
            .handleServerRefusal,
        isAuthorized: () =>
            ref.read(adminAuthorizationControllerProvider) is AdminAuthorized,
      );
    });

class AdminDashboardV2Controller extends StateNotifier<AdminDashboardV2State> {
  AdminDashboardV2Controller({
    required AdminDashboardV2Gateway gateway,
    required void Function(AdminAuthFailure failure) onServerRefusal,
    required bool Function() isAuthorized,
  }) : _gateway = gateway,
       _onServerRefusal = onServerRefusal,
       _isAuthorized = isAuthorized,
       super(const AdminDashboardV2Loading()) {
    load();
  }

  final AdminDashboardV2Gateway _gateway;
  final void Function(AdminAuthFailure failure) _onServerRefusal;
  final bool Function() _isAuthorized;
  int _generation = 0;

  Future<void> load() => _fetch(keepPrevious: false);

  Future<void> refresh() => _fetch(keepPrevious: true);

  Future<void> _fetch({required bool keepPrevious}) async {
    if (!_isAuthorized()) {
      state = const AdminDashboardV2Unavailable(retryable: false);
      return;
    }
    final generation = ++_generation;
    final previous = state;
    state = keepPrevious && previous is AdminDashboardV2Ready
        ? AdminDashboardV2Ready(previous.metrics, refreshing: true)
        : const AdminDashboardV2Loading();
    try {
      final metrics = await _gateway.fetchMetrics();
      if (generation != _generation) return;
      state = AdminDashboardV2Ready(metrics);
    } on AdminAuthFailure catch (failure) {
      if (generation != _generation) return;
      if (failure.isUnauthenticated || failure.isUnauthorized) {
        _onServerRefusal(failure);
      }
      state = AdminDashboardV2Unavailable(retryable: failure.retryable);
    } on AdminReadFailure catch (failure) {
      if (generation != _generation) return;
      state = AdminDashboardV2Unavailable(retryable: failure.retryable);
    } catch (_) {
      if (generation != _generation) return;
      state = const AdminDashboardV2Unavailable(retryable: true);
    }
  }
}
