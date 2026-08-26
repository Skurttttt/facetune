/// How the canonical premium final preview is shown alongside a step.
///
/// The canonical preview is the tutorial's exact destination. It is never
/// regenerated and never redrawn by AI, so every mode here must be derivable
/// from the real stored preview by non-generative means.
///
/// Only [fullCanonicalPreview] is supported today. The category-focused modes
/// are declared so the Step Spec contract does not have to change when a
/// reliable non-generative crop exists, but [isSupported] gates them and the
/// plan validator rejects them. Asking a model to redraw a focused target
/// crop is forbidden.
enum TutorialV3TargetReferenceMode {
  fullCanonicalPreview('full_canonical_preview'),
  cheekFocus('cheek_focus'),
  eyeFocus('eye_focus'),
  lipFocus('lip_focus');

  const TutorialV3TargetReferenceMode(this.code);

  final String code;

  /// The modes a plan may currently use.
  static const Set<TutorialV3TargetReferenceMode> supported = {
    TutorialV3TargetReferenceMode.fullCanonicalPreview,
  };

  bool get isSupported => supported.contains(this);

  static TutorialV3TargetReferenceMode? fromCode(String code) {
    for (final mode in values) {
      if (mode.code == code) return mode;
    }
    return null;
  }
}
