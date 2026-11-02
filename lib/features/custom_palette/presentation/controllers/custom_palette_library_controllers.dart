import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../results/data/providers/result_providers.dart';
import '../../../results/domain/services/result_share_service.dart';
import '../../data/custom_palette_providers.dart';
import '../../domain/entities/custom_palette_look.dart';
import '../../domain/repositories/custom_palette_gateway.dart';

enum CustomPaletteLibraryStatus { loading, ready, loadingMore, failure }

class CustomPaletteLibraryState<T> {
  const CustomPaletteLibraryState({
    this.status = CustomPaletteLibraryStatus.loading,
    this.items = const [],
    this.hasMore = false,
    this.message,
    this.sessionExpired = false,
    this.mutatingIds = const {},
  });

  final CustomPaletteLibraryStatus status;
  final List<T> items;
  final bool hasMore;
  final String? message;
  final bool sessionExpired;
  final Set<String> mutatingIds;

  CustomPaletteLibraryState<T> copyWith({
    CustomPaletteLibraryStatus? status,
    List<T>? items,
    bool? hasMore,
    String? message,
    bool? sessionExpired,
    Set<String>? mutatingIds,
  }) => CustomPaletteLibraryState<T>(
    status: status ?? this.status,
    items: items ?? this.items,
    hasMore: hasMore ?? this.hasMore,
    message: message,
    sessionExpired: sessionExpired ?? false,
    mutatingIds: mutatingIds ?? this.mutatingIds,
  );
}

/// Paging, shared by History and Saved Looks.
abstract class _PagedController<T>
    extends StateNotifier<CustomPaletteLibraryState<T>> {
  _PagedController() : super(CustomPaletteLibraryState<T>());

  static const pageSize = 12;
  int _generation = 0;

  Future<CustomPalettePage<T>> fetch(int offset);

  Future<void> loadInitial() async {
    final generation = ++_generation;
    state = CustomPaletteLibraryState<T>();
    await _load(offset: 0, append: false, generation: generation);
  }

  /// Reloads the first page without emptying the list first.
  Future<void> refresh() async {
    if (state.items.isEmpty) return loadInitial();
    final generation = ++_generation;
    await _load(offset: 0, append: false, generation: generation);
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.status != CustomPaletteLibraryStatus.ready) {
      return;
    }
    state = state.copyWith(status: CustomPaletteLibraryStatus.loadingMore);
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
      final page = await fetch(offset);
      if (!mounted || generation != _generation) return;
      state = state.copyWith(
        status: CustomPaletteLibraryStatus.ready,
        items: List.unmodifiable([if (append) ...state.items, ...page.items]),
        hasMore: page.hasMore,
      );
    } on CustomPaletteFailure catch (failure) {
      if (!mounted || generation != _generation) return;
      state = state.copyWith(
        status: CustomPaletteLibraryStatus.failure,
        message: failure.message,
        sessionExpired: failure.sessionExpired,
      );
    } catch (_) {
      if (!mounted || generation != _generation) return;
      state = state.copyWith(
        status: CustomPaletteLibraryStatus.failure,
        message: 'Your looks could not be loaded right now.',
      );
    }
  }
}

final customPaletteHistoryControllerProvider =
    StateNotifierProvider.autoDispose<
      CustomPaletteHistoryController,
      CustomPaletteLibraryState<CustomPaletteHistoryEntry>
    >((ref) {
      ref.watch(authControllerProvider.select((state) => state.user?.id));
      ref.watch(customPaletteLibraryRevisionProvider);
      final controller = CustomPaletteHistoryController(
        ref.watch(customPaletteLibraryRepositoryProvider),
      );
      unawaited(controller.loadInitial());
      return controller;
    });

class CustomPaletteHistoryController
    extends _PagedController<CustomPaletteHistoryEntry> {
  CustomPaletteHistoryController(this._repository);

  final CustomPaletteLibraryRepository _repository;

  @override
  Future<CustomPalettePage<CustomPaletteHistoryEntry>> fetch(int offset) =>
      _repository.loadHistoryPage(
        offset: offset,
        limit: _PagedController.pageSize,
      );

  /// Deletes the whole analysis session. Its charge stands.
  Future<bool> deleteSession(CustomPaletteHistoryEntry entry) async {
    final analysisId = entry.result.analysis.id;
    state = state.copyWith(
      status: state.status,
      mutatingIds: {...state.mutatingIds, analysisId},
    );
    try {
      await _repository.deleteSession(analysisId);
      if (!mounted) return true;
      state = state.copyWith(
        status: state.status,
        items: List.unmodifiable(
          state.items.where((item) => item.result.analysis.id != analysisId),
        ),
        mutatingIds: {...state.mutatingIds}..remove(analysisId),
      );
      return true;
    } catch (_) {
      if (!mounted) return false;
      state = state.copyWith(
        status: state.status,
        message: 'This history session could not be deleted.',
        mutatingIds: {...state.mutatingIds}..remove(analysisId),
      );
      return false;
    }
  }
}

final customPaletteSavedControllerProvider =
    StateNotifierProvider<
      CustomPaletteSavedController,
      CustomPaletteLibraryState<CustomPaletteSavedLook>
    >((ref) {
      ref.watch(authControllerProvider.select((state) => state.user?.id));
      ref.watch(customPaletteLibraryRevisionProvider);
      final controller = CustomPaletteSavedController(
        ref.watch(customPaletteLibraryRepositoryProvider),
      );
      unawaited(controller.loadInitial());
      return controller;
    });

