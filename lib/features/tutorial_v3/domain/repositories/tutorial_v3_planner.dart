/// Asks the server to plan a tutorial and persist its Step Specs.
///
/// Takes the session id and nothing else. The analysis, the recommendation,
/// the selected look, the source mode and the Kit inventory are all resolved
/// server-side, so the client cannot influence what the tutorial teaches.
///
/// The plan is not returned. It is read back from the database afterwards,
/// which keeps the persisted rows the single source of truth rather than a
/// response body the client would have to trust.
abstract interface class TutorialV3Planner {
  /// Plans and persists the tutorial for [sessionId].
  ///
  /// Throws `TutorialV3Failure` when planning fails; the session is left
  /// resumable so a retry re-plans rather than starting a second tutorial.
  Future<void> plan({required String sessionId});
}
