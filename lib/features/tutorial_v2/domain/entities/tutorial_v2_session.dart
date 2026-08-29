import '../errors/tutorial_v2_failure.dart';
import 'tutorial_v2_plan.dart';
import 'tutorial_v2_plan_context.dart';
import 'tutorial_v2_plan_version.dart';

/// The lifecycle of a tutorial session.
///
/// Asset-level progress is tracked per step (`TutorialV2StepAssets`); this
/// enum tracks only whether the *plan* exists.
enum TutorialV2SessionStatus {
  pending('pending'),
  planning('planning'),
  planReady('plan_ready'),
  planFailed('plan_failed'),

  /// The persisted row cannot be read by this build — a legacy V1 row, or a
  /// row from a newer build. The UI routes away from it instead of
  /// reinterpreting or rewriting it (Source of Truth §21).
  incompatible('incompatible');

  const TutorialV2SessionStatus(this.code);

  final String code;

  bool get hasPlan => this == TutorialV2SessionStatus.planReady;

  static TutorialV2SessionStatus? fromCode(String code) {
    for (final status in values) {
      if (status.code == code) return status;
    }
    return null;
  }
}

/// One user's tutorial for one analysis + recommendation + canonical look.
class TutorialV2Session {
  const TutorialV2Session._({
    required this.id,
    required this.userId,
    required this.analysisId,
    required this.context,
    required this.status,
    required this.totalSteps,
    required this.plan,
    required this.createdAt,
    required this.updatedAt,
  });

  /// A session whose plan is ready.
  ///
  /// [totalSteps] is taken from the plan itself rather than accepted as a
  /// parameter, so `session.total_steps` can never disagree with the
  /// canonical persisted step count (Source of Truth §19).
  factory TutorialV2Session.withPlan({
    required String id,
    required String userId,
    required String analysisId,
    required TutorialV2Plan plan,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) => TutorialV2Session._(
    id: id,
    userId: userId,
    analysisId: analysisId,
    context: plan.context,
    status: TutorialV2SessionStatus.planReady,
    totalSteps: plan.totalSteps,
    plan: plan,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  /// A session that has no plan yet, or whose planning failed.
  ///
  /// Throws [ArgumentError] if given a status that implies a plan exists.
  factory TutorialV2Session.withoutPlan({
    required String id,
    required String userId,
    required String analysisId,
    required TutorialV2PlanContext context,
    required TutorialV2SessionStatus status,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    if (status.hasPlan) {
      throw ArgumentError.value(
        status,
        'status',
        'A session without a plan cannot be plan_ready.',
      );
    }
    return TutorialV2Session._(
      id: id,
      userId: userId,
      analysisId: analysisId,
      context: context,
      status: status,
      totalSteps: 0,
      plan: null,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  final String id;
  final String userId;
  final String analysisId;
  final TutorialV2PlanContext context;
  final TutorialV2SessionStatus status;

  /// Equals `plan.totalSteps` whenever a plan exists, otherwise `0`.
  final int totalSteps;

  final TutorialV2Plan? plan;
  final DateTime createdAt;
  final DateTime updatedAt;

  TutorialV2PlanVersion get planVersion => context.planVersion;

  bool get isReadable => status != TutorialV2SessionStatus.incompatible;

  /// Guards a persisted row's version before it is read as V2.
  ///
  /// Throws [TutorialV2Failure] with
  /// [TutorialV2FailureKind.incompatiblePlanVersion] for a legacy V1 row or
  /// a row written by a newer build. Callers route on the failure instead of
  /// reinterpreting the row.
  static TutorialV2PlanVersion requireReadableVersion(int persistedVersion) {
    final version = TutorialV2PlanVersion.tryParse(persistedVersion);
    if (version != null) return version;
    return throw TutorialV2Failure(
      TutorialV2PlanVersion.isLegacyV1(persistedVersion)
          ? 'This tutorial was saved by an earlier version and cannot be '
                'opened. Start a new tutorial.'
          : 'This tutorial was saved by a newer version of the app. Update '
                'to open it.',
      kind: TutorialV2FailureKind.incompatiblePlanVersion,
      retryable: false,
    );
  }
}
