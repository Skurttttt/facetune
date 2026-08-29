import 'tutorial_v3_source_mode.dart';

/// A reference to the existing premium final preview a tutorial targets.
///
/// This is a pointer, never a copy and never a new image. [generatedImageId]
/// identifies the row in `generated_images` (standard) or
/// `kit_generated_images` (Kit), and [storagePath] is that row's existing
/// private path.
///
/// V3 reads this path and re-signs it for display. It never uploads to it,
/// never overwrites it, and never regenerates the preview for tutorial use.
/// Signed URLs for it are short-lived, so a long session must re-sign rather
/// than cache a URL.
class TutorialV3CanonicalPreview {
  const TutorialV3CanonicalPreview({
    required this.generatedImageId,
    required this.storagePath,
    required this.sourceMode,
  });

  /// The `generated_images` or `kit_generated_images` row id, chosen by
  /// [sourceMode].
  final String generatedImageId;

  /// The existing private storage path of that row. Read-only for V3.
  final String storagePath;

  final TutorialV3SourceMode sourceMode;

  /// Whether [storagePath] sits in the folder [sourceMode]'s previews are
  /// written to.
  ///
  /// Both chains write under the same analysis, so a Kit session pointed at a
  /// `generated/` path would target the standard look for the same face — the
  /// wrong destination, with nothing else on the row to reveal the mix-up.
  bool get matchesSourceModeFolder =>
      storagePath.contains('/${sourceMode.canonicalPreviewFolder}/');
}
