import 'tutorial_v2_category.dart';
import 'tutorial_v2_cumulative_category_state.dart';

/// Which image a guideline visual is drawn on top of.
enum TutorialV2GuidelineBaseState {
  /// The first step annotates the untouched selfie.
  originalSelfie('original_selfie'),

  /// Every later step annotates the previous step's cumulative result.
  previousCumulativeResult('previous_cumulative_result');

  const TutorialV2GuidelineBaseState(this.code);

  final String code;

  static TutorialV2GuidelineBaseState? fromCode(String code) {
    for (final state in values) {
      if (state.code == code) return state;
    }
    return null;
  }
}

/// Whether a step's result image is generated or reuses an existing asset.
enum TutorialV2ResultMode {
  generate('generate'),

  /// The terminal step points at the already-persisted canonical final
  /// preview. No second "final" image is ever generated (Source of Truth §6).
  canonicalReuse('canonical_reuse');

  const TutorialV2ResultMode(this.code);

  final String code;

  static TutorialV2ResultMode? fromCode(String code) {
    for (final mode in values) {
      if (mode.code == code) return mode;
    }
    return null;
  }
}

/// The guideline-generation intent for one step.
///
/// This type has no public constructor: it can only be produced by
/// [TutorialV2GuidelineInstruction.derive], which copies the placement
/// fields straight off the step's authored content. That is what makes the
/// written instruction and the guideline visual structurally incapable of
/// disagreeing — there is no second place to author placement (Source of
/// Truth §7). A planner cannot supply a guideline intent that differs from
/// the text the user reads, because it never supplies one at all.
class TutorialV2GuidelineInstruction {
  const TutorialV2GuidelineInstruction._({
    required this.baseState,
    required this.lockedCategory,
    required this.zones,
    required this.direction,
    required this.technique,
    required this.intensity,
    required this.mustNotAnnotateCategories,
  });

  /// Derives the guideline intent from a step's authored placement fields.
  ///
  /// [whereToApply], [direction], [technique] and [intensity] are the exact
  /// strings the UI renders, passed through unchanged.
  factory TutorialV2GuidelineInstruction.derive({
    required TutorialV2CumulativeCategoryState categories,
    required String whereToApply,
    required String direction,
    required String technique,
    required String intensity,
  }) {
    final locked = categories.currentCategory;
    return TutorialV2GuidelineInstruction._(
      baseState: categories.isFirstStep
          ? TutorialV2GuidelineBaseState.originalSelfie
          : TutorialV2GuidelineBaseState.previousCumulativeResult,
      lockedCategory: locked,
      zones: whereToApply,
      direction: direction,
      technique: technique,
      intensity: intensity,
      // A guideline teaches placement for the current category only. Every
      // other category — already completed or still ahead — must carry no
      // arrows, zones or markers, or the user cannot tell what this step
      // is asking them to do (Source of Truth §13).
      mustNotAnnotateCategories: List.unmodifiable(
        TutorialV2Category.values
            .where((category) => category != locked)
            .toList(),
      ),
    );
  }

  final TutorialV2GuidelineBaseState baseState;

  /// The only category this guideline may annotate.
  final TutorialV2Category lockedCategory;

  /// Where to apply — identical to the step's `whereToApply`.
  final String zones;

  /// Identical to the step's `direction`.
  final String direction;

  /// Identical to the step's `technique`.
  final String technique;

  /// Identical to the step's `intensity`.
  final String intensity;

  final List<TutorialV2Category> mustNotAnnotateCategories;
}

/// The result-generation intent for one step.
///
/// Like [TutorialV2GuidelineInstruction] this is derived, never authored, so
/// the result prompt cannot express a different intent from the written
/// instruction or the guideline.
class TutorialV2ResultInstruction {
  const TutorialV2ResultInstruction._({
    required this.mode,
    required this.appliedCategory,
    required this.preserveCategories,
    required this.forbiddenCategories,
    required this.appliedDescription,
    required this.technique,
    required this.intensity,
    required this.targetLookCues,
  });

  /// Derives the result intent from a step's authored content.
  ///
  /// The terminal [TutorialV2Category.finalLook] step is forced to
  /// [TutorialV2ResultMode.canonicalReuse]; every other step generates.
  factory TutorialV2ResultInstruction.derive({
    required TutorialV2CumulativeCategoryState categories,
    required String whatToApply,
    required String technique,
    required String intensity,
    required String targetLookCues,
  }) {
    final current = categories.currentCategory;
    return TutorialV2ResultInstruction._(
      mode: current.isFinalLook
          ? TutorialV2ResultMode.canonicalReuse
          : TutorialV2ResultMode.generate,
      appliedCategory: current,
      preserveCategories: categories.previouslyCompletedCategories,
      forbiddenCategories: categories.futureCategories,
      appliedDescription: whatToApply,
      technique: technique,
      intensity: intensity,
      targetLookCues: targetLookCues,
    );
  }

  final TutorialV2ResultMode mode;

  /// The only category this step may change.
  final TutorialV2Category appliedCategory;

  /// Already-completed categories that must survive unchanged.
  final List<TutorialV2Category> preserveCategories;

  /// Planned categories that must not appear yet.
  final List<TutorialV2Category> forbiddenCategories;

  /// What to apply — identical to the step's `whatToApply`.
  final String appliedDescription;

  /// Identical to the step's `technique`.
  final String technique;

  /// Identical to the step's `intensity`.
  final String intensity;

  /// Cues tying this step to the canonical final target.
  final String targetLookCues;

  bool get isCanonicalReuse => mode == TutorialV2ResultMode.canonicalReuse;
}
