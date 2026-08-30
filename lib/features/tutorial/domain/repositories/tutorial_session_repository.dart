import '../entities/canonical_preview_ref.dart';
import '../entities/tutorial_session.dart';

/// Creates and retrieves tutorial sessions, and materialises their steps.
abstract interface class TutorialSessionRepository {
  /// Returns the existing session for [preview], or `null`.
  ///
  /// Sessions are keyed by canonical preview rather than by recommendation so
  /// that regenerating a preview — a new visual target — cannot silently reuse
  /// a session whose manifest and steps describe the previous image.
  ///
  /// Performs no AI work, so it is safe on any rebuild.
  Future<TutorialSession?> loadForCanonicalPreview(CanonicalPreviewRef preview);

  Future<TutorialSession> loadById(String sessionId);

  /// Creates the step records for every category the accepted manifest
  /// includes, and returns the session with its steps attached.
  ///
  /// Idempotent by design: existing records are reused rather than replaced, a
  /// step already ready is never rebuilt, and calling this repeatedly for the
  /// same session converges on the same set of rows. It creates records only —
  /// no guideline image is generated and nothing is paid for here.
  Future<TutorialSession> ensureSteps(TutorialSession session);

  Future<void> delete(String sessionId);
}
