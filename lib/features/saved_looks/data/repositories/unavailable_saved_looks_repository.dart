import '../../../preview/domain/entities/generated_preview.dart';
import '../../domain/entities/saved_look.dart';
import '../../domain/errors/saved_looks_failure.dart';
import '../../domain/repositories/saved_looks_repository.dart';

class UnavailableSavedLooksRepository implements SavedLooksRepository {
  const UnavailableSavedLooksRepository();

  Never _unavailable() => throw const SavedLooksFailure(
    'Supabase runtime configuration is unavailable.',
    retryable: false,
  );

  @override
  Future<SavedLook?> findByGeneratedImageId(String generatedImageId) async =>
      _unavailable();

  @override
  Future<SavedLooksPageResult> loadPage({
    required int offset,
    required int limit,
  }) async => _unavailable();

  @override
  Future<void> remove(String savedLookId) async => _unavailable();

  @override
  Future<SavedLook> save(
    GeneratedPreview preview, {
    bool favorite = false,
  }) async => _unavailable();

  @override
  Future<SavedLook> setFavorite(SavedLook look, bool isFavorite) async =>
      _unavailable();
}
