import 'package:facetune/features/makeup_kit/domain/entities/kit_makeup_recommendation.dart';
import 'package:facetune/features/tutorial/domain/entities/look_product_snapshot.dart';
import 'package:facetune/features/tutorial/domain/entities/recommendation_source_mode.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_ai_configuration.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_category.dart';
import 'package:facetune/features/tutorial/domain/entities/validated_look_plan.dart';
import 'package:flutter_test/flutter_test.dart';

ValidatedLookPlan plan(LookPlanSource source) => ValidatedLookPlan(
  id: 'plan-1',
  analysisId: 'analysis-1',
  styleCode: 'soft_glam',
  source: source,
  modelId: 'server-reported-model',
  promptVersion: 'v1',
  createdAt: DateTime.utc(2026, 8, 30),
);

void main() {
  group('source mode is explicit, never inferred', () {
    test('standard source reports standard mode', () {
      final subject = plan(StandardLookPlanSource(recommendationId: 'rec-1'));

      expect(subject.sourceMode, RecommendationSourceMode.standard);
      expect(subject.source, isA<StandardLookPlanSource>());
    });

    test('kit source reports my_makeup_kit mode', () {
      final subject = plan(
        MyMakeupKitLookPlanSource(
          kitRecommendationId: 'kit-rec-1',
          productSnapshot: LookProductSnapshot.empty,
        ),
      );

      expect(subject.sourceMode, RecommendationSourceMode.myMakeupKit);
      expect(subject.source, isA<MyMakeupKitLookPlanSource>());
    });

    test('an empty kit selection still reports kit mode, not standard', () {
      final subject = plan(
        MyMakeupKitLookPlanSource(
          kitRecommendationId: 'kit-rec-1',
          productSnapshot: LookProductSnapshot.empty,
        ),
      );

      expect(subject.productSnapshot.items, isEmpty);
      expect(subject.sourceMode, RecommendationSourceMode.myMakeupKit);
      expect(
        subject.sourceMode,
        isNot(RecommendationSourceMode.standard),
        reason: 'an empty selection must never fall back to Standard Mode',
      );
    });

    test('the source variants are exhaustively matchable', () {
      for (final source in <LookPlanSource>[
        StandardLookPlanSource(recommendationId: 'rec-1'),
        MyMakeupKitLookPlanSource(
          kitRecommendationId: 'kit-rec-1',
          productSnapshot: LookProductSnapshot.empty,
        ),
      ]) {
        final matched = switch (source) {
          StandardLookPlanSource() => RecommendationSourceMode.standard,
          MyMakeupKitLookPlanSource() => RecommendationSourceMode.myMakeupKit,
        };
        expect(matched, source.mode);
      }
    });
  });

  group('product snapshot convergence', () {
    test('standard mode exposes an empty snapshot rather than null', () {
      final subject = plan(StandardLookPlanSource(recommendationId: 'rec-1'));

      expect(subject.productSnapshot.items, isEmpty);
      expect(subject.productBackedCategories, isEmpty);
    });

    test('kit mode exposes the immutable owned-product selection', () {
      final snapshot =
          LookProductSnapshot.fromKitSnapshots(<KitProductSnapshot>[
            const KitProductSnapshot(
              productId: 'p1',
              category: 'lipstick',
              colorHex: '#B86F72',
              finish: 'cream',
            ),
            const KitProductSnapshot(
              productId: 'p2',
              category: 'lip_gloss',
              colorHex: '#D8A0A2',
              finish: 'glossy',
            ),
            const KitProductSnapshot(
              productId: 'p3',
              category: 'foundation',
              colorHex: '#E3C4A8',
              finish: 'natural',
            ),
          ]);
      final subject = plan(
        MyMakeupKitLookPlanSource(
          kitRecommendationId: 'kit-rec-1',
          productSnapshot: snapshot,
        ),
      );

      expect(subject.productBackedCategories, const <TutorialCategory>[
        TutorialCategory.foundation,
        TutorialCategory.lips,
      ]);
      expect(
        subject.productSnapshot.itemsFor(TutorialCategory.lips),
        hasLength(2),
      );
    });
  });

  group('TutorialAiConfiguration', () {
    test('defaults the tutorial output resolution to 1K', () {
      expect(
        TutorialAiConfiguration.defaultOutputResolution,
        TutorialOutputResolution.oneK,
      );
      expect(TutorialAiConfiguration.defaultOutputResolution.code, '1K');
    });

    test('applies the 1K baseline when no resolution is supplied', () {
      const config = TutorialAiConfiguration(
        manifestModelId: 'server-reported-manifest-model',
        manifestPromptVersion: 'manifest_v1',
        manifestSchemaVersion: 'schema_v1',
        guidelineModelId: 'server-reported-guideline-model',
        guidelinePromptVersion: 'guideline_v1',
      );

      expect(config.outputResolution, TutorialOutputResolution.oneK);
      expect(config.outputResolution.code, '1K');
    });

    test('resolution vocabulary round-trips through its wire code', () {
      for (final resolution in TutorialOutputResolution.values) {
        expect(TutorialOutputResolution.fromCode(resolution.code), resolution);
      }
      expect(TutorialOutputResolution.fromCode('1080p'), isNull);
    });
  });
}
