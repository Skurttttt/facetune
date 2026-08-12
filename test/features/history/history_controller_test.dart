import 'package:facetune/features/analysis/data/models/face_analysis_dto.dart';
import 'package:facetune/features/history/domain/entities/history_entry.dart';
import 'package:facetune/features/history/domain/errors/history_failure.dart';
import 'package:facetune/features/history/domain/repositories/history_repository.dart';
import 'package:facetune/features/history/presentation/controllers/history_controller.dart';
import 'package:facetune/features/history/presentation/controllers/history_state.dart';
import 'package:facetune/features/makeup_styles/domain/catalog/makeup_style_catalog.dart';
import 'package:facetune/features/preview/data/models/generated_preview_dto.dart';
import 'package:facetune/features/preview/domain/entities/generated_preview.dart';
import 'package:facetune/features/recommendation/data/models/makeup_recommendation_dto.dart';
import 'package:facetune/features/saved_looks/domain/entities/saved_look.dart';
import 'package:facetune/features/saved_looks/domain/repositories/saved_looks_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/analysis_response_fixture.dart';
import '../../helpers/generated_preview_response_fixture.dart';
import '../../helpers/recommendation_response_fixture.dart';

void main() {
  test(
    'favorite filter loads later pages until a match is available',
    () async {
      final analysisOnly = _entry('analysis-only');
      final favorite = _entry('favorite', complete: true, favorite: true);
      final history = _FakeHistoryRepository([
        HistoryPageResult(items: [analysisOnly], hasMore: true, nextOffset: 1),
        HistoryPageResult(items: [favorite], hasMore: false, nextOffset: 2),
      ]);
      final controller = HistoryController(
        history,
        _FakeSavedLooksRepository(),
        () {},
      );
      addTearDown(controller.dispose);
      await controller.loadInitial();

      await controller.setFilter(HistoryFilter.favorites);

      expect(controller.state.visibleItems, [favorite]);
      expect(history.offsets, [0, 1]);
    },
  );

  test('favorite and deletion mutations update linked state', () async {
    final complete = _entry('complete', complete: true);
    final history = _FakeHistoryRepository([
      HistoryPageResult(items: [complete], hasMore: false, nextOffset: 1),
    ]);
    final saved = _FakeSavedLooksRepository(template: complete);
    var savedRevisions = 0;
    final controller = HistoryController(
      history,
      saved,
      () => savedRevisions++,
    );
    addTearDown(controller.dispose);
    await controller.loadInitial();

    await controller.toggleFavorite(complete);
    expect(controller.state.items.single.isFavorite, isTrue);

    final deleted = await controller.delete(controller.state.items.single);
    expect(deleted, isTrue);
    expect(controller.state.items, isEmpty);
    expect(history.deletedId, complete.id);
    expect(savedRevisions, 2);
  });

  test(
    'automatic filtered pagination stops after failure and retries once',
    () async {
      final analysisOnly = _entry('analysis-only');
      final favorite = _entry('favorite', complete: true, favorite: true);
      final history = _OutcomeHistoryRepository([
        HistoryPageResult(items: [analysisOnly], hasMore: true, nextOffset: 1),
        const HistoryFailure('Check your connection and try again.'),
        HistoryPageResult(items: [favorite], hasMore: false, nextOffset: 2),
      ]);
      final controller = HistoryController(
        history,
        _FakeSavedLooksRepository(),
        () {},
      );
      addTearDown(controller.dispose);
      await controller.loadInitial();

      await controller.setFilter(HistoryFilter.favorites);
      expect(controller.state.status, HistoryLoadStatus.failure);
      expect(history.calls, 2);

      await Future<void>.delayed(Duration.zero);
      expect(history.calls, 2);

      await controller.retryLoadMore();
      expect(history.calls, 3);
      expect(controller.state.visibleItems, [favorite]);
    },
  );
}

