/// Deterministic, owner-scoped storage paths for Tutorial V3 assets.
///
/// The shape is:
///
/// ```text
/// {userId}/analyses/{analysisId}/tutorial-v3/{sessionId}/step_{NNNN}_guideline.{ext}
/// ```
///
/// Three properties matter and are enforced here rather than assumed:
///
/// * The first segment is the owner's id, which is what the `face-images`
///   bucket's storage RLS policy checks
///   (`storage.foldername(name)[1] = auth.uid()`).
/// * The path sits under `{userId}/analyses/{analysisId}`, which is the
///   prefix `delete-history-item` sweeps recursively — so tutorial assets are
///   cleaned up with the rest of the analysis and never orphaned.
/// * The `tutorial-v3` folder keeps guidelines out of `original/`,
///   `generated/` and `kit-generated/`, so a guideline can never overwrite an
///   original selfie or a canonical premium preview.
///
/// There is only one asset kind. V3 generates no intermediate makeup result,
/// so no `_result` path exists to build.
///
/// Validation is segment-by-segment, deliberately not a `startsWith` prefix
/// test: a prefix match accepts `..` traversal and extra segments that
/// resolve outside the session's own folder. This mirrors
/// `isOwnedOriginalPath` in `supabase/functions/_shared/storage_ownership.ts`.
abstract final class TutorialV3StoragePaths {
  static const bucket = 'face-images';
  static const folder = 'tutorial-v3';
  static const guidelineAsset = 'guideline';

  static const allowedExtensions = <String>['png', 'jpg', 'jpeg', 'webp'];

  static final RegExp _fileName = RegExp(r'^step_(\d{4})_(guideline)\.([a-z0-9]+)$');

  /// The directory holding every asset for one session.
  static String sessionDirectory({
    required String userId,
    required String analysisId,
    required String sessionId,
  }) => '$userId/analyses/$analysisId/$folder/$sessionId';

  /// The guideline path for a one-based [stepIndex].
  static String guideline({
    required String userId,
    required String analysisId,
    required String sessionId,
    required int stepIndex,
    String extension = 'png',
  }) {
    if (stepIndex < 1) {
      throw ArgumentError.value(stepIndex, 'stepIndex', 'must be one-based');
    }
    final directory = sessionDirectory(
      userId: userId,
      analysisId: analysisId,
      sessionId: sessionId,
    );
    final number = _padded(stepIndex);
    return '$directory/step_${number}_$guidelineAsset.${extension.toLowerCase()}';
  }

  /// Whether [path] is exactly an owner-scoped guideline for this session,
  /// and optionally for a specific [stepIndex].
  static bool isOwnedAssetPath(
    String path, {
    required String userId,
    required String analysisId,
    required String sessionId,
    int? stepIndex,
  }) {
    final segments = path.split('/');
    if (segments.length != 6 ||
        segments[0] != userId ||
        segments[1] != 'analyses' ||
        segments[2] != analysisId ||
        segments[3] != folder ||
        segments[4] != sessionId) {
      return false;
    }
    final match = _fileName.firstMatch(segments[5]);
    if (match == null) return false;
    if (!allowedExtensions.contains(match.group(3)!.toLowerCase())) {
      return false;
    }
    if (stepIndex != null && match.group(1) != _padded(stepIndex)) return false;
    return true;
  }

  /// The one-based step index encoded in [path], or `null` when [path] is not
  /// a tutorial guideline path.
  static int? stepIndexOf(String path) {
    final segments = path.split('/');
    if (segments.length != 6) return null;
    final match = _fileName.firstMatch(segments[5]);
    if (match == null) return null;
    final number = int.tryParse(match.group(1)!);
    return number == null || number < 1 ? null : number;
  }

  static String _padded(int stepIndex) => stepIndex.toString().padLeft(4, '0');
}
