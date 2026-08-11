class ResultActionsState {
  const ResultActionsState({
    this.savedPreviewIds = const {},
    this.favoritePreviewIds = const {},
    this.isSharing = false,
    this.feedback,
    this.isError = false,
  });

  final Set<String> savedPreviewIds;
  final Set<String> favoritePreviewIds;
  final bool isSharing;
  final String? feedback;
  final bool isError;

  bool isSaved(String previewId) => savedPreviewIds.contains(previewId);
  bool isFavorite(String previewId) => favoritePreviewIds.contains(previewId);
}
