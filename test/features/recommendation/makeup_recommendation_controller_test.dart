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
