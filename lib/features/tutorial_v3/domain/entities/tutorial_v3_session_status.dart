/// The lifecycle of a tutorial session.
///
/// The status describes planning, not appearance: a session is [ready] once
/// its full plan is validated and persisted, regardless of how many
/// guideline images have been generated. Per-step generation progress lives
/// on each step's guideline status instead.
enum TutorialV3SessionStatus {
  /// The plan is being generated and validated. No steps are persisted yet.
  planning('planning'),

  /// A complete validated plan is persisted and the tutorial is usable.
  ready('ready'),

  /// Planning failed. No partial plan is exposed as usable.
  failed('failed');

  const TutorialV3SessionStatus(this.code);

  final String code;

  static TutorialV3SessionStatus? fromCode(String code) {
    for (final status in values) {
      if (status.code == code) return status;
    }
    return null;
  }
}
