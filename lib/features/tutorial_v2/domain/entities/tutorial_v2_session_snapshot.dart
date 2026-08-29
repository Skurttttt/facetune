import 'tutorial_v2_generation_status.dart';
import 'tutorial_v2_plan.dart';
import 'tutorial_v2_plan_context.dart';
import 'tutorial_v2_session.dart';
import 'tutorial_v2_step_spec.dart';

/// Why a persisted session cannot be trusted as-is.
///
/// A session is only reusable when it is [intact]. Anything else means the
/// persisted rows disagree with themselves — a half-written plan, a partial
/// delete, an interrupted insert — and the tutorial must be replanned rather
/// than displayed from bad data.
enum TutorialV2SessionIntegrity {
  intact,

  /// The session claims a ready plan but no step rows came back.
  missingSteps,

  /// `total_steps` disagrees with the number of persisted step rows.
  stepCountMismatch,

  /// Two rows share a `step_index`.
  duplicateStepIndex,

  /// A `step_spec_json` payload could not be decoded, or the decoded steps
  /// do not form a valid plan.
  unreadableSpec,
}

/// The aggregate state of a loaded tutorial.
///
/// Derived, never stored: it is computed from the session status, the plan
/// version, integrity, and the per-step asset statuses.
enum TutorialV2Readiness {
  /// No plan yet.
  planning,

  /// The plan and its written steps exist; assets have not been generated.
  planReady,

  /// At least one asset is being generated.
  generating,

  /// Every asset the plan requires is available.
  ready,

  /// Planning failed, or an asset failed and needs a retry.
  failed,

  /// Written by a plan version this build cannot read.
  incompatible,

  /// Persisted rows disagree with themselves.
  stale,
}

/// One persisted step: its validated spec plus its asset state.
///
/// Assets are not part of [TutorialV2Plan] — the plan is the authored
/// content, the assets are what generation produced from it.
class TutorialV2StepRecord {
  const TutorialV2StepRecord({
    required this.id,
    required this.spec,
    required this.assets,
  });

  final String id;
  final TutorialV2StepSpec spec;
  final TutorialV2StepAssets assets;

  int get stepIndex => spec.stepIndex;

  /// Whether this step has everything it needs to be displayed.
  ///
  /// The canonical-reuse final step requires no generated asset at all, so
  /// it is satisfied the moment it exists.
  bool get isSatisfied {
    final guidelineOk =
        !spec.requiresGuidelineAsset || assets.guidelineStatus.isReady;
    final resultOk = !spec.requiresResultAsset || assets.resultStatus.isReady;
    return guidelineOk && resultOk;
  }

  /// Whether generation is currently in flight for either asset.
  bool get isGenerating =>
      (spec.requiresGuidelineAsset && assets.guidelineStatus.isInFlight) ||
      (spec.requiresResultAsset && assets.resultStatus.isInFlight);

  /// Whether either required asset failed.
  bool get hasFailure =>
      (spec.requiresGuidelineAsset &&
          assets.guidelineStatus == TutorialV2GenerationStatus.failed) ||
      (spec.requiresResultAsset &&
          assets.resultStatus == TutorialV2GenerationStatus.failed);

  TutorialV2StepRecord copyWith({TutorialV2StepAssets? assets}) =>
      TutorialV2StepRecord(
        id: id,
        spec: spec,
        assets: assets ?? this.assets,
      );
}

/// Everything the repository loaded for one tutorial.
///
/// This is what a reopened tutorial page consumes. If [readiness] is
/// [TutorialV2Readiness.ready] there is nothing left to generate, and the
/// page must render the persisted assets rather than regenerating them.
class TutorialV2SessionSnapshot {
  TutorialV2SessionSnapshot({
    required this.id,
    required this.userId,
    required this.analysisId,
    required this.context,
    required this.status,
    required this.totalSteps,
    required this.plan,
    required List<TutorialV2StepRecord> steps,
    required this.integrity,
    required this.createdAt,
    required this.updatedAt,
    this.planError,
  }) : steps = List.unmodifiable(steps);

  final String id;
  final String userId;
  final String analysisId;
  final TutorialV2PlanContext context;
  final TutorialV2SessionStatus status;
  final int totalSteps;
  final TutorialV2Plan? plan;
  final List<TutorialV2StepRecord> steps;
  final TutorialV2SessionIntegrity integrity;
  final String? planError;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isIntact => integrity == TutorialV2SessionIntegrity.intact;

  TutorialV2Readiness get readiness {
    if (status == TutorialV2SessionStatus.incompatible) {
      return TutorialV2Readiness.incompatible;
    }
    if (!isIntact) return TutorialV2Readiness.stale;
    if (status == TutorialV2SessionStatus.planFailed) {
      return TutorialV2Readiness.failed;
    }
    if (!status.hasPlan) return TutorialV2Readiness.planning;
    if (steps.any((step) => step.hasFailure)) return TutorialV2Readiness.failed;
    if (steps.every((step) => step.isSatisfied)) {
      return TutorialV2Readiness.ready;
    }
    if (steps.any((step) => step.isGenerating)) {
      return TutorialV2Readiness.generating;
    }
    return TutorialV2Readiness.planReady;
  }

  /// Whether a revisit can reuse this session instead of replanning.
  bool get isReusable =>
      readiness != TutorialV2Readiness.stale &&
      readiness != TutorialV2Readiness.incompatible;

  /// The first step still missing an asset, or `null` when nothing is
  /// outstanding. Drives which step generation resumes from.
  int? get firstIncompleteStepIndex {
    for (final step in steps) {
      if (!step.isSatisfied) return step.stepIndex;
    }
    return null;
  }

  TutorialV2StepRecord? stepAt(int index) {
    for (final step in steps) {
      if (step.stepIndex == index) return step;
    }
    return null;
  }
}
