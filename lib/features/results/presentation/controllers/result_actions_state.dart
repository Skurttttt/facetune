import '../../../saved_looks/domain/entities/saved_look.dart';

class ResultActionsState {
  const ResultActionsState({
    this.savedLooksByPreviewId = const {},
    this.loadedPreviewIds = const {},
    this.failedPreviewIds = const {},
    this.isMutating = false,
    this.isSharing = false,
    this.feedback,
    this.isError = false,
    this.sessionExpired = false,
  });

  final Map<String, SavedLook> savedLooksByPreviewId;
  final Set<String> loadedPreviewIds;
  final Set<String> failedPreviewIds;
  final bool isMutating;
  final bool isSharing;
  final String? feedback;
  final bool isError;
  final bool sessionExpired;

  bool isSaved(String previewId) =>
      savedLooksByPreviewId.containsKey(previewId);
  bool isFavorite(String previewId) =>
      savedLooksByPreviewId[previewId]?.isFavorite ?? false;
}
