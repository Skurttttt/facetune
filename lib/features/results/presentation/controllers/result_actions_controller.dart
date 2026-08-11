import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../preview/domain/entities/generated_preview.dart';
import '../../data/providers/result_providers.dart';
import '../../domain/services/result_share_service.dart';
import 'result_actions_state.dart';

final resultActionsControllerProvider =
    StateNotifierProvider<ResultActionsController, ResultActionsState>(
      (ref) => ResultActionsController(ref.watch(resultShareServiceProvider)),
    );

class ResultActionsController extends StateNotifier<ResultActionsState> {
  ResultActionsController(this._shareService)
    : super(const ResultActionsState());

  final ResultShareService _shareService;

  void toggleSaved(String previewId) {
    final saved = {...state.savedPreviewIds};
    final favorites = {...state.favoritePreviewIds};
    final nowSaved = !saved.remove(previewId);
    if (nowSaved) {
      saved.add(previewId);
    } else {
      favorites.remove(previewId);
    }
    state = ResultActionsState(
      savedPreviewIds: Set.unmodifiable(saved),
      favoritePreviewIds: Set.unmodifiable(favorites),
      feedback: nowSaved
          ? 'Saved for this session.'
          : 'Removed from this session.',
    );
  }

  void toggleFavorite(String previewId) {
    final saved = {...state.savedPreviewIds}..add(previewId);
    final favorites = {...state.favoritePreviewIds};
    final nowFavorite = !favorites.remove(previewId);
    if (nowFavorite) favorites.add(previewId);
    state = ResultActionsState(
      savedPreviewIds: Set.unmodifiable(saved),
      favoritePreviewIds: Set.unmodifiable(favorites),
      feedback: nowFavorite
          ? 'Added to favorites for this session.'
          : 'Removed from favorites.',
    );
  }

  Future<void> share({
    required GeneratedPreview preview,
    required String styleName,
  }) async {
    if (state.isSharing) return;
    state = ResultActionsState(
      savedPreviewIds: state.savedPreviewIds,
      favoritePreviewIds: state.favoritePreviewIds,
      isSharing: true,
    );
    try {
      await _shareService.share(preview: preview, styleName: styleName);
      if (mounted) {
        state = ResultActionsState(
          savedPreviewIds: state.savedPreviewIds,
          favoritePreviewIds: state.favoritePreviewIds,
          feedback: 'Share sheet opened.',
        );
      }
    } on ResultShareFailure catch (failure) {
      if (mounted) {
        state = ResultActionsState(
          savedPreviewIds: state.savedPreviewIds,
          favoritePreviewIds: state.favoritePreviewIds,
          feedback: failure.message,
          isError: true,
        );
      }
    }
  }

  void clearFeedback() {
    state = ResultActionsState(
      savedPreviewIds: state.savedPreviewIds,
      favoritePreviewIds: state.favoritePreviewIds,
      isSharing: state.isSharing,
    );
  }
}
