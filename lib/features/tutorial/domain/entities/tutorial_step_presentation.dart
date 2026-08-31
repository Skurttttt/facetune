import 'look_product_snapshot.dart';
import 'recommendation_source_mode.dart';
import 'standard_look_entry.dart';
import 'tutorial_category.dart';
import 'tutorial_instruction.dart';
import 'tutorial_shade_details.dart';
import 'validated_look_plan.dart';

/// What to show in the product area of a tutorial step, and where it came from.
///
/// Sealed for the same reason [LookPlanSource] is: the mode must be matched on,
/// never inferred from which list happens to be non-empty. Today the tutorial
/// page branches on a boolean and then picks a list by hand, which is a
/// correctness question the compiler cannot help with. Matching on this
/// hierarchy makes the two modes exhaustive and makes it impossible to render
/// kit products from anything but a validated snapshot.
sealed class TutorialProductPresentation {
  const TutorialProductPresentation({required this.category});

  final TutorialCategory category;

  RecommendationSourceMode get sourceMode;

  /// The shade blocks to render, one per contributing entry or product.
  ///
  /// A list rather than a single value because one tutorial category can draw
  /// on more than one source: a Lips step is fed by both the lipstick and the
  /// lip gloss, in either mode.
  List<TutorialShadeDetails> get shades;

  /// Whether there is anything to render at all. An empty product area is a
  /// truthful state — the recommendation may say nothing about a category, and
  /// a step can be visually grounded without owned-product wording.
  bool get isEmpty => shades.isEmpty;
}

/// Standard Mode: brand-neutral colour guidance.
///
/// Carries shade descriptions and nothing purchasable. The type has no product
/// name, brand, retailer, or price field, so brand neutrality here is a
/// property of the contract rather than a rule someone has to remember.
final class StandardShadePresentation extends TutorialProductPresentation {
  StandardShadePresentation({
    required super.category,
    required List<StandardLookEntry> entries,
  }) : entries = List<StandardLookEntry>.unmodifiable(entries);

  /// The validated recommendation entries feeding this category, in plan-key
  /// order.
  final List<StandardLookEntry> entries;

  @override
  RecommendationSourceMode get sourceMode => RecommendationSourceMode.standard;

  @override
  List<TutorialShadeDetails> get shades =>
      List<TutorialShadeDetails>.unmodifiable(
        entries.map(TutorialShadeDetails.fromStandardEntry),
      );
}

/// My Makeup Kit: the user's own products, exactly as captured.
///
/// [items] is the identity authority and is the only place a product name may
/// come from. It is an immutable snapshot taken when the look was validated,
/// so a product edited or deleted since then still presents as it was used —
/// live inventory is never consulted here.
final class MyMakeupKitProductPresentation extends TutorialProductPresentation {
  MyMakeupKitProductPresentation({
    required super.category,
    required List<LookProductSnapshotItem> items,
  }) : items = List<LookProductSnapshotItem>.unmodifiable(items);

  final List<LookProductSnapshotItem> items;

  @override
  RecommendationSourceMode get sourceMode =>
      RecommendationSourceMode.myMakeupKit;

  @override
  List<TutorialShadeDetails> get shades =>
      List<TutorialShadeDetails>.unmodifiable(
        items.map(TutorialShadeDetails.fromSnapshotItem),
      );
}

/// Everything one tutorial step presents beside its guideline image.
///
/// The four parts answer four different questions, from four different
/// authorities, and the type keeps them separate on purpose:
///
///  * the guideline image shows **where** — grounded in the canonical preview;
///  * [instructions] explain **how**, each tied to a visible guide marking;
///  * [product] says **what to use** — the recommendation, or the owned-product
///    snapshot;
///  * [goal] states **what to achieve** for this category.
///
/// [goal] and [instructions] are optional and empty by default. This phase
/// defines the shape; it authors no copy, and nothing here generates wording
/// from a style name or a category. An unauthored step presents its image and
/// its product data and says nothing it cannot support.
///
/// Nothing in this contract needs a database column. Every value is derived
/// from data the system already persists and validates.
class TutorialStepPresentation {
  const TutorialStepPresentation({
    required this.category,
    required this.product,
    this.goal,
    this.instructions = TutorialInstructionSequence.empty,
  });

  final TutorialCategory category;

  /// One short sentence describing the result for this category, grounded in
  /// the canonical final preview. Null when none has been authored.
  final String? goal;

  final TutorialInstructionSequence instructions;

  final TutorialProductPresentation product;

  RecommendationSourceMode get sourceMode => product.sourceMode;

  /// Builds the presentation shell for [category] from a validated look plan.
  ///
  /// This is the single place the mode decides which product authority applies,
  /// so no caller has to branch on it. Standard Mode reads the brand-neutral
  /// entries; My Makeup Kit reads the immutable snapshot. Neither can reach the
  /// other's data, because [ValidatedLookPlan] returns empty for the mode that
  /// does not apply.
  factory TutorialStepPresentation.fromLookPlan(
    ValidatedLookPlan plan,
    TutorialCategory category, {
    String? goal,
    TutorialInstructionSequence instructions =
        TutorialInstructionSequence.empty,
  }) {
    final product = switch (plan.source) {
      StandardLookPlanSource() => StandardShadePresentation(
        category: category,
        entries: plan.standardEntriesFor(category),
      ),
      MyMakeupKitLookPlanSource(:final productSnapshot) =>
        MyMakeupKitProductPresentation(
          category: category,
          items: productSnapshot.itemsFor(category),
        ),
    };
    return TutorialStepPresentation(
      category: category,
      product: product,
      goal: goal,
      instructions: instructions,
    );
  }
}
