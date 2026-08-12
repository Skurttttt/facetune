import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../saved_looks/data/providers/saved_looks_providers.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../saved_looks/domain/errors/saved_looks_failure.dart';
import '../../../saved_looks/domain/repositories/saved_looks_repository.dart';
import '../../data/providers/history_providers.dart';
import '../../domain/entities/history_entry.dart';
import '../../domain/errors/history_failure.dart';
import '../../domain/repositories/history_repository.dart';
import 'history_state.dart';

final historyControllerProvider =
    StateNotifierProvider.autoDispose<HistoryController, HistoryState>((ref) {
      ref.watch(authControllerProvider.select((state) => state.user?.id));
      final controller = HistoryController(
        ref.watch(historyRepositoryProvider),
        ref.watch(savedLooksRepositoryProvider),
        () => ref.read(savedLooksRevisionProvider.notifier).state++,
      );
      controller.loadInitial();
      return controller;
    });

class HistoryController extends StateNotifier<HistoryState> {
  HistoryController(
    this._repository,
    this._savedLooksRepository,
    this._notifySavedLooksChanged,
  ) : super(const HistoryState());

  static const pageSize = 12;
  static const _mutationTimeout = Duration(seconds: 30);
  final HistoryRepository _repository;
  final SavedLooksRepository _savedLooksRepository;
  final void Function() _notifySavedLooksChanged;
  int _loadGeneration = 0;
  int _filterGeneration = 0;

  Future<void> loadInitial() async {
    final generation = ++_loadGeneration;
    state = HistoryState(filter: state.filter, query: state.query);
    await _load(offset: 0, append: false, generation: generation);
    await _ensureVisible(++_filterGeneration);
  }

  Future<void> refresh() => loadInitial();

  Future<void> loadMore() async {
    if (!state.hasMore || state.status != HistoryLoadStatus.ready) {
      return;
    }
    final generation = _loadGeneration;
    state = _state(status: HistoryLoadStatus.loadingMore);
    await _load(offset: state.nextOffset, append: true, generation: generation);
  }

  Future<void> retryLoadMore() async {
    if (state.status != HistoryLoadStatus.failure || state.items.isEmpty) {
      return;
    }
    state = _state(status: HistoryLoadStatus.ready);
    await loadMore();
  }

  Future<void> _load({
    required int offset,
    required bool append,
    required int generation,
  }) async {
    try {
      final page = await _repository.loadPage(offset: offset, limit: pageSize);
      if (!mounted || generation != _loadGeneration) return;
      state = _state(
        status: HistoryLoadStatus.ready,
        items: List.unmodifiable([if (append) ...state.items, ...page.items]),
        hasMore: page.hasMore,
        nextOffset: page.nextOffset,
        sessionExpired: false,
      );
      await _ensureVisible(_filterGeneration);
    } on HistoryFailure catch (failure) {
      if (!mounted || generation != _loadGeneration) return;
      state = _state(
        status: HistoryLoadStatus.failure,
        items: append ? state.items : const [],
        hasMore: append && state.hasMore,
        message: failure.message,
        sessionExpired: failure.sessionExpired,
      );
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      state = _state(
        status: HistoryLoadStatus.failure,
        items: append ? state.items : const [],
        hasMore: append && state.hasMore,
        message: 'Your FaceTune history could not be loaded right now.',
        sessionExpired: false,
      );
    }
  }

  Future<void> setQuery(String query) async {
    state = _state(query: query);
    await _ensureVisible(++_filterGeneration);
  }

  Future<void> setFilter(HistoryFilter filter) async {
    if (filter == state.filter) return;
    state = _state(filter: filter);
    await _ensureVisible(++_filterGeneration);
  }

  Future<void> _ensureVisible(int generation) async {
    // Paging stops as soon as a page fails to advance the offset, so a backend
    // that keeps reporting `hasMore` can never trap this in an endless loop.
    var previousOffset = -1;
    while (mounted &&
        generation == _filterGeneration &&
        state.visibleItems.isEmpty &&
        state.hasMore &&
        state.nextOffset != previousOffset &&
        state.status == HistoryLoadStatus.ready) {
      previousOffset = state.nextOffset;
      await loadMore();
    }
  }

