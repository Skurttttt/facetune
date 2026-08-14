/// Generation status of an entire [TutorialSession].
///
/// Session-level status is coarser than step-level status
/// ([TutorialStepGenerationStatus]) because planning (deciding step count,
/// order, and categories) happens once per session before any per-step
/// generation begins. See FACETUNE_STEP_BY_STEP_TUTORIAL_GUIDE.md §14.
///
/// [code] is the stable identifier persisted in
/// `tutorial_sessions.generation_status`, not a derivation of the Dart
/// member name.
enum TutorialGenerationStatus {
  notStarted('not_started'),
  planning('planning'),
  queued('queued'),
  generating('generating'),
  partiallyComplete('partially_complete'),
  completed('completed'),
  failed('failed');

  const TutorialGenerationStatus(this.code);

  final String code;

  static TutorialGenerationStatus? fromCode(String code) {
    for (final status in values) {
      if (status.code == code) return status;
    }
    return null;
  }
}

/// Generation status of a single [TutorialStep].
///
/// Deliberately smaller than [TutorialGenerationStatus]: the V1 cost
/// strategy (guide §4.1) reuses the previous step's result image as the
/// current step's placement image, so a step only ever generates one new
/// image (its result) rather than progressing through a planning phase of
/// its own.
///
/// [code] is the stable identifier persisted in
/// `tutorial_steps.generation_status`.
enum TutorialStepGenerationStatus {
  notStarted('not_started'),
  queued('queued'),
  generating('generating'),
  completed('completed'),
  failed('failed');

  const TutorialStepGenerationStatus(this.code);

  final String code;

  static TutorialStepGenerationStatus? fromCode(String code) {
    for (final status in values) {
      if (status.code == code) return status;
    }
    return null;
  }
}
