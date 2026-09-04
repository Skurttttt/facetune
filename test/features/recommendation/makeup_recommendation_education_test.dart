import 'package:facetune/features/recommendation/data/models/makeup_recommendation_dto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/recommendation_response_fixture.dart';

/// Rebuilds the fixture with one plan item replaced.
Map<String, Object?> _withBlush(
  Map<String, Object?> source,
  Object? blush, {
  bool removeKey = false,
}) {
  final response = Map<String, Object?>.from(source);
  final recommendation = Map<String, Object?>.from(
    response['recommendation']! as Map,
  );
  final plan = Map<String, Object?>.from(recommendation['plan']! as Map);
  if (removeKey) {
    plan['blush'] = Map<String, Object?>.from(educatedRecommendationItem)
      ..remove('education');
  } else {
    plan['blush'] = blush;
  }
  recommendation['plan'] = plan;
  response['recommendation'] = recommendation;
  return response;
}

void main() {
  group('typed education', () {
    test('is representable on every category of a v3 plan', () {
      final result = MakeupRecommendationDto.fromResponse(
        educatedRecommendationResponse,
      ).recommendation;

      expect(result.promptVersion, 'makeup_recommendation_v3');
      expect(result.items.length, 10);
      for (final entry in result.items.entries) {
        expect(
          entry.value.hasEducation,
          isTrue,
          reason: '${entry.key} should carry education',
        );
      }
      final blush = result.items['blush']!.education!;
      expect(blush.features, validRecommendationEducation['features']);
      expect(blush.effect, validRecommendationEducation['effect']);
      expect(blush.style, validRecommendationEducation['style']);
    });
  });

  group('historical compatibility', () {
    test('a plan stored before education decodes without crashing', () {
      final result = MakeupRecommendationDto.fromResponse(
        legacyRecommendationResponse,
      ).recommendation;

      expect(result.items.length, 10);
      expect(result.promptVersion, 'makeup_recommendation_v1');
    });

    test('a legacy plan reports absent education rather than inventing it', () {
      final result = MakeupRecommendationDto.fromResponse(
        legacyRecommendationResponse,
      ).recommendation;

      for (final entry in result.items.entries) {
        expect(
          entry.value.education,
          isNull,
          reason: '${entry.key} must not fabricate education',
        );
        expect(entry.value.hasEducation, isFalse);
      }
    });

    test('an individual item missing education stays null', () {
      final result = MakeupRecommendationDto.fromResponse(
        _withBlush(educatedRecommendationResponse, null, removeKey: true),
      ).recommendation;

      expect(result.items['blush']?.education, isNull);
      // The neighbouring categories are untouched, so absence is per item
      // rather than collapsing the whole plan.
      expect(result.items['lipstick']?.hasEducation, isTrue);
    });
  });

  group('malformed education', () {
    test('rejects a partial education object', () {
      final partial = Map<String, Object?>.from(validRecommendationEducation)
        ..remove('style');

      expect(
        () => MakeupRecommendationDto.fromResponse(
          _withBlush(educatedRecommendationResponse, {
            ...educatedRecommendationItem,
            'education': partial,
          }),
        ),
        throwsFormatException,
      );
    });

    test('rejects a non-string education section', () {
      expect(
        () => MakeupRecommendationDto.fromResponse(
          _withBlush(educatedRecommendationResponse, {
            ...educatedRecommendationItem,
            'education': {...validRecommendationEducation, 'effect': 42},
          }),
        ),
        throwsFormatException,
      );
    });

    test('rejects an empty education section', () {
      expect(
        () => MakeupRecommendationDto.fromResponse(
          _withBlush(educatedRecommendationResponse, {
            ...educatedRecommendationItem,
            'education': {...validRecommendationEducation, 'features': '   '},
          }),
        ),
        throwsFormatException,
      );
    });

    test('rejects education that is not an object', () {
      expect(
        () => MakeupRecommendationDto.fromResponse(
          _withBlush(educatedRecommendationResponse, {
            ...educatedRecommendationItem,
            'education': 'warm peach suits you',
          }),
        ),
        throwsFormatException,
      );
    });
  });

  group('preserved recommendation data', () {
    test('placement and technique survive on an educated plan', () {
      final result = MakeupRecommendationDto.fromResponse(
        educatedRecommendationResponse,
      ).recommendation;

      for (final entry in result.items.entries) {
        expect(
          entry.value.placement,
          'Upper cheekbones',
          reason: '${entry.key} placement must be preserved',
        );
        expect(
          entry.value.technique,
          'Blend upward with a soft brush',
          reason: '${entry.key} technique must be preserved',
        );
      }
    });

    test('category, shade, finish and intensity survive', () {
      final result = MakeupRecommendationDto.fromResponse(
        educatedRecommendationResponse,
      ).recommendation;
      final blush = result.items['blush']!;

      expect(result.items.keys, contains('blush'));
      expect(blush.name, 'Warm peach');
      expect(blush.hex, '#E69A7A');
      expect(blush.finish, 'satin');
      expect(blush.intensity, 'soft');
      expect(blush.reasoning, 'Adds balanced warmth to the complexion.');
      expect(result.overallIntensity, 'soft');
    });
  });
}
