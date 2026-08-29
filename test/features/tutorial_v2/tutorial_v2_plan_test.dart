import 'package:facetune/features/tutorial_v2/domain/entities/tutorial_v2_category.dart';
import 'package:facetune/features/tutorial_v2/domain/entities/tutorial_v2_plan.dart';
import 'package:facetune/features/tutorial_v2/domain/entities/tutorial_v2_plan_context.dart';
import 'package:facetune/features/tutorial_v2/domain/entities/tutorial_v2_source_mode.dart';
import 'package:facetune/features/tutorial_v2/domain/entities/tutorial_v2_step_instructions.dart';
import 'package:facetune/features/tutorial_v2/domain/errors/tutorial_v2_failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/tutorial_v2_fixtures.dart';

TutorialV2Plan _plan(List<TutorialV2Category> categories) =>
    TutorialV2Plan.fromDrafts(
      context: tutorialV2Context(),
      drafts: tutorialV2Drafts(categories),
    );

Matcher _planValidationFailure(String fragment) => throwsA(
  isA<TutorialV2Failure>()
      .having(
        (failure) => failure.kind,
        'kind',
        TutorialV2FailureKind.planValidation,
      )
      .having((failure) => failure.retryable, 'retryable', false)
      .having((failure) => failure.message, 'message', contains(fragment)),
);

