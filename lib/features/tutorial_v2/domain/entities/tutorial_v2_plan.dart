import '../validation/tutorial_v2_plan_validator.dart';
import 'tutorial_v2_category.dart';
import 'tutorial_v2_cumulative_category_state.dart';
import 'tutorial_v2_plan_context.dart';
import 'tutorial_v2_step_instructions.dart';
import 'tutorial_v2_step_spec.dart';

/// A validated, ordered tutorial plan.
///
/// The plan is the canonical source of the step count: [totalSteps] is
/// simply how many steps were planned, derived from the selected look and
/// the actual recommendation. No fixed length is ever assumed.
class TutorialV2Plan {
  const TutorialV2Plan._({required this.context, required this.steps});

  /// Validates authored [drafts] and builds the plan.
  ///
  /// This is the only way a [TutorialV2StepSpec] comes into existence, which
  /// is what guarantees every step's cumulative state and derived
  /// instructions actually match its position in the sequence.
  ///
  /// Throws [TutorialV2Failure] with
  /// [TutorialV2FailureKind.planValidation] when the plan violates the
  /// contract.
  factory TutorialV2Plan.fromDrafts({
    required TutorialV2PlanContext context,
    required List<TutorialV2StepDraft> drafts,
    Set<String> ownedProductIds = const <String>{},
  }) {
    TutorialV2PlanValidator.validateDrafts(
      context: context,
      drafts: drafts,
      ownedProductIds: ownedProductIds,
    );

    final plannedCategories = drafts
        .map((draft) => draft.category)
        .toList(growable: false);

    final steps = <TutorialV2StepSpec>[];
    for (var index = 0; index < drafts.length; index++) {
      final draft = drafts[index];
      final categories = TutorialV2CumulativeCategoryState(
        // Only real makeup counts as "already applied" — the Final Look
        // marker is never a completed category.
        previouslyCompletedCategories: plannedCategories
            .take(index)
            .where((category) => !category.isFinalLook)
            .toList(growable: false),
        currentCategory: draft.category,
        futureCategories: plannedCategories
            .skip(index + 1)
            .where((category) => !category.isFinalLook)
            .toList(growable: false),
      );

      final resultInstruction = TutorialV2ResultInstruction.derive(
        categories: categories,
        whatToApply: draft.whatToApply,
        technique: draft.technique,
        intensity: draft.intensity,
        targetLookCues: draft.targetLookCues,
      );

      steps.add(
        TutorialV2StepSpec.internal(
          stepIndex: index,
          category: draft.category,
          title: draft.title,
          whatToApply: draft.whatToApply,
          whereToApply: draft.whereToApply,
          direction: draft.direction,
          technique: draft.technique,
          intensity: draft.intensity,
          faceRationale: draft.faceRationale,
          targetLookCues: draft.targetLookCues,
          amount: draft.amount,
          toolSuggestion: draft.toolSuggestion,
          personalizedTip: draft.personalizedTip,
          avoid: draft.avoid,
          productSnapshot: draft.productSnapshot,
          categories: categories,
          // The canonical-reuse step teaches no placement, so it gets no
          // guideline intent at all rather than an empty one.
          guidelineInstruction: draft.category.isFinalLook
              ? null
              : TutorialV2GuidelineInstruction.derive(
                  categories: categories,
                  whereToApply: draft.whereToApply,
                  direction: draft.direction,
                  technique: draft.technique,
                  intensity: draft.intensity,
                ),
          resultInstruction: resultInstruction,
        ),
      );
    }

    return TutorialV2Plan._(
      context: context,
      steps: List.unmodifiable(steps),
    );
  }

  final TutorialV2PlanContext context;
  final List<TutorialV2StepSpec> steps;

  /// The canonical step count. Never a hardcoded number.
  int get totalSteps => steps.length;

  TutorialV2StepSpec get finalStep => steps.last;

  /// Every makeup category this plan teaches, in order, excluding the
  /// terminal Final Look marker.
  List<TutorialV2Category> get plannedCategories => List.unmodifiable(
    steps
        .map((step) => step.category)
        .where((category) => !category.isFinalLook)
        .toList(),
  );

  TutorialV2StepSpec stepAt(int index) => steps[index];

  /// Binds session context to one step, producing everything the written
  /// instruction, the guideline prompt and the result prompt need.
  TutorialV2ResolvedStep resolveStep(int index) => TutorialV2ResolvedStep(
    context: context,
    step: steps[index],
    totalSteps: totalSteps,
  );
}

/// One step bound to its session context.
///
/// This is what generation code consumes. It exists so session-level values
/// (style, face attributes, canonical target) never have to be copied onto
/// each persisted step, while a single object still carries everything a
/// prompt needs.
class TutorialV2ResolvedStep {
  const TutorialV2ResolvedStep({
    required this.context,
    required this.step,
    required this.totalSteps,
  });

  final TutorialV2PlanContext context;
  final TutorialV2StepSpec step;
  final int totalSteps;

  /// "STEP 4 OF 8".
  String get progressLabel => 'STEP ${step.displayNumber} OF $totalSteps';

  bool get isFinalStep => step.stepIndex == totalSteps - 1;
}
