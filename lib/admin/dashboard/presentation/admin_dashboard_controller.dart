import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/subscription/domain/errors/subscription_error_code.dart';
import '../../auth/domain/admin_auth_failure.dart';
import '../../auth/presentation/admin_authorization_controller.dart';
import '../../auth/presentation/admin_authorization_state.dart';
import '../data/admin_dashboard_gateway_provider.dart';
import '../domain/admin_dashboard_gateway.dart';
import '../domain/admin_dashboard_metrics.dart';

/// What the dashboard page renders. Sealed so every state is drawn on
/// purpose: there is no "success with missing bits".
sealed class AdminDashboardState {
  const AdminDashboardState();
}

/// Nothing has been asked for yet, or a refresh is in flight with no prior
/// figures to keep showing.
final class AdminDashboardLoading extends AdminDashboardState {
  const AdminDashboardLoading();
}

final class AdminDashboardReady extends AdminDashboardState {
  const AdminDashboardReady(this.metrics, {this.refreshing = false});

  final AdminDashboardMetrics metrics;

  /// A refresh is in flight; the previous figures stay on screen meanwhile.
  final bool refreshing;
}

/// The server could not answer. Authorization refusals never land here; they
/// are handed to the authorization controller and the router takes over.
final class AdminDashboardUnavailable extends AdminDashboardState {
  const AdminDashboardUnavailable(this.code, {required this.retryable});

  final SubscriptionErrorCode code;
  final bool retryable;
}

final adminDashboardControllerProvider =
    StateNotifierProvider.autoDispose<
      AdminDashboardController,
      AdminDashboardState
    >((ref) {
      return AdminDashboardController(
        gateway: ref.watch(adminDashboardGatewayProvider),
        onServerRefusal: ref
            .read(adminAuthorizationControllerProvider.notifier)
            .handleServerRefusal,
        isAuthorized: () =>
            ref.read(adminAuthorizationControllerProvider) is AdminAuthorized,
      );
    });

/// Loads the dashboard figures for the current admin session.
///
/// Fetches only when the authorization controller already says the session
/// is administrative — never before — so no privileged call is made while the
/// server's authorization answer is outstanding. A refusal from the metrics
/// call itself (revoked mid-session, token expired) is forwarded to the
/// authorization controller, which moves the whole app to the secure state.
class AdminDashboardController extends StateNotifier<AdminDashboardState> {
  AdminDashboardController({
    required AdminDashboardGateway gateway,
    required void Function(AdminAuthFailure failure) onServerRefusal,
    required bool Function() isAuthorized,
  }) : _gateway = gateway,
       _onServerRefusal = onServerRefusal,
       _isAuthorized = isAuthorized,
       super(const AdminDashboardLoading()) {
    load();
  }

  final AdminDashboardGateway _gateway;
  final void Function(AdminAuthFailure failure) _onServerRefusal;
  final bool Function() _isAuthorized;
  int _generation = 0;

  Future<void> load() => _fetch(keepPrevious: false);

  Future<void> refresh() => _fetch(keepPrevious: true);

  Future<void> _fetch({required bool keepPrevious}) async {
    if (!_isAuthorized()) {
      // The router will never show the page in this state; if it is asked
      // anyway, ask the server for nothing.
      state = const AdminDashboardUnavailable(
        SubscriptionErrorCode.adminUnauthorized,
        retryable: false,
      );
      return;
    }
    final generation = ++_generation;
    final previous = state;
    state = keepPrevious && previous is AdminDashboardReady
        ? AdminDashboardReady(previous.metrics, refreshing: true)
        : const AdminDashboardLoading();
    try {
      final metrics = await _gateway.fetchMetrics();
      if (generation != _generation) return;
      state = AdminDashboardReady(metrics);
    } on AdminAuthFailure catch (failure) {
      if (generation != _generation) return;
      if (failure.isUnauthenticated || failure.isUnauthorized) {
        _onServerRefusal(failure);
        state = AdminDashboardUnavailable(failure.code, retryable: false);
      } else {
        state = AdminDashboardUnavailable(
          failure.code,
          retryable: failure.retryable,
        );
      }
    } catch (_) {
      if (generation != _generation) return;
      state = const AdminDashboardUnavailable(
        SubscriptionErrorCode.temporaryBackendFailure,
        retryable: true,
      );
    }
  }
}
