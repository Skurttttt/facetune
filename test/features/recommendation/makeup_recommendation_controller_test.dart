import 'dart:async';

import 'package:facetune/features/analysis/data/models/face_analysis_dto.dart';
import 'package:facetune/features/analysis/domain/entities/face_analysis.dart';
import 'package:facetune/features/makeup_styles/domain/catalog/makeup_style_catalog.dart';
import 'package:facetune/features/makeup_styles/domain/entities/makeup_style.dart';
import 'package:facetune/features/recommendation/data/models/makeup_recommendation_dto.dart';
import 'package:facetune/features/recommendation/domain/entities/makeup_recommendation.dart';
import 'package:facetune/features/recommendation/domain/repositories/makeup_recommendation_repository.dart';
import 'package:facetune/features/recommendation/domain/usecases/generate_makeup_recommendation.dart';
import 'package:facetune/features/recommendation/presentation/controllers/makeup_recommendation_controller.dart';
import 'package:facetune/features/recommendation/presentation/controllers/makeup_recommendation_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/analysis_response_fixture.dart';
import '../../helpers/recommendation_response_fixture.dart';

void main() {
  test(
    'generates and retains the recommendation for the scan session',
    () async {
      final expected = MakeupRecommendationDto.fromResponse(
        validRecommendationResponse,
      ).recommendation;
      final repository = _FakeRepository(expected);
      final controller = MakeupRecommendationController(
        GenerateMakeupRecommendation(repository),
      );
      addTearDown(controller.dispose);
      final analysis = FaceAnalysisDto.fromResponse(
        validAnalysisResponse,
      ).analysis;
      final style = MakeupStyleCatalog.styles[3];

      await controller.generate(analysis: analysis, style: style);
      await controller.generate(analysis: analysis, style: style);

      expect(controller.state.status, MakeupRecommendationStatus.success);
      expect(controller.state.recommendation?.styleCode, 'soft_glam');
      expect(repository.calls, 1);
    },
  );

  test('clear ignores a recommendation that completes late', () async {
    final completer = Completer<MakeupRecommendation>();
    final controller = MakeupRecommendationController(
      GenerateMakeupRecommendation(_PendingRepository(completer.future)),
    );
    addTearDown(controller.dispose);
    final analysis = FaceAnalysisDto.fromResponse(
      validAnalysisResponse,
    ).analysis;
    final style = MakeupStyleCatalog.styles[3];

    final operation = controller.generate(analysis: analysis, style: style);
    expect(controller.state.status, MakeupRecommendationStatus.generating);

    controller.clear();
    completer.complete(
      MakeupRecommendationDto.fromResponse(
        validRecommendationResponse,
      ).recommendation,
    );
    await operation;

    expect(controller.state.status, MakeupRecommendationStatus.idle);
    expect(controller.state.recommendation, isNull);
  });

  test('unexpected errors leave a friendly retryable state', () async {
    final controller = MakeupRecommendationController(
      GenerateMakeupRecommendation(_UnexpectedRepository()),
    );
    addTearDown(controller.dispose);

    await controller.generate(
      analysis: FaceAnalysisDto.fromResponse(validAnalysisResponse).analysis,
      style: MakeupStyleCatalog.styles[3],
    );

    expect(controller.state.status, MakeupRecommendationStatus.failure);
    expect(controller.state.retryable, isTrue);
    expect(controller.state.message, isNot(contains('StateError')));
  });
}

class _FakeRepository implements MakeupRecommendationRepository {
  _FakeRepository(this.result);

  final MakeupRecommendation result;
  int calls = 0;

  @override
  Future<MakeupRecommendation> generate({
    required FaceAnalysis analysis,
    required MakeupStyle style,
  }) async {
    calls += 1;
    return result;
  }
}

class _PendingRepository implements MakeupRecommendationRepository {
  const _PendingRepository(this.result);

  final Future<MakeupRecommendation> result;

  @override
  Future<MakeupRecommendation> generate({
    required FaceAnalysis analysis,
    required MakeupStyle style,
  }) => result;
}

class _UnexpectedRepository implements MakeupRecommendationRepository {
  @override
  Future<MakeupRecommendation> generate({
    required FaceAnalysis analysis,
    required MakeupStyle style,
  }) => Future.error(StateError('internal detail'));
}
