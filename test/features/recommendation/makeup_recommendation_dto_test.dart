import 'package:facetune/features/recommendation/data/models/makeup_recommendation_dto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/recommendation_response_fixture.dart';

void main() {
  test('parses a complete display-ready recommendation', () {
    final result = MakeupRecommendationDto.fromResponse(
      validRecommendationResponse,
    ).recommendation;

    expect(result.styleCode, 'soft_glam');
    expect(result.items.length, 10);
    expect(result.items['blush']?.hex, '#E69A7A');
    expect(result.promptVersion, 'makeup_recommendation_v1');
  });

  test('rejects malformed color values', () {
    final response = Map<String, Object?>.from(validRecommendationResponse);
    final recommendation = Map<String, Object?>.from(
      response['recommendation']! as Map,
    );
    final plan = Map<String, Object?>.from(recommendation['plan']! as Map);
    plan['blush'] = {...validRecommendationItem, 'hex': 'warm peach'};
    recommendation['plan'] = plan;
    response['recommendation'] = recommendation;

    expect(
      () => MakeupRecommendationDto.fromResponse(response),
      throwsFormatException,
    );
  });
}
