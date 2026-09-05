import 'package:facetune/features/makeup_kit/domain/entities/kit_generated_preview.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_look_result.dart';
import 'package:facetune/features/makeup_kit/domain/repositories/makeup_kit_library_repository.dart';
import 'package:facetune/features/preview/domain/entities/generated_preview.dart';
import 'package:facetune/features/saved_looks/domain/entities/saved_look.dart';
import 'package:facetune/features/saved_looks/domain/repositories/saved_looks_repository.dart';

/// Library repositories that succeed and return nothing.
///
/// The `Unavailable*` repositories the QA matrix used before these land every
/// page in its failure state, which is a legitimate state to render but not the
/// one whose layout most needs checking. A page whose load *succeeded* and came
/// back empty still draws its header, its subtitle and its empty state — so
/// these are what let the matrix see a top-level screen's real chrome.
class FakeSavedLooksRepository implements SavedLooksRepository {
  FakeSavedLooksRepository({this.items = const []});

  final List<SavedLook> items;
  int loadCount = 0;

  @override
  Future<SavedLooksPageResult> loadPage({
    required int offset,
    required int limit,
  }) async {
    loadCount += 1;
    return SavedLooksPageResult(
      items: offset >= items.length ? const [] : items,
      hasMore: false,
    );
  }

  @override
  Future<SavedLook?> findByGeneratedImageId(String generatedImageId) async =>
      null;

  @override
  Future<SavedLook> save(GeneratedPreview preview, {bool favorite = false}) =>
      throw UnimplementedError('QA matrix never saves');

  @override
  Future<void> remove(String savedLookId) async {}

  @override
  Future<SavedLook> setFavorite(SavedLook look, bool isFavorite) =>
      throw UnimplementedError('QA matrix never mutates');
}

class FakeMakeupKitLibraryRepository implements MakeupKitLibraryRepository {
  FakeMakeupKitLibraryRepository({
    this.saved = const [],
    this.history = const [],
  });

  final List<KitSavedLook> saved;
  final List<KitHistoryEntry> history;

  @override
  Future<KitSavedLooksPageResult> loadSavedPage({
    required int offset,
    required int limit,
  }) async => KitSavedLooksPageResult(
    items: offset >= saved.length ? const [] : saved,
    hasMore: false,
  );

  @override
  Future<KitHistoryPageResult> loadHistoryPage({
    required int offset,
    required int limit,
  }) async => KitHistoryPageResult(
    items: offset >= history.length ? const [] : history,
    hasMore: false,
  );

  @override
  Future<KitSavedLook?> findSaved(String kitGeneratedImageId) async => null;

  @override
  Future<KitSavedLook> save(
    KitGeneratedPreview preview, {
    bool favorite = false,
  }) => throw UnimplementedError('QA matrix never saves');

  @override
  Future<KitSavedLook> setFavorite(KitSavedLook look, bool isFavorite) =>
      throw UnimplementedError('QA matrix never mutates');

  @override
  Future<void> removeSaved(String savedLookId) async {}

  @override
  Future<void> deleteSession(String analysisId) async {}
}
