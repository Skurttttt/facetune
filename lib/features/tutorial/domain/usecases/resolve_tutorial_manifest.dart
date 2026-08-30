import '../entities/canonical_preview_ref.dart';
import '../entities/tutorial_session.dart';
import '../repositories/tutorial_manifest_repository.dart';
import '../repositories/tutorial_session_repository.dart';

/// Opens the tutorial for a canonical preview, analyzing only when necessary.
///
/// This use case exists so manifest reuse is the default path rather than
/// something each caller must remember to check. Analysis is a paid AI call, so
/// it runs only when no usable manifest already exists for this exact preview.
///
/// The ordering is deliberate: check locally, then ask the server (which also
/// reuses), and only then accept that analysis will run. A rebuild that lands
/// here repeatedly costs nothing.
class ResolveTutorialManifest {
  const ResolveTutorialManifest({
    required TutorialManifestRepository manifestRepository,
    required TutorialSessionRepository sessionRepository,
  }) : _manifests = manifestRepository,
       _sessions = sessionRepository;

  final TutorialManifestRepository _manifests;
  final TutorialSessionRepository _sessions;

  Future<TutorialSession> call(CanonicalPreviewRef preview) async {
    final existing = await _sessions.loadForCanonicalPreview(preview);
    if (existing != null && existing.hasReusableManifest) {
      return _sessions.ensureSteps(existing);
    }
    final accepted = await _manifests.loadAccepted(preview);
    if (accepted != null && accepted.hasReusableManifest) {
      return _sessions.ensureSteps(accepted);
    }
    final analyzed = await _manifests.analyze(preview);
    if (!analyzed.hasReusableManifest) {
      // A mismatched or failed manifest is returned as-is. Building steps from
      // it would produce exactly the misleading tutorial the architecture
      // forbids, and retrying would just pay for the same answer again.
      return analyzed;
    }
    return _sessions.ensureSteps(analyzed);
  }
}
