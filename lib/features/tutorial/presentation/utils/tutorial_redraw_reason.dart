/// Why the user wants a tutorial step drawn again.
///
/// A closed vocabulary, so the confirmation sheet cannot grow ad-hoc options
/// and tests can assert exactly what is offered.
///
/// **Nothing consumes these values.** The reason is not persisted, not logged,
/// not sent with the request, and does not alter the prompt, the model, or the
/// resolution — because there is nowhere to put it. `tutorial_v4_steps` has no
/// user-feedback column (`failure_code` is server-written technical state under
/// a not-blank check, and is not client-writable), and `ai_usage_events`
/// constrains `operation` with no metadata field. Storing one would require a
/// schema migration, which V4-QA-7 forbids without explicit approval.
///
/// So this is not feedback collection and must never be described as such. It
/// is a deliberation aid: naming the problem is how the user decides whether
/// redrawing is likely to help, before spending a generation finding out.
///
/// It lives beside the display strings rather than in the domain precisely
/// because it has no domain meaning — putting it in `domain/entities` would
/// imply it is part of the model's state, which is the impression to avoid.
enum TutorialRedrawReason {
  placementWrong,
  guideUnclear,
  faceChanged,
  tooManyGuidelines,
  anotherVersion,
}
