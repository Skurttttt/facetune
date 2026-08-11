import '../../../saved_looks/domain/entities/saved_look.dart';

class ResultActionsState {
  const ResultActionsState({
    this.savedLooksByPreviewId = const {},
    this.loadedPreviewIds = const {},
    this.isMutating = false,
    this.isSharing = false,
    this.feedback,
    this.isError = false,
  });

  final Map<String, SavedLook> savedLooksByPreviewId;
  final Set<String> loadedPreviewIds;
  final bool isMutating;
  final bool isSharing;
  final String? feedback;
  final bool isError;

  bool isSaved(String previewId) =>
      savedLooksByPreviewId.containsKey(previewId);
  bool isFavorite(String previewId) =>
      savedLooksByPreviewId[previewId]?.isFavorite ?? false;
}
