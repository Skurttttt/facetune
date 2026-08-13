import '../entities/kit_generated_preview.dart';
import '../entities/kit_look_result.dart';

abstract interface class MakeupKitLibraryRepository {
  Future<KitSavedLook?> findSaved(String kitGeneratedImageId);

  Future<KitSavedLook> save(
    KitGeneratedPreview preview, {
    bool favorite = false,
  });

  Future<KitSavedLook> setFavorite(KitSavedLook look, bool isFavorite);

  Future<void> removeSaved(String savedLookId);

  Future<KitSavedLooksPageResult> loadSavedPage({
    required int offset,
    required int limit,
  });

  Future<KitHistoryPageResult> loadHistoryPage({
    required int offset,
    required int limit,
  });

  Future<void> deleteSession(String analysisId);
}
