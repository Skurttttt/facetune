import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../data/providers/makeup_kit_library_providers.dart';
import '../../domain/entities/kit_generated_preview.dart';
import '../../domain/entities/kit_look_result.dart';
import '../../domain/errors/makeup_kit_library_failure.dart';
import '../../domain/repositories/makeup_kit_library_repository.dart';
import '../../../results/data/providers/result_providers.dart';
import '../../../results/domain/services/result_share_service.dart';
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
        // The app's one share authority, the same instance Standard uses. Kit
        // mode reuses that operation rather than owning a second copy of it.
        shareService: ref.watch(resultShareServiceProvider),
      );
    });

class MakeupKitResultActionsController
    extends StateNotifier<MakeupKitResultActionsState> {
  MakeupKitResultActionsController(
    this._repository,
    this._notifyChanged, {
    required ResultShareService shareService,
    Duration timeout = const Duration(seconds: 30),
  }) : _shareService = shareService,
       _timeout = timeout,
       super(const MakeupKitResultActionsState());

  final MakeupKitLibraryRepository _repository;
  final void Function() _notifyChanged;
  final ResultShareService _shareService;
  final Duration _timeout;
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
    } catch (_) {
      _failed('Saved status could not be loaded right now.');
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
    } catch (_) {
      _failed('The kit look could not be saved right now.');
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
    } catch (_) {
      _failed('The favorite could not be updated right now.');
    }
  }

  /// Shares the kit look's already-generated canonical preview.
  ///
  /// A read-only operation on a result that already exists: it hands the
  /// preview's signed URL to the shared share service, which downloads that one
  /// object and opens the system sheet. Nothing here consults the product
  /// library, the immutable snapshot, the manifest or any generator, so a share
  /// can neither re-run nor re-decide the look it is sharing.
  ///
  /// Mirrors [ResultActionsController.share] deliberately — same guard, same
  /// states, same messages — because a user should not be able to tell which
  /// mode they are in from how sharing behaves.
  Future<void> share({
    required KitGeneratedPreview preview,
    required String styleName,
  }) async {
    if (state.isSharing) return;
    state = _copy(isSharing: true);
    try {
      await _shareService.share(
        imageUrl: preview.generatedImageUrl,
        storagePath: preview.generatedImagePath,
        previewId: preview.id,
        styleName: styleName,
      );
      if (mounted) {
        state = _copy(isSharing: false, feedback: 'Share sheet opened.');
      }
    } on ResultShareFailure catch (failure) {
      if (mounted) {
        state = _copy(isSharing: false, feedback: failure.message);
      }
    } catch (_) {
      if (mounted) {
        state = _copy(
          isSharing: false,
          feedback: 'Sharing is unavailable right now. Please try again.',
        );
      }
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
    bool? isSharing,
    String? feedback,
    bool sessionExpired = false,
  }) => MakeupKitResultActionsState(
    savedByPreviewId: savedByPreviewId ?? state.savedByPreviewId,
    loadedPreviewIds: loadedPreviewIds ?? state.loadedPreviewIds,
    isMutating: isMutating ?? state.isMutating,
    isSharing: isSharing ?? state.isSharing,
    feedback: feedback,
    sessionExpired: sessionExpired,
  );
}
