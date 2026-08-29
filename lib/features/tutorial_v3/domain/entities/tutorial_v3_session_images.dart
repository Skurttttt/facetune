/// Short-lived signed URLs for the two images a V3 tutorial displays.
///
/// Exactly two, and both already exist before the tutorial starts:
///
/// * [originalSelfieUrl] — the untouched original photograph. Every non-final
///   step draws its overlay on top of this. It is displayed, never rewritten,
///   never re-uploaded, and never replaced by anything a model produced.
/// * [canonicalPreviewUrl] — the premium final preview the tutorial drives
///   toward, shown as the TARGET LOOK reference exactly as it was generated.
///
/// There is deliberately no third image. V3 produces no per-step picture, so
/// there is no intermediate makeup result to sign, cache or display.
class TutorialV3SessionImages {
  const TutorialV3SessionImages({
    required this.originalSelfieUrl,
    required this.canonicalPreviewUrl,
  });

  final String originalSelfieUrl;
  final String canonicalPreviewUrl;
}
