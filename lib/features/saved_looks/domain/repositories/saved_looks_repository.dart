import '../../../preview/domain/entities/generated_preview.dart';
import '../entities/saved_look.dart';

abstract interface class SavedLooksRepository {
  Future<SavedLook?> findByGeneratedImageId(String generatedImageId);

  Future<SavedLook> save(GeneratedPreview preview, {bool favorite = false});

  Future<void> remove(String savedLookId);

  Future<SavedLook> setFavorite(SavedLook look, bool isFavorite);

  Future<SavedLooksPageResult> loadPage({
    required int offset,
    required int limit,
  });
}
