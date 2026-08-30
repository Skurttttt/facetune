import '../entities/canonical_preview_ref.dart';
import '../entities/tutorial_session.dart';

/// Produces and retrieves the visual manifest for a canonical final preview.
///
/// [loadAccepted] and [analyze] are separate operations on purpose. Analysis is
/// a paid multimodal AI call, so callers must be able to check for an existing
/// accepted manifest without any possibility of accidentally triggering a new
/// one — which a single `getOrCreate` method could not guarantee.
abstract interface class TutorialManifestRepository {
  /// Returns the session carrying an accepted manifest for [preview], or
  /// `null` when none exists.
  ///
  /// Never performs AI work. Safe on widget rebuild, route rebuild, app resume,
  /// and reopen.
  Future<TutorialSession?> loadAccepted(CanonicalPreviewRef preview);

  /// Runs the server-side visual comparison of the original selfie against the
  /// canonical final preview, and persists the accepted result.
  ///
  /// The server resolves both images, the look plan, and the owned-product
  /// snapshot itself; the client supplies only which preview to analyze. The
  /// server reuses an accepted manifest rather than re-analyzing, so a
  /// duplicate call is wasteful but not double-charged.
  Future<TutorialSession> analyze(CanonicalPreviewRef preview);
}
