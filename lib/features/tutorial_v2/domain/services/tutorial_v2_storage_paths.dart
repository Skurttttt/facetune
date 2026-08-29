/// Deterministic, owner-scoped storage paths for Tutorial V2 assets.
///
/// The shape is:
///
/// ```text
/// {userId}/analyses/{analysisId}/tutorial-v2/{sessionId}/step_{NNNN}_guideline.{ext}
/// {userId}/analyses/{analysisId}/tutorial-v2/{sessionId}/step_{NNNN}_result.{ext}
/// ```
///
/// Two properties matter and are enforced here rather than assumed:
///
/// * The first segment is the owner's id, which is what the `face-images`
///   bucket's storage RLS policy checks
///   (`storage.foldername(name)[1] = auth.uid()`).
/// * The path sits under `{userId}/analyses/{analysisId}`, which is the
///   prefix `delete-history-item` sweeps recursively — so tutorial assets are
///   cleaned up with the rest of the analysis and never orphaned.
///
/// Validation is segment-by-segment, deliberately not a `startsWith` prefix
/// test: a prefix match accepts `..` traversal and extra segments that
/// resolve outside the session's own folder. This mirrors
/// `isOwnedOriginalPath` in `supabase/functions/_shared/storage_ownership.ts`.
abstract final class TutorialV2StoragePaths {
  static const bucket = 'face-images';
  static const folder = 'tutorial-v2';

  static const guidelineAsset = 'guideline';
  static const resultAsset = 'result';

  static const allowedExtensions = <String>['png', 'jpg', 'jpeg', 'webp'];

  static final RegExp _fileName = RegExp(
    r'^step_(\d{4})_(guideline|result)\.([a-z0-9]+)$',
  );

  /// The directory holding every asset for one session.
  static String sessionDirectory({
    required String userId,
    required String analysisId,
    required String sessionId,
  }) => '$userId/analyses/$analysisId/$folder/$sessionId';

  static String guideline({
    required String userId,
    required String analysisId,
    required String sessionId,
    required int stepIndex,
    String extension = 'png',
  }) => _asset(
    userId: userId,
    analysisId: analysisId,
    sessionId: sessionId,
    stepIndex: stepIndex,
    asset: guidelineAsset,
    extension: extension,
  );

  static String result({
    required String userId,
    required String analysisId,
    required String sessionId,
    required int stepIndex,
    String extension = 'png',
  }) => _asset(
    userId: userId,
    analysisId: analysisId,
    sessionId: sessionId,
    stepIndex: stepIndex,
    asset: resultAsset,
    extension: extension,
  );

  static String _asset({
    required String userId,
    required String analysisId,
    required String sessionId,
    required int stepIndex,
    required String asset,
    required String extension,
  }) {
    if (stepIndex < 0) {
      throw ArgumentError.value(stepIndex, 'stepIndex', 'must not be negative');
    }
    // Step indexes are zero-based in the domain; the file name is
    // one-based and zero-padded so a directory listing sorts naturally.
    final number = (stepIndex + 1).toString().padLeft(4, '0');
    final directory = sessionDirectory(
      userId: userId,
      analysisId: analysisId,
      sessionId: sessionId,
    );
    return '$directory/step_${number}_$asset.${extension.toLowerCase()}';
  }

  /// Whether [path] is exactly an owner-scoped tutorial asset for this
  /// session, and optionally for a specific [stepIndex] and [asset] kind.
  static bool isOwnedAssetPath(
    String path, {
    required String userId,
    required String analysisId,
    required String sessionId,
    int? stepIndex,
    String? asset,
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
    if (asset != null && match.group(2) != asset) return false;
    if (stepIndex != null && match.group(1) != _padded(stepIndex)) return false;
    return true;
  }

  /// The zero-based step index encoded in [path], or `null` when [path] is
  /// not a tutorial asset path.
  static int? stepIndexOf(String path) {
    final segments = path.split('/');
    if (segments.length != 6) return null;
    final match = _fileName.firstMatch(segments[5]);
    if (match == null) return null;
    final number = int.tryParse(match.group(1)!);
    return number == null || number < 1 ? null : number - 1;
  }

  static String _padded(int stepIndex) =>
      (stepIndex + 1).toString().padLeft(4, '0');
}
