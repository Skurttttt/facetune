/// The lifecycle of one step's mapped geometry.
///
/// Replaces the guideline-image status from V3-2. V3 no longer generates an
/// image per step: the mapper returns normalized coordinates and Flutter draws
/// them over the untouched original (V3-6R). The states are the same shape,
/// but what reaches `ready` is a validated geometry document, not a file.
///
/// This is runtime state, not plan content. A failed mapping never rewrites
/// the Step Spec, so a retry reuses the same instruction rather than
/// re-planning.
///
/// There is deliberately no `result` state — V3 produces no makeup appearance.
enum TutorialV3GeometryStatus {
  /// The final-look step reuses the canonical premium preview and maps no
  /// geometry at all.
  notRequired('not_required'),

  /// Planned and persisted, no mapping attempted yet.
  pending('pending'),

  /// A mapping attempt is in flight. Set by an atomic claim, which is what
  /// prevents duplicate concurrent mapping for one `(sessionId, stepIndex)`.
  generating('generating'),

  /// Validated geometry exists and must be reused rather than re-mapped.
  ready('ready'),

  /// Mapping failed. The Step Spec is intact and a bounded retry is allowed.
  /// A missing overlay is shown as missing — never substituted with a
  /// neighbouring step's geometry or a generic template.
  failed('failed');

  const TutorialV3GeometryStatus(this.code);

  final String code;

  /// Whether a mapping attempt may be started from this state.
  bool get canStartGeneration =>
      this == TutorialV3GeometryStatus.pending ||
      this == TutorialV3GeometryStatus.failed;

  /// Whether this state expects a stored geometry document.
  bool get expectsGeometry => this == TutorialV3GeometryStatus.ready;

  static TutorialV3GeometryStatus? fromCode(String code) {
    for (final status in values) {
      if (status.code == code) return status;
    }
    return null;
  }
}
