import '../errors/tutorial_v3_failure.dart';
import 'tutorial_v3_guideline_status.dart';
import 'tutorial_v3_session.dart';
import 'tutorial_v3_session_readiness.dart';
import 'tutorial_v3_session_status.dart';
import 'tutorial_v3_step.dart';
import 'tutorial_v3_step_spec.dart';

/// One consistent read of a persisted tutorial.
///
/// The hierarchy is sealed and has exactly two variants, because a stored
/// session is either readable by this build or it is not. Modelling the
/// unreadable case as a value rather than an exception is what lets a
/// reopened tutorial report `incompatible` instead of crashing the screen —
/// and modelling it as a *separate type* is what stops any caller from
/// reading steps that were never decoded.
sealed class TutorialV3SessionSnapshot {
  const TutorialV3SessionSnapshot();

  String get sessionId;

  /// What the caller should do next. Derived, never stored.
  TutorialV3SessionReadiness get readiness;

  /// Narrows to a readable session, or throws if this build cannot interpret
  /// the persisted plan version.
  ///
  /// Use this at the point where a caller genuinely needs the plan. Anything
  /// that merely reports state should switch on the variant instead.
  TutorialV3LoadedSession get requireLoaded => switch (this) {
    TutorialV3LoadedSession() => this as TutorialV3LoadedSession,
    TutorialV3IncompatibleSession(:final persistedPlanVersion) =>
      throw TutorialV3Failure(
        'This tutorial was created by a different version of FaceTune '
        '(plan version $persistedPlanVersion) and cannot be opened here.',
        kind: TutorialV3FailureKind.validation,
        retryable: false,
      ),
  };
}

/// A session this build can read, together with its persisted steps.
final class TutorialV3LoadedSession extends TutorialV3SessionSnapshot {
  const TutorialV3LoadedSession({required this.session, required this.steps});

  final TutorialV3Session session;

  /// Steps in ascending step index. Empty until a plan is persisted.
  final List<TutorialV3Step> steps;

  @override
  String get sessionId => session.id;

  /// Whether a complete plan is persisted and its length agrees with the
  /// session's recorded total.
  bool get hasPlan => steps.isNotEmpty && steps.length == session.totalSteps;

  @override
  TutorialV3SessionReadiness get readiness {
    if (session.status == TutorialV3SessionStatus.failed) {
      return TutorialV3SessionReadiness.failed;
    }
    if (!hasPlan) return TutorialV3SessionReadiness.planning;
    if (steps.any(
      (step) => step.guidelineStatus == TutorialV3GuidelineStatus.generating,
    )) {
      return TutorialV3SessionReadiness.generating;
    }
    if (guidelineSteps.every((step) => step.hasGuideline)) {
      return TutorialV3SessionReadiness.ready;
    }
    return TutorialV3SessionReadiness.planReady;
  }

  /// The steps that need a generated guideline, i.e. everything but the final
  /// look.
  Iterable<TutorialV3Step> get guidelineSteps =>
      steps.where((step) => !step.isFinalLook);

  TutorialV3Step? stepAt(int stepIndex) {
    for (final step in steps) {
      if (step.stepIndex == stepIndex) return step;
    }
    return null;
  }

  /// The terminal step, or `null` when no plan is persisted yet.
  TutorialV3Step? get finalStep {
    if (steps.isEmpty) return null;
    final last = steps.last;
    return last.spec is TutorialV3FinalLookStepSpec ? last : null;
  }

  /// The next step that still needs a guideline, in plan order.
  ///
  /// This is what makes reopening a tutorial resumable: whatever was already
  /// generated is kept, and generation picks up at the first gap. A step that
  /// has exhausted its retries is skipped so a permanently failing step does
  /// not block the rest of the tutorial.
  TutorialV3Step? nextGeneratableStep({required int maxAttempts}) {
    for (final step in guidelineSteps) {
      if (step.hasGuideline) continue;
      if (step.guidelineStatus == TutorialV3GuidelineStatus.generating) {
        continue;
      }
      if (step.attemptCount >= maxAttempts) continue;
      return step;
    }
    return null;
  }
}

/// A stored session whose plan version this build cannot interpret.
///
/// Only the row's identity is exposed. The steps are deliberately not
/// decoded: their Step Specs belong to a schema this build does not know, and
/// guessing at them is exactly the silent reinterpretation V3 forbids.
///
/// Nothing here is repaired or rewritten. A V1 or V2 row keeps its own data,
/// and a row from a newer build is left for that build to read.
final class TutorialV3IncompatibleSession extends TutorialV3SessionSnapshot {
  const TutorialV3IncompatibleSession({
    required this.sessionId,
    required this.persistedPlanVersion,
  });

  @override
  final String sessionId;

  /// The `plan_version` actually stored on the row.
  final int persistedPlanVersion;

  @override
  TutorialV3SessionReadiness get readiness =>
      TutorialV3SessionReadiness.incompatible;
}
