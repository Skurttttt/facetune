import '../../../makeup_styles/domain/catalog/makeup_style_catalog.dart';
import '../entities/tutorial_v2_category.dart';
import '../entities/tutorial_v2_plan_context.dart';
import '../entities/tutorial_v2_step_spec.dart';
import '../errors/tutorial_v2_failure.dart';

/// Enforces the Tutorial V2 plan contract before a plan can exist.
///
/// Planner output is never trusted (Source of Truth §24). This is the single
/// place the structural rules live, so the same rules apply whether a plan
/// arrives from the AI planner, from persistence, or from a test fixture.
///
/// What this deliberately does NOT check: how many steps a plan has. Step
/// count is derived from the selected look and the actual recommendation, so
/// any length from one makeup step upward is valid.
abstract final class TutorialV2PlanValidator {
  /// Validates the session-level context.
  static void validateContext(TutorialV2PlanContext context) {
    final errors = _contextErrors(context);
    if (errors.isNotEmpty) throw TutorialV2Failure.planValidation(errors);
  }

  /// Validates authored steps against [context].
  ///
  /// [ownedProductIds] is the set of product ids the user actually owns,
  /// taken from the persisted Kit recommendation's snapshots. It is required
  /// in Kit mode and ignored in standard mode.
  static void validateDrafts({
    required TutorialV2PlanContext context,
    required List<TutorialV2StepDraft> drafts,
    Set<String> ownedProductIds = const <String>{},
  }) {
    final errors = <String>[
      ..._contextErrors(context),
      ..._draftErrors(context, drafts, ownedProductIds),
    ];
    if (errors.isNotEmpty) throw TutorialV2Failure.planValidation(errors);
  }

  static List<String> _contextErrors(TutorialV2PlanContext context) {
    final errors = <String>[];

    if (context.styleCode.trim().isEmpty) {
      errors.add('A tutorial requires the selected makeup style.');
    } else if (!MakeupStyleCatalog.styles.any(
      (style) => style.code == context.styleCode,
    )) {
      errors.add('Unknown makeup style "${context.styleCode}".');
    }

    if (context.recommendation.sourceMode != context.sourceMode) {
      errors.add(
        'The recommendation reference does not match source mode '
        '${context.sourceMode.code}.',
      );
    }
    if (context.recommendation.id.trim().isEmpty) {
      errors.add('A tutorial requires a persisted recommendation.');
    }

    if (context.canonicalFinalPreview.sourceMode != context.sourceMode) {
      errors.add(
        'The canonical final preview does not match source mode '
        '${context.sourceMode.code}.',
      );
    }
    if (context.canonicalFinalPreview.generatedImageId.trim().isEmpty ||
        context.canonicalFinalPreview.storagePath.trim().isEmpty) {
      errors.add('A tutorial requires the canonical final preview.');
    }

    return errors;
  }

  static List<String> _draftErrors(
    TutorialV2PlanContext context,
    List<TutorialV2StepDraft> drafts,
    Set<String> ownedProductIds,
  ) {
    final errors = <String>[];

    if (drafts.isEmpty) {
      errors.add('A tutorial requires at least one step.');
      return errors;
    }

    // Final Look is always last, and appears exactly once.
    final finalLookCount = drafts
        .where((draft) => draft.category.isFinalLook)
        .length;
    if (finalLookCount == 0) {
      errors.add('A tutorial must end with the Final Look step.');
    } else if (finalLookCount > 1) {
      errors.add('A tutorial must contain exactly one Final Look step.');
    } else if (!drafts.last.category.isFinalLook) {
      errors.add('The Final Look step must be last.');
    }

    // A tutorial that only reveals the final look teaches nothing.
    if (drafts.where((draft) => !draft.category.isFinalLook).isEmpty) {
      errors.add('A tutorial requires at least one makeup step.');
    }

    // Duplicate categories, and ordering that contradicts the canonical
    // progression. Strictly increasing rank covers both at once: it rejects
    // repeats, rejects Concealer before Foundation, and rejects Lip Gloss
    // before Lip Color.
    final seen = <TutorialV2Category>{};
    for (var index = 0; index < drafts.length; index++) {
      final category = drafts[index].category;
      if (!seen.add(category)) {
        errors.add('Category ${category.code} appears more than once.');
        continue;
      }
      if (index == 0) continue;
      final previous = drafts[index - 1].category;
      if (category.canonicalRank <= previous.canonicalRank) {
        errors.add(
          'Step ${index + 1} (${category.code}) cannot follow '
          '${previous.code}.',
        );
      }
    }

    for (var index = 0; index < drafts.length; index++) {
      errors.addAll(
        _singleDraftErrors(context, drafts[index], index, ownedProductIds),
      );
    }

    return errors;
  }

