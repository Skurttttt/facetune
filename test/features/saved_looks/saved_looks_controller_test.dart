import 'dart:async';

import 'package:facetune/features/analysis/data/models/face_analysis_dto.dart';
import 'package:facetune/features/makeup_styles/domain/catalog/makeup_style_catalog.dart';
import 'package:facetune/features/preview/data/models/generated_preview_dto.dart';
import 'package:facetune/features/preview/domain/entities/generated_preview.dart';
import 'package:facetune/features/recommendation/data/models/makeup_recommendation_dto.dart';
import 'package:facetune/features/saved_looks/domain/entities/saved_look.dart';
import 'package:facetune/features/saved_looks/domain/repositories/saved_looks_repository.dart';
import 'package:facetune/features/saved_looks/presentation/controllers/saved_looks_controller.dart';
import 'package:facetune/features/saved_looks/presentation/controllers/saved_looks_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/analysis_response_fixture.dart';
import '../../helpers/generated_preview_response_fixture.dart';
import '../../helpers/recommendation_response_fixture.dart';

void main() {
  test('loads pages lazily and appends the next page', () async {
    final first = _look('look-1');
    final second = _look('look-2');
    final repository = _FakeRepository([
      SavedLooksPageResult(items: [first], hasMore: true),
      SavedLooksPageResult(items: [second], hasMore: false),
    ]);
    final controller = SavedLooksController(repository);
    addTearDown(controller.dispose);

    await controller.loadInitial();
    expect(controller.state.items, [first]);
    expect(controller.state.hasMore, isTrue);

    await controller.loadMore();
    expect(controller.state.items, [first, second]);
    expect(controller.state.hasMore, isFalse);
    expect(repository.offsets, [0, 1]);
  });

  test('favorite and remove mutations update the loaded collection', () async {
    final look = _look('look-1');
    final repository = _FakeRepository([
      SavedLooksPageResult(items: [look], hasMore: false),
    ]);
    final controller = SavedLooksController(repository);
    addTearDown(controller.dispose);
    await controller.loadInitial();

    await controller.toggleFavorite(look);
    expect(controller.state.items.single.isFavorite, isTrue);

    await controller.remove(controller.state.items.single);
    expect(controller.state.status, SavedLooksStatus.ready);
    expect(controller.state.items, isEmpty);
    expect(repository.removedId, look.id);
  });

  test(
    'duplicate favorite taps are ignored while the item is mutating',
    () async {
      final look = _look('look-1');
      final completer = Completer<SavedLook>();
      final repository = _PendingMutationRepository(look, completer);
      final controller = SavedLooksController(repository);
      addTearDown(controller.dispose);
      await controller.loadInitial();

      final first = controller.toggleFavorite(look);
      final second = controller.toggleFavorite(look);
      expect(repository.favoriteCalls, 1);
      expect(controller.state.mutatingIds, contains(look.id));

      completer.complete(look.copyWith(isFavorite: true));
      await Future.wait([first, second]);
      expect(controller.state.mutatingIds, isNot(contains(look.id)));
      expect(controller.state.items.single.isFavorite, isTrue);
    },
  );

  test('a stale initial load cannot overwrite a newer refresh', () async {
    final first = Completer<SavedLooksPageResult>();
    final second = Completer<SavedLooksPageResult>();
    final repository = _PendingPagesRepository([first, second]);
    final controller = SavedLooksController(repository);
    addTearDown(controller.dispose);

    final oldLoad = controller.loadInitial();
    final newLoad = controller.loadInitial();
    second.complete(
      SavedLooksPageResult(items: [_look('new')], hasMore: false),
    );
    await newLoad;
    first.complete(SavedLooksPageResult(items: [_look('old')], hasMore: false));
    await oldLoad;

    expect(controller.state.items.single.id, 'new');
  });
}

SavedLook _look(String id) {
  final preview =
      GeneratedPreviewDto.fromResponse(validGeneratedPreviewResponse).toDomain(
        originalImageUrl: 'https://signed.example/$id/original',
        generatedImageUrl: 'https://signed.example/$id/generated',
      );
  return SavedLook(
    id: id,
    preview: preview,
    analysis: FaceAnalysisDto.fromResponse(validAnalysisResponse).analysis,
    recommendation: MakeupRecommendationDto.fromResponse(
      validRecommendationResponse,
    ).recommendation,
    style: MakeupStyleCatalog.styles[3],
    isFavorite: false,
    createdAt: DateTime.utc(2026, 8, 11),
  );
}

class _FakeRepository implements SavedLooksRepository {
  _FakeRepository(this.pages);

  final List<SavedLooksPageResult> pages;
  final List<int> offsets = [];
  String? removedId;

  @override
  Future<SavedLooksPageResult> loadPage({
    required int offset,
    required int limit,
  }) async {
    offsets.add(offset);
    return pages.removeAt(0);
  }

  @override
  Future<SavedLook> setFavorite(SavedLook look, bool favorite) async =>
      look.copyWith(isFavorite: favorite);

  @override
  Future<void> remove(String savedLookId) async {
    removedId = savedLookId;
  }

  @override
  Future<SavedLook?> findByGeneratedImageId(String generatedImageId) async =>
      null;

  @override
  Future<SavedLook> save(GeneratedPreview preview, {bool favorite = false}) =>
      throw UnimplementedError();
}

class _PendingMutationRepository implements SavedLooksRepository {
  _PendingMutationRepository(this.look, this.favoriteCompleter);

  final SavedLook look;
  final Completer<SavedLook> favoriteCompleter;
  int favoriteCalls = 0;

  @override
  Future<SavedLooksPageResult> loadPage({
    required int offset,
    required int limit,
  }) async => SavedLooksPageResult(items: [look], hasMore: false);

  @override
  Future<SavedLook> setFavorite(SavedLook look, bool favorite) {
    favoriteCalls += 1;
    return favoriteCompleter.future;
  }

  @override
  Future<void> remove(String savedLookId) async {}

  @override
  Future<SavedLook?> findByGeneratedImageId(String generatedImageId) async =>
      null;

  @override
  Future<SavedLook> save(GeneratedPreview preview, {bool favorite = false}) =>
      throw UnimplementedError();
}

class _PendingPagesRepository implements SavedLooksRepository {
  _PendingPagesRepository(this.pages);

  final List<Completer<SavedLooksPageResult>> pages;
  int call = 0;

  @override
  Future<SavedLooksPageResult> loadPage({
    required int offset,
    required int limit,
  }) => pages[call++].future;

  @override
  Future<SavedLook?> findByGeneratedImageId(String generatedImageId) async =>
      null;

  @override
  Future<void> remove(String savedLookId) async {}

  @override
  Future<SavedLook> save(GeneratedPreview preview, {bool favorite = false}) =>
      throw UnimplementedError();

  @override
  Future<SavedLook> setFavorite(SavedLook look, bool isFavorite) async =>
      look.copyWith(isFavorite: isFavorite);
}