  Future<void> toggleFavorite(HistoryEntry entry) async {
    final preview = entry.preview;
    if (preview == null || state.mutatingIds.contains(entry.id)) return;
    state = _state(mutatingIds: {...state.mutatingIds, entry.id});
    try {
      final savedLook = entry.savedLook == null
          ? await _savedLooksRepository
                .save(preview, favorite: true)
                .timeout(_mutationTimeout)
          : await _savedLooksRepository
                .setFavorite(entry.savedLook!, !entry.savedLook!.isFavorite)
                .timeout(_mutationTimeout);
      if (!mounted) return;
      state = _state(
        status: HistoryLoadStatus.ready,
        items: List.unmodifiable([
          for (final item in state.items)
            if (item.id == entry.id)
              item.copyWith(savedLook: savedLook)
            else
              item,
        ]),
        mutatingIds: {...state.mutatingIds}..remove(entry.id),
        feedback: savedLook.isFavorite
            ? 'Added to favorites.'
            : 'Removed from favorites.',
        sessionExpired: false,
      );
      _notifySavedLooksChanged();
    } on SavedLooksFailure catch (failure) {
      if (!mounted) return;
      state = _state(
        mutatingIds: {...state.mutatingIds}..remove(entry.id),
        feedback: failure.message,
        feedbackIsError: true,
        sessionExpired: failure.sessionExpired,
      );
    } on TimeoutException {
      if (!mounted) return;
      state = _state(
        mutatingIds: {...state.mutatingIds}..remove(entry.id),
        feedback: 'Updating the favorite took too long. Check your connection.',
        feedbackIsError: true,
        sessionExpired: false,
      );
    } catch (_) {
      if (!mounted) return;
      state = _state(
        mutatingIds: {...state.mutatingIds}..remove(entry.id),
        feedback: 'The favorite could not be updated right now.',
        feedbackIsError: true,
        sessionExpired: false,
      );
    }
  }

  Future<bool> delete(HistoryEntry entry) async {
    if (state.mutatingIds.contains(entry.id)) return false;
    state = _state(mutatingIds: {...state.mutatingIds, entry.id});
    try {
      await _repository.deleteSession(entry.id);
      if (!mounted) return false;
      state = _state(
        status: HistoryLoadStatus.ready,
        items: List.unmodifiable(
          state.items.where((item) => item.id != entry.id),
        ),
        mutatingIds: {...state.mutatingIds}..remove(entry.id),
        feedback: 'History session deleted.',
        sessionExpired: false,
      );
      _notifySavedLooksChanged();
      return true;
    } on HistoryFailure catch (failure) {
      if (!mounted) return false;
      state = _state(
        mutatingIds: {...state.mutatingIds}..remove(entry.id),
        feedback: failure.message,
        feedbackIsError: true,
        sessionExpired: failure.sessionExpired,
      );
      return false;
    } catch (_) {
      if (!mounted) return false;
      state = _state(
        mutatingIds: {...state.mutatingIds}..remove(entry.id),
        feedback: 'This history session could not be deleted right now.',
        feedbackIsError: true,
        sessionExpired: false,
      );
      return false;
    }
  }

  void clearFeedback() => state = _state();

  HistoryState _state({
    HistoryLoadStatus? status,
    List<HistoryEntry>? items,
    HistoryFilter? filter,
    String? query,
    bool? hasMore,
    int? nextOffset,
    Set<String>? mutatingIds,
    String? message,
    String? feedback,
    bool feedbackIsError = false,
    bool? sessionExpired,
  }) => HistoryState(
    status: status ?? state.status,
    items: items ?? state.items,
    filter: filter ?? state.filter,
    query: query ?? state.query,
    hasMore: hasMore ?? state.hasMore,
    nextOffset: nextOffset ?? state.nextOffset,
    mutatingIds: Set.unmodifiable(mutatingIds ?? state.mutatingIds),
    message: message,
    feedback: feedback,
    feedbackIsError: feedbackIsError,
    sessionExpired: sessionExpired ?? state.sessionExpired,
  );
}
