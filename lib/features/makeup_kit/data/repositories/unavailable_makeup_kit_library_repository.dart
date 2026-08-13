import '../../domain/entities/kit_generated_preview.dart';
import '../../domain/entities/kit_look_result.dart';
import '../../domain/errors/makeup_kit_library_failure.dart';
import '../../domain/repositories/makeup_kit_library_repository.dart';

class UnavailableMakeupKitLibraryRepository
    implements MakeupKitLibraryRepository {
  const UnavailableMakeupKitLibraryRepository();

  Never _unavailable() => throw const MakeupKitLibraryFailure(
    'My Makeup Kit result history is not configured in this build.',
    retryable: false,
  );

  @override
  Future<void> deleteSession(String analysisId) async => _unavailable();

  @override
  Future<KitSavedLook?> findSaved(String kitGeneratedImageId) async =>
      _unavailable();

  @override
  Future<KitHistoryPageResult> loadHistoryPage({
    required int offset,
    required int limit,
  }) async => _unavailable();

  @override
  Future<KitSavedLooksPageResult> loadSavedPage({
    required int offset,
    required int limit,
  }) async => _unavailable();

  @override
  Future<void> removeSaved(String savedLookId) async => _unavailable();

  @override
  Future<KitSavedLook> save(
    KitGeneratedPreview preview, {
    bool favorite = false,
  }) async => _unavailable();

  @override
  Future<KitSavedLook> setFavorite(KitSavedLook look, bool isFavorite) async =>
      _unavailable();
}
