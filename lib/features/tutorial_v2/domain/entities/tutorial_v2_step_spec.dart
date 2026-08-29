import 'tutorial_v2_category.dart';
import 'tutorial_v2_cumulative_category_state.dart';
import 'tutorial_v2_product_snapshot.dart';
import 'tutorial_v2_step_instructions.dart';

/// One step exactly as the planner authored it, before validation and before
/// the tutorial's derived structure is attached.
///
/// A draft is deliberately positional-free: it carries no step index and no
/// cumulative state, because the planner does not get to decide either. The
/// ordering rules and the cumulative progression are computed by
/// `TutorialV2Plan.fromDrafts` from the draft sequence, so a planner cannot
/// claim a step is "step 3" or that contour is already complete.
///
/// Mirrors the `MakeupKitProductDraft` idiom: a full authored payload that is
/// validated as a whole rather than a sparse patch.
class TutorialV2StepDraft {
  const TutorialV2StepDraft({
    required this.category,
    required this.title,
    required this.whatToApply,
    required this.whereToApply,
    required this.direction,
    required this.technique,
    required this.intensity,
    required this.faceRationale,
    required this.targetLookCues,
    this.amount,
    this.toolSuggestion,
    this.personalizedTip,
    this.avoid,
    this.productSnapshot,
  });

  final TutorialV2Category category;
  final String title;

  /// WHAT to apply.
  final String whatToApply;

  /// WHERE to apply it.
  final String whereToApply;

  /// WHICH DIRECTION to blend or draw.
  final String direction;

  /// HOW to apply it.
  final String technique;

  /// HOW MUCH / what intensity.
  final String intensity;

  /// Why this user received this placement, given their face attributes.
  /// Persisted for debuggability (Source of Truth §8); not necessarily shown.
  final String faceRationale;

  /// How this step ties to the canonical final target.
  final String targetLookCues;

  final String? amount;
  final String? toolSuggestion;
  final String? personalizedTip;
  final String? avoid;

  /// The owned product this step teaches. Required in Kit mode for every
  /// makeup step, forbidden in standard mode and on the final step.
  final TutorialV2ProductSnapshot? productSnapshot;
}

/// A validated, positioned tutorial step.
///
/// This is the single persisted specification that drives all three outputs
/// for the step (Source of Truth §7):
///
/// 1. the written UI instruction — the authored text fields;
/// 2. guideline generation — [guidelineInstruction];
/// 3. result generation — [resultInstruction].
///
/// The two instruction objects are *derived* from the authored fields at
/// construction, never authored separately, so the core invariant holds
/// structurally rather than by convention:
///
/// ```text
/// WRITTEN INSTRUCTION = GUIDELINE INTENT = RESULT GENERATION INTENT
/// ```
///
/// There is no public constructor. Steps come from
/// `TutorialV2Plan.fromDrafts`, which is the only place ordering and
/// cumulative state are computed.
class TutorialV2StepSpec {
  const TutorialV2StepSpec.internal({
    required this.stepIndex,
    required this.category,
    required this.title,
    required this.whatToApply,
    required this.whereToApply,
    required this.direction,
    required this.technique,
    required this.intensity,
    required this.faceRationale,
    required this.targetLookCues,
    required this.categories,
    required this.resultInstruction,
    required this.guidelineInstruction,
    this.amount,
    this.toolSuggestion,
    this.personalizedTip,
    this.avoid,
    this.productSnapshot,
  });

  /// Zero-based position in the plan.
  final int stepIndex;

  final TutorialV2Category category;
  final String title;
  final String whatToApply;
  final String whereToApply;
  final String direction;
  final String technique;
  final String intensity;
  final String faceRationale;
  final String targetLookCues;
  final String? amount;
  final String? toolSuggestion;
  final String? personalizedTip;
  final String? avoid;
  final TutorialV2ProductSnapshot? productSnapshot;

  /// Explicit previous / current / future category sets.
  final TutorialV2CumulativeCategoryState categories;

  /// Null for the canonical-reuse final step, which teaches no new placement
  /// and therefore needs no guideline asset.
  final TutorialV2GuidelineInstruction? guidelineInstruction;

  final TutorialV2ResultInstruction resultInstruction;

  /// One-based step number for display ("STEP 4 OF 8").
  int get displayNumber => stepIndex + 1;

  TutorialV2Category get currentCategory => categories.currentCategory;

  List<TutorialV2Category> get previouslyCompletedCategories =>
      categories.previouslyCompletedCategories;

  List<TutorialV2Category> get cumulativeCategories =>
      categories.cumulativeCategories;

  List<TutorialV2Category> get futureCategories => categories.futureCategories;

  /// Whether this step reuses the canonical final preview instead of
  /// generating a result.
  bool get isCanonicalReuse => resultInstruction.isCanonicalReuse;

  /// Whether this step needs a generated guideline asset.
  bool get requiresGuidelineAsset => guidelineInstruction != null;

  /// Whether this step needs a generated result asset.
  bool get requiresResultAsset => !isCanonicalReuse;
}
