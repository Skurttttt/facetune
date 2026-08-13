import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../data/providers/makeup_kit_library_providers.dart';
import '../../domain/entities/kit_look_result.dart';
import '../../domain/errors/makeup_kit_library_failure.dart';
import '../../domain/repositories/makeup_kit_library_repository.dart';
import 'makeup_kit_library_state.dart';

final makeupKitSavedControllerProvider =
    StateNotifierProvider<MakeupKitSavedController, MakeupKitSavedState>((ref) {
      ref.watch(authControllerProvider.select((state) => state.user?.id));
      ref.watch(makeupKitLibraryRevisionProvider);
      final controller = MakeupKitSavedController(
        ref.watch(makeupKitLibraryRepositoryProvider),
      );
      controller.loadInitial();
      return controller;
    });

class MakeupKitSavedController extends StateNotifier<MakeupKitSavedState> {
  MakeupKitSavedController(
    this._repository, {
    Duration timeout = const Duration(seconds: 30),
  }) : _timeout = timeout,
       super(const MakeupKitSavedState());

  static const pageSize = 12;
  final MakeupKitLibraryRepository _repository;
  final Duration _timeout;
  int _generation = 0;

  Future<void> loadInitial() async {
    final generation = ++_generation;
    state = const MakeupKitSavedState();
    await _load(offset: 0, append: false, generation: generation);
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.status != MakeupKitLibraryStatus.ready) return;
    state = _copy(status: MakeupKitLibraryStatus.loadingMore);
    await _load(
      offset: state.items.length,
      append: true,
      generation: _generation,
    );
  }

  Future<void> _load({
    required int offset,
    required bool append,
    required int generation,
  }) async {
    try {
      final result = await _repository
          .loadSavedPage(offset: offset, limit: pageSize)
          .timeout(_timeout);
      if (!mounted || generation != _generation) return;
      state = MakeupKitSavedState(
        status: MakeupKitLibraryStatus.ready,
        items: List.unmodifiable([if (append) ...state.items, ...result.items]),
        hasMore: result.hasMore,
        mutatingIds: state.mutatingIds,
      );
    } on MakeupKitLibraryFailure catch (failure) {
      if (!mounted || generation != _generation) return;
      state = MakeupKitSavedState(
        status: MakeupKitLibraryStatus.failure,
        items: append ? state.items : const [],
        hasMore: append && state.hasMore,
        message: failure.message,
        sessionExpired: failure.sessionExpired,
      );
    } on TimeoutException {
      if (!mounted || generation != _generation) return;
      state = MakeupKitSavedState(
        status: MakeupKitLibraryStatus.failure,
        items: append ? state.items : const [],
        hasMore: append && state.hasMore,
        message: 'Loading My Makeup Kit looks took too long.',
      );
    } catch (_) {
      if (!mounted || generation != _generation) return;
      state = MakeupKitSavedState(
        status: MakeupKitLibraryStatus.failure,
        items: append ? state.items : const [],
        hasMore: append && state.hasMore,
        message: 'My Makeup Kit looks could not be loaded right now.',
      );
    }
  }

  Future<void> toggleFavorite(KitSavedLook look) async {
    if (state.mutatingIds.contains(look.id)) return;
    state = _copy(mutatingIds: {...state.mutatingIds, look.id});
    try {
      final updated = await _repository
          .setFavorite(look, !look.isFavorite)
          .timeout(_timeout);
      if (!mounted) return;
      state = _copy(
        status: MakeupKitLibraryStatus.ready,
        items: List.unmodifiable([
          for (final item in state.items)
            if (item.id == look.id) updated else item,
        ]),
        mutatingIds: {...state.mutatingIds}..remove(look.id),
        feedback: updated.isFavorite
            ? 'Added to favorites.'
            : 'Removed from favorites.',
      );
    } on MakeupKitLibraryFailure catch (failure) {
      _mutationFailed(look.id, failure);
    } on TimeoutException {
      _mutationFailed(
        look.id,
        const MakeupKitLibraryFailure(
          'Updating the favorite took too long. Check your connection.',
        ),
      );
    } catch (_) {
      _mutationFailed(
        look.id,
        const MakeupKitLibraryFailure(
          'The favorite could not be updated right now.',
        ),
      );
    }
  }

  Future<void> remove(KitSavedLook look) async {
    if (state.mutatingIds.contains(look.id)) return;
    state = _copy(mutatingIds: {...state.mutatingIds, look.id});
    try {
      await _repository.removeSaved(look.id).timeout(_timeout);
      if (!mounted) return;
      state = _copy(
        status: MakeupKitLibraryStatus.ready,
        items: List.unmodifiable(
          state.items.where((item) => item.id != look.id),
        ),
        mutatingIds: {...state.mutatingIds}..remove(look.id),
        feedback: 'Kit look removed.',
      );
    } on MakeupKitLibraryFailure catch (failure) {
      _mutationFailed(look.id, failure);
    } on TimeoutException {
      _mutationFailed(
        look.id,
        const MakeupKitLibraryFailure(
          'Removing the kit look took too long. Check your connection.',
        ),
      );
    } catch (_) {
      _mutationFailed(
        look.id,
        const MakeupKitLibraryFailure(
          'The kit look could not be removed right now.',
        ),
      );
    }
  }

  void clearFeedback() => state = _copy();

  void _mutationFailed(String id, MakeupKitLibraryFailure failure) {
    if (!mounted) return;
    state = _copy(
      mutatingIds: {...state.mutatingIds}..remove(id),
      feedback: failure.message,
      sessionExpired: failure.sessionExpired,
    );
  }

  MakeupKitSavedState _copy({
    MakeupKitLibraryStatus? status,
    List<KitSavedLook>? items,
    bool? hasMore,
    Set<String>? mutatingIds,
    String? feedback,
    bool sessionExpired = false,
  }) => MakeupKitSavedState(
    status: status ?? state.status,
    items: items ?? state.items,
    hasMore: hasMore ?? state.hasMore,
    mutatingIds: Set.unmodifiable(mutatingIds ?? state.mutatingIds),
    message: state.message,
    feedback: feedback,
    sessionExpired: sessionExpired,
  );
}