HistoryEntry _entry(String id, {bool complete = false, bool favorite = false}) {
  final rawAnalysis =
      validAnalysisResponse['analysis']! as Map<String, Object?>;
  final analysis = FaceAnalysisDto.fromResponse({
    'analysis': {
      ...rawAnalysis,
      'id': id,
      'originalImagePath': 'user/analyses/$id/original/image.jpg',
    },
  }).analysis;
  if (!complete) {
    return HistoryEntry(
      analysis: analysis,
      thumbnailUrl: 'https://signed.example/$id/original',
      status: HistoryCompletionStatus.analysisReady,
      createdAt: analysis.createdAt,
      latestActivityAt: analysis.createdAt,
    );
  }
  final rawRecommendation =
      validRecommendationResponse['recommendation']! as Map<String, Object?>;
  final recommendation = MakeupRecommendationDto.fromResponse({
    'recommendation': {
      ...rawRecommendation,
      'id': 'recommendation-$id',
      'analysisId': id,
    },
  }).recommendation;
  final rawPreview =
      validGeneratedPreviewResponse['preview']! as Map<String, Object?>;
  final preview =
      GeneratedPreviewDto.fromResponse({
        'preview': {
          ...rawPreview,
          'id': 'preview-$id',
          'analysisId': id,
          'recommendationId': recommendation.id,
          'originalImagePath': analysis.originalImagePath,
          'generatedImagePath': 'user/analyses/$id/generated/preview.png',
        },
      }).toDomain(
        originalImageUrl: 'https://signed.example/$id/original',
        generatedImageUrl: 'https://signed.example/$id/generated',
      );
  final style = MakeupStyleCatalog.styles[3];
  final savedLook = favorite
      ? SavedLook(
          id: 'saved-$id',
          preview: preview,
          analysis: analysis,
          recommendation: recommendation,
          style: style,
          isFavorite: true,
          createdAt: preview.createdAt,
        )
      : null;
  return HistoryEntry(
    analysis: analysis,
    recommendation: recommendation,
    style: style,
    preview: preview,
    savedLook: savedLook,
    thumbnailUrl: preview.generatedImageUrl,
    status: HistoryCompletionStatus.complete,
    createdAt: analysis.createdAt,
    latestActivityAt: preview.createdAt,
  );
}

class _FakeHistoryRepository implements HistoryRepository {
  _FakeHistoryRepository(this.pages);

  final List<HistoryPageResult> pages;
  final List<int> offsets = [];
  String? deletedId;

  @override
  Future<HistoryPageResult> loadPage({
    required int offset,
    required int limit,
  }) async {
    offsets.add(offset);
    return pages.removeAt(0);
  }

  @override
  Future<void> deleteSession(String analysisId) async {
    deletedId = analysisId;
  }
}

class _FakeSavedLooksRepository implements SavedLooksRepository {
  _FakeSavedLooksRepository({this.template});

  final HistoryEntry? template;

  @override
  Future<SavedLook> save(
    GeneratedPreview preview, {
    bool favorite = false,
  }) async {
    final entry = template!;
    return SavedLook(
      id: 'saved-${entry.id}',
      preview: preview,
      analysis: entry.analysis,
      recommendation: entry.recommendation!,
      style: entry.style!,
      isFavorite: favorite,
      createdAt: preview.createdAt,
    );
  }

  @override
  Future<SavedLook> setFavorite(SavedLook look, bool favorite) async =>
      look.copyWith(isFavorite: favorite);

  @override
  Future<SavedLook?> findByGeneratedImageId(String generatedImageId) async =>
      null;

  @override
  Future<SavedLooksPageResult> loadPage({
    required int offset,
    required int limit,
  }) async => const SavedLooksPageResult(items: [], hasMore: false);

  @override
  Future<void> remove(String savedLookId) async {}
}

class _OutcomeHistoryRepository implements HistoryRepository {
  _OutcomeHistoryRepository(this.outcomes);

  final List<Object> outcomes;
  int calls = 0;

  @override
  Future<HistoryPageResult> loadPage({
    required int offset,
    required int limit,
  }) async {
    calls += 1;
    final outcome = outcomes.removeAt(0);
    if (outcome is HistoryFailure) throw outcome;
    return outcome as HistoryPageResult;
  }

  @override
  Future<void> deleteSession(String analysisId) async {}
}
