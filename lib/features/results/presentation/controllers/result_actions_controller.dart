import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../preview/domain/entities/generated_preview.dart';
import '../../../saved_looks/data/providers/saved_looks_providers.dart';
import '../../../saved_looks/domain/entities/saved_look.dart';
import '../../../saved_looks/domain/errors/saved_looks_failure.dart';
import '../../../saved_looks/domain/repositories/saved_looks_repository.dart';
import '../../data/providers/result_providers.dart';
import '../../domain/services/result_share_service.dart';
import 'result_actions_state.dart';

final resultActionsControllerProvider =
    StateNotifierProvider<ResultActionsController, ResultActionsState>(
      (ref) => ResultActionsController(
        ref.watch(resultShareServiceProvider),
        ref.watch(savedLooksRepositoryProvider),
        () => ref.read(savedLooksRevisionProvider.notifier).state++,
      ),
    );

class ResultActionsController extends StateNotifier<ResultActionsState> {
  ResultActionsController(
    this._shareService,
    this._savedLooksRepository,
    this._notifySavedLooksChanged,
  ) : super(const ResultActionsState());

  final ResultShareService _shareService;
  final SavedLooksRepository _savedLooksRepository;
  final void Function() _notifySavedLooksChanged;
  final Set<String> _loadingPreviewIds = <String>{};

  Future<void> loadSavedStatus(GeneratedPreview preview) async {
    if (state.loadedPreviewIds.contains(preview.id) ||
        !_loadingPreviewIds.add(preview.id)) {
      return;
    }
    try {
      final saved = await _savedLooksRepository.findByGeneratedImageId(
        preview.id,
      );
      if (!mounted) return;
      final looks = {...state.savedLooksByPreviewId};
      if (saved != null) looks[preview.id] = saved;
      state = _copy(
        savedLooksByPreviewId: Map.unmodifiable(looks),
        loadedPreviewIds: Set.unmodifiable({
          ...state.loadedPreviewIds,
          preview.id,
        }),
      );
    } on SavedLooksFailure catch (failure) {
      if (mounted) {
        state = _copy(feedback: failure.message, isError: true);
      }
    } finally {
      _loadingPreviewIds.remove(preview.id);
    }
  }

  Future<void> toggleSaved(GeneratedPreview preview) async {
    if (state.isMutating) return;
    state = _copy(isMutating: true);
    try {
      final looks = {...state.savedLooksByPreviewId};
      final existing = looks[preview.id];
      if (existing == null) {
        looks[preview.id] = await _savedLooksRepository.save(preview);
      } else {
        await _savedLooksRepository.remove(existing.id);
        looks.remove(preview.id);
      }
      if (mounted) {
        _notifySavedLooksChanged();
        state = _copy(
          savedLooksByPreviewId: Map.unmodifiable(looks),
          loadedPreviewIds: Set.unmodifiable({
            ...state.loadedPreviewIds,
            preview.id,
          }),
          isMutating: false,
          feedback: existing == null ? 'Look saved.' : 'Look removed.',
        );
      }
    } on SavedLooksFailure catch (failure) {
      if (mounted) {
        state = _copy(
          isMutating: false,
          feedback: failure.message,
          isError: true,
        );
      }
    }
  }

  Future<void> toggleFavorite(GeneratedPreview preview) async {
    if (state.isMutating) return;
    state = _copy(isMutating: true);
    try {
      final looks = {...state.savedLooksByPreviewId};
      final existing = looks[preview.id];
      final updated = existing == null
          ? await _savedLooksRepository.save(preview, favorite: true)
          : await _savedLooksRepository.setFavorite(
              existing,
              !existing.isFavorite,
            );
      looks[preview.id] = updated;
      if (mounted) {
        _notifySavedLooksChanged();
        state = _copy(
          savedLooksByPreviewId: Map.unmodifiable(looks),
          loadedPreviewIds: Set.unmodifiable({
            ...state.loadedPreviewIds,
            preview.id,
          }),
          isMutating: false,
          feedback: updated.isFavorite
              ? 'Added to favorites.'
              : 'Removed from favorites.',
        );
      }
    } on SavedLooksFailure catch (failure) {
      if (mounted) {
        state = _copy(
          isMutating: false,
          feedback: failure.message,
          isError: true,
        );
      }
    }
  }

  void restoreSavedLook(SavedLook look) {
    state = _copy(
      savedLooksByPreviewId: Map.unmodifiable({
        ...state.savedLooksByPreviewId,
        look.preview.id: look,
      }),
      loadedPreviewIds: Set.unmodifiable({
        ...state.loadedPreviewIds,
        look.preview.id,
      }),
    );
  }

  void forgetSavedLook(String generatedImageId) {
    final looks = {...state.savedLooksByPreviewId}..remove(generatedImageId);
    state = _copy(
      savedLooksByPreviewId: Map.unmodifiable(looks),
      loadedPreviewIds: Set.unmodifiable({
        ...state.loadedPreviewIds,
        generatedImageId,
      }),
    );
  }

  void forgetAnalysis(String analysisId) {
    final looks = {...state.savedLooksByPreviewId}
      ..removeWhere((_, look) => look.analysis.id == analysisId);
    state = _copy(savedLooksByPreviewId: Map.unmodifiable(looks));
  }

  Future<void> share({
    required GeneratedPreview preview,
    required String styleName,
  }) async {
    if (state.isSharing) return;
    state = _copy(isSharing: true);
    try {
      await _shareService.share(preview: preview, styleName: styleName);
      if (mounted) {
        state = _copy(isSharing: false, feedback: 'Share sheet opened.');
      }
    } on ResultShareFailure catch (failure) {
      if (mounted) {
        state = _copy(
          isSharing: false,
          feedback: failure.message,
          isError: true,
        );
      }
    }
  }

  void clearFeedback() => state = _copy();

  ResultActionsState _copy({
    Map<String, SavedLook>? savedLooksByPreviewId,
    Set<String>? loadedPreviewIds,
    bool? isMutating,
    bool? isSharing,
    String? feedback,
    bool isError = false,
  }) => ResultActionsState(
    savedLooksByPreviewId: savedLooksByPreviewId ?? state.savedLooksByPreviewId,
    loadedPreviewIds: loadedPreviewIds ?? state.loadedPreviewIds,
    isMutating: isMutating ?? state.isMutating,
    isSharing: isSharing ?? state.isSharing,
    feedback: feedback,
    isError: isError,
  );
}
