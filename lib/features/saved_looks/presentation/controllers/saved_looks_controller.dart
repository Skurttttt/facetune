import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../data/providers/saved_looks_providers.dart';
import '../../domain/entities/saved_look.dart';
import '../../domain/errors/saved_looks_failure.dart';
import '../../domain/repositories/saved_looks_repository.dart';
import 'saved_looks_state.dart';

final savedLooksControllerProvider =
    StateNotifierProvider<SavedLooksController, SavedLooksState>((ref) {
      ref.watch(savedLooksRevisionProvider);
      ref.watch(authControllerProvider.select((state) => state.user?.id));
      final controller = SavedLooksController(
        ref.watch(savedLooksRepositoryProvider),
      );
      controller.loadInitial();
      return controller;
    });

class SavedLooksController extends StateNotifier<SavedLooksState> {
  SavedLooksController(this._repository) : super(const SavedLooksState());

  static const pageSize = 12;
  static const _operationTimeout = Duration(seconds: 30);
  final SavedLooksRepository _repository;
  int _loadGeneration = 0;

  Future<void> loadInitial() async {
    final generation = ++_loadGeneration;
    state = const SavedLooksState();
    await _load(offset: 0, append: false, generation: generation);
  }

  Future<void> refresh() => loadInitial();

  Future<void> loadMore() async {
    if (!state.hasMore || state.status != SavedLooksStatus.ready) return;
    state = SavedLooksState(
      status: SavedLooksStatus.loadingMore,
      items: state.items,
      hasMore: state.hasMore,
    );
    await _load(
      offset: state.items.length,
      append: true,
      generation: _loadGeneration,
    );
  }

  Future<void> retryLoadMore() async {
    if (state.status != SavedLooksStatus.failure || state.items.isEmpty) return;
    state = SavedLooksState(
      status: SavedLooksStatus.ready,
      items: state.items,
      hasMore: state.hasMore,
      mutatingIds: state.mutatingIds,
    );
    await loadMore();
  }

  Future<void> _load({
    required int offset,
    required bool append,
    required int generation,
  }) async {
    try {
      final result = await _repository
          .loadPage(offset: offset, limit: pageSize)
          .timeout(_operationTimeout);
      if (!mounted || generation != _loadGeneration) return;
      state = SavedLooksState(
        status: SavedLooksStatus.ready,
        items: List.unmodifiable([if (append) ...state.items, ...result.items]),
        hasMore: result.hasMore,
        mutatingIds: state.mutatingIds,
      );
    } on SavedLooksFailure catch (failure) {
      if (!mounted || generation != _loadGeneration) return;
      state = SavedLooksState(
        status: SavedLooksStatus.failure,
        items: append ? state.items : const [],
        hasMore: append && state.hasMore,
        mutatingIds: state.mutatingIds,
        message: failure.message,
        sessionExpired: failure.sessionExpired,
      );
    } on TimeoutException {
      _loadFailed(
        append: append,
        generation: generation,
        message: 'Loading saved looks took too long. Check your connection.',
      );
    } catch (_) {
      _loadFailed(
        append: append,
        generation: generation,
        message: 'Your saved looks could not be loaded right now.',
      );
    }
  }

  void _loadFailed({
    required bool append,
    required int generation,
    required String message,
  }) {
    if (!mounted || generation != _loadGeneration) return;
    state = SavedLooksState(
      status: SavedLooksStatus.failure,
      items: append ? state.items : const [],
      hasMore: append && state.hasMore,
      mutatingIds: state.mutatingIds,
      message: message,
    );
  }

  Future<void> toggleFavorite(SavedLook look) async {
    if (state.mutatingIds.contains(look.id)) return;
    state = _state(mutatingIds: {...state.mutatingIds, look.id});
    try {
      final updated = await _repository
          .setFavorite(look, !look.isFavorite)
          .timeout(_operationTimeout);
      if (!mounted) return;
      state = _state(
        status: SavedLooksStatus.ready,
        items: List.unmodifiable([
          for (final item in state.items)
            if (item.id == look.id) updated else item,
        ]),
        mutatingIds: {...state.mutatingIds}..remove(look.id),
        feedback: updated.isFavorite
            ? 'Added to favorites.'
            : 'Removed from favorites.',
        sessionExpired: false,
      );
    } on SavedLooksFailure catch (failure) {
      _mutationFailed(
        look.id,
        failure.message,
        sessionExpired: failure.sessionExpired,
      );
    } on TimeoutException {
      _mutationFailed(
        look.id,
        'Updating the favorite took too long. Check your connection.',
      );
    } catch (_) {
      _mutationFailed(look.id, 'The favorite could not be updated right now.');
    }
  }

  Future<void> remove(SavedLook look) async {
    if (state.mutatingIds.contains(look.id)) return;
    state = _state(mutatingIds: {...state.mutatingIds, look.id});
    try {
      await _repository.remove(look.id).timeout(_operationTimeout);
      if (!mounted) return;
      state = _state(
        status: SavedLooksStatus.ready,
        items: List.unmodifiable(
          state.items.where((item) => item.id != look.id),
        ),
        mutatingIds: {...state.mutatingIds}..remove(look.id),
        feedback: 'Saved look removed.',
        sessionExpired: false,
      );
    } on SavedLooksFailure catch (failure) {
      _mutationFailed(
        look.id,
        failure.message,
        sessionExpired: failure.sessionExpired,
      );
    } on TimeoutException {
      _mutationFailed(
        look.id,
        'Removing the look took too long. Check your connection.',
      );
    } catch (_) {
      _mutationFailed(
        look.id,
        'The saved look could not be removed right now.',
      );
    }
  }

  void _mutationFailed(
    String id,
    String message, {
    bool sessionExpired = false,
  }) {
    if (!mounted) return;
    state = _state(
      mutatingIds: {...state.mutatingIds}..remove(id),
      feedback: message,
      feedbackIsError: true,
      sessionExpired: sessionExpired,
    );
  }

  void clearFeedback() => state = _state();

  SavedLooksState _state({
    SavedLooksStatus? status,
    List<SavedLook>? items,
    bool? hasMore,
    Set<String>? mutatingIds,
    String? feedback,
    bool feedbackIsError = false,
    bool? sessionExpired,
  }) => SavedLooksState(
    status: status ?? state.status,
    items: items ?? state.items,
    hasMore: hasMore ?? state.hasMore,
    mutatingIds: Set.unmodifiable(mutatingIds ?? state.mutatingIds),
    message: state.message,
    feedback: feedback,
    feedbackIsError: feedbackIsError,
    sessionExpired: sessionExpired ?? state.sessionExpired,
  );
}
