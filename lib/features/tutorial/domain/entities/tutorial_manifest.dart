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

  /// The analysis completed, but the canonical preview visibly contains a
  /// makeup category with no validated owned-product selection behind it.
  ///
  /// Distinct from [failed]: nothing went wrong mechanically — the manifest is
  /// perfectly readable, and that is exactly the problem. It says the preview
  /// promises a look the user cannot reproduce from their own kit. Kept
  /// separate so this can never be retried as if it were a transient error, and
  /// so the preview is not treated as a valid canonical My Makeup Kit result
  /// until the inconsistency is resolved.
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
  /// Only [TutorialCategoryPresence.present] qualifies. [uncertain] is
  /// excluded here by design — it is surfaced through [uncertainCategories]
  /// for deliberate handling rather than being quietly promoted.
  ///
  /// Inclusion and order are computed independently: this filters, then
  /// [TutorialCategory.orderedSubset] sorts. Removing categories therefore
  /// never disturbs the relative sequence of those that remain.
  List<TutorialCategory> get includedCategories =>
      TutorialCategory.orderedSubset(
        items
            .where((item) => item.presence == TutorialCategoryPresence.present)
            .map((item) => item.category),
      );

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
  /// condition: the preview promises makeup the user cannot reproduce from
  /// their own kit. It is never resolved by inventing a product or by falling
  /// back to Standard Mode.
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

  /// Whether this manifest describes a look the user cannot reproduce from
  /// their own kit.
  ///
  /// True only in My Makeup Kit mode, and only when the canonical preview
  /// visibly contains a category no validated owned product backs. The correct
  /// response is never to invent a product, never to drop to Standard Mode, and
  /// never to build the step anyway — it is to surface
  /// [TutorialManifestStatus.kitPreviewMismatch] for controlled recovery.
  bool get hasKitPreviewMismatch => unbackedPresentCategories.isNotEmpty;

  /// Whether an accepted manifest may be used to build tutorial steps.
  ///
  /// [TutorialManifestStatus.kitPreviewMismatch] is deliberately excluded even
  /// though the analysis itself succeeded.
  bool get isUsable =>
      status == TutorialManifestStatus.accepted && !hasKitPreviewMismatch;

  /// The verdict for [category], or `null` when the manifest does not cover it.
  TutorialManifestItem? itemFor(TutorialCategory category) {
    for (final item in items) {
      if (item.category == category) return item;
    }
    return null;
  }
}
