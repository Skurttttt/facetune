import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_category.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_geometry.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_geometry_status.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_guideline_visual_intent.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_scoped_face_attributes.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_source_mode.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_step.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_step_spec.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_target_reference_mode.dart';
import 'package:facetune/features/tutorial_v3/domain/errors/tutorial_v3_failure.dart';
import 'package:facetune/features/tutorial_v3/domain/validation/tutorial_v3_plan_validator.dart';
import 'package:facetune/features/analysis/domain/entities/facial_attributes.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tutorial_v3_fixtures.dart';

Matcher throwsValidation(String messagePart) => throwsA(
  isA<TutorialV3Failure>()
      .having((f) => f.kind, 'kind', TutorialV3FailureKind.validation)
      .having((f) => f.retryable, 'retryable', isFalse)
      .having((f) => f.message, 'message', contains(messagePart)),
);

void main() {
  group('dynamic plans', () {
    test('accepts a short plan', () {
      final plan = planTeaching([
        TutorialV3Category.foundation,
        TutorialV3Category.lipstick,
      ]);

      expect(() => TutorialV3PlanValidator.validate(plan), returnsNormally);
      expect(plan.totalSteps, 3);
    });

    test('accepts a long plan', () {
      final plan = planTeaching([
        TutorialV3Category.foundation,
        TutorialV3Category.concealer,
        TutorialV3Category.contourBronzer,
        TutorialV3Category.blush,
        TutorialV3Category.highlighter,
        TutorialV3Category.eyebrow,
        TutorialV3Category.eyeshadow,
        TutorialV3Category.eyeliner,
        TutorialV3Category.lipstick,
        TutorialV3Category.lipGloss,
      ]);

      expect(() => TutorialV3PlanValidator.validate(plan), returnsNormally);
      expect(plan.totalSteps, 11);
    });

    test('accepts a plan that omits categories entirely', () {
      final plan = planTeaching([
        TutorialV3Category.concealer,
        TutorialV3Category.eyeliner,
      ]);

      expect(() => TutorialV3PlanValidator.validate(plan), returnsNormally);
    });

    test('total steps always equals the real plan length', () {
      for (final count in [1, 3, 7]) {
        final categories = TutorialV3Category.guidelineCategories
            .take(count)
            .toList();
        final plan = planTeaching(categories);
        expect(plan.totalSteps, plan.steps.length);
        expect(plan.totalSteps, count + 1);
      }
    });

    test('rejects an empty plan', () {
      expect(
        () => TutorialV3PlanValidator.validate(planOf(steps: const [])),
        throwsValidation('at least one step'),
      );
    });

    test('accepts a final-look-only plan', () {
      final plan = planOf(steps: [finalLookStep(stepIndex: 1)]);
      expect(() => TutorialV3PlanValidator.validate(plan), returnsNormally);
    });
  });

  group('ordering and termination', () {
    test('rejects a plan that does not end with the final look', () {
      final plan = planOf(
        steps: [guidelineStep(stepIndex: 1, category: TutorialV3Category.blush)],
      );

      expect(
        () => TutorialV3PlanValidator.validate(plan),
        throwsValidation('last step'),
      );
    });

    test('rejects a final look that is not last', () {
      final plan = planOf(
        steps: [
          finalLookStep(stepIndex: 1),
          guidelineStep(stepIndex: 2, category: TutorialV3Category.blush),
        ],
      );

      expect(
        () => TutorialV3PlanValidator.validate(plan),
        throwsValidation('only appear as the last step'),
      );
    });

    test('rejects categories out of canonical order', () {
      final plan = planTeaching([
        TutorialV3Category.blush,
        TutorialV3Category.foundation,
      ]);

      expect(
        () => TutorialV3PlanValidator.validate(plan),
        throwsValidation('out of canonical order'),
      );
    });

    test('rejects lip gloss taught before lip color', () {
      final plan = planTeaching([
        TutorialV3Category.lipGloss,
        TutorialV3Category.lipstick,
      ]);

      expect(
        () => TutorialV3PlanValidator.validate(plan),
        throwsValidation('out of canonical order'),
      );
    });

    test('accepts lip gloss without lip color', () {
      final plan = planTeaching([TutorialV3Category.lipGloss]);
      expect(() => TutorialV3PlanValidator.validate(plan), returnsNormally);
    });

    test('rejects a duplicated category', () {
      final plan = planOf(
        steps: [
          guidelineStep(stepIndex: 1, category: TutorialV3Category.blush),
          guidelineStep(stepIndex: 2, category: TutorialV3Category.blush),
          finalLookStep(stepIndex: 3),
        ],
      );

      expect(
        () => TutorialV3PlanValidator.validate(plan),
        throwsValidation('more than once'),
      );
    });

    test('rejects a step index that disagrees with its position', () {
      final plan = planOf(
        steps: [
          guidelineStep(stepIndex: 5, category: TutorialV3Category.blush),
          finalLookStep(stepIndex: 2),
        ],
      );

      expect(
        () => TutorialV3PlanValidator.validate(plan),
        throwsValidation('declares step index'),
      );
    });
  });

  group('plan-wide agreement', () {
    test('rejects an unknown selected style', () {
      expect(
        () => TutorialV3PlanValidator.validate(
          planOf(selectedStyleCode: 'glam_supreme'),
        ),
        throwsValidation('Unknown selected style'),
      );
    });

    test('rejects a step whose style disagrees with the plan', () {
      final plan = planOf(
        steps: [
          guidelineStep(stepIndex: 1, selectedStyleCode: 'natural'),
          finalLookStep(stepIndex: 2),
        ],
      );

      expect(
        () => TutorialV3PlanValidator.validate(plan),
        throwsValidation('declares style'),
      );
    });

    test('rejects a step whose source mode disagrees with the plan', () {
      final plan = planOf(
        steps: [
          guidelineStep(
            stepIndex: 1,
            sourceMode: TutorialV3SourceMode.makeupKit,
          ),
          finalLookStep(stepIndex: 2),
        ],
      );

      expect(
        () => TutorialV3PlanValidator.validate(plan),
        throwsValidation('declares source mode'),
      );
    });

    test('rejects an unsupported target reference mode', () {
      final plan = planOf(
        steps: [
          guidelineStep(
            stepIndex: 1,
            targetReferenceMode: TutorialV3TargetReferenceMode.cheekFocus,
          ),
          finalLookStep(stepIndex: 2),
        ],
      );

      expect(
        () => TutorialV3PlanValidator.validate(plan),
        throwsValidation('unsupported target reference mode'),
      );
    });
  });

  group('required instruction content', () {
    test('rejects a blank placement', () {
      final plan = planOf(
        steps: [
          guidelineStep(stepIndex: 1, whereToApply: '   '),
          finalLookStep(stepIndex: 2),
        ],
      );

      expect(
        () => TutorialV3PlanValidator.validate(plan),
        throwsValidation('where to apply'),
      );
    });

    test('rejects a blank direction, technique or rationale', () {
      final cases = <String, TutorialV3StepSpec>{
        'a direction': guidelineStep(stepIndex: 1, direction: ''),
        'a technique': guidelineStep(stepIndex: 1, technique: ''),
        'a face rationale': guidelineStep(stepIndex: 1, faceRationale: ''),
        'a target rationale': guidelineStep(stepIndex: 1, targetRationale: ''),
      };

      cases.forEach((expected, step) {
        expect(
          () => TutorialV3PlanValidator.validate(
            planOf(steps: [step, finalLookStep(stepIndex: 2)]),
          ),
          throwsValidation(expected),
        );
      });
    });

    test('rejects a guideline that draws nothing', () {
      final plan = planOf(
        steps: [
          guidelineStep(
            stepIndex: 1,
            guidelineVisualIntent: const TutorialV3GuidelineVisualIntent(
              description: 'Nothing in particular.',
              graphics: {},
            ),
          ),
          finalLookStep(stepIndex: 2),
        ],
      );

      expect(
        () => TutorialV3PlanValidator.validate(plan),
        throwsValidation('at least one instructional mark'),
      );
    });

    test('rejects missing or blank target look cues', () {
      expect(
        () => TutorialV3PlanValidator.validate(
          planOf(
            steps: [
              guidelineStep(stepIndex: 1, targetLookCues: const []),
              finalLookStep(stepIndex: 2),
            ],
          ),
        ),
        throwsValidation('target look cues'),
      );

      expect(
        () => TutorialV3PlanValidator.validate(
          planOf(
            steps: [
              guidelineStep(stepIndex: 1, targetLookCues: const ['  ']),
              finalLookStep(stepIndex: 2),
            ],
          ),
        ),
        throwsValidation('blank target look cue'),
      );
    });

    test('rejects a final look with no rationale', () {
      final plan = planOf(
        steps: [finalLookStep(stepIndex: 1, targetRationale: '')],
      );

      expect(
        () => TutorialV3PlanValidator.validate(plan),
        throwsValidation('final-look rationale'),
      );
    });
  });

  group('facial attribute scoping', () {
    test('rejects an attribute that is irrelevant to the category', () {
      final plan = planOf(
        steps: [
          guidelineStep(
            stepIndex: 1,
            category: TutorialV3Category.blush,
            relevantFaceAttributes: const TutorialV3ScopedFaceAttributes(
              faceShape: FaceShape.round,
              lipShape: LipShape.full,
            ),
          ),
          finalLookStep(stepIndex: 2),
        ],
      );

      expect(
        () => TutorialV3PlanValidator.validate(plan),
        throwsValidation('not relevant to "blush": lip_shape'),
      );
    });

    test('rejects a step with no personalizing attribute', () {
      final plan = planOf(
        steps: [
          guidelineStep(
            stepIndex: 1,
            relevantFaceAttributes: const TutorialV3ScopedFaceAttributes(),
          ),
          finalLookStep(stepIndex: 2),
        ],
      );

      expect(
        () => TutorialV3PlanValidator.validate(plan),
        throwsValidation('at least one facial attribute'),
      );
    });

    test('accepts a scope built from the catalog for every category', () {
      for (final category in TutorialV3Category.guidelineCategories) {
        final plan = planTeaching([category]);
        expect(
          () => TutorialV3PlanValidator.validate(plan),
          returnsNormally,
          reason: '${category.code} failed scoping',
        );
      }
    });
  });

  group('My Makeup Kit constraints', () {
    test('accepts a Kit plan whose products are owned', () {
      final plan = planTeaching(
        [TutorialV3Category.blush],
        sourceMode: TutorialV3SourceMode.makeupKit,
      );

      expect(
        () => TutorialV3PlanValidator.validate(
          plan,
          ownedKitProductIds: const {testOwnedProductId},
        ),
        returnsNormally,
      );
    });

    test('rejects a Kit product the user does not own', () {
      final plan = planTeaching(
        [TutorialV3Category.blush],
        sourceMode: TutorialV3SourceMode.makeupKit,
      );

      expect(
        () => TutorialV3PlanValidator.validate(
          plan,
          ownedKitProductIds: const {'some-other-product'},
        ),
        throwsValidation('which the user does not own'),
      );
    });

    test('rejects a Kit step that invents a product', () {
      final plan = planOf(
        sourceMode: TutorialV3SourceMode.makeupKit,
        steps: [
          guidelineStep(
            stepIndex: 1,
            sourceMode: TutorialV3SourceMode.makeupKit,
            productSnapshot: standardProductSnapshot(),
          ),
          finalLookStep(
            stepIndex: 2,
            sourceMode: TutorialV3SourceMode.makeupKit,
          ),
        ],
      );

      expect(
        () => TutorialV3PlanValidator.validate(plan),
        throwsValidation('does not own'),
      );
    });

    test('rejects a Kit step with no product at all', () {
      final plan = planOf(
        sourceMode: TutorialV3SourceMode.makeupKit,
        steps: [
          guidelineStep(
            stepIndex: 1,
            sourceMode: TutorialV3SourceMode.makeupKit,
            omitProductSnapshot: true,
          ),
          finalLookStep(
            stepIndex: 2,
            sourceMode: TutorialV3SourceMode.makeupKit,
          ),
        ],
      );

      expect(
        () => TutorialV3PlanValidator.validate(plan),
        throwsValidation('must snapshot an owned product'),
      );
    });

    test('rejects an owned Kit product inside a standard plan', () {
      final plan = planOf(
        steps: [
          guidelineStep(stepIndex: 1, productSnapshot: kitProductSnapshot()),
          finalLookStep(stepIndex: 2),
        ],
      );

      expect(
        () => TutorialV3PlanValidator.validate(plan),
        throwsValidation('must not reference an owned'),
      );
    });

    test('rejects a snapshot from a different category', () {
      final plan = planOf(
        steps: [
          guidelineStep(
            stepIndex: 1,
            category: TutorialV3Category.blush,
            productSnapshot: standardProductSnapshot(
              category: TutorialV3Category.lipstick,
            ),
          ),
          finalLookStep(stepIndex: 2),
        ],
      );

      expect(
        () => TutorialV3PlanValidator.validate(plan),
        throwsValidation('snapshots a "lipstick" product'),
      );
    });

    test('a standard plan may omit products entirely', () {
      final plan = planOf(
        steps: [
          guidelineStep(stepIndex: 1, omitProductSnapshot: true),
          finalLookStep(stepIndex: 2),
        ],
      );

      expect(() => TutorialV3PlanValidator.validate(plan), returnsNormally);
    });
  });

  group('step runtime state', () {
    test('a planned guideline step starts pending', () {
      final step = TutorialV3Step.planned(guidelineStep());

      expect(step.geometryStatus, TutorialV3GeometryStatus.pending);
      expect(step.geometry, isNull);
      expect(step.hasGeometry, isFalse);
      expect(() => TutorialV3PlanValidator.validateStep(step), returnsNormally);
    });

    test('a planned final look never needs generation', () {
      final step = TutorialV3Step.planned(finalLookStep());

      expect(step.geometryStatus, TutorialV3GeometryStatus.notRequired);
      expect(step.geometryStatus.canStartGeneration, isFalse);
      expect(() => TutorialV3PlanValidator.validateStep(step), returnsNormally);
    });

    test('the final look may not own geometry', () {
      final step = TutorialV3Step(
        spec: finalLookStep(),
        geometryStatus: TutorialV3GeometryStatus.ready,
        geometry: testGeometry(),
        geometrySchemaVersion: tutorialV3GeometrySchemaVersion,
      );

      expect(
        () => TutorialV3PlanValidator.validateStep(step),
        throwsValidation('must not have geometry status'),
      );
    });

    test('a guideline step may not be marked as not required', () {
      final step = TutorialV3Step(
        spec: guidelineStep(),
        geometryStatus: TutorialV3GeometryStatus.notRequired,
      );

      expect(
        () => TutorialV3PlanValidator.validateStep(step),
        throwsValidation('requires mapped geometry'),
      );
    });

    test('a ready step must carry a document', () {
      final step = TutorialV3Step(
        spec: guidelineStep(),
        geometryStatus: TutorialV3GeometryStatus.ready,
      );

      expect(
        () => TutorialV3PlanValidator.validateStep(step),
        throwsValidation('is ready but has no geometry'),
      );
    });

    test('an unfinished step must not carry a document', () {
      final step = TutorialV3Step(
        spec: guidelineStep(),
        geometryStatus: TutorialV3GeometryStatus.failed,
        geometry: testGeometry(),
        geometrySchemaVersion: tutorialV3GeometrySchemaVersion,
      );

      expect(
        () => TutorialV3PlanValidator.validateStep(step),
        throwsValidation('while its status is "failed"'),
      );
    });

    test('geometry must describe the category the step teaches', () {
      // A blush document rendered on an eyeliner step would draw a confidently
      // wrong overlay, so the categories must agree exactly.
      final step = TutorialV3Step(
        spec: guidelineStep(category: TutorialV3Category.eyeliner),
        geometryStatus: TutorialV3GeometryStatus.ready,
        geometry: testGeometry(category: TutorialV3Category.blush),
        geometrySchemaVersion: tutorialV3GeometrySchemaVersion,
      );

      expect(
        () => TutorialV3PlanValidator.validateStep(step),
        throwsValidation('teaches "eyeliner" but carries "blush" geometry'),
      );
    });

    test('a failed step keeps its spec and may be retried', () {
      final spec = guidelineStep();
      final step = TutorialV3Step(
        spec: spec,
        geometryStatus: TutorialV3GeometryStatus.failed,
        attemptCount: 2,
        lastErrorCode: 'invalid_geometry',
      );

      expect(step.spec, same(spec));
      expect(step.geometryStatus.canStartGeneration, isTrue);
      expect(step.hasGeometry, isFalse);
      expect(() => TutorialV3PlanValidator.validateStep(step), returnsNormally);
    });

    test('a ready step is reusable rather than regenerated', () {
      final step = TutorialV3Step(
        spec: guidelineStep(),
        geometryStatus: TutorialV3GeometryStatus.ready,
        geometry: testGeometry(),
        geometrySchemaVersion: tutorialV3GeometrySchemaVersion,
      );

      expect(step.hasGeometry, isTrue);
      expect(step.hasStaleGeometry, isFalse);
      expect(step.geometryStatus.canStartGeneration, isFalse);
      expect(() => TutorialV3PlanValidator.validateStep(step), returnsNormally);
    });

    test('a document written by an older build reads as stale', () {
      // Stale is a property of the persisted row, not a validation error: the
      // repository re-maps it rather than refusing to open the tutorial.
      final step = TutorialV3Step(
        spec: guidelineStep(),
        geometryStatus: TutorialV3GeometryStatus.ready,
        geometry: testGeometry(),
        geometrySchemaVersion: tutorialV3GeometrySchemaVersion - 1,
      );

      expect(step.hasStaleGeometry, isTrue);
    });

    test('rejects a negative attempt count', () {
      final step = TutorialV3Step(
        spec: guidelineStep(),
        geometryStatus: TutorialV3GeometryStatus.pending,
        attemptCount: -1,
      );

      expect(
        () => TutorialV3PlanValidator.validateStep(step),
        throwsValidation('negative attempt count'),
      );
    });
  });
}
