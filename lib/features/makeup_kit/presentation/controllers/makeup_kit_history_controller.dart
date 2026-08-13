import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../saved_looks/data/providers/saved_looks_providers.dart';
import '../../data/providers/makeup_kit_library_providers.dart';
import '../../domain/entities/kit_look_result.dart';
import '../../domain/errors/makeup_kit_library_failure.dart';
import '../../domain/repositories/makeup_kit_library_repository.dart';
import 'makeup_kit_library_state.dart';

final makeupKitHistoryControllerProvider =
    StateNotifierProvider.autoDispose<
      MakeupKitHistoryController,
      MakeupKitHistoryState
    >((ref) {
      ref.watch(authControllerProvider.select((state) => state.user?.id));
      final controller = MakeupKitHistoryController(
        ref.watch(makeupKitLibraryRepositoryProvider),
        () {
          ref.read(makeupKitLibraryRevisionProvider.notifier).state++;
          ref.read(savedLooksRevisionProvider.notifier).state++;
        },
      );
      controller.loadInitial();
      return controller;
    });

class MakeupKitHistoryController extends StateNotifier<MakeupKitHistoryState> {
  MakeupKitHistoryController(this._repository, this._notifyChanged)
    : super(const MakeupKitHistoryState());

  static const pageSize = 12;
  static const _timeout = Duration(seconds: 30);
  final MakeupKitLibraryRepository _repository;
  final void Function() _notifyChanged;
  int _generation = 0;

  Future<void> loadInitial() async {
    final generation = ++_generation;
    state = const MakeupKitHistoryState();
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
          .loadHistoryPage(offset: offset, limit: pageSize)
          .timeout(_timeout);
      if (!mounted || generation != _generation) return;
      state = MakeupKitHistoryState(
        status: MakeupKitLibraryStatus.ready,
        items: List.unmodifiable([if (append) ...state.items, ...result.items]),
        hasMore: result.hasMore,
        mutatingIds: state.mutatingIds,
      );
    } on MakeupKitLibraryFailure catch (failure) {
      if (!mounted || generation != _generation) return;
      state = MakeupKitHistoryState(
        status: MakeupKitLibraryStatus.failure,
        items: append ? state.items : const [],
        hasMore: append && state.hasMore,
        message: failure.message,
        sessionExpired: failure.sessionExpired,
      );
    } on TimeoutException {
      if (!mounted || generation != _generation) return;
      state = MakeupKitHistoryState(
        status: MakeupKitLibraryStatus.failure,
        items: append ? state.items : const [],
        hasMore: append && state.hasMore,
        message: 'Loading My Makeup Kit history took too long.',
      );
    }
  }

  Future<bool> delete(KitHistoryEntry entry) async {
    final analysisId = entry.result.analysis.id;
    if (state.mutatingIds.contains(analysisId)) return false;
    state = _copy(mutatingIds: {...state.mutatingIds, analysisId});
    try {
      await _repository.deleteSession(analysisId).timeout(_timeout);
      if (!mounted) return false;
      _notifyChanged();
      state = _copy(
        status: MakeupKitLibraryStatus.ready,
        items: List.unmodifiable(
          state.items.where((item) => item.result.analysis.id != analysisId),
        ),
        mutatingIds: {...state.mutatingIds}..remove(analysisId),
        feedback: 'History session deleted.',
      );
      return true;
    } on MakeupKitLibraryFailure catch (failure) {
      if (!mounted) return false;
      state = _copy(
        mutatingIds: {...state.mutatingIds}..remove(analysisId),
        feedback: failure.message,
        sessionExpired: failure.sessionExpired,
      );
      return false;
    }
  }

  void clearFeedback() => state = _copy();

  MakeupKitHistoryState _copy({
    MakeupKitLibraryStatus? status,
    List<KitHistoryEntry>? items,
    bool? hasMore,
    Set<String>? mutatingIds,
    String? feedback,
    bool sessionExpired = false,
  }) => MakeupKitHistoryState(
    status: status ?? state.status,
    items: items ?? state.items,
    hasMore: hasMore ?? state.hasMore,
    mutatingIds: Set.unmodifiable(mutatingIds ?? state.mutatingIds),
    message: state.message,
    feedback: feedback,
    sessionExpired: sessionExpired,
  );
}
