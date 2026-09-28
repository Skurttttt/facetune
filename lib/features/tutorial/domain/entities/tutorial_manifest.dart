import 'look_product_snapshot.dart';
import 'recommendation_source_mode.dart';
import 'tutorial_category.dart';

/// Whether a supported category is visibly part of one specific final look.
///
/// [uncertain] is a first-class outcome, not a placeholder to be collapsed
/// into one of the other two. Treating it as [present] fabricates a step the
/// look may not contain; treating it as [absent] silently drops a step the
/// look may need. It is preserved so the system can decide deliberately.
enum TutorialCategoryPresence {
  present('present'),
  absent('absent'),
  uncertain('uncertain');

  const TutorialCategoryPresence(this.code);

  final String code;

  static TutorialCategoryPresence? fromCode(String code) {
    for (final presence in values) {
      if (presence.code == code) return presence;
    }
    return null;
  }
}

/// Lifecycle of the visual manifest analysis.
///
/// Explicit states rather than booleans: "has a manifest" and "the manifest
/// analysis failed" and "analysis has not started" are three different
/// situations that a nullable flag cannot distinguish.
enum TutorialManifestStatus {
  pending('pending'),
  analyzing('analyzing'),
  accepted('accepted'),
  failed('failed'),

  /// The analysis completed, and the canonical preview visibly contains a
  /// makeup category with no validated owned-product selection behind it.
  ///
  /// My Makeup Kit only, and a diagnostic rather than a failure: the manifest
  /// is complete and usable (see [TutorialManifest.isUsable]). The unbacked
  /// category is simply never a step, because the look's product snapshot —
  /// not the image — decides which steps exist. Kept distinct from [accepted]
  /// so the persisted record stays truthful about what the analyzer saw.
  kitPreviewMismatch('kit_preview_mismatch');

  const TutorialManifestStatus(this.code);

  final String code;

  static TutorialManifestStatus? fromCode(String code) {
    for (final status in values) {
      if (status.code == code) return status;
    }
    return null;
  }
}

/// The verdict for one supported category within one manifest.
class TutorialManifestItem {
  const TutorialManifestItem({
    required this.category,
    required this.presence,
    this.visualConfidence,
    this.productBacked = false,
  });

  final TutorialCategory category;
  final TutorialCategoryPresence presence;

  /// Optional evidence score in `0.0..1.0`, when the analyzer supplies one.
  ///
  /// Deliberately not thresholded anywhere in the domain. SoT forbids
  /// hardcoding confidence cutoffs before controlled QA produces evidence for
  /// them, so this is carried for diagnostics and later tuning only.
  final double? visualConfidence;

  /// Whether this category maps to at least one validated owned-product
  /// snapshot item. Always `false` in Standard Mode.
  final bool productBacked;
}

/// The accepted decision about which supported categories are visibly part of
/// one canonical final preview.
///
/// A manifest is scoped to a specific canonical preview. Regenerating the
/// preview produces a new visual target, so the old manifest stops being
/// authoritative and a new one must be analyzed — see [canonicalPreviewId].
///
/// Once accepted, a manifest is reused. It is never re-analyzed on widget
/// rebuild, route rebuild, app resume, or a simple reopen, because analysis is
/// a paid AI call.
class TutorialManifest {
  TutorialManifest({
    required this.canonicalPreviewId,
    required this.sourceMode,
    required this.status,
    required List<TutorialManifestItem> items,
    required this.modelId,
    required this.promptVersion,
    required this.schemaVersion,
    required this.createdAt,
  }) : items = List<TutorialManifestItem>.unmodifiable(items);

  /// The canonical final preview this manifest describes. A manifest is only
  /// valid for this exact visual target.
  final String canonicalPreviewId;

  final RecommendationSourceMode sourceMode;
  final TutorialManifestStatus status;
  final List<TutorialManifestItem> items;

  /// The analyzer model, prompt version, and response schema version as
  /// reported by the server. Recorded for provenance and cache invalidation;
  /// never chosen by the client.
  final String modelId;
  final String promptVersion;
  final String schemaVersion;