  static List<String> _singleDraftErrors(
    TutorialV2PlanContext context,
    TutorialV2StepDraft draft,
    int index,
    Set<String> ownedProductIds,
  ) {
    final errors = <String>[];
    final position = 'Step ${index + 1} (${draft.category.code})';

    void requireText(String value, String field) {
      if (value.trim().isEmpty) errors.add('$position is missing $field.');
    }

    void rejectBlankOptional(String? value, String field) {
      if (value != null && value.trim().isEmpty) {
        errors.add('$position has a blank $field.');
      }
    }

    requireText(draft.title, 'a title');
    requireText(draft.whatToApply, 'what to apply');
    requireText(draft.technique, 'a technique');
    requireText(draft.intensity, 'an intensity');
    requireText(draft.targetLookCues, 'target look cues');

    // The final step is a reveal: it has no placement of its own, so it is
    // not required to carry where/direction/rationale.
    if (!draft.category.isFinalLook) {
      requireText(draft.whereToApply, 'where to apply');
      requireText(draft.direction, 'a direction');
      requireText(draft.faceRationale, 'a face rationale');
    }

    rejectBlankOptional(draft.amount, 'amount');
    rejectBlankOptional(draft.toolSuggestion, 'tool suggestion');
    rejectBlankOptional(draft.personalizedTip, 'tip');
    rejectBlankOptional(draft.avoid, 'avoid note');

    errors.addAll(_productErrors(context, draft, position, ownedProductIds));

    return errors;
  }

  static List<String> _productErrors(
    TutorialV2PlanContext context,
    TutorialV2StepDraft draft,
    String position,
    Set<String> ownedProductIds,
  ) {
    final errors = <String>[];
    final snapshot = draft.productSnapshot;

    if (draft.category.isFinalLook) {
      if (snapshot != null) {
        errors.add('$position must not carry a product.');
      }
      return errors;
    }

    if (!context.sourceMode.isMakeupKit) {
      // Standard mode teaches the standard recommendation. Attaching a Kit
      // product here would smuggle Kit inventory into a non-Kit tutorial.
      if (snapshot != null) {
        errors.add('$position must not carry a Kit product in standard mode.');
      }
      return errors;
    }

    if (snapshot == null) {
      // Kit mode may omit a category the user cannot cover, but it may never
      // teach a category with no owned product behind it.
      errors.add('$position requires an owned product in Kit mode.');
      return errors;
    }

    if (snapshot.category != draft.category) {
      errors.add(
        '$position has a ${snapshot.category.code} product attached.',
      );
    }
    if (snapshot.productId.trim().isEmpty) {
      errors.add('$position has a product with no id.');
    } else if (!ownedProductIds.contains(snapshot.productId)) {
      errors.add('$position references a product the user does not own.');
    }
    if (snapshot.productName != null && snapshot.productName!.trim().isEmpty) {
      errors.add('$position has a blank product name.');
    }
    if (snapshot.colorLabel != null && snapshot.colorLabel!.trim().isEmpty) {
      errors.add('$position has a blank shade name.');
    }

    return errors;
  }
}
