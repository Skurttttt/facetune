import 'package:facetune/features/analysis/data/models/face_analysis_dto.dart';
import 'package:facetune/features/makeup_styles/domain/catalog/makeup_style_catalog.dart';
import 'package:facetune/features/preview/data/models/generated_preview_dto.dart';
import 'package:facetune/features/preview/domain/entities/generated_preview.dart';
import 'package:facetune/features/recommendation/data/models/makeup_recommendation_dto.dart';
import 'package:facetune/features/results/domain/services/result_share_service.dart';
import 'package:facetune/features/results/presentation/controllers/result_actions_controller.dart';
import 'package:facetune/features/saved_looks/domain/entities/saved_look.dart';
import 'package:facetune/features/saved_looks/domain/errors/saved_looks_failure.dart';
import 'package:facetune/features/saved_looks/domain/repositories/saved_looks_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/analysis_response_fixture.dart';
import '../../helpers/generated_preview_response_fixture.dart';
import '../../helpers/recommendation_response_fixture.dart';

void main() {
  late GeneratedPreview preview;
  late _FakeSavedLooksRepository repository;

  setUp(() {
    preview = GeneratedPreviewDto.fromResponse(validGeneratedPreviewResponse)
        .toDomain(
          originalImageUrl: 'https://signed.example/original',
          generatedImageUrl: 'https://signed.example/generated',
        );
    repository = _FakeSavedLooksRepository();
  });

  test('save and favorite mutations persist through the repository', () async {
    var revisions = 0;
    final controller = ResultActionsController(
      _FakeShareService(),
      repository,
      () => revisions++,
    );
    addTearDown(controller.dispose);

    await controller.toggleFavorite(preview);

    expect(controller.state.isSaved(preview.id), isTrue);
    expect(controller.state.isFavorite(preview.id), isTrue);

    await controller.toggleSaved(preview);

    expect(controller.state.isSaved(preview.id), isFalse);
    expect(controller.state.isFavorite(preview.id), isFalse);
    expect(revisions, 2);
  });

  test('loads an existing saved record for the generated preview', () async {
    await repository.save(preview, favorite: true);
    final controller = ResultActionsController(
      _FakeShareService(),
      repository,
      () {},
    );
    addTearDown(controller.dispose);

    await controller.loadSavedStatus(preview);

    expect(controller.state.isSaved(preview.id), isTrue);
    expect(controller.state.isFavorite(preview.id), isTrue);
  });

  test('share delegates only the generated preview and style name', () async {
    final service = _FakeShareService();
    final controller = ResultActionsController(service, repository, () {});
    addTearDown(controller.dispose);

    await controller.share(preview: preview, styleName: 'Soft Glam');

    expect(service.previewId, preview.id);
    expect(service.styleName, 'Soft Glam');
    expect(controller.state.isSharing, isFalse);
    expect(controller.state.isError, isFalse);
  });

  test('share failures return friendly action feedback', () async {
    final controller = ResultActionsController(
      _FakeShareService(shouldFail: true),
      repository,
      () {},
    );
    addTearDown(controller.dispose);

    await controller.share(preview: preview, styleName: 'Soft Glam');

    expect(controller.state.isError, isTrue);
    expect(controller.state.feedback, 'Sharing failed safely.');
  });

  test('failed saved status waits for an explicit retry', () async {
    repository.findFailuresRemaining = 1;
    final controller = ResultActionsController(
      _FakeShareService(),
      repository,
      () {},
    );
    addTearDown(controller.dispose);

    await controller.loadSavedStatus(preview);
    await controller.loadSavedStatus(preview);
    expect(repository.findCalls, 1);
    expect(controller.state.failedPreviewIds, contains(preview.id));

    await controller.retrySavedStatus(preview);
    expect(repository.findCalls, 2);
    expect(controller.state.failedPreviewIds, isNot(contains(preview.id)));
    expect(controller.state.loadedPreviewIds, contains(preview.id));
  });

  test('unexpected share failures always clear the busy flag', () async {
    final controller = ResultActionsController(
      _UnexpectedShareService(),
      repository,
      () {},
    );
    addTearDown(controller.dispose);

    await controller.share(preview: preview, styleName: 'Soft Glam');

    expect(controller.state.isSharing, isFalse);
    expect(controller.state.feedback, contains('unavailable'));
  });
}

class _FakeSavedLooksRepository implements SavedLooksRepository {
  final Map<String, SavedLook> _looks = {};
  int findCalls = 0;
  int findFailuresRemaining = 0;

  @override
  Future<SavedLook?> findByGeneratedImageId(String generatedImageId) async {
    findCalls += 1;
    if (findFailuresRemaining > 0) {
      findFailuresRemaining -= 1;
      throw const SavedLooksFailure('Check your connection and try again.');
    }
    return _looks[generatedImageId];
  }

  @override
  Future<SavedLook> save(
    GeneratedPreview preview, {
    bool favorite = false,
  }) async {
    final existing = _looks[preview.id];
    if (existing != null) return existing;
    final look = SavedLook(
      id: 'saved-${preview.id}',
      preview: preview,
      analysis: FaceAnalysisDto.fromResponse(validAnalysisResponse).analysis,
      recommendation: MakeupRecommendationDto.fromResponse(
        validRecommendationResponse,
      ).recommendation,
      style: MakeupStyleCatalog.styles.firstWhere(
        (style) => style.code == 'soft_glam',
      ),
      isFavorite: favorite,
      createdAt: DateTime.utc(2026, 8, 11),
    );
    _looks[preview.id] = look;
    return look;
  }

  @override
  Future<void> remove(String savedLookId) async {
    _looks.removeWhere((_, look) => look.id == savedLookId);
  }

  @override
  Future<SavedLook> setFavorite(SavedLook look, bool favorite) async {
    final updated = look.copyWith(isFavorite: favorite);
    _looks[look.preview.id] = updated;
    return updated;
  }

  @override
  Future<SavedLooksPageResult> loadPage({
    required int offset,
    required int limit,
  }) async => SavedLooksPageResult(
    items: _looks.values.skip(offset).take(limit).toList(),
    hasMore: false,
  );
}

class _FakeShareService implements ResultShareService {
  _FakeShareService({this.shouldFail = false});

  final bool shouldFail;
  String? previewId;
  String? styleName;

  @override
  Future<void> share({
    required GeneratedPreview preview,
    required String styleName,
  }) async {
    if (shouldFail) {
      throw const ResultShareFailure('Sharing failed safely.');
    }
    previewId = preview.id;
    this.styleName = styleName;
  }
}

class _UnexpectedShareService implements ResultShareService {
  @override
  Future<void> share({
    required GeneratedPreview preview,
    required String styleName,
  }) => Future.error(StateError('platform detail'));
}
