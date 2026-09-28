import 'recommendation_source_mode.dart';
import 'tutorial_ai_configuration.dart';
import 'tutorial_category.dart';
import 'tutorial_manifest.dart';
import 'tutorial_step.dart';
import 'validated_look_plan.dart';

/// Lifecycle of a tutorial session.
///
/// Modelled as explicit states rather than a set of booleans. Flags like
/// `isLoading` plus `hasManifest` plus `hasError` can represent combinations
/// that cannot actually occur, and cannot distinguish "manifest analysis
/// failed" from "manifest analysis has not started".
enum TutorialSessionStatus {
  notStarted('not_started'),
  creatingSession('creating_session'),
  analyzingManifest('analyzing_manifest'),
  manifestReady('manifest_ready'),
  manifestFailed('manifest_failed'),
  ready('ready'),
  generatingStep('generating_step'),
  stepReady('step_ready'),
  stepFailed('step_failed'),

  /// My Makeup Kit only: the canonical preview visibly shows a category no
  /// selected product backs.
  ///
  /// Persisted by the analyzer as a truthful record, and no longer a block: the
  /// session's steps come from the look's product snapshot, so the unbacked
  /// category is left out and every selected one is still taught. It is never
  /// resolved by inventing a product or by continuing in Standard Mode.
  kitPreviewMismatch('kit_preview_mismatch'),

  completed('completed');

  const TutorialSessionStatus(this.code);

  final String code;

  static TutorialSessionStatus? fromCode(String code) {
    for (final status in values) {
      if (status.code == code) return status;
    }
    return null;
  }
}

/// One user's tutorial for one canonical final preview.
///
/// A session binds together the three things a tutorial cannot be built
/// without: the validated look plan (what makeup was decided), the canonical
/// final preview (the visual target every guideline is grounded in), and the
/// accepted manifest (which categories that target visibly contains).
class TutorialSession {
  TutorialSession({
    required this.id,
    required this.userId,
    required this.analysisId,
    required this.canonicalPreviewId,
    required this.lookPlan,
    required this.status,
    this.manifest,
    List<TutorialStep> steps = const <TutorialStep>[],
    this.aiConfiguration,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  }) : steps = List<TutorialStep>.unmodifiable(steps);

  final String id;
  final String userId;

  /// The face analysis this tutorial descends from. Resolves the original
  /// selfie — the tutorial's first mandatory image reference.
  final String analysisId;

  /// The canonical final preview — the tutorial's second mandatory image
  /// reference, and the highest authority for what the finished look contains.
  ///
  /// Regenerating the preview creates a new visual target, which invalidates
  /// the manifest and therefore requires a new session or a versioned manifest.
  final String canonicalPreviewId;

  /// The validated look plan, carrying the explicit source mode and, in My
  /// Makeup Kit mode, the immutable owned-product snapshot.
  final ValidatedLookPlan lookPlan;

  final TutorialSessionStatus status;

  /// The visual manifest. Null before analysis has produced one.
  final TutorialManifest? manifest;

  final List<TutorialStep> steps;

  /// What the server reported it used. Null before generation has run.
  final TutorialAiConfiguration? aiConfiguration;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  /// The explicit source mode, read from the look plan so there is exactly one
  /// source of truth for it.
  RecommendationSourceMode get sourceMode => lookPlan.sourceMode;

  /// The manifest's lifecycle state, or [TutorialManifestStatus.pending] when
  /// no manifest exists yet.
  TutorialManifestStatus get manifestStatus =>
      manifest?.status ?? TutorialManifestStatus.pending;

  /// Whether a usable manifest can be reused instead of re-analyzed.
  ///
  /// Reopening a tutorial checks this rather than re-running the paid
  /// analysis. A manifest is only reusable for the preview it was analyzed
  /// against, so the id must still match. In My Makeup Kit a kit-preview
  /// mismatch is reusable: it is a diagnostic, not a failed analysis.
  bool get hasReusableManifest =>
      manifest != null &&
      manifest!.isUsable &&
      manifest!.canonicalPreviewId == canonicalPreviewId;

  /// Whether the preview showed a category no selected product backs.
  ///
  /// True when either the session was marked
  /// [TutorialSessionStatus.kitPreviewMismatch], or its manifest detected
  /// unbacked categories. A diagnostic only: it never blocks the tutorial,
  /// whose steps come from [includedCategories].
  bool get hasKitPreviewMismatch =>
      status == TutorialSessionStatus.kitPreviewMismatch ||
      (manifest?.hasKitPreviewMismatch ?? false);

  /// The categories the canonical preview shows but no owned product backs.
  ///
  /// Empty in Standard Mode and in a consistent My Makeup Kit look. When
  /// non-empty this is the exact discrepancy to report — never something to
  /// paper over by inventing products.
  List<TutorialCategory> get unbackedPresentCategories =>
      manifest?.unbackedPresentCategories ?? const <TutorialCategory>[];

  /// The categories this tutorial contains, in deterministic logical order.
  /// Empty until a manifest exists.
  ///
  /// In My Makeup Kit these are the categories the look's product snapshot
  /// backs, whatever the visual verdict; in Standard Mode, the visibly present
  /// ones. See [TutorialManifest.includedCategoriesFor].
  List<TutorialCategory> get includedCategories =>
      manifest?.includedCategoriesFor(lookPlan.productSnapshot) ??
      const <TutorialCategory>[];

  /// The steps in deterministic presentation order.
  List<TutorialStep> get orderedSteps => List<TutorialStep>.unmodifiable(
    steps.toList()..sort((a, b) => a.position.compareTo(b.position)),
  );

  /// The step for [category], or `null` when the tutorial does not include it.
  TutorialStep? stepFor(TutorialCategory category) {
    for (final step in steps) {
      if (step.category == category) return step;
    }
    return null;
  }

  /// Steps still needing generation, in deterministic order.
  ///
  /// Excludes anything already [TutorialStepStatus.ready] so a reopen never
  /// pays to regenerate work that already exists.
  List<TutorialStep> get pendingSteps => List<TutorialStep>.unmodifiable(
    orderedSteps.where((step) => step.status == TutorialStepStatus.pending),
  );
}
