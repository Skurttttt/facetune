/// The lifecycle of a single step's guideline image.
///
/// This is runtime state, not plan content: the Step Spec never changes when
/// generation fails, so a failed guideline keeps its instruction and can be
/// retried without re-planning.
///
/// There is deliberately no `result` state. V3 produces guideline images
/// only, so "the makeup result for this step" is not representable.
enum TutorialV3GuidelineStatus {
  /// The final-look step reuses the existing canonical premium preview and
  /// therefore never generates anything.
  notRequired('not_required'),

  /// Planned and persisted, no generation attempted yet.
  pending('pending'),

  /// A generation attempt is in flight. Used to prevent duplicate concurrent
  /// generation for the same `(sessionId, stepIndex)`.
  generating('generating'),

  /// A validated guideline asset exists and must be reused rather than
  /// regenerated.
  ready('ready'),

  /// Generation failed. The Step Spec is intact and a bounded retry is
  /// allowed. A missing guideline is shown as missing — never substituted
  /// with the original selfie or another step's asset.
  failed('failed');

  const TutorialV3GuidelineStatus(this.code);

  final String code;

  /// Whether a generation attempt may be started from this state.
  bool get canStartGeneration =>
      this == TutorialV3GuidelineStatus.pending ||
      this == TutorialV3GuidelineStatus.failed;

  /// Whether this state expects a stored guideline asset to exist.
  bool get expectsAsset => this == TutorialV3GuidelineStatus.ready;

  static TutorialV3GuidelineStatus? fromCode(String code) {
    for (final status in values) {
      if (status.code == code) return status;
    }
    return null;
  }
}
