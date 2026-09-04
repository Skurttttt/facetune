import '../../domain/entities/kit_look_result.dart';

class MakeupKitResultActionsState {
  const MakeupKitResultActionsState({
    this.savedByPreviewId = const {},
    this.loadedPreviewIds = const {},
    this.isMutating = false,
    this.isSharing = false,
    this.feedback,
    this.sessionExpired = false,
  });

  final Map<String, KitSavedLook> savedByPreviewId;
  final Set<String> loadedPreviewIds;
  final bool isMutating;

  /// A share is in flight. Kept separate from [isMutating] because sharing
  /// changes nothing about the saved look — it moves an image that already
  /// exists — so it must not disable Favorite, and Favorite must not disable it.
  final bool isSharing;

  final String? feedback;
  final bool sessionExpired;

  bool isSaved(String previewId) => savedByPreviewId.containsKey(previewId);
  bool isFavorite(String previewId) =>
      savedByPreviewId[previewId]?.isFavorite == true;
}