class CustomPaletteSavedController
    extends _PagedController<CustomPaletteSavedLook> {
  CustomPaletteSavedController(this._repository);

  final CustomPaletteLibraryRepository _repository;

  @override
  Future<CustomPalettePage<CustomPaletteSavedLook>> fetch(int offset) =>
      _repository.loadSavedPage(
        offset: offset,
        limit: _PagedController.pageSize,
      );

  Future<void> toggleFavorite(CustomPaletteSavedLook look) async {
    state = state.copyWith(
      status: state.status,
      mutatingIds: {...state.mutatingIds, look.id},
    );
    try {
      final updated = await _repository.setFavorite(look, !look.isFavorite);
      if (!mounted) return;
      state = state.copyWith(
        status: state.status,
        items: List.unmodifiable(
          state.items.map((item) => item.id == look.id ? updated : item),
        ),
        mutatingIds: {...state.mutatingIds}..remove(look.id),
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        status: state.status,
        message: 'The favorite could not be updated right now.',
        mutatingIds: {...state.mutatingIds}..remove(look.id),
      );
    }
  }

  Future<void> remove(CustomPaletteSavedLook look) async {
    state = state.copyWith(
      status: state.status,
      mutatingIds: {...state.mutatingIds, look.id},
    );
    try {
      await _repository.removeSaved(look.id);
      if (!mounted) return;
      state = state.copyWith(
        status: state.status,
        items: List.unmodifiable(state.items.where((i) => i.id != look.id)),
        mutatingIds: {...state.mutatingIds}..remove(look.id),
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        status: state.status,
        message: 'This look could not be removed right now.',
        mutatingIds: {...state.mutatingIds}..remove(look.id),
      );
    }
  }
}

class CustomPaletteResultActionsState {
  const CustomPaletteResultActionsState({
    this.savedByPreviewId = const {},
    this.isMutating = false,
    this.isSharing = false,
    this.feedback,
    this.feedbackIsError = false,
  });

  final Map<String, CustomPaletteSavedLook> savedByPreviewId;
  final bool isMutating;
  final bool isSharing;
  final String? feedback;
  final bool feedbackIsError;

  bool isFavorite(String previewId) =>
      savedByPreviewId[previewId]?.isFavorite == true;
}

final customPaletteResultActionsControllerProvider =
    StateNotifierProvider<
      CustomPaletteResultActionsController,
      CustomPaletteResultActionsState
    >((ref) {
      ref.watch(authControllerProvider.select((state) => state.user?.id));
      return CustomPaletteResultActionsController(
        ref.watch(customPaletteLibraryRepositoryProvider),
        () => ref.read(customPaletteLibraryRevisionProvider.notifier).state++,
        shareService: ref.watch(resultShareServiceProvider),
      );
    });

class CustomPaletteResultActionsController
    extends StateNotifier<CustomPaletteResultActionsState> {
  CustomPaletteResultActionsController(
    this._repository,
    this._notifyChanged, {
    required ResultShareService shareService,
  }) : _shareService = shareService,
       super(const CustomPaletteResultActionsState());

  final CustomPaletteLibraryRepository _repository;
  final void Function() _notifyChanged;
  final ResultShareService _shareService;

  Future<void> loadSavedStatus(CustomPaletteGeneratedPreview preview) async {
    try {
      final saved = await _repository.findSaved(preview.id);
      if (!mounted || saved == null) return;
      _set(looks: {...state.savedByPreviewId, preview.id: saved});
    } catch (_) {
      // The heart stays empty. Saving still works, and is idempotent.
    }
  }

  void restoreSavedLook(CustomPaletteSavedLook look) {
    _set(looks: {...state.savedByPreviewId, look.result.preview.id: look});
  }

  Future<void> toggleFavorite(CustomPaletteGeneratedPreview preview) async {
    if (state.isMutating) return;
    _set(isMutating: true);
    try {
      final existing = state.savedByPreviewId[preview.id];
      final updated = existing == null
          ? await _repository.save(preview, favorite: true)
          : await _repository.setFavorite(existing, !existing.isFavorite);
      if (!mounted) return;
      _notifyChanged();
      _set(
        looks: {...state.savedByPreviewId, preview.id: updated},
        feedback: updated.isFavorite
            ? 'Added to favorites.'
            : 'Removed from favorites.',
      );
    } catch (_) {
      if (!mounted) return;
      _set(
        feedback: 'The favorite could not be updated right now.',
        feedbackIsError: true,
      );
    }
  }

  Future<void> share({
    required CustomPaletteGeneratedPreview preview,
    required String styleName,
  }) async {
    if (state.isSharing) return;
    _set(isSharing: true);
    try {
      await _shareService.share(
        imageUrl: preview.generatedImageUrl,
        storagePath: preview.generatedImagePath,
        previewId: preview.id,
        styleName: styleName,
      );
      if (mounted) _set();
    } catch (_) {
      if (!mounted) return;
      _set(
        feedback: 'This look could not be shared right now.',
        feedbackIsError: true,
      );
    }
  }

  void clearFeedback() => _set();

  void _set({
    Map<String, CustomPaletteSavedLook>? looks,
    bool isMutating = false,
    bool isSharing = false,
    String? feedback,
    bool feedbackIsError = false,
  }) {
    state = CustomPaletteResultActionsState(
      savedByPreviewId: looks ?? state.savedByPreviewId,
      isMutating: isMutating,
      isSharing: isSharing,
      feedback: feedback,
      feedbackIsError: feedbackIsError,
    );
  }
}
