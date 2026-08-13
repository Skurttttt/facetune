import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../data/providers/makeup_kit_library_providers.dart';
import '../../domain/entities/kit_generated_preview.dart';
import '../../domain/entities/kit_look_result.dart';
import '../../domain/errors/makeup_kit_library_failure.dart';
import '../../domain/repositories/makeup_kit_library_repository.dart';
import 'makeup_kit_result_actions_state.dart';

final makeupKitResultActionsControllerProvider =
    StateNotifierProvider<
      MakeupKitResultActionsController,
      MakeupKitResultActionsState
    >((ref) {
      ref.watch(authControllerProvider.select((state) => state.user?.id));
      return MakeupKitResultActionsController(
        ref.watch(makeupKitLibraryRepositoryProvider),
        () => ref.read(makeupKitLibraryRevisionProvider.notifier).state++,
      );
    });

class MakeupKitResultActionsController
    extends StateNotifier<MakeupKitResultActionsState> {
  MakeupKitResultActionsController(this._repository, this._notifyChanged)
    : super(const MakeupKitResultActionsState());

  static const _timeout = Duration(seconds: 30);
  final MakeupKitLibraryRepository _repository;
  final void Function() _notifyChanged;
  final Set<String> _loading = {};

  Future<void> loadSavedStatus(KitGeneratedPreview preview) async {
    if (state.loadedPreviewIds.contains(preview.id) ||
        !_loading.add(preview.id)) {
      return;
    }
    try {
      final saved = await _repository.findSaved(preview.id).timeout(_timeout);
      if (!mounted) return;
      final looks = {...state.savedByPreviewId};
      if (saved != null) looks[preview.id] = saved;
      state = _copy(
        savedByPreviewId: Map.unmodifiable(looks),
        loadedPreviewIds: Set.unmodifiable({
          ...state.loadedPreviewIds,
          preview.id,
        }),
      );
    } on MakeupKitLibraryFailure catch (failure) {
      _failed(failure.message, sessionExpired: failure.sessionExpired);
    } on TimeoutException {
      _failed('Saved status took too long to load.');
    } finally {
      _loading.remove(preview.id);
      if (mounted && !state.loadedPreviewIds.contains(preview.id)) {
        state = _copy(
          loadedPreviewIds: Set.unmodifiable({
            ...state.loadedPreviewIds,
            preview.id,
          }),
        );
      }
    }
  }

  Future<void> toggleSaved(KitGeneratedPreview preview) async {
    if (state.isMutating) return;
    state = _copy(isMutating: true);
    try {
      final looks = {...state.savedByPreviewId};
      final existing = looks[preview.id];
      if (existing == null) {
        looks[preview.id] = await _repository.save(preview).timeout(_timeout);
      } else {
        await _repository.removeSaved(existing.id).timeout(_timeout);
        looks.remove(preview.id);
      }
      if (!mounted) return;
      _notifyChanged();
      state = _copy(
        savedByPreviewId: Map.unmodifiable(looks),
        loadedPreviewIds: Set.unmodifiable({
          ...state.loadedPreviewIds,
          preview.id,
        }),
        isMutating: false,
        feedback: existing == null ? 'Kit look saved.' : 'Kit look removed.',
      );
    } on MakeupKitLibraryFailure catch (failure) {
      _failed(failure.message, sessionExpired: failure.sessionExpired);
    } on TimeoutException {
      _failed('Saving took too long. Check your connection.');
    }
  }

  Future<void> toggleFavorite(KitGeneratedPreview preview) async {
    if (state.isMutating) return;
    state = _copy(isMutating: true);
    try {
      final looks = {...state.savedByPreviewId};
      final existing = looks[preview.id];
      final updated = existing == null
          ? await _repository.save(preview, favorite: true).timeout(_timeout)
          : await _repository
                .setFavorite(existing, !existing.isFavorite)
                .timeout(_timeout);
      looks[preview.id] = updated;
      if (!mounted) return;
      _notifyChanged();
      state = _copy(
        savedByPreviewId: Map.unmodifiable(looks),
        loadedPreviewIds: Set.unmodifiable({
          ...state.loadedPreviewIds,
          preview.id,
        }),
        isMutating: false,
        feedback: updated.isFavorite
            ? 'Added to favorites.'
            : 'Removed from favorites.',
      );
    } on MakeupKitLibraryFailure catch (failure) {
      _failed(failure.message, sessionExpired: failure.sessionExpired);
    } on TimeoutException {
      _failed('Updating the favorite took too long.');
    }
  }

  void restoreSavedLook(KitSavedLook look) {
    state = _copy(
      savedByPreviewId: Map.unmodifiable({
        ...state.savedByPreviewId,
        look.result.preview.id: look,
      }),
      loadedPreviewIds: Set.unmodifiable({
        ...state.loadedPreviewIds,
        look.result.preview.id,
      }),
    );
  }

  void clearFeedback() => state = _copy();

  void _failed(String message, {bool sessionExpired = false}) {
    if (!mounted) return;
    state = _copy(
      isMutating: false,
      feedback: message,
      sessionExpired: sessionExpired,
    );
  }

  MakeupKitResultActionsState _copy({
    Map<String, KitSavedLook>? savedByPreviewId,
    Set<String>? loadedPreviewIds,
    bool? isMutating,
    String? feedback,
    bool sessionExpired = false,
  }) => MakeupKitResultActionsState(
    savedByPreviewId: savedByPreviewId ?? state.savedByPreviewId,
    loadedPreviewIds: loadedPreviewIds ?? state.loadedPreviewIds,
    isMutating: isMutating ?? state.isMutating,
    feedback: feedback,
    sessionExpired: sessionExpired,
  );
}