void main() {
  group('dynamic step count', () {
    test('a short natural plan is valid', () {
      final plan = _plan([
        TutorialV2Category.foundation,
        TutorialV2Category.lipstick,
      ]);

      expect(plan.totalSteps, 3);
      expect(plan.steps.last.category, TutorialV2Category.finalLook);
    });

    test('a long full-glam plan is valid', () {
      final plan = _plan(TutorialV2Category.makeupCategories);

      expect(plan.totalSteps, TutorialV2Category.makeupCategories.length + 1);
    });

    test('total steps is the planned length, never a fixed count', () {
      final lengths = [
        _plan([TutorialV2Category.lipstick]).totalSteps,
        _plan([
          TutorialV2Category.foundation,
          TutorialV2Category.blush,
          TutorialV2Category.lipstick,
        ]).totalSteps,
        _plan(TutorialV2Category.makeupCategories).totalSteps,
      ];

      expect(lengths, [2, 4, 11]);
      expect(lengths.toSet().length, lengths.length);
    });

    test('a single makeup step plus the final look is valid', () {
      expect(() => _plan([TutorialV2Category.lipstick]), returnsNormally);
    });

    test('rejects a plan with no makeup step', () {
      expect(
        () => _plan(const []),
        _planValidationFailure('at least one makeup step'),
      );
    });

    test('rejects an empty plan', () {
      expect(
        () => TutorialV2Plan.fromDrafts(
          context: tutorialV2Context(),
          drafts: const [],
        ),
        _planValidationFailure('at least one step'),
      );
    });
  });

  group('Final Look placement', () {
    test('rejects a plan with no Final Look step', () {
      expect(
        () => TutorialV2Plan.fromDrafts(
          context: tutorialV2Context(),
          drafts: [tutorialV2Draft(TutorialV2Category.blush)],
        ),
        _planValidationFailure('must end with the Final Look step'),
      );
    });

    test('rejects a Final Look step that is not last', () {
      expect(
        () => TutorialV2Plan.fromDrafts(
          context: tutorialV2Context(),
          drafts: [
            tutorialV2Draft(TutorialV2Category.finalLook),
            tutorialV2Draft(TutorialV2Category.blush),
          ],
        ),
        _planValidationFailure('must be last'),
      );
    });

    test('rejects more than one Final Look step', () {
      expect(
        () => TutorialV2Plan.fromDrafts(
          context: tutorialV2Context(),
          drafts: [
            tutorialV2Draft(TutorialV2Category.blush),
            tutorialV2Draft(TutorialV2Category.finalLook),
            tutorialV2Draft(TutorialV2Category.finalLook),
          ],
        ),
        _planValidationFailure('exactly one Final Look step'),
      );
    });

    test('the final step reuses the canonical preview instead of generating', () {
      final plan = _plan([TutorialV2Category.foundation]);
      final finalStep = plan.finalStep;

      expect(finalStep.isCanonicalReuse, isTrue);
      expect(
        finalStep.resultInstruction.mode,
        TutorialV2ResultMode.canonicalReuse,
      );
      expect(finalStep.requiresResultAsset, isFalse);
      expect(finalStep.requiresGuidelineAsset, isFalse);
      expect(finalStep.guidelineInstruction, isNull);
    });

    test('every non-final step generates its own result', () {
      final plan = _plan([
        TutorialV2Category.foundation,
        TutorialV2Category.blush,
      ]);

      for (final step in plan.steps.take(plan.totalSteps - 1)) {
        expect(step.isCanonicalReuse, isFalse);
        expect(step.requiresResultAsset, isTrue);
        expect(step.requiresGuidelineAsset, isTrue);
      }
    });
  });

  group('ordering', () {
    test('rejects concealer before foundation', () {
      expect(
        () => _plan([
          TutorialV2Category.concealer,
          TutorialV2Category.foundation,
        ]),
        _planValidationFailure('cannot follow'),
      );
    });

    test('rejects lip gloss before lip colour', () {
      expect(
        () => _plan([
          TutorialV2Category.lipGloss,
          TutorialV2Category.lipstick,
        ]),
        _planValidationFailure('cannot follow'),
      );
    });

    test('accepts lip gloss immediately after lip colour', () {
      expect(
        () => _plan([
          TutorialV2Category.lipstick,
          TutorialV2Category.lipGloss,
        ]),
        returnsNormally,
      );
    });

    test('accepts a plan that omits categories entirely', () {
      expect(
        () => _plan([
          TutorialV2Category.foundation,
          TutorialV2Category.eyeliner,
        ]),
        returnsNormally,
      );
    });

    test('rejects a duplicated category', () {
      expect(
        () => _plan([
          TutorialV2Category.blush,
          TutorialV2Category.blush,
        ]),
        _planValidationFailure('appears more than once'),
      );
    });

    test('canonical ranks follow the documented progression', () {
      final ordered = TutorialV2Category.makeupCategories
          .map((category) => category.code)
          .toList();

      expect(ordered, [
        'foundation',
        'concealer',
        'contour_bronzer',
        'blush',
        'highlighter',
        'eyebrow',
        'eyeshadow',
        'eyeliner',
        'lipstick',
        'lip_gloss',
      ]);
    });
  });

  group('cumulative category progression', () {
    late TutorialV2Plan plan;

    setUp(() {
      plan = _plan([
        TutorialV2Category.foundation,
        TutorialV2Category.blush,
        TutorialV2Category.lipstick,
      ]);
    });

    test('the first step has nothing completed before it', () {
      final first = plan.stepAt(0);

      expect(first.previouslyCompletedCategories, isEmpty);
      expect(first.currentCategory, TutorialV2Category.foundation);
      expect(first.categories.isFirstStep, isTrue);
    });

    test('each step accumulates exactly the categories before it', () {
      expect(plan.stepAt(1).previouslyCompletedCategories, [
        TutorialV2Category.foundation,
      ]);
      expect(plan.stepAt(2).previouslyCompletedCategories, [
        TutorialV2Category.foundation,
        TutorialV2Category.blush,
      ]);
    });

    test('cumulative equals previously completed plus current', () {
      for (final step in plan.steps) {
        expect(step.cumulativeCategories, [
          ...step.previouslyCompletedCategories,
          step.currentCategory,
        ]);
      }
    });

    test('future categories are the ones still ahead', () {
      expect(plan.stepAt(0).futureCategories, [
        TutorialV2Category.blush,
        TutorialV2Category.lipstick,
      ]);
      expect(plan.stepAt(2).futureCategories, isEmpty);
    });

    test('a category is never both completed and still ahead', () {
      for (final step in plan.steps) {
        expect(
          step.previouslyCompletedCategories.toSet().intersection(
            step.futureCategories.toSet(),
          ),
          isEmpty,
        );
      }
    });

    test('Final Look never counts as a completed makeup category', () {
      final finalStep = plan.finalStep;

      expect(
        finalStep.previouslyCompletedCategories,
        isNot(contains(TutorialV2Category.finalLook)),
      );
      expect(finalStep.previouslyCompletedCategories, [
        TutorialV2Category.foundation,
        TutorialV2Category.blush,
        TutorialV2Category.lipstick,
      ]);
      expect(finalStep.futureCategories, isEmpty);
    });

    test('step indexes are contiguous and one-based for display', () {
      for (var index = 0; index < plan.totalSteps; index++) {
        expect(plan.stepAt(index).stepIndex, index);
        expect(plan.stepAt(index).displayNumber, index + 1);
      }
    });
  });

  group('single source of truth per step', () {
    late TutorialV2Plan plan;

    setUp(() {
      plan = _plan([TutorialV2Category.foundation, TutorialV2Category.blush]);
    });

    test('guideline intent is the written instruction, not a second copy', () {
      final step = plan.stepAt(1);
      final guideline = step.guidelineInstruction!;

      expect(guideline.zones, step.whereToApply);
      expect(guideline.direction, step.direction);
      expect(guideline.technique, step.technique);
      expect(guideline.intensity, step.intensity);
    });

    test('result intent is the written instruction, not a second copy', () {
      final step = plan.stepAt(1);

      expect(step.resultInstruction.appliedDescription, step.whatToApply);
      expect(step.resultInstruction.technique, step.technique);
      expect(step.resultInstruction.intensity, step.intensity);
      expect(step.resultInstruction.targetLookCues, step.targetLookCues);
    });

    test('the guideline locks onto the current category only', () {
      final step = plan.stepAt(1);
      final guideline = step.guidelineInstruction!;

      expect(guideline.lockedCategory, TutorialV2Category.blush);
      expect(
        guideline.mustNotAnnotateCategories,
        isNot(contains(TutorialV2Category.blush)),
      );
      expect(
        guideline.mustNotAnnotateCategories,
        contains(TutorialV2Category.foundation),
      );
      expect(
        guideline.mustNotAnnotateCategories.length,
        TutorialV2Category.values.length - 1,
      );
    });

    test('the first guideline annotates the original selfie', () {
      expect(
        plan.stepAt(0).guidelineInstruction!.baseState,
        TutorialV2GuidelineBaseState.originalSelfie,
      );
    });

    test('later guidelines annotate the previous cumulative result', () {
      expect(
        plan.stepAt(1).guidelineInstruction!.baseState,
        TutorialV2GuidelineBaseState.previousCumulativeResult,
      );
    });

    test('the result preserves completed and forbids future categories', () {
      final step = plan.stepAt(0);

      expect(step.resultInstruction.appliedCategory, step.currentCategory);
      expect(step.resultInstruction.preserveCategories, isEmpty);
      expect(step.resultInstruction.forbiddenCategories, [
        TutorialV2Category.blush,
      ]);
    });
  });

  group('context', () {
    test('rejects an unknown makeup style', () {
      expect(
        () => TutorialV2Plan.fromDrafts(
          context: tutorialV2Context(styleCode: 'disco_glam'),
          drafts: tutorialV2Drafts([TutorialV2Category.blush]),
        ),
        _planValidationFailure('Unknown makeup style'),
      );
    });

    test('rejects a blank makeup style', () {
      expect(
        () => TutorialV2Plan.fromDrafts(
          context: tutorialV2Context(styleCode: '  '),
          drafts: tutorialV2Drafts([TutorialV2Category.blush]),
        ),
        _planValidationFailure('requires the selected makeup style'),
      );
    });

    test('rejects a recommendation reference from the other mode', () {
      expect(
        () => TutorialV2Plan.fromDrafts(
          context: tutorialV2Context(
            sourceMode: TutorialV2SourceMode.standardRecommendation,
            recommendation: const TutorialV2RecommendationRef.kit('kit-1'),
          ),
          drafts: tutorialV2Drafts([TutorialV2Category.blush]),
        ),
        _planValidationFailure('does not match source mode'),
      );
    });

    test('rejects a canonical preview from the other mode', () {
      expect(
        () => TutorialV2Plan.fromDrafts(
          context: tutorialV2Context(
            canonicalSourceMode: TutorialV2SourceMode.makeupKit,
          ),
          drafts: tutorialV2Drafts([TutorialV2Category.blush]),
        ),
        _planValidationFailure('canonical final preview does not match'),
      );
    });

    test('resolving a step binds session context to it', () {
      final plan = _plan([
        TutorialV2Category.foundation,
        TutorialV2Category.blush,
      ]);
      final resolved = plan.resolveStep(1);

      expect(resolved.context.styleCode, 'soft_glam');
      expect(resolved.step.category, TutorialV2Category.blush);
      expect(resolved.totalSteps, 3);
      expect(resolved.progressLabel, 'STEP 2 OF 3');
      expect(resolved.isFinalStep, isFalse);
      expect(plan.resolveStep(2).isFinalStep, isTrue);
    });
  });

  group('required text', () {
    test('rejects a step missing where to apply', () {
      expect(
        () => TutorialV2Plan.fromDrafts(
          context: tutorialV2Context(),
          drafts: [
            tutorialV2Draft(TutorialV2Category.blush, whereToApply: '  '),
            tutorialV2Draft(TutorialV2Category.finalLook),
          ],
        ),
        _planValidationFailure('missing where to apply'),
      );
    });

    test('rejects a step missing a direction', () {
      expect(
        () => TutorialV2Plan.fromDrafts(
          context: tutorialV2Context(),
          drafts: [
            tutorialV2Draft(TutorialV2Category.blush, direction: ''),
            tutorialV2Draft(TutorialV2Category.finalLook),
          ],
        ),
        _planValidationFailure('missing a direction'),
      );
    });

    test('rejects a blank optional field rather than storing it', () {
      expect(
        () => TutorialV2Plan.fromDrafts(
          context: tutorialV2Context(),
          drafts: [
            tutorialV2Draft(TutorialV2Category.blush, personalizedTip: '  '),
            tutorialV2Draft(TutorialV2Category.finalLook),
          ],
        ),
        _planValidationFailure('blank tip'),
      );
    });

    test('reports every violation at once', () {
      expect(
        () => TutorialV2Plan.fromDrafts(
          context: tutorialV2Context(styleCode: 'disco_glam'),
          drafts: [
            tutorialV2Draft(TutorialV2Category.blush, direction: ''),
            tutorialV2Draft(TutorialV2Category.finalLook),
          ],
        ),
        throwsA(
          isA<TutorialV2Failure>()
              .having(
                (failure) => failure.message,
                'message',
                contains('Unknown makeup style'),
              )
              .having(
                (failure) => failure.message,
                'message',
                contains('missing a direction'),
              ),
        ),
      );
    });
  });
}
