import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/admin_auth_failure.dart';
import '../../auth/presentation/admin_authorization_controller.dart';
import '../../auth/presentation/admin_authorization_state.dart';
import '../data/admin_users_gateway_provider.dart';
import '../domain/admin_user_models.dart';
import '../domain/admin_users_failure.dart';
import '../domain/admin_users_gateway.dart';

sealed class AdminUsersState {
  const AdminUsersState();
}

final class AdminUsersLoading extends AdminUsersState {
  const AdminUsersLoading();
}

final class AdminUsersReady extends AdminUsersState {
  const AdminUsersReady({
    required this.page,
    required this.search,
    required this.pageNumber,
    required this.canGoBack,
    this.refreshing = false,
  });

  final AdminUserPage page;
  final String? search;
  final int pageNumber;
  final bool canGoBack;
  final bool refreshing;
}

final class AdminUsersUnavailable extends AdminUsersState {
  const AdminUsersUnavailable({required this.retryable});

  final bool retryable;
}

final adminUsersControllerProvider =
    StateNotifierProvider.autoDispose<AdminUsersController, AdminUsersState>((
      ref,
    ) {
      return AdminUsersController(
        gateway: ref.watch(adminUsersGatewayProvider),
        isAuthorized: () =>
            ref.read(adminAuthorizationControllerProvider) is AdminAuthorized,
        onServerRefusal: ref
            .read(adminAuthorizationControllerProvider.notifier)
            .handleServerRefusal,
      );
    });

/// Loads one fixed-size server page at a time.
///
/// Previous cursors are kept only for navigation. No prior page's account
/// rows are retained, so a large user base can never accumulate in browser
/// memory as the operator pages through it.
class AdminUsersController extends StateNotifier<AdminUsersState> {
  AdminUsersController({
    required AdminUsersGateway gateway,
    required bool Function() isAuthorized,
    required void Function(AdminAuthFailure failure) onServerRefusal,
  }) : _gateway = gateway,
       _isAuthorized = isAuthorized,
       _onServerRefusal = onServerRefusal,
       super(const AdminUsersLoading()) {
    load();
  }

  final AdminUsersGateway _gateway;
  final bool Function() _isAuthorized;
  final void Function(AdminAuthFailure failure) _onServerRefusal;
  final List<String?> _previousCursors = [];
  String? _currentCursor;
  String? _search;
  int _generation = 0;

  Future<void> search(String value) async {
    final trimmed = value.trim().toLowerCase();
    _search = trimmed.isEmpty ? null : trimmed;
    _currentCursor = null;
    _previousCursors.clear();
    await _fetch(keepPrevious: false);
  }

  Future<void> load() => _fetch(keepPrevious: false);

  Future<void> refresh() => _fetch(keepPrevious: true);

  Future<void> nextPage() async {
    final current = state;
    if (current is! AdminUsersReady || current.page.nextCursor == null) return;
    _previousCursors.add(_currentCursor);
    _currentCursor = current.page.nextCursor;
    await _fetch(keepPrevious: false);
  }

  Future<void> previousPage() async {
    if (_previousCursors.isEmpty) return;
    _currentCursor = _previousCursors.removeLast();
    await _fetch(keepPrevious: false);
  }

  Future<void> _fetch({required bool keepPrevious}) async {
    if (!_isAuthorized()) {
      state = const AdminUsersUnavailable(retryable: false);
      return;
    }
    final generation = ++_generation;
    final previous = state;
    state = keepPrevious && previous is AdminUsersReady
        ? AdminUsersReady(
            page: previous.page,
            search: previous.search,
            pageNumber: previous.pageNumber,
            canGoBack: previous.canGoBack,
            refreshing: true,
          )
        : const AdminUsersLoading();
    try {
      final page = await _gateway.searchUsers(
        search: _search,
        cursor: _currentCursor,
      );
      if (generation != _generation) return;
      state = AdminUsersReady(
        page: page,
        search: _search,
        pageNumber: _previousCursors.length + 1,
        canGoBack: _previousCursors.isNotEmpty,
      );
    } on AdminAuthFailure catch (failure) {
      if (generation != _generation) return;
      _onServerRefusal(failure);
      state = const AdminUsersUnavailable(retryable: false);
    } on AdminUsersFailure catch (failure) {
      if (generation != _generation) return;
      state = AdminUsersUnavailable(retryable: failure.retryable);
    } catch (_) {
      if (generation != _generation) return;
      state = const AdminUsersUnavailable(retryable: true);
    }
  }
}

sealed class AdminUserDetailState {
  const AdminUserDetailState();
}

final class AdminUserDetailLoading extends AdminUserDetailState {
  const AdminUserDetailLoading();
}

final class AdminUserDetailReady extends AdminUserDetailState {
  const AdminUserDetailReady(this.detail);

  final AdminUserDetail detail;
}

final class AdminUserDetailNotFound extends AdminUserDetailState {
  const AdminUserDetailNotFound();
}

final class AdminUserDetailUnavailable extends AdminUserDetailState {
  const AdminUserDetailUnavailable({required this.retryable});

  final bool retryable;
}

final adminUserDetailControllerProvider = StateNotifierProvider.autoDispose
    .family<AdminUserDetailController, AdminUserDetailState, String>((
      ref,
      userId,
    ) {
      return AdminUserDetailController(
        userId: userId,
        gateway: ref.watch(adminUsersGatewayProvider),
        isAuthorized: () =>
            ref.read(adminAuthorizationControllerProvider) is AdminAuthorized,
        onServerRefusal: ref
            .read(adminAuthorizationControllerProvider.notifier)
            .handleServerRefusal,
      );
    });

class AdminUserDetailController extends StateNotifier<AdminUserDetailState> {
  AdminUserDetailController({
    required this.userId,
    required AdminUsersGateway gateway,
    required bool Function() isAuthorized,
    required void Function(AdminAuthFailure failure) onServerRefusal,
  }) : _gateway = gateway,
       _isAuthorized = isAuthorized,
       _onServerRefusal = onServerRefusal,
       super(const AdminUserDetailLoading()) {
    load();
  }

  final String userId;
  final AdminUsersGateway _gateway;
  final bool Function() _isAuthorized;
  final void Function(AdminAuthFailure failure) _onServerRefusal;
  int _generation = 0;

  Future<void> load() async {
    if (!_isAuthorized()) {
      state = const AdminUserDetailUnavailable(retryable: false);
      return;
    }
    final generation = ++_generation;
    state = const AdminUserDetailLoading();
    try {
      final detail = await _gateway.getUser(userId);
      if (generation != _generation) return;
      state = AdminUserDetailReady(detail);
    } on AdminAuthFailure catch (failure) {
      if (generation != _generation) return;
      _onServerRefusal(failure);
      state = const AdminUserDetailUnavailable(retryable: false);
    } on AdminUsersFailure catch (failure) {
      if (generation != _generation) return;
      state = failure.type == AdminUsersFailureType.notFound
          ? const AdminUserDetailNotFound()
          : AdminUserDetailUnavailable(retryable: failure.retryable);
    } catch (_) {
      if (generation != _generation) return;
      state = const AdminUserDetailUnavailable(retryable: true);
    }
  }
}