  final DateTime createdAt;

  /// The categories that become tutorial steps, in deterministic logical
  /// order.
  ///
  /// Standard Mode: only [TutorialCategoryPresence.present] qualifies.
  /// [uncertain] is excluded by design — it is surfaced through
  /// [uncertainCategories] for deliberate handling rather than being quietly
  /// promoted.
  ///
  /// My Makeup Kit: every category a selected product backs, whatever the
  /// visual verdict. The look's immutable product snapshot decides which steps
  /// exist; the image only informs where and how. A category no selected
  /// product backs is never a step, even when it is visible.
  ///
  /// Inclusion and order are computed independently: this filters, then
  /// [TutorialCategory.orderedSubset] sorts. Removing categories therefore
  /// never disturbs the relative sequence of those that remain.
  List<TutorialCategory> get includedCategories =>
      TutorialCategory.orderedSubset(
        items
            .where(
              (item) => sourceMode == RecommendationSourceMode.myMakeupKit
                  ? item.productBacked
                  : item.presence == TutorialCategoryPresence.present,
            )
            .map((item) => item.category),
      );

  /// [includedCategories], narrowed to what [snapshot] can actually present.
  ///
  /// In My Makeup Kit a persisted `product_backed` flag is only a record of the
  /// snapshot at analysis time, so a category also has to be covered by the
  /// look's snapshot now. The check can only remove a category, never add one.
  /// Standard Mode has no snapshot and is returned unchanged.
  List<TutorialCategory> includedCategoriesFor(LookProductSnapshot snapshot) =>
      sourceMode == RecommendationSourceMode.myMakeupKit
      ? List<TutorialCategory>.unmodifiable(
          includedCategories.where(snapshot.covers),
        )
      : includedCategories;

  /// Categories the analyzer could not confidently resolve, in deterministic
  /// logical order.
  List<TutorialCategory> get uncertainCategories =>
      TutorialCategory.orderedSubset(
        items
            .where(
              (item) => item.presence == TutorialCategoryPresence.uncertain,
            )
            .map((item) => item.category),
      );

  /// Categories visibly present in the canonical preview that have no
  /// validated owned-product selection behind them.
  ///
  /// Always empty in Standard Mode, which has no ownership requirement. A
  /// non-empty result in My Makeup Kit mode is the `kit_preview_mismatch`
  /// diagnostic: the preview shows makeup no selected product accounts for.
  /// Those categories never become steps — no product is invented and there is
  /// no fall back to Standard Mode — but they no longer block the tutorial.
  List<TutorialCategory> get unbackedPresentCategories =>
      sourceMode == RecommendationSourceMode.standard
      ? const <TutorialCategory>[]
      : TutorialCategory.orderedSubset(
          items
              .where(
                (item) =>
                    item.presence == TutorialCategoryPresence.present &&
                    !item.productBacked,
              )
              .map((item) => item.category),
        );

  /// Whether the preview visibly shows makeup no selected product accounts for.
  ///
  /// True only in My Makeup Kit mode. A diagnostic, not a block: the unbacked
  /// categories are left out of the tutorial and every selected category still
  /// gets its step.
  bool get hasKitPreviewMismatch => unbackedPresentCategories.isNotEmpty;

  /// Whether this manifest may be used to build tutorial steps.
  ///
  /// Standard Mode: only [TutorialManifestStatus.accepted].
  /// My Makeup Kit: also [TutorialManifestStatus.kitPreviewMismatch], which in
  /// this mode records the diagnostic above rather than a failed analysis.
  bool get isUsable =>
      status == TutorialManifestStatus.accepted ||
      (sourceMode == RecommendationSourceMode.myMakeupKit &&
          status == TutorialManifestStatus.kitPreviewMismatch);

  /// The verdict for [category], or `null` when the manifest does not cover it.
  TutorialManifestItem? itemFor(TutorialCategory category) {
    for (final item in items) {
      if (item.category == category) return item;
    }
    return null;
  }
}
