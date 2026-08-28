import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_canonical_preview.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_category.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_guideline_base_image.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_guideline_graphic.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_guideline_intent.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_geometry_status.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_session.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_session_status.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_source_mode.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_step_spec.dart';
import 'package:facetune/features/tutorial_v3/domain/value_objects/tutorial_v3_plan_version.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tutorial_v3_fixtures.dart';

/// V3's central rule, asserted as a contract rather than a convention.
///
/// These tests fail the moment someone reintroduces cumulative generation,
/// an intermediate makeup result, or a guideline-to-guideline chain.
void main() {
  test('no category represents an intermediate makeup result', () {
    for (final category in TutorialV3Category.values) {
      expect(
        category.code.contains('result'),
        isFalse,
        reason: '${category.code} looks like a result step',
      );
    }
  });

  test('no guideline status represents a produced makeup appearance', () {
    for (final status in TutorialV3GeometryStatus.values) {
      expect(
        status.code.contains('result'),
        isFalse,
        reason: '${status.code} looks like a result state',
      );
    }
    expect(TutorialV3GeometryStatus.values.map((s) => s.code), <String>[
      'not_required',
      'pending',
      'generating',
      'ready',
      'failed',
    ]);
  });

  test('a guideline may only draw instructional marks', () {
    expect(TutorialV3GuidelineGraphic.values.map((g) => g.code), <String>[
      'translucent_zone',
      'arrow',
      'path',
      'soft_band',
      'marker',
    ]);
  });

  test('the only base image is the original selfie', () {
    expect(TutorialV3GuidelineBaseImage.values.length, 1);
    expect(
      TutorialV3GuidelineBaseImage.values.single,
      TutorialV3GuidelineBaseImage.originalSelfie,
    );
  });

  test('a step spec is either a guideline or the final look', () {
    final specs = <TutorialV3StepSpec>[guidelineStep(), finalLookStep()];
    final kinds = specs
        .map(
          (spec) => switch (spec) {
            TutorialV3GuidelineStepSpec() => 'guideline',
            TutorialV3FinalLookStepSpec() => 'final_look',
          },
        )
        .toList();

    expect(kinds, ['guideline', 'final_look']);
  });

  test('a later step never depends on an earlier one', () {
    final afterFoundation = planTeaching([
      TutorialV3Category.foundation,
      TutorialV3Category.blush,
    ]);
    final afterConcealer = planTeaching([
      TutorialV3Category.concealer,
      TutorialV3Category.blush,
    ]);

    TutorialV3GuidelineIntent blushIntent(plan) =>
        TutorialV3GuidelineIntent.fromSpec(
          plan.guidelineSteps.firstWhere(
            (step) => step.category == TutorialV3Category.blush,
          ),
        );

    // The blush guideline is byte-for-byte the same regardless of which step
    // preceded it, because nothing about the previous step reaches it.
    expect(blushIntent(afterFoundation), blushIntent(afterConcealer));
  });

  test('a plan contains exactly one terminal step', () {
    final plan = planTeaching([
      TutorialV3Category.foundation,
      TutorialV3Category.blush,
      TutorialV3Category.lipstick,
    ]);

    expect(plan.steps.whereType<TutorialV3FinalLookStepSpec>().length, 1);
    expect(plan.steps.last, isA<TutorialV3FinalLookStepSpec>());
    expect(plan.finalStep, isNotNull);
    expect(plan.guidelineSteps.length, 3);
    expect(plan.taughtCategories, [
      TutorialV3Category.foundation,
      TutorialV3Category.blush,
      TutorialV3Category.lipstick,
    ]);
  });

  test('the final step reuses the existing canonical preview', () {
    const preview = TutorialV3CanonicalPreview(
      generatedImageId: 'generated-image-1',
      storagePath: 'user/analyses/a/generated/r/preview_0001.png',
      sourceMode: TutorialV3SourceMode.standard,
    );
    final plan = planTeaching([TutorialV3Category.blush]);
    final session = TutorialV3Session(
      id: 'session-1',
      userId: 'user-1',
      analysisId: 'analysis-1',
      sourceMode: TutorialV3SourceMode.standard,
      recommendationId: 'recommendation-1',
      selectedStyleCode: testStyleCode,
      canonicalPreview: preview,
      totalSteps: plan.totalSteps,
      planVersion: TutorialV3PlanVersion.current,
      status: TutorialV3SessionStatus.ready,
      createdAt: DateTime.utc(2026, 8, 26),
      updatedAt: DateTime.utc(2026, 8, 26),
    );

    // The destination is an existing generated_images row, not something the
    // tutorial produces.
    expect(session.canonicalPreview.generatedImageId, 'generated-image-1');
    expect(session.canonicalPreview.storagePath, preview.storagePath);
    expect(session.totalSteps, plan.totalSteps);
    expect(session.activeRecommendationId, 'recommendation-1');
  });

  test('a Kit session carries only the Kit recommendation', () {
    const preview = TutorialV3CanonicalPreview(
      generatedImageId: 'kit-image-1',
      storagePath: 'user/analyses/a/kit-generated/k/preview_0001.png',
      sourceMode: TutorialV3SourceMode.makeupKit,
    );
    final session = TutorialV3Session(
      id: 'session-2',
      userId: 'user-1',
      analysisId: 'analysis-1',
      sourceMode: TutorialV3SourceMode.makeupKit,
      kitRecommendationId: 'kit-recommendation-1',
      selectedStyleCode: testStyleCode,
      canonicalPreview: preview,
      totalSteps: 2,
      planVersion: TutorialV3PlanVersion.current,
      status: TutorialV3SessionStatus.ready,
      createdAt: DateTime.utc(2026, 8, 26),
      updatedAt: DateTime.utc(2026, 8, 26),
    );

    expect(session.activeRecommendationId, 'kit-recommendation-1');
    expect(session.recommendationId, isNull);
  });
}
