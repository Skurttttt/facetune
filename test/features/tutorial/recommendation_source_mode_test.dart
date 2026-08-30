import 'package:facetune/features/makeup_kit/domain/entities/makeup_recommendation_mode.dart';
import 'package:facetune/features/tutorial/domain/entities/recommendation_source_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecommendationSourceMode', () {
    test('exposes exactly the two supported modes', () {
      expect(RecommendationSourceMode.values, hasLength(2));
      expect(
        RecommendationSourceMode.values.map((mode) => mode.code),
        containsAll(<String>['standard', 'my_makeup_kit']),
      );
    });

    test('round-trips through its stable wire code', () {
      for (final mode in RecommendationSourceMode.values) {
        expect(RecommendationSourceMode.fromCode(mode.code), mode);
      }
    });

    test('rejects a code outside the vocabulary', () {
      expect(RecommendationSourceMode.fromCode('kit'), isNull);
      expect(RecommendationSourceMode.fromCode('myMakeupKit'), isNull);
      expect(RecommendationSourceMode.fromCode(''), isNull);
    });

    test('converts to and from the shipped selection enum without loss', () {
      for (final mode in MakeupRecommendationMode.values) {
        expect(
          RecommendationSourceMode.fromRecommendationMode(
            mode,
          ).toRecommendationMode(),
          mode,
        );
      }
      for (final mode in RecommendationSourceMode.values) {
        expect(
          RecommendationSourceMode.fromRecommendationMode(
            mode.toRecommendationMode(),
          ),
          mode,
        );
      }
    });

    test('maps kit selection to my_makeup_kit, not to standard', () {
      expect(
        RecommendationSourceMode.fromRecommendationMode(
          MakeupRecommendationMode.makeupKit,
        ),
        RecommendationSourceMode.myMakeupKit,
      );
      expect(
        RecommendationSourceMode.fromRecommendationMode(
          MakeupRecommendationMode.standard,
        ),
        RecommendationSourceMode.standard,
      );
    });
  });
}
