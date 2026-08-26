import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_category.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_guideline_base_image.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_guideline_intent.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_step_instructions.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_step_spec.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tutorial_v3_fixtures.dart';

void main() {
  test('the final-look flag is derived from the category', () {
    expect(guidelineStep().isFinalLook, isFalse);
    expect(guidelineStep().category.isFinalLook, isFalse);

    final last = finalLookStep();
    expect(last.isFinalLook, isTrue);
    expect(last.category, TutorialV3Category.finalLook);
  });

  test('a final-look step cannot be built with another category', () {
    // `category` is a constant getter on the final-look variant, not a
    // constructor parameter, so no call site can disagree with it.
    expect(
      finalLookStep().category,
      same(TutorialV3Category.finalLook),
    );
  });

  test('every guideline step is based on the original selfie', () {
    for (final category in TutorialV3Category.guidelineCategories) {
      final step = guidelineStep(category: category);
      expect(step.baseImage, TutorialV3GuidelineBaseImage.originalSelfie);
      expect(
        step.guidelineVisualIntent.baseImage,
        TutorialV3GuidelineBaseImage.originalSelfie,
      );
    }
  });

  test('there is exactly one possible guideline base image', () {
    // A `previousGuideline` member would be required to build a cumulative
    // chain. There is none, so the chain is unrepresentable.
    expect(TutorialV3GuidelineBaseImage.values, [
      TutorialV3GuidelineBaseImage.originalSelfie,
    ]);
  });

  test('the guideline intent is derived only from the spec', () {
    final step = guidelineStep(
      category: TutorialV3Category.eyeshadow,
      coverage: 'Medium',
      intensity: 'Soft',
    );
    final intent = TutorialV3GuidelineIntent.fromSpec(step);

    expect(intent.category, step.category);
    expect(intent.whereToApply, step.whereToApply);
    expect(intent.direction, step.direction);
    expect(intent.technique, step.technique);
    expect(intent.coverage, step.coverage);
    expect(intent.intensity, step.intensity);
    expect(intent.visualDescription, step.guidelineVisualIntent.description);
    expect(intent.graphics, step.guidelineVisualIntent.graphics);
    expect(intent.selectedStyleCode, step.selectedStyleCode);
    expect(intent.targetReferenceMode, step.targetReferenceMode);
    expect(intent.baseImage, TutorialV3GuidelineBaseImage.originalSelfie);
  });

  test('deriving the same spec twice yields an identical intent', () {
    final step = guidelineStep();

    expect(
      TutorialV3GuidelineIntent.fromSpec(step),
      TutorialV3GuidelineIntent.fromSpec(step),
    );
    expect(
      TutorialV3GuidelineIntent.fromSpec(step).hashCode,
      TutorialV3GuidelineIntent.fromSpec(step).hashCode,
    );
  });

  test('a different instruction produces a different intent', () {
    final original = TutorialV3GuidelineIntent.fromSpec(guidelineStep());
    final altered = TutorialV3GuidelineIntent.fromSpec(
      guidelineStep(direction: 'Downward toward the jaw'),
    );

    expect(altered, isNot(original));
  });

  test('the intent carries only the current step category', () {
    final blush = TutorialV3GuidelineIntent.fromSpec(
      guidelineStep(category: TutorialV3Category.blush),
    );
    final eyeliner = TutorialV3GuidelineIntent.fromSpec(
      guidelineStep(category: TutorialV3Category.eyeliner),
    );

    expect(blush.category, TutorialV3Category.blush);
    expect(eyeliner.category, TutorialV3Category.eyeliner);
    expect(blush, isNot(eyeliner));
  });

  test('rendered text is copied from the spec, never invented', () {
    final step = guidelineStep(
      stepIndex: 4,
      personalizedTip: 'Build slowly.',
      avoid: 'Do not drag toward the nose.',
      amount: 'A light sweep',
      toolSuggestion: 'Fluffy brush',
    );
    final text = TutorialV3StepInstructions.fromSpec(step);

    expect(text.stepIndex, 4);
    expect(text.category, step.category);
    expect(text.whereToApply, step.whereToApply);
    expect(text.direction, step.direction);
    expect(text.technique, step.technique);
    expect(text.whyThisPlacement, step.faceRationale);
    expect(text.howThisBuildsTheLook, step.targetRationale);
    expect(text.tip, step.personalizedTip);
    expect(text.avoid, step.avoid);
    expect(text.amount, step.amount);
    expect(text.toolSuggestion, step.toolSuggestion);
    expect(text.product, same(step.productSnapshot));
  });

  test('text and guideline intent stay in agreement', () {
    final step = guidelineStep();
    final text = TutorialV3StepInstructions.fromSpec(step);
    final intent = TutorialV3GuidelineIntent.fromSpec(step);

    expect(text.whereToApply, intent.whereToApply);
    expect(text.direction, intent.direction);
    expect(text.technique, intent.technique);
    expect(text.category, intent.category);
  });

  test('optional fields stay absent rather than being filled in', () {
    final step = guidelineStep(omitProductSnapshot: true);
    final text = TutorialV3StepInstructions.fromSpec(step);

    expect(text.product, isNull);
    expect(text.tip, isNull);
    expect(text.avoid, isNull);
    expect(text.coverage, isNull);
    expect(text.intensity, isNull);
  });

  test('the spec hierarchy has exactly two variants', () {
    final specs = <TutorialV3StepSpec>[guidelineStep(), finalLookStep()];

    for (final spec in specs) {
      final label = switch (spec) {
        TutorialV3GuidelineStepSpec() => 'guideline',
        TutorialV3FinalLookStepSpec() => 'final',
      };
      expect(label, isNotEmpty);
    }
  });
}
