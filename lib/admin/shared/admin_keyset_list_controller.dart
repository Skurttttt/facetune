import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/domain/admin_auth_failure.dart';
import 'admin_read_failure.dart';

/// One fixed-size server page of [T] plus the cursor for the next one.
class AdminListPage<T> {
  const AdminListPage({required this.items, required this.nextCursor});

  final List<T> items;
  final String? nextCursor;
}

sealed class AdminListState<T, F> {
  const AdminListState();
}

final class AdminListLoading<T, F> extends AdminListState<T, F> {
  const AdminListLoading();
}

final class AdminListReady<T, F> extends AdminListState<T, F> {
  const AdminListReady({
    required this.page,
    required this.filters,
    required this.pageNumber,
    required this.canGoBack,
    this.refreshing = false,
  });

  final AdminListPage<T> page;
  final F filters;
  final int pageNumber;
  final bool canGoBack;
  final bool refreshing;
}

final class AdminListUnavailable<T, F> extends AdminListState<T, F> {
  const AdminListUnavailable({required this.retryable});

  final bool retryable;
}

/// The server refused the request as sent — a filter or cursor it does not
/// accept. Distinct from unavailable: retrying the same request cannot help,
/// but changing the filters can.
final class AdminListRejected<T, F> extends AdminListState<T, F> {
  const AdminListRejected();
}

/// Loads one fixed-size, server-sorted keyset page at a time under a set of
/// filters [F].
///
/// Previous cursors are kept only for navigation. No prior page's rows are
/// retained, so a large table never accumulates in browser memory as the
/// operator pages through it — the WA-5 users controller's rule, generalized
/// for the filtered listings that follow it. Changing filters restarts at the
/// first page, because a cursor is only valid for the filters it was issued
/// under (the server enforces this too).
abstract class AdminKeysetListController<T, F>
    extends StateNotifier<AdminListState<T, F>> {
  AdminKeysetListController({
    required F initialFilters,
    required bool Function() isAuthorized,
    required void Function(AdminAuthFailure failure) onServerRefusal,
  }) : _filters = initialFilters,
       _isAuthorized = isAuthorized,
       _onServerRefusal = onServerRefusal,
       super(const AdminListLoading()) {
    load();
  }

  final bool Function() _isAuthorized;
  final void Function(AdminAuthFailure failure) _onServerRefusal;
  final List<String?> _previousCursors = [];
  String? _currentCursor;
  F _filters;
  int _generation = 0;

  F get filters => _filters;

  /// Fetches one page for [filters] at [cursor]. Throws [AdminAuthFailure]
  /// or [AdminReadFailure]; anything else is treated as unavailable.
  Future<AdminListPage<T>> fetch(F filters, String? cursor);

  Future<void> applyFilters(F filters) async {
    _filters = filters;
    _currentCursor = null;
    _previousCursors.clear();
    await _fetch(keepPrevious: false);
  }

  Future<void> load() => _fetch(keepPrevious: false);

  Future<void> refresh() => _fetch(keepPrevious: true);

  Future<void> nextPage() async {
    final current = state;
    if (current is! AdminListReady<T, F> || current.page.nextCursor == null) {
      return;
    }
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
      state = const AdminListUnavailable(retryable: false);
      return;
    }
    final generation = ++_generation;
    final previous = state;
    state = keepPrevious && previous is AdminListReady<T, F>
        ? AdminListReady(
            page: previous.page,
            filters: previous.filters,
            pageNumber: previous.pageNumber,
            canGoBack: previous.canGoBack,
            refreshing: true,
          )
        : const AdminListLoading();
    try {
      final page = await fetch(_filters, _currentCursor);
      if (generation != _generation) return;
      state = AdminListReady(
        page: page,
        filters: _filters,
        pageNumber: _previousCursors.length + 1,
        canGoBack: _previousCursors.isNotEmpty,
      );
    } on AdminAuthFailure catch (failure) {
      if (generation != _generation) return;
      _onServerRefusal(failure);
      state = const AdminListUnavailable(retryable: false);
    } on AdminReadFailure catch (failure) {
      if (generation != _generation) return;
      state = failure.type == AdminReadFailureType.rejected
          ? const AdminListRejected()
          : AdminListUnavailable(retryable: failure.retryable);
    } catch (_) {
      if (generation != _generation) return;
      state = const AdminListUnavailable(retryable: true);
    }
  }
}
