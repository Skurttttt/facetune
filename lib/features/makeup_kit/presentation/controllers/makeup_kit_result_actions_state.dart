import '../../domain/entities/kit_look_result.dart';

class MakeupKitResultActionsState {
  const MakeupKitResultActionsState({
    this.savedByPreviewId = const {},
    this.loadedPreviewIds = const {},
    this.isMutating = false,
    this.feedback,
    this.sessionExpired = false,
  });

  final Map<String, KitSavedLook> savedByPreviewId;
  final Set<String> loadedPreviewIds;
  final bool isMutating;
  final String? feedback;
  final bool sessionExpired;

  bool isSaved(String previewId) => savedByPreviewId.containsKey(previewId);
  bool isFavorite(String previewId) =>
      savedByPreviewId[previewId]?.isFavorite == true;
}
