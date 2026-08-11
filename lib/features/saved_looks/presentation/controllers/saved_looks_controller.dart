import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/saved_looks_providers.dart';
import '../../domain/entities/saved_look.dart';
import '../../domain/errors/saved_looks_failure.dart';
import '../../domain/repositories/saved_looks_repository.dart';
import 'saved_looks_state.dart';

final savedLooksControllerProvider =
    StateNotifierProvider<SavedLooksController, SavedLooksState>((ref) {
      ref.watch(savedLooksRevisionProvider);
      final controller = SavedLooksController(
        ref.watch(savedLooksRepositoryProvider),
      );
      controller.loadInitial();
      return controller;
    });

class SavedLooksController extends StateNotifier<SavedLooksState> {
  SavedLooksController(this._repository) : super(const SavedLooksState());

  static const pageSize = 12;
  final SavedLooksRepository _repository;

  Future<void> loadInitial() async {
    state = const SavedLooksState();
    await _load(offset: 0, append: false);
  }

  Future<void> refresh() => loadInitial();

  Future<void> loadMore() async {
    if (!state.hasMore || state.status == SavedLooksStatus.loadingMore) return;
    state = SavedLooksState(
      status: SavedLooksStatus.loadingMore,
      items: state.items,
      hasMore: state.hasMore,
    );
    await _load(offset: state.items.length, append: true);
  }

  Future<void> _load({required int offset, required bool append}) async {
    try {
      final result = await _repository.loadPage(
        offset: offset,
        limit: pageSize,
      );
      if (!mounted) return;
      state = SavedLooksState(
        status: SavedLooksStatus.ready,
        items: List.unmodifiable([if (append) ...state.items, ...result.items]),
        hasMore: result.hasMore,
      );
    } on SavedLooksFailure catch (failure) {
      if (!mounted) return;
      state = SavedLooksState(
        status: SavedLooksStatus.failure,
        items: append ? state.items : const [],
        hasMore: append && state.hasMore,
        message: failure.message,
      );
    }
  }

  Future<void> toggleFavorite(SavedLook look) async {
    try {
      final updated = await _repository.setFavorite(look, !look.isFavorite);
      if (!mounted) return;
      state = SavedLooksState(
        status: SavedLooksStatus.ready,
        items: List.unmodifiable([
          for (final item in state.items)
            if (item.id == look.id) updated else item,
        ]),
        hasMore: state.hasMore,
      );
    } on SavedLooksFailure catch (failure) {
      if (mounted) {
        state = SavedLooksState(
          status: SavedLooksStatus.failure,
          items: state.items,
          hasMore: state.hasMore,
          message: failure.message,
        );
      }
    }
  }

  Future<void> remove(SavedLook look) async {
    try {
      await _repository.remove(look.id);
      if (!mounted) return;
      state = SavedLooksState(
        status: SavedLooksStatus.ready,
        items: List.unmodifiable(
          state.items.where((item) => item.id != look.id),
        ),
        hasMore: state.hasMore,
      );
    } on SavedLooksFailure catch (failure) {
      if (mounted) {
        state = SavedLooksState(
          status: SavedLooksStatus.failure,
          items: state.items,
          hasMore: state.hasMore,
          message: failure.message,
        );
      }
    }
  }
}
