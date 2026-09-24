import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/admin_auth_failure.dart';
import '../../auth/presentation/admin_authorization_controller.dart';
import '../../auth/presentation/admin_authorization_state.dart';
import '../../shared/admin_read_failure.dart';
import '../data/admin_research_gateway_provider.dart';
import '../domain/admin_research_gateway.dart';
import '../domain/admin_research_models.dart';

/// What the research page's aggregate section renders. Sealed so every state
/// is drawn on purpose: there is no "success with missing bits".
sealed class AdminResearchState {
  const AdminResearchState();
}

final class AdminResearchLoading extends AdminResearchState {
  const AdminResearchLoading();
}

final class AdminResearchReady extends AdminResearchState {
  const AdminResearchReady(this.research, {this.refreshing = false});

  final AdminSalonPilotResearch research;

  /// A refresh is in flight; the previous figures stay on screen meanwhile.
  final bool refreshing;
}

/// The server could not answer. Authorization refusals never land here; they
/// are handed to the authorization controller and the router takes over.
final class AdminResearchUnavailable extends AdminResearchState {
  const AdminResearchUnavailable({required this.retryable});

  final bool retryable;
}

final adminResearchControllerProvider =
    StateNotifierProvider.autoDispose<
      AdminResearchController,
      AdminResearchState
    >((ref) {
      return AdminResearchController(
        gateway: ref.watch(adminResearchGatewayProvider),
        onServerRefusal: ref
            .read(adminAuthorizationControllerProvider.notifier)
            .handleServerRefusal,
        isAuthorized: () =>
            ref.read(adminAuthorizationControllerProvider) is AdminAuthorized,
      );
    });

/// Loads the Salon Pilot aggregate for the current admin session, on the
/// WA-4 dashboard controller's rules: fetch only once the session is known
/// to be administrative, and hand any refusal to the authorization
/// controller so the whole app moves to the secure state.
class AdminResearchController extends StateNotifier<AdminResearchState> {
  AdminResearchController({
    required AdminResearchGateway gateway,
    required void Function(AdminAuthFailure failure) onServerRefusal,
    required bool Function() isAuthorized,
  }) : _gateway = gateway,
       _onServerRefusal = onServerRefusal,
       _isAuthorized = isAuthorized,
       super(const AdminResearchLoading()) {
    load();
  }

  final AdminResearchGateway _gateway;
  final void Function(AdminAuthFailure failure) _onServerRefusal;
  final bool Function() _isAuthorized;
  int _generation = 0;

  Future<void> load() => _fetch(keepPrevious: false);

  Future<void> refresh() => _fetch(keepPrevious: true);

  Future<void> _fetch({required bool keepPrevious}) async {
    if (!_isAuthorized()) {
      state = const AdminResearchUnavailable(retryable: false);
      return;
    }
    final generation = ++_generation;
    final previous = state;
    state = keepPrevious && previous is AdminResearchReady
        ? AdminResearchReady(previous.research, refreshing: true)
        : const AdminResearchLoading();
    try {
      final research = await _gateway.fetchResearch();
      if (generation != _generation) return;
      state = AdminResearchReady(research);
    } on AdminAuthFailure catch (failure) {
      if (generation != _generation) return;
      _onServerRefusal(failure);
      state = const AdminResearchUnavailable(retryable: false);
    } on AdminReadFailure catch (failure) {
      if (generation != _generation) return;
      state = AdminResearchUnavailable(retryable: failure.retryable);
    } catch (_) {
      if (generation != _generation) return;
      state = const AdminResearchUnavailable(retryable: true);
    }
  }
}
