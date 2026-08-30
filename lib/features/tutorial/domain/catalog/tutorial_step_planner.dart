import '../entities/look_product_snapshot.dart';
import '../entities/recommendation_source_mode.dart';
import '../entities/tutorial_category.dart';
import '../entities/tutorial_manifest.dart';
import '../entities/tutorial_step.dart';
import '../entities/validated_look_plan.dart';
import '../errors/tutorial_failure.dart';

/// One step the tutorial should contain, before any record exists for it.
class PlannedTutorialStep {
  const PlannedTutorialStep({
    required this.category,
    required this.position,
    required this.productSnapshotItems,
  });

  final TutorialCategory category;

  /// 1-based position among the INCLUDED steps — the N in "Step X of N" is the
  /// number of planned steps, never the size of the vocabulary.
  final int position;

  /// The validated owned product(s) this step presents. Always empty in
  /// Standard Mode.
  final List<LookProductSnapshotItem> productSnapshotItems;
}

/// Turns an accepted manifest plus its validated look plan into the exact set
/// of steps a tutorial should contain.
///
/// Pure and deterministic: the same manifest and plan always produce the same
/// steps in the same order, with no I/O and no AI. That is what makes it safe
/// to call on every reopen — planning costs nothing, so a widget rebuild can
/// never trigger paid work.
abstract final class TutorialStepPlanner {
  /// Plans the steps for [manifest] under [lookPlan].
  ///
  /// Throws a [TutorialFailure] when the manifest is not usable — unaccepted,
  /// or blocked by a kit-preview mismatch. Planning around an inconsistent
  /// manifest would be exactly the "misleading tutorial step" the architecture
  /// forbids.
  static List<PlannedTutorialStep> plan({
    required TutorialManifest manifest,
    required ValidatedLookPlan lookPlan,
  }) {
    if (manifest.sourceMode != lookPlan.sourceMode) {
      throw const TutorialFailure(
        'This tutorial could not be prepared.',
        kind: TutorialFailureKind.validation,
        retryable: false,
      );
    }
    if (manifest.hasKitPreviewMismatch) {
      throw const TutorialFailure(
        'This look uses makeup that is not in your kit yet.',
        kind: TutorialFailureKind.kitPreviewMismatch,
        retryable: false,
      );
    }
    if (manifest.status != TutorialManifestStatus.accepted) {
      throw const TutorialFailure(
        'This tutorial is not ready yet.',
        kind: TutorialFailureKind.manifestUnavailable,
      );
    }

    // includedCategories is already filtered and in deterministic vocabulary
    // order, so positions are simply its indices. Assigning them here — after
    // filtering — is what keeps "which steps" and "in what order" independent.
    final included = manifest.includedCategories;
    final snapshot = lookPlan.productSnapshot;
    final isKit = lookPlan.sourceMode == RecommendationSourceMode.myMakeupKit;

    return List<PlannedTutorialStep>.unmodifiable(<PlannedTutorialStep>[
      for (var index = 0; index < included.length; index += 1)
        PlannedTutorialStep(
          category: included[index],
          position: index + 1,
          // Linked to the exact immutable snapshot item(s) for this category.
          // A Lips step legitimately carries both a Lipstick and a Lip Gloss.
          // Standard Mode has no owned-product selection, so the list is empty
          // rather than fabricated.
          productSnapshotItems: isKit
              ? snapshot.itemsFor(included[index])
              : const <LookProductSnapshotItem>[],
        ),
    ]);
  }

  /// Reconciles planned steps against the records that already exist.
  ///
  /// Existing rows are kept as-is — critically, a step already
  /// [TutorialStepStatus.ready] is never rebuilt, because its guideline image
  /// was paid for once and must not be regenerated on reopen. Only genuinely
  /// missing categories are reported as needing creation.
  static List<PlannedTutorialStep> missingSteps({
    required List<PlannedTutorialStep> planned,
    required List<TutorialStep> existing,
  }) {
    final present = existing.map((step) => step.category).toSet();
    return List<PlannedTutorialStep>.unmodifiable(
      planned.where((step) => !present.contains(step.category)),
    );
  }

  /// Whether every planned step already has a record.
  static bool isComplete({
    required List<PlannedTutorialStep> planned,
    required List<TutorialStep> existing,
  }) => missingSteps(planned: planned, existing: existing).isEmpty;
}
