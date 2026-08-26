/// What a caller should do next with a tutorial it just loaded.
///
/// This is **derived at read time and never stored**. The persisted column is
/// [TutorialV3SessionStatus], which only records how far *planning* got
/// (`planning` / `ready` / `failed`); readiness combines that with the actual
/// state of the persisted steps.
///
/// The two therefore do not map one-to-one, and the overlap in names is worth
/// reading carefully: a stored status of `ready` means "a plan is persisted"
/// and shows up here as [planReady], [generating] or [ready] depending on how
/// many guidelines exist yet.
///
/// [incompatible] can never be stored — the table's status check constraint
/// does not allow it. It is inferred from a plan version this build cannot
/// interpret, which is how a V1, V2 or future-build row is refused instead of
/// being reinterpreted as V3.
enum TutorialV3SessionReadiness {
  /// The persisted plan version is not one this build can read. The session
  /// is surfaced, not decoded, and no operation may mutate it.
  incompatible('incompatible'),

  /// No usable plan is persisted yet. The caller should plan.
  planning('planning'),

  /// Planning failed. The caller may retry planning.
  failed('failed'),

  /// A complete plan is persisted and at least one guideline is still
  /// missing. The caller should generate the next one.
  planReady('plan_ready'),

  /// A guideline generation is currently in flight.
  generating('generating'),

  /// Every step that needs a guideline has one. Nothing left to generate.
  ready('ready');

  const TutorialV3SessionReadiness(this.code);

  final String code;

  /// Whether the tutorial can be displayed at all.
  bool get hasUsablePlan =>
      this == TutorialV3SessionReadiness.planReady ||
      this == TutorialV3SessionReadiness.generating ||
      this == TutorialV3SessionReadiness.ready;

  /// Whether planning should run.
  bool get needsPlan =>
      this == TutorialV3SessionReadiness.planning ||
      this == TutorialV3SessionReadiness.failed;
}
