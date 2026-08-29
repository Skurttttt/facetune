enum TutorialV2FailureKind {
  offline,
  timeout,
  sessionExpired,

  /// The planner produced a plan that violates the V2 contract. Never
  /// retryable as-is: the plan must be regenerated, not resubmitted.
  planValidation,

  /// A persisted session was written by a plan version this build cannot
  /// read — a legacy V1 row, or a row from a newer build.
  incompatiblePlanVersion,

  notFound,
  unavailable,
  unknown,
}

class TutorialV2Failure implements Exception {
  const TutorialV2Failure(
    this.message, {
    this.kind = TutorialV2FailureKind.unknown,
    this.retryable = true,
  });

  /// A plan that failed contract validation.
  ///
  /// [errors] are joined into a single message so the caller sees every
  /// violation at once instead of fixing them one round-trip at a time.
  factory TutorialV2Failure.planValidation(List<String> errors) =>
      TutorialV2Failure(
        errors.join(' '),
        kind: TutorialV2FailureKind.planValidation,
        retryable: false,
      );

  final String message;
  final TutorialV2FailureKind kind;
  final bool retryable;

  @override
  String toString() => message;
}
